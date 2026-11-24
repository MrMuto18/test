--!strict
--[[
	MovementController
	Tactical locomotion for the local character:

	  • Walk / ADS walk / crouch / sprint speeds, eased (no instant snaps)
	  • Sprint (hold Shift / L3): only while moving forward, drains stamina,
	    blocked while aiming or right after firing
	  • Crouch (C / Ctrl / B): toggles; real collision change via HipHeight
	  • Slide: crouch while sprinting fast enough → momentum burst that decays
	    into a crouch; costs stamina; jump cancels it into a slide-hop
	  • Stamina with regen delay + exhaustion lockout; jumps cost stamina
	  • Can't stand up under low ceilings
	  • FOV kicks for sprint/slide through TacticalCamera
	  • Stance + sprint state replicated (throttled) so others see the pose
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)
local Trove = require(Shared.Trove)
local Types = require(Shared.Types)

local TacticalCamera = require(script.Parent.TacticalCamera)

local M = Config.Movement
local KEYS = Config.Combat.Keybinds
local player = Players.LocalPlayer

local MovementController = {}
MovementController.StanceChanged = Signal.new() -- (stance)

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local trove: Trove.Trove? = nil

local stance: Types.Stance = "Stand"
local sprintHeld = false
local sprinting = false
local stamina = M.StaminaMax
local exhausted = false
local lastDrain = 0
local aiming = false
local speedMultiplier = 1
local sprintBlockedUntil = 0
local baseHipHeight = 2
local slideTime = 0
local slideDir = Vector3.zero
local lastSlideEnd = -math.huge
local lastSent = 0
local pendingSend = false
local controls: any = nil
local enabled = true

local function getControls(): any
	if controls then
		return controls
	end
	local ok, result = pcall(function(): any
		local scripts = player:WaitForChild("PlayerScripts")
		local module = scripts:WaitForChild("PlayerModule", 5)
		return if module then (require(module :: ModuleScript) :: any):GetControls() else nil
	end)
	if ok then
		controls = result
	end
	return controls
end

local function replicate()
	local model = character
	if not model then
		return
	end
	model:SetAttribute("Stance", stance)
	model:SetAttribute("Sprinting", sprinting)
	local now = os.clock()
	if now - lastSent >= M.StanceSendInterval then
		lastSent = now
		pendingSend = false
		Net.event(Net.Events.SetStance):FireServer(stance, sprinting)
	else
		pendingSend = true
	end
end

local function blockedAbove(): boolean
	local r = root
	if not r or not character then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Model }
	local height = baseHipHeight + r.Size.Y * 0.5 + 0.6
	return Workspace:Spherecast(r.Position, 0.9, Vector3.new(0, height, 0), params) ~= nil
end

local function setStance(nextStance: Types.Stance): boolean
	local h = humanoid
	if not h or nextStance == stance then
		return false
	end
	if nextStance == "Stand" and blockedAbove() then
		return false
	end
	stance = nextStance
	h.HipHeight = if nextStance == "Stand" then baseHipHeight else baseHipHeight - M.CrouchHipDrop
	if nextStance ~= "Stand" then
		sprinting = false
		TacticalCamera.setFovOffset("Sprint", nil)
	end
	replicate()
	MovementController.StanceChanged:Fire(stance)
	return true
end

local function endSlide(toStance: Types.Stance)
	local c = getControls()
	if c then
		c:Enable()
	end
	TacticalCamera.setFovOffset("Slide", nil)
	lastSlideEnd = os.clock()
	if not setStance(toStance) and stance == "Slide" then
		setStance("Crouch")
	end
end

local function startSlide(): boolean
	local r = root
	local h = humanoid
	if not r or not h then
		return false
	end
	local now = os.clock()
	if stamina < M.SlideCost or now - lastSlideEnd < M.SlideCooldown or h.FloorMaterial == Enum.Material.Air then
		return false
	end
	local v = r.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < M.SlideMinSpeed then
		return false
	end
	slideDir = flat.Unit
	slideTime = 0
	stamina -= M.SlideCost
	lastDrain = now
	setStance("Slide")
	local c = getControls()
	if c then
		c:Disable()
	end
	TacticalCamera.setFovOffset("Slide", M.SlideFovKick)
	return true
end

local function onCrouch()
	if stance == "Stand" then
		if sprinting and startSlide() then
			return
		end
		setStance("Crouch")
	elseif stance == "Crouch" then
		setStance("Stand")
	end
end

local function cameraForward(): Vector3
	local yaw = TacticalCamera.getYaw()
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

local function update(dt: number)
	local h = humanoid
	local r = root
	if not h or not r or h.Health <= 0 or not enabled then
		return
	end
	local now = os.clock()
	local moveDir = h.MoveDirection
	local carrying = character ~= nil and (character :: Model):GetAttribute("CarryingBag") == true

	-- Crouch/slide + jump interplay
	if h.Jump then
		if stance == "Crouch" then
			h.Jump = false
			setStance("Stand")
		elseif stance == "Slide" then
			endSlide("Stand")
		end
	end
	h:SetStateEnabled(Enum.HumanoidStateType.Jumping, stamina >= M.JumpCost and stance ~= "Crouch")

	-- Slide physics: drive the humanoid along the slide direction, decaying.
	if stance == "Slide" then
		slideTime += dt
		local t = math.clamp(slideTime / M.SlideDuration, 0, 1)
		local eased = 1 - (1 - t) * (1 - t)
		h.WalkSpeed = M.SlideSpeed + (M.CrouchSpeed - M.SlideSpeed) * eased
		h:Move(slideDir, false)
		if t >= 1 then
			endSlide("Crouch")
		end
	else
		-- Sprint gate
		local forwardDot = if moveDir.Magnitude > 0.1 then moveDir.Unit:Dot(cameraForward()) else 0
		local canSprint = sprintHeld
			and not carrying
			and stance == "Stand"
			and not aiming
			and not exhausted
			and now >= sprintBlockedUntil
			and forwardDot > M.SprintForwardDot
			and h.FloorMaterial ~= Enum.Material.Air
		if canSprint ~= sprinting then
			sprinting = canSprint
			TacticalCamera.setFovOffset("Sprint", if sprinting then M.SprintFovKick else nil)
			replicate()
		end

		local target = M.WalkSpeed
		if stance == "Crouch" then
			target = M.CrouchSpeed
		elseif sprinting then
			target = M.SprintSpeed
		elseif aiming then
			target = M.AdsSpeed
		end
		target *= speedMultiplier
		if carrying then
			target *= Config.Loot.CarrySpeedMultiplier
		end
		h.WalkSpeed += (target - h.WalkSpeed) * (1 - math.exp(-dt * M.SpeedResponse))
	end

	-- Stamina
	if sprinting then
		stamina = math.max(0, stamina - M.SprintDrain * dt)
		lastDrain = now
		if stamina <= 0 then
			exhausted = true
		end
	elseif now - lastDrain > M.RegenDelay then
		stamina = math.min(M.StaminaMax, stamina + M.StaminaRegen * dt)
	end
	if exhausted and stamina >= M.MinStaminaToSprint * 2 then
		exhausted = false
	end

	if pendingSend and now - lastSent >= M.StanceSendInterval then
		replicate()
	end
end

local function bind()
	ContextActionService:BindAction("MoveSprint", function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			sprintHeld = true
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			sprintHeld = false
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(KEYS.Sprint))

	ContextActionService:BindAction("MoveDropBag", function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin and character and (character :: Model):GetAttribute("CarryingBag") == true then
			Net.event(Net.Events.DropBag):FireServer()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(KEYS.DropBag))

	ContextActionService:BindAction("MoveCrouch", function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			onCrouch()
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(KEYS.Crouch))
end

local function unbind()
	ContextActionService:UnbindAction("MoveSprint")
	ContextActionService:UnbindAction("MoveCrouch")
	ContextActionService:UnbindAction("MoveDropBag")
end

function MovementController.attach(model: Model)
	MovementController.detach()
	local h = model:FindFirstChildOfClass("Humanoid")
	local r = model:FindFirstChild("HumanoidRootPart")
	if not h or not r or not r:IsA("BasePart") then
		return
	end
	character = model
	humanoid = h
	root = r
	enabled = true
	baseHipHeight = h.HipHeight
	stance = "Stand"
	sprinting = false
	sprintHeld = false
	stamina = M.StaminaMax
	exhausted = false
	h.WalkSpeed = M.WalkSpeed

	local t = Trove.new()
	trove = t
	t:Connect(RunService.Heartbeat, update)
	t:Connect(h.StateChanged, function(_, newState: Enum.HumanoidStateType)
		if newState == Enum.HumanoidStateType.Jumping then
			stamina = math.max(0, stamina - M.JumpCost)
			lastDrain = os.clock()
		end
	end)
	t:Connect(h.Died, function()
		MovementController.detach()
	end)
	bind()
	replicate()
end

function MovementController.detach()
	unbind()
	if trove then
		local t = trove
		trove = nil
		t:Clean()
	end
	if stance == "Slide" then
		local c = getControls()
		if c then
			c:Enable()
		end
	end
	TacticalCamera.setFovOffset("Sprint", nil)
	TacticalCamera.setFovOffset("Slide", nil)
	local h = humanoid
	if h and h.Parent then
		h.HipHeight = baseHipHeight
	end
	character = nil
	humanoid = nil
	root = nil
	stance = "Stand"
	sprinting = false
end

-- Vehicles: no sprint/crouch input while seated; stand up first.
function MovementController.setEnabled(value: boolean)
	if enabled == value then
		return
	end
	enabled = value
	if not value then
		unbind()
		if stance == "Slide" then
			endSlide("Stand")
		end
		if stance ~= "Stand" then
			stance = "Stand"
			local h = humanoid
			if h then
				h.HipHeight = baseHipHeight
			end
		end
		sprinting = false
		sprintHeld = false
		TacticalCamera.setFovOffset("Sprint", nil)
		replicate()
	elseif character then
		bind()
	end
end

function MovementController.setAiming(value: boolean)
	aiming = value
end

function MovementController.setSpeedMultiplier(value: number)
	speedMultiplier = value
end

-- Firing or reloading drops you out of sprint for a beat.
function MovementController.interruptSprint(duration: number?)
	sprintBlockedUntil = os.clock() + (duration or 0.3)
end

function MovementController.isSprinting(): boolean
	return sprinting
end

function MovementController.getStance(): Types.Stance
	return stance
end

function MovementController.getStamina01(): number
	return stamina / M.StaminaMax
end

function MovementController.isExhausted(): boolean
	return exhausted
end

return MovementController
