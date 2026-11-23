--!strict
--[[
	TacticalCamera
	Over-the-shoulder third-person camera (Phase 2 layers ADS, recoil springs
	and sprint FOV on top of this).

	• Mouse / right-stick yaw + pitch with user sensitivity
	• Spring-smoothed pivot follow and shoulder offset
	• Shoulder swap (V / D-pad right) with a springy slide
	• Sphere-cast collision: snaps in instantly, eases back out
	• Strafe roll sway driven by lateral velocity
	• FOV spring toward the player's FOV setting
	• Character turns to the camera heading while moving (AlignOrientation)
	• Fades the character out when the camera is forced very close

	evaluate(dt) computes the camera without writing it, which is what lets
	the deploy transition blend from the menu shot into the live tactical
	camera with zero cut.
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Spring = require(Shared.Spring)
local Trove = require(Shared.Trove)

local SettingsController = require(script.Parent.SettingsController)

local TacticalCamera = {}

local RENDER_NAME = "TacticalCamera"
local SWAP_ACTION = "TacticalShoulderSwap"
local C = Config.Camera.Tactical

local character: Model? = nil
local root: BasePart? = nil
local humanoid: Humanoid? = nil
local align: AlignOrientation? = nil
local trove: Trove.Trove? = nil
local reticle: ScreenGui? = nil

local yaw = 0
local pitch = 0
local bodyYaw = 0
local shoulder = 1
local currentDistance = C.ShoulderOffset.Z
local gamepadLook = Vector2.zero
local attached = false
local running = false

local pivotSpring = Spring.new(Vector3.zero, C.PivotFrequency, 1)
local shoulderSpring = Spring.new(Vector3.new(1, 0, 0), C.ShoulderFrequency, C.ShoulderDamping)
local rollSpring = Spring.new(Vector3.zero, 3, 0.7)
local fovSpring = Spring.new(Vector3.new(72, 0, 0), C.FovFrequency, 1)

local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude

local lastCF = CFrame.identity
local lastFov = 72

local function sphereCast(origin: Vector3, offset: Vector3): Vector3
	local length = offset.Magnitude
	if length < 1e-3 then
		return origin + offset
	end
	local result = Workspace:Spherecast(origin, C.CollisionRadius, offset, castParams)
	if result then
		return origin + offset.Unit * math.max(result.Distance - 0.05, 0)
	end
	return origin + offset
end

local function setCharacterFade(alpha: number)
	local model = character
	if not model then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = alpha
		end
	end
end

local function readInput(dt: number)
	local settings = SettingsController.get()
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		local delta = UserInputService:GetMouseDelta()
		local k = C.MouseRadiansPerPixel * settings.Sensitivity
		yaw -= delta.X * k
		pitch -= delta.Y * k
	end
	if gamepadLook.Magnitude > C.GamepadDeadzone then
		local speed = C.GamepadRadiansPerSecond * settings.Sensitivity * dt
		yaw -= gamepadLook.X * speed
		pitch += gamepadLook.Y * speed
	end
	pitch = math.clamp(pitch, math.rad(C.MinPitch), math.rad(C.MaxPitch))
end

local function updateBody(dt: number)
	local h = humanoid
	local constraint = align
	if not h or not constraint then
		return
	end
	if h.MoveDirection.Magnitude > 0.1 then
		bodyYaw = yaw
	else
		-- Idle free-look; turn the body only when looking far over the shoulder.
		local diff = math.atan2(math.sin(yaw - bodyYaw), math.cos(yaw - bodyYaw))
		if math.abs(diff) > math.rad(100) then
			bodyYaw += diff * math.min(1, dt * 6)
		end
	end
	constraint.CFrame = CFrame.Angles(0, bodyYaw, 0)
end

function TacticalCamera.evaluate(dt: number): (CFrame, number)
	local r = root
	if not r or not r.Parent then
		return lastCF, lastFov
	end

	readInput(dt)
	updateBody(dt)

	pivotSpring.Target = r.Position + Vector3.new(0, C.PivotHeight, 0)
	local pivot = pivotSpring:update(dt)

	shoulderSpring.Target = Vector3.new(shoulder, 0, 0)
	local side = shoulderSpring:update(dt).X

	local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local offset = C.ShoulderOffset
	local lateral = rotation.RightVector * (offset.X * side) + rotation.UpVector * offset.Y
	local back = rotation.LookVector * -offset.Z

	local shoulderPoint = sphereCast(pivot, lateral)
	local desired = sphereCast(shoulderPoint, back)
	local desiredDistance = (desired - shoulderPoint).Magnitude
	if desiredDistance < currentDistance then
		currentDistance = desiredDistance
	else
		currentDistance += (desiredDistance - currentDistance) * (1 - math.exp(-dt * 4))
	end
	local cameraPosition = shoulderPoint + rotation.LookVector * -currentDistance

	-- Strafe roll
	local lateralSpeed = rotation.RightVector:Dot(r.AssemblyLinearVelocity)
	rollSpring.Target = Vector3.new(math.clamp(-lateralSpeed * C.RollPerStudPerSecond, -C.MaxRoll, C.MaxRoll), 0, 0)
	local roll = rollSpring:update(dt).X

	fovSpring.Target = Vector3.new(SettingsController.get().FieldOfView, 0, 0)
	local fov = fovSpring:update(dt).X

	local fade = math.clamp((C.CloseFadeStart - currentDistance) / (C.CloseFadeStart - C.CloseFadeEnd), 0, 1)
	setCharacterFade(fade * 0.85)

	lastCF = CFrame.new(cameraPosition) * rotation.Rotation * CFrame.Angles(0, 0, roll)
	lastFov = fov
	return lastCF, lastFov
end

local function buildReticle(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "TacticalReticle"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(4, 4)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BackgroundTransparency = 1
	dot.BorderSizePixel = 0
	dot.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 1
	stroke.Thickness = 1
	stroke.Parent = dot
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

-- Binds to a freshly spawned character. Call before evaluate()/start().
function TacticalCamera.attach(model: Model)
	TacticalCamera.detach()
	local r = model:WaitForChild("HumanoidRootPart", 5)
	local h = model:FindFirstChildOfClass("Humanoid")
	if not r or not r:IsA("BasePart") or not h then
		warn("[TacticalCamera] character missing HumanoidRootPart/Humanoid")
		return
	end
	character = model
	root = r
	humanoid = h
	local t = Trove.new()
	trove = t

	local look = r.CFrame.LookVector
	yaw = math.atan2(-look.X, -look.Z)
	bodyYaw = yaw
	pitch = math.rad(-8)
	shoulder = 1
	currentDistance = C.ShoulderOffset.Z
	pivotSpring:reset(r.Position + Vector3.new(0, C.PivotHeight, 0))
	shoulderSpring:reset(Vector3.new(1, 0, 0))
	rollSpring:reset(Vector3.zero)
	fovSpring:reset(Vector3.new(SettingsController.get().FieldOfView, 0, 0))
	castParams.FilterDescendantsInstances = { model, Workspace:FindFirstChild("ClientFX") or model }

	h.AutoRotate = false
	local attachment = r:FindFirstChild("RootAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		local created = Instance.new("Attachment")
		created.Name = "RootAttachment"
		created.Parent = r
		attachment = created
	end
	local constraint = Instance.new("AlignOrientation")
	constraint.Name = "TacticalFacing"
	constraint.Mode = Enum.OrientationAlignmentMode.OneAttachment
	constraint.Attachment0 = attachment :: Attachment
	constraint.Responsiveness = C.BodyResponsiveness
	constraint.MaxTorque = math.huge
	constraint.MaxAngularVelocity = math.huge
	constraint.RigidityEnabled = false
	constraint.CFrame = CFrame.Angles(0, yaw, 0)
	constraint.Parent = r
	align = constraint
	t:Add(constraint)

	t:Connect(UserInputService.InputChanged, function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			gamepadLook = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	t:Connect(model.AncestryChanged, function(_, parent: Instance?)
		if parent == nil then
			TacticalCamera.detach()
		end
	end)

	attached = true
end

function TacticalCamera.start()
	if not attached or running then
		return
	end
	running = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	ContextActionService:BindAction(SWAP_ACTION, function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			shoulder = -shoulder
			-- Small roll kick sells the weight of the swap.
			rollSpring:impulse(Vector3.new(shoulder * 0.06, 0, 0))
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(Config.Keybinds.ShoulderSwap))

	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		local cf, fov = TacticalCamera.evaluate(dt)
		camera.CFrame = cf
		camera.FieldOfView = fov
	end)

	local gui = reticle or buildReticle()
	reticle = gui
	gui.Enabled = true
	local dot = gui:FindFirstChild("Dot")
	if dot and dot:IsA("Frame") then
		dot.BackgroundTransparency = 1
		TweenService:Create(dot, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { BackgroundTransparency = 0.15 }):Play()
		local stroke = dot:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 0.6 }):Play()
		end
	end
end

function TacticalCamera.stop()
	if running then
		running = false
		RunService:UnbindFromRenderStep(RENDER_NAME)
		ContextActionService:UnbindAction(SWAP_ACTION)
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	if reticle then
		reticle.Enabled = false
	end
end

function TacticalCamera.detach()
	TacticalCamera.stop()
	if trove then
		local t = trove
		trove = nil
		t:Clean()
	end
	setCharacterFade(0)
	local h = humanoid
	if h and h.Parent then
		h.AutoRotate = true
	end
	character = nil
	root = nil
	humanoid = nil
	align = nil
	attached = false
end

function TacticalCamera.isAttached(): boolean
	return attached
end

function TacticalCamera.isRunning(): boolean
	return running
end

return TacticalCamera
