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
		-- Phase 2
		AdsShoulderOffset = Vector3.new(1.25, 0.35, 3.3),
		AdsSensitivity = 0.6,
		RecoilFrequency = 9,
		RecoilDamping = 0.55,
		RecoilRecoveryRate = math.rad(9), -- radians/s of climb recovered after firing stops
		RecoilRecoveryDelay = 0.12,
		BobFrequency = 1.15, -- steps per stud travelled
		BobAmplitude = 0.07,
		BobRoll = math.rad(0.35),
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
-- Weapons: menu stats (0..1 bars) + real combat numbers used by client & server.
--------------------------------------------------------------------------------
local WEAPONS: { [string]: Types.WeaponDef } = {
	SuppressedRifle = {
		DisplayName = "VK-9 SUPPRESSED",
		Class = "RIFLE",
		Slot = "Primary",
		Description = "Integrally suppressed 5.56 carbine with holographic optic. Quiet, accurate, deliberate.",
		Stats = { Damage = 0.62, FireRate = 0.68, Handling = 0.52, Range = 0.84 },
		Order = 1,
		Combat = {
			Damage = 28,
			HeadMultiplier = 2.0,
			RPM = 720,
			FireMode = "Auto",
			MagSize = 30,
			Reserve = 120,
			ReloadTime = 2.1,
			EmptyReloadTime = 2.6,
			DrawTime = 0.45,
			Range = 600,
			FalloffStart = 120,
			MinDamageRatio = 0.6,
			HipSpread = 2.4,
			AdsSpread = 0.35,
			MoveSpread = 1.6,
			SpreadPerShot = 0.35,
			MaxBloom = 2.5,
			BloomRecovery = 6,
			RecoilPitch = 1.1,
			RecoilYaw = 0.5,
			RecoilRecovery = 0.6,
			AdsFovMultiplier = 0.72,
			AdsTime = 0.22,
			MoveSpeedMultiplier = 1.0,
			Suppressed = true,
			TracerColor = Color3.fromRGB(255, 214, 150),
			FireSound = "FireRifle",
		},
	},
	CompactSMG = {
		DisplayName = "KR-45 COMPACT",
		Class = "SMG",
		Slot = "Primary",
		Description = "Short-barrel .45 SMG with folding stock. Brutal up close, falls off fast.",
		Stats = { Damage = 0.48, FireRate = 0.92, Handling = 0.86, Range = 0.38 },
		Order = 2,
		Combat = {
			Damage = 19,
			HeadMultiplier = 1.7,
			RPM = 950,
			FireMode = "Auto",
			MagSize = 32,
			Reserve = 160,
			ReloadTime = 1.8,
			EmptyReloadTime = 2.2,
			DrawTime = 0.35,
			Range = 300,
			FalloffStart = 40,
			MinDamageRatio = 0.45,
			HipSpread = 3.2,
			AdsSpread = 0.9,
			MoveSpread = 1.2,
			SpreadPerShot = 0.28,
			MaxBloom = 3.0,
			BloomRecovery = 8,
			RecoilPitch = 0.75,
			RecoilYaw = 0.6,
			RecoilRecovery = 0.7,
			AdsFovMultiplier = 0.82,
			AdsTime = 0.16,
			MoveSpeedMultiplier = 1.05,
			Suppressed = false,
			TracerColor = Color3.fromRGB(255, 190, 120),
			FireSound = "FireSMG",
		},
	},
	HeavyPistol = {
		DisplayName = "M-50 HEAVY",
		Class = "PISTOL",
		Slot = "Secondary",
		Description = "Full-size .50 sidearm with micro red-dot. Two taps, one problem.",
		Stats = { Damage = 0.82, FireRate = 0.34, Handling = 0.66, Range = 0.55 },
		Order = 1,
		Combat = {
			Damage = 46,
			HeadMultiplier = 2.2,
			RPM = 300,
			FireMode = "Semi",
			MagSize = 8,
			Reserve = 40,
			ReloadTime = 1.6,
			EmptyReloadTime = 1.9,
			DrawTime = 0.28,
			Range = 300,
			FalloffStart = 50,
			MinDamageRatio = 0.55,
			HipSpread = 1.8,
			AdsSpread = 0.4,
			MoveSpread = 1.0,
			SpreadPerShot = 0.9,
			MaxBloom = 3.0,
			BloomRecovery = 7,
			RecoilPitch = 2.6,
			RecoilYaw = 0.6,
			RecoilRecovery = 0.75,
			AdsFovMultiplier = 0.86,
			AdsTime = 0.14,
			MoveSpeedMultiplier = 1.1,
			Suppressed = false,
			TracerColor = Color3.fromRGB(255, 200, 130),
			FireSound = "FirePistol",
		},
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
-- Movement (Phase 2)
--------------------------------------------------------------------------------
Config.Movement = {
	WalkSpeed = 14,
	SprintSpeed = 23,
	CrouchSpeed = 7,
	AdsSpeed = 9,
	SpeedResponse = 9, -- how fast WalkSpeed eases to its target (1/s)
	StaminaMax = 100,
	SprintDrain = 16, -- per second
	StaminaRegen = 24,
	RegenDelay = 1.1,
	MinStaminaToSprint = 15,
	JumpCost = 10,
	SlideCost = 22,
	SlideSpeed = 34,
	SlideDuration = 0.85,
	SlideCooldown = 0.9,
	SlideMinSpeed = 15, -- must be moving at least this fast to slide
	CrouchHipDrop = 0.9,
	SprintForwardDot = 0.35, -- must be moving roughly forward to sprint
	SprintFovKick = 7,
	SlideFovKick = 10,
	StanceSendInterval = 0.1,
}

--------------------------------------------------------------------------------
-- Combat (Phase 2)
--------------------------------------------------------------------------------
Config.Combat = {
	PvPEnabled = false, -- safehouse is a safe zone; Phase 4 enables it per raid zone
	MaxOriginDistance = 10, -- muzzle must be this close to the shooter's head
	FireRateTolerance = 0.8, -- fraction of the real interval the server accepts
	ShotBurstAllowance = 2, -- token bucket size for network jitter
	AimSendRate = 12, -- pitch updates per second
	-- Where the RIGHT HAND (and so the weapon grip) is placed, in UpperTorso
	-- space. The weapon is welded to the hand; arm IK drives the hand here.
	-- Pivot is roughly the right shoulder (pitch / low-ready rotate around it).
	PosePivot = Vector3.new(0.3, 0.45, 0),
	HoldOffsets = {
		RIFLE = { Hip = Vector3.new(0.35, 0.0, -0.75), Ads = Vector3.new(0.25, 0.3, -0.7) },
		SMG = { Hip = Vector3.new(0.35, 0.02, -0.8), Ads = Vector3.new(0.25, 0.3, -0.75) },
		PISTOL = { Hip = Vector3.new(0.3, 0.25, -1.45), Ads = Vector3.new(0.15, 0.45, -1.5) },
	},
	DamageNumbers = true,
	Keybinds = {
		Fire = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 },
		Aim = { Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2 },
		Reload = { Enum.KeyCode.R, Enum.KeyCode.ButtonX },
		Primary = { Enum.KeyCode.One },
		Secondary = { Enum.KeyCode.Two },
		SwapWeapon = { Enum.KeyCode.ButtonY },
		Sprint = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 },
		Crouch = { Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB },
	},
	TrainingDummyHealth = 150,
	TrainingDummyRespawn = 4,
}

--------------------------------------------------------------------------------
-- Vehicles (Phase 3)
--------------------------------------------------------------------------------
Config.Vehicle = {
	-- Where drivable cars park (relative to World.Origin). Front faces +Z (toward the proving ground).
	SpawnPads = {
		CFrame.new(-7, 0, -30) * CFrame.Angles(0, math.pi, 0),
		CFrame.new(7, 0, -46) * CFrame.Angles(0, math.pi, 0),
	},
	WheelRadius = 1.3,
	-- Mass + suspension
	BallastDensity = 1.6,
	SuspensionTravel = 0.55,
	SuspensionFrequency = 2.2, -- Hz at rest load
	SuspensionDamping = 0.38, -- damping ratio
	TireFriction = 1.6,
	TireFrictionHandbrake = 0.35,
	-- Drivetrain (RWD)
	MaxSpeed = 125, -- studs/s
	ReverseSpeed = 32,
	DriveTorque = 2000, -- per rear wheel at peak
	BrakeTorque = 3200, -- per wheel
	HandbrakeTorque = 7000, -- rear wheels
	CoastTorque = 120, -- engine braking when off throttle
	Gears = { 0, 28, 52, 76, 100, 125 }, -- upshift speed thresholds (studs/s)
	ShiftTime = 0.18,
	-- Steering
	SteerAngleLow = 32, -- degrees at low speed
	SteerAngleHigh = 9, -- degrees at max speed
	SteerSpeed = 3.2, -- input smoothing (1/s)
	-- Aero
	Downforce = 0.32, -- force = Downforce * speed²
	-- Camera
	CameraDistance = 13,
	CameraHeight = 3.2,
	CameraLift = 2.1,
	CameraFovKick = 18,
	CameraRecenterDelay = 1.4,
	-- Networking
	StateSendRate = 15,
	FlipCheckInterval = 1,
	TrunkCapacity = 4,
}

Config.Loot = {
	CarrySpeedMultiplier = 0.75,
	DropDistance = 3.5,
	PracticeBags = {
		{ Position = Vector3.new(11.8, 0.6, 21), Value = 4200 },
		{ Position = Vector3.new(11.6, 0.6, 24.5), Value = 6800 },
		{ Position = Vector3.new(11.9, 0.6, 28), Value = 9500 },
	},
	PracticeRespawn = 25, -- seconds after a practice bag leaves its pad
}

Config.VehicleKeys = {
	Handbrake = { Enum.KeyCode.Space, Enum.KeyCode.ButtonX },
	Exit = { Enum.KeyCode.F, Enum.KeyCode.ButtonY },
	Lights = { Enum.KeyCode.L },
	Hazards = { Enum.KeyCode.H },
	Underglow = { Enum.KeyCode.U },
}
Config.Combat.Keybinds.DropBag = { Enum.KeyCode.G, Enum.KeyCode.DPadDown }

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
	-- Combat. Gunshots need Creator Store audio ids; hit feedback uses built-ins.
	FireRifle = { Id = "", Volume = 0.7, Speed = 1, Group = "World" },
	FireSMG = { Id = "", Volume = 0.7, Speed = 1, Group = "World" },
	FirePistol = { Id = "", Volume = 0.8, Speed = 1, Group = "World" },
	DryFire = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.4, Speed = 0.7, Group = "World" },
	ReloadOut = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.45, Speed = 0.8, Group = "World" },
	ReloadIn = { Id = "rbxasset://sounds/button.wav", Volume = 0.45, Speed = 0.9, Group = "World" },
	Equip = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.25, Speed = 1.6, Group = "World" },
	HitBody = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.35, Speed = 2.0, Group = "UI" },
	HitHead = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35, Speed = 1.4, Group = "UI" },
	HitKill = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Speed = 0.9, Group = "UI" },
	-- Vehicles. EngineLoop falls back to EngineIdle's id when empty.
	EngineLoop = { Id = "", Volume = 0.6, Speed = 1, Group = "World" },
	TireSkid = { Id = "", Volume = 0.5, Speed = 1, Group = "World" },
	Backfire = { Id = "", Volume = 0.8, Speed = 1, Group = "World" },
	DoorOpen = { Id = "rbxasset://sounds/button.wav", Volume = 0.4, Speed = 0.6, Group = "World" },
	BagPickup = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.35, Speed = 0.8, Group = "World" },
}
Config.Audio = AUDIO

Config.CoreGui = {
	-- CoreGui types re-enabled once deployed. Everything else stays hidden.
	Gameplay = { Enum.CoreGuiType.Chat },
}

return Config
