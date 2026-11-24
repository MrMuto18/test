--!strict
--[[
	TacticalCamera
	Over-the-shoulder third-person camera.

	Phase 1: mouse/stick look, spring-smoothed pivot + shoulder, shoulder swap
	(V / D-pad right), sphere-cast collision, strafe roll, FOV spring, body
	turns to heading (AlignOrientation), close-camera character fade.

	Phase 2 adds:
	  • ADS: shoulder tucks in (AdsShoulderOffset), FOV × weapon multiplier,
	    sensitivity scaled down, timed by the weapon's AdsTime
	  • Recoil: permanent climb on pitch/yaw + a damped visual kick spring;
	    climb partially recovers once you stop firing
	  • Named FOV offsets (sprint / slide kicks) on the same FOV spring
	  • Head bob tied to distance travelled (not time), stronger when sprinting

	evaluate(dt) computes the camera without writing it; the deploy transition
	blends from the menu shot into it with zero cut.
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

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

local yaw = 0
local pitch = 0
local bodyYaw = 0
local shoulder = 1
local currentDistance = C.ShoulderOffset.Z
local gamepadLook = Vector2.zero
local attached = false
local running = false

-- ADS
local aimTarget = 0
local aim = 0
local adsTime = 0.2
local adsFovMultiplier = 0.75

-- Recoil
local recoilDebt = 0
local lastRecoil = 0

-- FOV offsets (sprint, slide...)
local fovOffsets: { [string]: number } = {}

-- Bob
local bobPhase = 0
local bobWeight = 0

local pivotSpring = Spring.new(Vector3.zero, C.PivotFrequency, 1)
local shoulderSpring = Spring.new(Vector3.new(1, 0, 0), C.ShoulderFrequency, C.ShoulderDamping)
local rollSpring = Spring.new(Vector3.zero, 3, 0.7)
local fovSpring = Spring.new(Vector3.new(72, 0, 0), C.FovFrequency, 1)
local kickSpring = Spring.new(Vector3.zero, C.RecoilFrequency, C.RecoilDamping)

local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude

local lastCF = CFrame.identity
local lastFov = 72

local function sphereCast(origin: Vector3, offset: Vector3): Vector3
	if offset.Magnitude < 1e-3 then
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
	local sensitivity = settings.Sensitivity * (1 + (C.AdsSensitivity - 1) * aim)
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		local delta = UserInputService:GetMouseDelta()
		local k = C.MouseRadiansPerPixel * sensitivity
		yaw -= delta.X * k
		pitch -= delta.Y * k
	end
	if gamepadLook.Magnitude > C.GamepadDeadzone then
		local speed = C.GamepadRadiansPerSecond * sensitivity * dt
		yaw -= gamepadLook.X * speed
		pitch += gamepadLook.Y * speed
	end

	-- Recover part of the recoil climb once firing stops.
	if recoilDebt > 0 and os.clock() - lastRecoil > C.RecoilRecoveryDelay then
		local step = math.min(recoilDebt, C.RecoilRecoveryRate * dt)
		recoilDebt -= step
		pitch -= step
	end
	pitch = math.clamp(pitch, math.rad(C.MinPitch), math.rad(C.MaxPitch))
end

local function updateBody(dt: number)
	local h = humanoid
	local constraint = align
	if not h or not constraint then
		return
	end
	if h.MoveDirection.Magnitude > 0.1 or aim > 0.2 then
		bodyYaw = yaw
	else
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

	aim += (aimTarget - aim) * (1 - math.exp(-dt * 3 / math.max(adsTime, 0.05)))

	readInput(dt)
	updateBody(dt)

	pivotSpring.Target = r.Position + Vector3.new(0, C.PivotHeight, 0)
	local pivot = pivotSpring:update(dt)

	shoulderSpring.Target = Vector3.new(shoulder, 0, 0)
	local side = shoulderSpring:update(dt).X

	local kick = kickSpring:update(dt)
	local rotation = CFrame.Angles(0, yaw + kick.Y, 0) * CFrame.Angles(pitch + kick.X, 0, 0)
	local offset = C.ShoulderOffset:Lerp(C.AdsShoulderOffset, aim)

	-- Head bob: phase advances with ground distance so it matches footsteps.
	local velocity = r.AssemblyLinearVelocity
	local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local h = humanoid
	local grounded = h ~= nil and h.FloorMaterial ~= Enum.Material.Air
	bobPhase += flatSpeed * dt * C.BobFrequency * math.pi
	local targetWeight = if grounded then math.clamp(flatSpeed / 23, 0, 1.2) * (1 - aim * 0.8) else 0
	bobWeight += (targetWeight - bobWeight) * (1 - math.exp(-dt * 8))
	local bobY = math.abs(math.sin(bobPhase)) * C.BobAmplitude * bobWeight
	local bobRoll = math.sin(bobPhase) * C.BobRoll * bobWeight

	local lateral = rotation.RightVector * (offset.X * side) + rotation.UpVector * (offset.Y - bobY)
	local back = rotation.LookVector * -offset.Z

	local shoulderPoint = sphereCast(pivot, lateral)
	local desired = sphereCast(shoulderPoint, back)
	local desiredDistance = (desired - shoulderPoint).Magnitude
	if desiredDistance < currentDistance then
		currentDistance = desiredDistance
	else
		currentDistance += (desiredDistance - currentDistance) * (1 - math.exp(-dt * 4))
	end
	-- ADS should tuck in quickly, not ease out like collision.
	currentDistance = math.min(currentDistance, offset.Z)
	local cameraPosition = shoulderPoint + rotation.LookVector * -currentDistance

	local lateralSpeed = rotation.RightVector:Dot(velocity)
	rollSpring.Target = Vector3.new(math.clamp(-lateralSpeed * C.RollPerStudPerSecond, -C.MaxRoll, C.MaxRoll), 0, 0)
	local roll = rollSpring:update(dt).X + bobRoll + kick.Z

	local fovTarget = SettingsController.get().FieldOfView * (1 + (adsFovMultiplier - 1) * aim)
	for _, extra in fovOffsets do
		fovTarget += extra * (1 - aim)
	end
	fovSpring.Target = Vector3.new(fovTarget, 0, 0)
	local fov = fovSpring:update(dt).X

	local fade = math.clamp((C.CloseFadeStart - currentDistance) / (C.CloseFadeStart - C.CloseFadeEnd), 0, 1)
	setCharacterFade(fade * 0.85)

	lastCF = CFrame.new(cameraPosition) * rotation.Rotation * CFrame.Angles(0, 0, roll)
	lastFov = fov
	return lastCF, lastFov
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
	aim, aimTarget = 0, 0
	recoilDebt = 0
	table.clear(fovOffsets)
	currentDistance = C.ShoulderOffset.Z
	pivotSpring:reset(r.Position + Vector3.new(0, C.PivotHeight, 0))
	shoulderSpring:reset(Vector3.new(1, 0, 0))
	rollSpring:reset(Vector3.zero)
	kickSpring:reset(Vector3.zero)
	fovSpring:reset(Vector3.new(SettingsController.get().FieldOfView, 0, 0))
	local ignore: { Instance } = { model }
	for _, name in { "ClientFX", "WeaponFX" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	castParams.FilterDescendantsInstances = ignore

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
end

function TacticalCamera.stop()
	if running then
		running = false
		RunService:UnbindFromRenderStep(RENDER_NAME)
		ContextActionService:UnbindAction(SWAP_ACTION)
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
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

--------------------------------------------------------------------------------
-- Phase 2 hooks (weapons / movement)
--------------------------------------------------------------------------------
function TacticalCamera.setAiming(aiming: boolean, fovMultiplier: number?, time: number?)
	aimTarget = if aiming then 1 else 0
	if fovMultiplier then
		adsFovMultiplier = fovMultiplier
	end
	if time then
		adsTime = time
	end
end

function TacticalCamera.getAim(): number
	return aim
end

-- pitchDeg climbs permanently (partially recovered later); yawDeg is random drift.
function TacticalCamera.addRecoil(pitchDeg: number, yawDeg: number, recoveryShare: number)
	local p = math.rad(pitchDeg)
	local y = math.rad(yawDeg)
	pitch += p
	yaw += y
	recoilDebt += p * math.clamp(recoveryShare, 0, 1)
	lastRecoil = os.clock()
	-- Visual punch on top of the real climb.
	kickSpring:impulse(Vector3.new(p * 14, y * 10, (math.random() - 0.5) * p * 6))
end

function TacticalCamera.setFovOffset(key: string, value: number?)
	fovOffsets[key] = value
end

function TacticalCamera.getPitch(): number
	return pitch
end

function TacticalCamera.getYaw(): number
	return yaw
end

function TacticalCamera.getCFrame(): CFrame
	return lastCF
end

function TacticalCamera.getFieldOfView(): number
	return lastFov
end

function TacticalCamera.isAttached(): boolean
	return attached
end

function TacticalCamera.isRunning(): boolean
	return running
end

return TacticalCamera
