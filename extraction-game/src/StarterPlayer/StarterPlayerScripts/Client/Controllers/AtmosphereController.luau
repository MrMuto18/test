--!strict
--[[
	AtmosphereController
	Everything weather/ambience that should run per-client:

	  • Camera-following rain volume (velocity-aligned streaks, wind drift)
	  • Ground splashes snapped to the surface under the camera
	  • Lightning: double-strike exposure flash + delayed thunder
	  • Flicker for anything tagged "FlickerLight" (lamps, neon sign, bulbs)
	  • Idle engine rumble + lope on the parked getaway car
	  • Quality preset toggles for mist, volumetric beams, exhaust smoke and
	    shadow-casting lights
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)

type Hooks = {
	Flash: (amount: number) -> (),
	Thunder: (intensity: number) -> (),
	EngineSound: () -> Sound?,
}

local AtmosphereController = {}

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local RAIN_COLOR = Color3.fromRGB(200, 210, 225)

local preset: Types.QualityPreset = Config.Quality.High
local hooks: Hooks
local fxFolder: Folder
local rainPart: BasePart
local rainEmitter: ParticleEmitter
local splashPart: BasePart
local splashEmitter: ParticleEmitter
local rayParams = RaycastParams.new()
local groundY = 0
local groundTimer = 0
local rng = Random.new()

local carRoot: BasePart? = nil
local carBase: CFrame? = nil

local function makeFxPart(name: string, size: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.CastShadow = false
	part.Parent = fxFolder
	return part
end

local function buildRain()
	local area = Config.Weather.RainAreaSize
	rainPart = makeFxPart("RainVolume", Vector3.new(area, 1, area))
	rainEmitter = Instance.new("ParticleEmitter")
	rainEmitter.Name = "Rain"
	rainEmitter.Texture = SPARK_TEXTURE
	rainEmitter.EmissionDirection = Enum.NormalId.Bottom
	rainEmitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	rainEmitter.Speed = Config.Weather.RainSpeed
	rainEmitter.SpreadAngle = Vector2.new(3, 3)
	rainEmitter.Acceleration = Config.Weather.Wind
	rainEmitter.Lifetime = NumberRange.new(0.55, 0.75)
	rainEmitter.Size = NumberSequence.new(0.16)
	rainEmitter.Squash = NumberSequence.new(-2.6)
	rainEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.85, 0.62),
		NumberSequenceKeypoint.new(1, 1),
	})
	rainEmitter.Color = ColorSequence.new(RAIN_COLOR)
	rainEmitter.LightEmission = 0.15
	rainEmitter.LightInfluence = 0.9
	rainEmitter.Rate = preset.RainRate
	rainEmitter.Parent = rainPart

	splashPart = makeFxPart("SplashVolume", Vector3.new(40, 0.2, 40))
	splashEmitter = Instance.new("ParticleEmitter")
	splashEmitter.Name = "Splash"
	splashEmitter.Texture = SPARK_TEXTURE
	splashEmitter.EmissionDirection = Enum.NormalId.Top
	splashEmitter.Speed = NumberRange.new(2, 4)
	splashEmitter.SpreadAngle = Vector2.new(60, 60)
	splashEmitter.Acceleration = Vector3.new(0, -30, 0)
	splashEmitter.Lifetime = NumberRange.new(0.12, 0.22)
	splashEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 0.22),
	})
	splashEmitter.Squash = NumberSequence.new(0.8)
	splashEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	splashEmitter.Color = ColorSequence.new(RAIN_COLOR)
	splashEmitter.LightInfluence = 1
	splashEmitter.Rate = preset.RainRate * 0.35
	splashEmitter.Parent = splashPart
end

local function refreshRayFilter()
	local ignore: { Instance } = { fxFolder }
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(ignore, character)
	end
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignore
end

local function followCamera(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cf = camera.CFrame
	local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if flatLook.Magnitude > 1e-3 then
		flatLook = flatLook.Unit
	end
	-- Bias the volume ahead of the view and upwind so streaks fill the frame.
	local wind = Config.Weather.Wind
	local upwind = -Vector3.new(wind.X, 0, wind.Z) * 0.25
	rainPart.CFrame = CFrame.new(cf.Position + Vector3.new(0, Config.Weather.RainHeight, 0) + flatLook * 18 + upwind)

	groundTimer -= dt
	if groundTimer <= 0 then
		groundTimer = 0.25
		refreshRayFilter()
		local hit = Workspace:Raycast(cf.Position, Vector3.new(0, -200, 0), rayParams)
		if hit then
			groundY = hit.Position.Y
		end
	end
	splashPart.CFrame = CFrame.new(cf.Position.X + flatLook.X * 10, groundY + 0.15, cf.Position.Z + flatLook.Z * 10)
end

--------------------------------------------------------------------------------
-- Flicker
--------------------------------------------------------------------------------
type FlickerTarget = {
	Lights: { Light },
	Beams: { Beam },
	Neon: { BasePart },
	NeonColors: { Color3 },
	Guis: { SurfaceGui },
	GuiBrightness: { number },
}

local function collectFlicker(root: Instance): FlickerTarget
	local target: FlickerTarget = { Lights = {}, Beams = {}, Neon = {}, NeonColors = {}, Guis = {}, GuiBrightness = {} }
	local candidates = root:GetDescendants()
	table.insert(candidates, root)
	for _, d in candidates do
		if d:IsA("Light") then
			table.insert(target.Lights, d)
		elseif d:IsA("Beam") then
			table.insert(target.Beams, d)
		elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			table.insert(target.Neon, d)
			table.insert(target.NeonColors, d.Color)
		elseif d:IsA("SurfaceGui") then
			table.insert(target.Guis, d)
			table.insert(target.GuiBrightness, d.Brightness)
		end
	end
	return target
end

local function setFlickerOn(target: FlickerTarget, on: boolean, level: number)
	for _, light in target.Lights do
		light.Enabled = on
	end
	for _, beam in target.Beams do
		beam.Enabled = on and preset.Beams
	end
	for i, part in target.Neon do
		local base = target.NeonColors[i]
		part.Color = if on then base else base:Lerp(Color3.new(0, 0, 0), 0.82 * level)
	end
	for i, gui in target.Guis do
		gui.Brightness = if on then target.GuiBrightness[i] else target.GuiBrightness[i] * (1 - 0.85 * level)
	end
end

local function runFlicker(instance: Instance)
	local target = collectFlicker(instance)
	local isSign = instance:GetAttribute("FlickerStyle") == "Sign"
	task.spawn(function()
		while instance.Parent do
			-- Long stable stretch, then a burst of stutters.
			task.wait(if isSign then rng:NextNumber(5, 14) else rng:NextNumber(2.5, 8))
			local bursts = rng:NextInteger(2, if isSign then 4 else 7)
			for _ = 1, bursts do
				if not instance.Parent then
					return
				end
				setFlickerOn(target, false, rng:NextNumber(0.6, 1))
				task.wait(rng:NextNumber(0.03, 0.11))
				setFlickerOn(target, true, 1)
				task.wait(rng:NextNumber(0.04, 0.25))
			end
			-- Occasional long dropout on bad lamps.
			if not isSign and rng:NextNumber() < 0.18 then
				setFlickerOn(target, false, 1)
				task.wait(rng:NextNumber(0.4, 1.4))
				setFlickerOn(target, true, 1)
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Lightning
--------------------------------------------------------------------------------
local function runLightning()
	task.spawn(function()
		local interval = Config.Weather.LightningInterval
		while true do
			task.wait(rng:NextNumber(interval.Min, interval.Max))
			if preset.Lightning then
				local strength = rng:NextNumber(0.6, 1.25)
				hooks.Flash(1.1 * strength)
				task.wait(rng:NextNumber(0.07, 0.14))
				hooks.Flash(0.65 * strength)
				if rng:NextNumber() < 0.5 then
					task.wait(rng:NextNumber(0.12, 0.25))
					hooks.Flash(0.4 * strength)
				end
				local delay = Config.Weather.ThunderDelay
				task.delay(rng:NextNumber(delay.Min, delay.Max), hooks.Thunder, strength)
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Car idle
--------------------------------------------------------------------------------
local function bindCar()
	task.spawn(function()
		local safehouse = Workspace:WaitForChild(Config.World.SafehouseName, 60)
		local car = safehouse and safehouse:WaitForChild(Config.World.CarName, 30)
		local root = car and car:WaitForChild("Root", 30)
		if root and root:IsA("BasePart") and root.Anchored then
			carRoot = root
			carBase = root.CFrame
		end
	end)
end

local function idleCar()
	local root = carRoot
	local base = carBase
	local camera = Workspace.CurrentCamera
	if not root or not base or not camera then
		return
	end
	if (camera.CFrame.Position - base.Position).Magnitude > 140 then
		return
	end
	local t = os.clock()
	-- Muscle-car cam lope (~2.2 Hz) on top of high-frequency rumble.
	local lope = math.sin(t * 2.2 * 2 * math.pi) * math.sin(t * 0.7) * 0.5 + 0.5
	local rumble = math.noise(t * 22, 0.3) * 0.012
	local roll = math.noise(t * 17, 4.1) * 0.0016 + (lope - 0.5) * 0.0012
	local pitch = math.noise(t * 19, 9.2) * 0.0012
	root.CFrame = base * CFrame.new(0, rumble + lope * 0.004, 0) * CFrame.Angles(pitch, 0, roll)

	local engine = hooks.EngineSound()
	if engine then
		local def = Config.Audio.EngineIdle
		engine.PlaybackSpeed = def.Speed * (0.97 + lope * 0.05)
	end
end

--------------------------------------------------------------------------------
-- Quality
--------------------------------------------------------------------------------
local function applyTagged(tag: string, apply: (Instance) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		apply(instance)
	end
end

local function applyPresetToInstance(tag: string, instance: Instance)
	if tag == "GroundMist" and instance:IsA("ParticleEmitter") then
		instance.Enabled = preset.GroundMist
	elseif tag == "VolumetricBeam" and instance:IsA("Beam") then
		instance.Enabled = preset.Beams
	elseif tag == "ExhaustSmoke" and instance:IsA("ParticleEmitter") then
		instance.Enabled = preset.ExhaustSmoke
	elseif tag == "ShadowLight" and instance:IsA("Light") then
		instance.Shadows = preset.LightShadows
	end
end

local QUALITY_TAGS = { "GroundMist", "VolumetricBeam", "ExhaustSmoke", "ShadowLight" }

function AtmosphereController.applyQuality(quality: Types.QualityLevel)
	preset = Config.Quality[quality] or Config.Quality.High
	if rainEmitter then
		rainEmitter.Rate = preset.RainRate
		splashEmitter.Rate = preset.RainRate * 0.35
		splashEmitter.Enabled = preset.Splashes
	end
	for _, tag in QUALITY_TAGS do
		applyTagged(tag, function(instance: Instance)
			applyPresetToInstance(tag, instance)
		end)
	end
end

function AtmosphereController.init(injected: Hooks)
	hooks = injected
	local folder = Instance.new("Folder")
	folder.Name = "ClientFX"
	folder.Parent = Workspace
	fxFolder = folder

	buildRain()
	refreshRayFilter()

	for _, instance in CollectionService:GetTagged("FlickerLight") do
		runFlicker(instance)
	end
	CollectionService:GetInstanceAddedSignal("FlickerLight"):Connect(runFlicker)

	-- Late-streamed tagged instances still get the active preset.
	for _, tag in QUALITY_TAGS do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance)
			applyPresetToInstance(tag, instance)
		end)
	end

	runLightning()
	bindCar()

	RunService:BindToRenderStep("Atmosphere", Enum.RenderPriority.Camera.Value + 10, function(dt: number)
		followCamera(dt)
		idleCar()
	end)
end

return AtmosphereController
