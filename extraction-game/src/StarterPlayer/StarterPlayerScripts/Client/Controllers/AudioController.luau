--!strict
--[[
	AudioController
	SoundGroups (UI / Ambience / World), 2D UI one-shots with pitch variance,
	looping rain bed, distant thunder, and the 3D engine idle on the car.
	Any Config.Audio entry with an empty Id is skipped cleanly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)

local AudioController = {}

local groups: { [string]: SoundGroup } = {}
local sounds: { [string]: Sound } = {}
local rng = Random.new()

local function ensureGroup(name: string, volume: number): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Volume = volume
	group.Parent = SoundService
	return group
end

local function makeSound(name: string, parent: Instance): Sound?
	local def = Config.Audio[name]
	if not def or def.Id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	sound.PlaybackSpeed = def.Speed
	sound.SoundGroup = groups[def.Group]
	sound.Parent = parent
	sounds[name] = sound
	return sound
end

function AudioController.init()
	groups.UI = ensureGroup("UI", 1)
	groups.Ambience = ensureGroup("Ambience", 1)
	groups.World = ensureGroup("World", 1)

	local missing: { string } = {}
	for name, def in Config.Audio do
		if def.Id == "" then
			table.insert(missing, name)
		end
	end
	if #missing > 0 then
		table.sort(missing)
		warn(
			"[Audio] No asset id set for: "
				.. table.concat(missing, ", ")
				.. " — paste rbxassetid:// ids you own into Shared.Config.Audio to enable them."
		)
	end

	for _, name in { "UIHover", "UIClick", "UIBack", "UIDeploy", "UITick", "Thunder" } do
		makeSound(name, SoundService)
	end

	local rain = makeSound("RainLoop", SoundService)
	if rain then
		rain.Looped = true
		rain:Play()
	end

	-- Engine idle lives on the car so it falls off with distance.
	task.spawn(function()
		local safehouse = Workspace:WaitForChild(Config.World.SafehouseName, 60)
		local car = safehouse and safehouse:WaitForChild(Config.World.CarName, 30)
		local bay = car and car:WaitForChild("EngineBay", 30)
		if bay and bay:IsA("BasePart") then
			local engine = makeSound("EngineIdle", bay)
			if engine then
				engine.Looped = true
				engine.RollOffMode = Enum.RollOffMode.InverseTapered
				engine.RollOffMinDistance = 6
				engine.RollOffMaxDistance = 90
				engine:Play()
			end
		end
	end)
end

-- Fire-and-forget 2D one-shot with optional pitch variance (±fraction).
function AudioController.play(name: string, variance: number?)
	local sound = sounds[name]
	local def = Config.Audio[name]
	if not sound or not def then
		return
	end
	local v = variance or 0.04
	sound.PlaybackSpeed = def.Speed * (1 + rng:NextNumber(-v, v))
	SoundService:PlayLocalSound(sound)
end

function AudioController.thunder(intensity: number)
	local sound = sounds.Thunder
	local def = Config.Audio.Thunder
	if not sound or not def then
		return
	end
	sound.Volume = def.Volume * math.clamp(intensity, 0.2, 1.2)
	sound.PlaybackSpeed = def.Speed * rng:NextNumber(0.85, 1.05)
	sound:Play()
end

function AudioController.get(name: string): Sound?
	return sounds[name]
end

-- Ducks the world/ambience while in the menu so UI reads cleanly.
function AudioController.setMenuMix(inMenu: boolean, duration: number?)
	local info = TweenInfo.new(duration or 1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local ambience = groups.Ambience
	local world = groups.World
	if ambience then
		TweenService:Create(ambience, info, { Volume = if inMenu then 0.75 else 1 }):Play()
	end
	if world then
		TweenService:Create(world, info, { Volume = if inMenu then 0.8 else 1 }):Play()
	end
end

return AudioController
