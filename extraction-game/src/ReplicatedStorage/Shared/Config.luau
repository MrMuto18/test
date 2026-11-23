--!strict
--[[
	Config
	Single source of truth for every tunable shared by server and client.
	Change values here; no other file hard-codes gameplay or look-dev numbers.
]]

local Types = require(script.Parent.Types)

local Config = {}

--------------------------------------------------------------------------------
-- Branding
--------------------------------------------------------------------------------
Config.Branding = {
	Title = "ZABOUR",
	Subtitle = "TACTICAL EXTRACTION",
	Location = "SAFEHOUSE  //  SECTOR 7",
	Build = "BUILD 0.1.0  ·  PHASE 1",
	PlateText = "ZBR 077",
	SignText = "ZABOUR  24H",
}

--------------------------------------------------------------------------------
-- World layout
--------------------------------------------------------------------------------
Config.World = {
	SafehouseName = "Safehouse",
	CarName = "Zabour",
	-- Everything in the safehouse is built relative to this frame.
	-- Lifted 0.2 studs so a leftover template Baseplate (top at y=0) cannot z-fight.
	Origin = CFrame.new(0, 0.2, 0),
	-- Car pose inside the safehouse (relative to Origin). Front faces the menu camera.
	CarPose = CFrame.new(-2, 0, 5) * CFrame.Angles(0, math.rad(-25), 0),
}

--------------------------------------------------------------------------------
-- Lighting / post-processing (gameplay grade). Applied by LightingService.
--------------------------------------------------------------------------------
Config.Lighting = {
	ClockTime = 18.35,
	GeographicLatitude = 38,
	Brightness = 1.6,
	ExposureCompensation = -0.15,
	EnvironmentDiffuseScale = 0.85,
	EnvironmentSpecularScale = 1.0,
	ShadowSoftness = 0.2,
	Ambient = Color3.fromRGB(22, 24, 30),
	OutdoorAmbient = Color3.fromRGB(70, 74, 86),
	ColorShiftTop = Color3.fromRGB(255, 196, 150),
	ColorShiftBottom = Color3.fromRGB(30, 40, 58),

	Atmosphere = {
		Density = 0.42,
		Offset = 0.18,
		Color = Color3.fromRGB(128, 134, 146),
		Decay = Color3.fromRGB(92, 80, 72),
		Glare = 0.12,
		Haze = 2.2,
	},
	Clouds = {
		Cover = 0.82,
		Density = 0.75,
		Color = Color3.fromRGB(104, 110, 122),
	},
	ColorCorrection = {
		Brightness = -0.03,
		Contrast = 0.2,
		Saturation = -0.25,
		TintColor = Color3.fromRGB(255, 243, 230),
	},
	Bloom = {
		Intensity = 0.7,
		Size = 30,
		Threshold = 1.35,
	},
	SunRays = {
		Intensity = 0.035,
		Spread = 0.6,
	},
	DepthOfField = {
		FarIntensity = 0.18,
		FocusDistance = 55,
		InFocusRadius = 70,
		NearIntensity = 0,
	},
}

-- Menu grade: the client blends from this to Config.Lighting while deploying.
Config.MenuGrade = {
	FarIntensity = 0.55,
	NearIntensity = 0.7,
	Contrast = 0.26,
	Saturation = -0.32,
	ExposureCompensation = -0.25,
}

--------------------------------------------------------------------------------
-- Cameras
--------------------------------------------------------------------------------
Config.Camera = {
	Menu = {
		BreathPosition = 0.12, -- studs
		BreathRotation = 0.45, -- degrees
		BreathSpeed = 0.16, -- noise frequency multiplier
		ParallaxYaw = 2.0, -- degrees at screen edge
		ParallaxPitch = 1.2,
		ParallaxFrequency = 1.1, -- spring Hz
		ShotTransitionTime = 1.6,
		DeployPushIn = 1.6, -- studs of dolly while the server spawns you
	},
	DeployTransitionTime = 2.1,
	Tactical = {
		PivotHeight = 1.55,
		ShoulderOffset = Vector3.new(1.85, 0.45, 6.4), -- right, up, back
		MinPitch = -70,
		MaxPitch = 65,
		CollisionRadius = 0.35,
		PivotFrequency = 11, -- spring Hz for follow
		ShoulderFrequency = 4.2,
		ShoulderDamping = 0.82,
		FovFrequency = 3.5,
		MouseRadiansPerPixel = 0.0032,
		GamepadRadiansPerSecond = 4.2,
		GamepadDeadzone = 0.15,
		BodyResponsiveness = 35,
		RollPerStudPerSecond = 0.0045, -- radians of roll per stud/s of strafe speed
		MaxRoll = math.rad(1.2),
		CloseFadeStart = 2.2,
		CloseFadeEnd = 0.9,
	},
}

Config.Keybinds = {
	ShoulderSwap = { Enum.KeyCode.V, Enum.KeyCode.DPadRight },
	MenuUp = { Enum.KeyCode.Up, Enum.KeyCode.W, Enum.KeyCode.DPadUp },
	MenuDown = { Enum.KeyCode.Down, Enum.KeyCode.S, Enum.KeyCode.DPadDown },
	MenuLeft = { Enum.KeyCode.Left, Enum.KeyCode.A, Enum.KeyCode.DPadLeft },
	MenuRight = { Enum.KeyCode.Right, Enum.KeyCode.D, Enum.KeyCode.DPadRight },
	MenuSelect = { Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonA },
	MenuBack = { Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB },
}

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------
local DEFAULT_SETTINGS: Types.PlayerSettings = {
	Quality = "High",
	FieldOfView = 72,
	Sensitivity = 1.0,
}

local QUALITY_LEVELS: { Types.QualityLevel } = { "Low", "Medium", "High", "Ultra" }

Config.Settings = {
	Defaults = DEFAULT_SETTINGS,
	QualityLevels = QUALITY_LEVELS,
	FovMin = 60,
	FovMax = 100,
	SensitivityMin = 0.1,
	SensitivityMax = 3.0,
	SaveDebounce = 1.25,
	ServerSaveCooldown = 0.5,
}

local QUALITY_PRESETS: { [Types.QualityLevel]: Types.QualityPreset } = {
	Low = {
		RainRate = 180,
		Splashes = false,
		GroundMist = false,
		Beams = false,
		SunRays = false,
		DepthOfField = false,
		BloomScale = 0.6,
		Lightning = true,
		ExhaustSmoke = false,
		LightShadows = false,
	},
	Medium = {
		RainRate = 420,
		Splashes = true,
		GroundMist = false,
		Beams = true,
		SunRays = false,
		DepthOfField = true,
		BloomScale = 0.85,
		Lightning = true,
		ExhaustSmoke = true,
		LightShadows = true,
	},
	High = {
		RainRate = 750,
		Splashes = true,
		GroundMist = true,
		Beams = true,
		SunRays = true,
		DepthOfField = true,
		BloomScale = 1,
		Lightning = true,
		ExhaustSmoke = true,
		LightShadows = true,
	},
	Ultra = {
		RainRate = 1100,
		Splashes = true,
		GroundMist = true,
		Beams = true,
		SunRays = true,
		DepthOfField = true,
		BloomScale = 1.1,
		Lightning = true,
		ExhaustSmoke = true,
		LightShadows = true,
	},
}
Config.Quality = QUALITY_PRESETS

--------------------------------------------------------------------------------
-- Weather
--------------------------------------------------------------------------------
Config.Weather = {
	RainAreaSize = 90,
	RainHeight = 32,
	RainSpeed = NumberRange.new(85, 110),
	Wind = Vector3.new(6, 0, 3),
	LightningInterval = NumberRange.new(16, 42),
	ThunderDelay = NumberRange.new(0.6, 2.6),
}

--------------------------------------------------------------------------------
-- Weapons (Phase 2 builds models + gunplay from these definitions)
--------------------------------------------------------------------------------
local WEAPONS: { [string]: Types.WeaponDef } = {
	SuppressedRifle = {
		DisplayName = "VK-9 SUPPRESSED",
		Class = "RIFLE",
		Slot = "Primary",
		Description = "Integrally suppressed 5.56 carbine with holographic optic. Quiet, accurate, deliberate.",
		Stats = { Damage = 0.62, FireRate = 0.68, Handling = 0.52, Range = 0.84 },
		Order = 1,
	},
	CompactSMG = {
		DisplayName = "KR-45 COMPACT",
		Class = "SMG",
		Slot = "Primary",
		Description = "Short-barrel .45 SMG with folding stock. Brutal up close, falls off fast.",
		Stats = { Damage = 0.48, FireRate = 0.92, Handling = 0.86, Range = 0.38 },
		Order = 2,
	},
	HeavyPistol = {
		DisplayName = "M-50 HEAVY",
		Class = "PISTOL",
		Slot = "Secondary",
		Description = "Full-size .50 sidearm with micro red-dot. Two taps, one problem.",
		Stats = { Damage = 0.82, FireRate = 0.34, Handling = 0.66, Range = 0.55 },
		Order = 1,
	},
}
Config.Weapons = WEAPONS

local DEFAULT_LOADOUT: Types.Loadout = {
	Primary = "SuppressedRifle",
	Secondary = "HeavyPistol",
}
Config.DefaultLoadout = DEFAULT_LOADOUT

--------------------------------------------------------------------------------
-- Persistence
--------------------------------------------------------------------------------
Config.Data = {
	StoreName = "ZabourProfiles_v1",
	KeyPrefix = "u_",
	SchemaVersion = 1,
	AutosaveInterval = 120,
	Retries = 4,
	ProfileWaitTimeout = 15,
}

--------------------------------------------------------------------------------
-- Deploy flow
--------------------------------------------------------------------------------
Config.Deploy = {
	RequestCooldown = 2.0,
	ReturnToMenuDelay = 4.0,
	SpawnTimeout = 12,
}

--------------------------------------------------------------------------------
-- Audio
-- Built-in rbxasset:// sounds ship with every Roblox client. Rain / thunder /
-- engine need Creator Store audio you have rights to: paste "rbxassetid://<id>".
-- Empty ids are skipped cleanly (one warning lists what is missing).
--------------------------------------------------------------------------------
local AUDIO: { [string]: Types.AudioDef } = {
	UIHover = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.22, Speed = 1.7, Group = "UI" },
	UIClick = { Id = "rbxasset://sounds/button.wav", Volume = 0.32, Speed = 1.15, Group = "UI" },
	UIBack = { Id = "rbxasset://sounds/button.wav", Volume = 0.26, Speed = 0.85, Group = "UI" },
	UIDeploy = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.5, Speed = 0.7, Group = "UI" },
	UITick = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.12, Speed = 2.4, Group = "UI" },
	RainLoop = { Id = "", Volume = 0.45, Speed = 1, Group = "Ambience" },
	Thunder = { Id = "", Volume = 0.6, Speed = 1, Group = "Ambience" },
	EngineIdle = { Id = "", Volume = 0.55, Speed = 1, Group = "World" },
}
Config.Audio = AUDIO

Config.CoreGui = {
	-- CoreGui types re-enabled once deployed. Everything else stays hidden.
	Gameplay = { Enum.CoreGuiType.Chat },
}

return Config
