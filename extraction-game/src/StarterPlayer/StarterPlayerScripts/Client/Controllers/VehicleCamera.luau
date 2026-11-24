--!strict
--[[
	VehicleCamera
	Chase camera for the getaway car:

	  • trails the car's heading with lag (feels the slide in a drift)
	  • free-look orbit with mouse / right stick, auto-recentres when idle
	  • pulls back slightly and widens FOV with speed (speed kick)
	  • high-speed micro shake, sphere-cast collision against walls
	  • blends in from whatever camera was active, no cut
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Spring = require(Shared.Spring)

local SettingsController = require(script.Parent.SettingsController)

local VehicleCamera = {}

local RENDER_NAME = "VehicleCamera"
local V = Config.Vehicle

local car: Model? = nil
local root: BasePart? = nil
local running = false
local followYaw = 0
local orbitYaw = 0
local orbitPitch = 0
local lastLook = 0
local gamepadLook = Vector2.zero
local blendFromCF: CFrame? = nil
local blendFromFov = 70
local blendTime = 0
local lastCF = CFrame.identity
local lastFov = 70
local fovSpring = Spring.new(Vector3.new(70, 0, 0), 2.5, 1)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function angleLerp(a: number, b: number, t: number): number
	local diff = math.atan2(math.sin(b - a), math.cos(b - a))
	return a + diff * t
end

local function headingOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function step(dt: number)
	local r = root
	local camera = Workspace.CurrentCamera
	if not r or not r.Parent or not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	local cf = r.CFrame
	local velocity = r.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local speed01 = math.clamp(speed / V.MaxSpeed, 0, 1)

	-- Free look
	local sensitivity = SettingsController.get().Sensitivity
	local delta = UserInputService:GetMouseDelta()
	if delta.Magnitude > 0.5 then
		orbitYaw -= delta.X * 0.004 * sensitivity
		orbitPitch = math.clamp(orbitPitch - delta.Y * 0.004 * sensitivity, -0.5, 0.6)
		lastLook = os.clock()
	end
	if gamepadLook.Magnitude > 0.15 then
		orbitYaw -= gamepadLook.X * 3 * dt
		orbitPitch = math.clamp(orbitPitch + gamepadLook.Y * 2 * dt, -0.5, 0.6)
		lastLook = os.clock()
	end
	if os.clock() - lastLook > V.CameraRecenterDelay then
		local k = 1 - math.exp(-dt * 2.5)
		orbitYaw = angleLerp(orbitYaw, 0, k)
		orbitPitch += (0 - orbitPitch) * k
	end

	-- Heading follow with lag (looser at low speed so parking isn't twitchy).
	followYaw = angleLerp(followYaw, headingOf(cf), 1 - math.exp(-dt * (2 + speed01 * 4)))

	local yaw = followYaw + orbitYaw
	local pitch = -0.13 + orbitPitch
	local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local pivot = cf.Position + Vector3.new(0, V.CameraHeight, 0)
	local offset = rotation:VectorToWorldSpace(Vector3.new(0, V.CameraLift, V.CameraDistance + speed01 * 3.5))

	local hit = Workspace:Spherecast(pivot, 0.6, offset, params)
	local position = if hit then pivot + offset.Unit * math.max(hit.Distance - 0.2, 2) else pivot + offset

	local t = os.clock()
	local shake = speed01 * speed01 * 0.006
	local target = CFrame.lookAt(position, pivot + rotation.LookVector * 6)
		* CFrame.Angles(math.noise(t * 9, 1.7) * shake, math.noise(t * 8, 4.2) * shake, 0)

	fovSpring.Target = Vector3.new(SettingsController.get().FieldOfView + speed01 * V.CameraFovKick, 0, 0)
	local fov = fovSpring:update(dt).X

	local from = blendFromCF
	if from then
		blendTime += dt
		local a = math.clamp(blendTime / 0.55, 0, 1)
		a = a * a * (3 - 2 * a)
		target = from:Lerp(target, a)
		fov = blendFromFov + (fov - blendFromFov) * a
		if a >= 1 then
			blendFromCF = nil
		end
	end

	camera.CFrame = target
	camera.FieldOfView = fov
	lastCF = target
	lastFov = fov
end

function VehicleCamera.init()
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			gamepadLook = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
end

function VehicleCamera.start(carModel: Model, fromCF: CFrame, fromFov: number, character: Model?)
	local r = carModel.PrimaryPart
	if not r then
		return
	end
	car = carModel
	root = r
	followYaw = headingOf(r.CFrame)
	orbitYaw, orbitPitch = 0, 0
	lastLook = 0
	blendFromCF = fromCF
	blendFromFov = fromFov
	blendTime = 0
	fovSpring:reset(Vector3.new(fromFov, 0, 0))
	local ignore: { Instance } = { carModel }
	if character then
		table.insert(ignore, character)
	end
	for _, name in { "ClientFX", "WeaponFX", "SkidMarks" } do
		local f = Workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	params.FilterDescendantsInstances = ignore
	if not running then
		running = true
		RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, step)
	end
end

function VehicleCamera.stop(): (CFrame, number, number)
	if running then
		running = false
		RunService:UnbindFromRenderStep(RENDER_NAME)
	end
	car = nil
	root = nil
	return lastCF, lastFov, followYaw + orbitYaw
end

function VehicleCamera.isRunning(): boolean
	return running
end

return VehicleCamera
