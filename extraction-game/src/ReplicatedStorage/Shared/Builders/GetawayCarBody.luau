--!strict
--[[
	GetawayCarBody
	Procedural "Zabour" fastback getaway car: ~150 parts, matte-black paint,
	tinted glass, widebody flares, 10-spoke rims, LED headlights with volumetric
	beams, full-width light bar, dual exhausts, diffuser, wing, lit interior.

	Phase 1 uses it as the static showpiece in the safehouse.
	Phase 3 reuses the same body on a physics chassis (pass Anchored = false).

	Local space: origin sits on the ground at the centre of the footprint,
	forward is -Z (origin.LookVector), up is +Y. All numbers are studs.

	Assembly: Root is the only part whose Anchored flag matters; every other
	part is unanchored and welded to Root, so moving Root moves the whole car
	(the client uses this for the idle engine rumble).
]]

local CollectionService = game:GetService("CollectionService")

local PartFactory = require(script.Parent.PartFactory)

export type BuildOptions = {
	Name: string?,
	Anchored: boolean?,
	PaintColor: Color3?,
	Interior: boolean?,
	PlateText: string?,
}

export type CarHandles = {
	Model: Model,
	Root: BasePart,
	Wheels: { [string]: Model },
	HeadlightLights: { SpotLight },
	HeadlightBeams: { Beam },
	HeadlightLenses: { BasePart },
	BrakeLights: { BasePart },
	BrakeLightSources: { SurfaceLight },
	Exhausts: { Attachment },
	UnderglowStrip: BasePart,
	UnderglowLights: { PointLight },
	EngineBay: BasePart,
	TrunkLid: BasePart,
}

type Style = PartFactory.Style

type AddExtra = {
	Class: ("Part" | "WedgePart" | "CornerWedgePart")?,
	Shape: Enum.PartType?,
	Collide: boolean?,
	Parent: Instance?,
}

local GetawayCarBody = {}

local RUBBER = PartFactory.material("Rubber", Enum.Material.SmoothPlastic)
local LEATHER = PartFactory.material("Leather", Enum.Material.Fabric)

-- Brake light brightness range (idle running lights -> full brake).
local BRAKE_IDLE_TRANSPARENCY = 0.35
local BRAKE_IDLE_BRIGHTNESS = 0.9
local BRAKE_FULL_BRIGHTNESS = 3.2

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function makeStyles(paint: Color3): { [string]: Style }
	return {
		Paint = PartFactory.style(paint, Enum.Material.SmoothPlastic, 0.02),
		PaintAccent = PartFactory.style(rgb(150, 18, 24), Enum.Material.SmoothPlastic, 0.05),
		Trim = PartFactory.style(rgb(12, 12, 13), Enum.Material.SmoothPlastic, 0),
		Carbon = PartFactory.style(rgb(20, 20, 22), Enum.Material.Fabric, 0),
		Chrome = PartFactory.style(rgb(168, 170, 176), Enum.Material.Metal, 0.25),
		Gunmetal = PartFactory.style(rgb(96, 98, 104), Enum.Material.Metal, 0.08),
		RimShadow = PartFactory.style(rgb(12, 12, 14), Enum.Material.Metal, 0),
		Rubber = PartFactory.style(rgb(24, 24, 26), RUBBER, 0),
		Glass = PartFactory.style(rgb(10, 12, 15), Enum.Material.Glass, 0.18, 0.32),
		LensDark = PartFactory.style(rgb(18, 20, 24), Enum.Material.Glass, 0.3, 0.1),
		LensRed = PartFactory.style(rgb(70, 8, 10), Enum.Material.Glass, 0.2, 0.15),
		NeonWhite = PartFactory.style(rgb(232, 240, 255), Enum.Material.Neon, 0, 0, false),
		NeonRed = PartFactory.style(rgb(255, 24, 34), Enum.Material.Neon, 0, BRAKE_IDLE_TRANSPARENCY, false),
		NeonGauge = PartFactory.style(rgb(60, 200, 255), Enum.Material.Neon, 0, 0.35, false),
		NeonScreen = PartFactory.style(rgb(255, 140, 60), Enum.Material.Neon, 0, 0.55, false),
		NeonUnder = PartFactory.style(rgb(255, 60, 170), Enum.Material.Neon, 0, 1, false),
		Interior = PartFactory.style(rgb(26, 26, 28), LEATHER, 0),
		Dash = PartFactory.style(rgb(18, 18, 20), Enum.Material.SmoothPlastic, 0),
		Plate = PartFactory.style(rgb(214, 214, 206), Enum.Material.SmoothPlastic, 0.05),
		Invisible = PartFactory.style(rgb(0, 0, 0), Enum.Material.SmoothPlastic, 0, 1, false),
	}
end

function GetawayCarBody.build(origin: CFrame, options: BuildOptions?): CarHandles
	local opts: BuildOptions = options or {}
	local anchored = if opts.Anchored == nil then true else opts.Anchored
	local styles = makeStyles(opts.PaintColor or rgb(16, 16, 18))
	local includeInterior = opts.Interior ~= false

	local model = Instance.new("Model")
	model.Name = opts.Name or "Zabour"
	model:SetAttribute("VehicleType", "Zabour")

	local root = PartFactory.make({
		Name = "Root",
		Size = Vector3.new(6.6, 2.1, 16),
		CFrame = origin * CFrame.new(0, 1.8, 0),
		Style = styles.Invisible,
		Anchored = anchored,
		CanCollide = false,
		Parent = model,
	})
	model.PrimaryPart = root

	local bodyFolder = PartFactory.folder("Body", model)
	local glassFolder = PartFactory.folder("Glass", model)
	local lightsFolder = PartFactory.folder("Lights", model)
	local trimFolder = PartFactory.folder("Trim", model)
	local wheelsFolder = PartFactory.folder("Wheels", model)
	local interiorFolder = PartFactory.folder("Interior", model)

	local function add(name: string, size: Vector3, localCF: CFrame, style: Style, extra: AddExtra?): BasePart
		local e: AddExtra = extra or {}
		local part = PartFactory.make({
			Name = name,
			Size = size,
			CFrame = origin * localCF,
			Style = style,
			Class = e.Class,
			Shape = e.Shape,
			CanCollide = e.Collide,
			Anchored = false,
			Parent = e.Parent or bodyFolder,
		})
		PartFactory.weld(root, part)
		return part
	end

	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x, y, z)
	end

	local SIDES = { -1, 1 }

	----------------------------------------------------------------------------
	-- Structure (sections along Z: bumper | wheel well | doors | wheel well | bumper)
	----------------------------------------------------------------------------
	add("FloorPan", Vector3.new(4.7, 0.25, 15.6), at(0, 0.72, 0), styles.Carbon, { Collide = true })

	-- Front
	add("FrontBumper", Vector3.new(6.6, 1.25, 1.2), at(0, 1.35, -7.4), styles.Paint, { Collide = true })
	add("FrontCore", Vector3.new(4.7, 1.25, 3.2), at(0, 1.35, -5.2), styles.Paint, { Collide = true })
	-- Hood: wedge rising from the nose (y 1.975) to the cowl (y 2.85).
	add("Hood", Vector3.new(6.6, 0.875, 4.4), at(0, 2.4125, -5.8), styles.Paint, { Class = "WedgePart", Collide = true })
	-- Hood power bulge + vents
	add("HoodBulge", Vector3.new(2.2, 0.16, 3.4), at(0, 2.48, -5.4) * CFrame.Angles(math.rad(-11.25), 0, 0), styles.Paint)
	for i = 0, 2 do
		add(
			"HoodVent" .. i,
			Vector3.new(1.6, 0.04, 0.12),
			at(0, 2.565 + i * 0.035, -5.9 + i * 0.3) * CFrame.Angles(math.rad(-11.25), 0, 0),
			styles.Trim
		)
	end

	-- Doors / cabin base
	add("DoorSection", Vector3.new(6.6, 2.1, 7.2), at(0, 1.8, 0), styles.Paint, { Collide = true })

	-- Rear
	add("RearCore", Vector3.new(4.7, 2.1, 2.8), at(0, 1.8, 5.0), styles.Paint, { Collide = true })
	add("RearFenderTop", Vector3.new(6.6, 0.25, 2.8), at(0, 2.725, 5.0), styles.Paint, { Collide = true })
	add("RearBumper", Vector3.new(6.6, 2.1, 1.6), at(0, 1.8, 7.2), styles.Paint, { Collide = true })
	add("Ducktail", Vector3.new(6.2, 0.3, 0.8), at(0, 3.0, 7.6), styles.Paint, { Class = "WedgePart" })

	local trunkLid = add("TrunkLid", Vector3.new(5.6, 0.06, 2.0), at(0, 2.88, 6.4), styles.Paint)
	trunkLid:SetAttribute("LootTrunk", true)
	local trunkPrompt = Instance.new("Attachment")
	trunkPrompt.Name = "TrunkPrompt"
	trunkPrompt.Position = Vector3.new(0, 0.6, 1.4)
	trunkPrompt.Parent = trunkLid

	-- Fender bulges over the front wheels, following the hood slope.
	for _, s in SIDES do
		add(
			if s < 0 then "FenderBulge_L" else "FenderBulge_R",
			Vector3.new(1.0, 0.3, 3.0),
			at(s * 2.9, 2.63, -5.2) * CFrame.Angles(math.rad(-11.25), 0, 0),
			styles.Paint
		)
	end

	-- Widebody flares: top + angled front/back segments framing each arch.
	local axles = {
		{ Name = "F", Z = -5.2 },
		{ Name = "R", Z = 5.0 },
	}
	for _, axle in axles do
		for _, s in SIDES do
			local tag = axle.Name .. (if s < 0 then "L" else "R")
			local x = s * 3.45
			add("FlareTop_" .. tag, Vector3.new(0.3, 0.22, 2.4), at(x, 2.72, axle.Z), styles.Trim)
			add(
				"FlareFront_" .. tag,
				Vector3.new(0.3, 0.22, 1.3),
				at(x, 2.22, axle.Z - 1.62) * CFrame.Angles(math.rad(-50), 0, 0),
				styles.Trim
			)
			add(
				"FlareRear_" .. tag,
				Vector3.new(0.3, 0.22, 1.3),
				at(x, 2.22, axle.Z + 1.62) * CFrame.Angles(math.rad(50), 0, 0),
				styles.Trim
			)
		end
	end

	-- Side skirts, door seams, handles, character line
	for _, s in SIDES do
		local side = if s < 0 then "L" else "R"
		add("SideSkirt_" .. side, Vector3.new(0.22, 0.3, 7.4), at(s * 3.36, 0.9, -0.1), styles.Carbon, { Parent = trimFolder })
		add("DoorSeamFront_" .. side, Vector3.new(0.04, 1.9, 0.05), at(s * 3.31, 1.85, -3.45), styles.Trim, { Parent = trimFolder })
		add("DoorSeamRear_" .. side, Vector3.new(0.04, 1.9, 0.05), at(s * 3.31, 1.85, 1.45), styles.Trim, { Parent = trimFolder })
		add("DoorSeamBottom_" .. side, Vector3.new(0.04, 0.05, 4.9), at(s * 3.31, 0.92, -1.0), styles.Trim, { Parent = trimFolder })
		add("DoorHandle_" .. side, Vector3.new(0.06, 0.1, 0.5), at(s * 3.33, 2.45, 0.9), styles.Chrome, { Parent = trimFolder })
		add("CharacterLine_" .. side, Vector3.new(0.03, 0.05, 7.1), at(s * 3.31, 2.42, 0), styles.Gunmetal, { Parent = trimFolder })

		-- Mirrors
		add("MirrorStalk_" .. side, Vector3.new(0.5, 0.08, 0.15), at(s * 2.98, 3.02, -2.3), styles.Trim, { Parent = trimFolder })
		add("Mirror_" .. side, Vector3.new(0.35, 0.32, 0.55), at(s * 3.2, 3.18, -2.3), styles.Paint, { Parent = trimFolder })
		add("MirrorGlass_" .. side, Vector3.new(0.3, 0.26, 0.02), at(s * 3.2, 3.18, -2.02), styles.Chrome, { Parent = trimFolder })
	end

	----------------------------------------------------------------------------
	-- Greenhouse (cabin)
	----------------------------------------------------------------------------
	-- Windshield: base (y 2.85, z -2.6) -> roof (y 4.35, z -0.3)
	local windshieldAngle = math.atan2(1.5, 2.3)
	local windshieldLength = math.sqrt(1.5 * 1.5 + 2.3 * 2.3)
	local windshieldCF = at(0, 3.6, -1.45) * CFrame.Angles(-windshieldAngle, 0, 0)
	add("Windshield", Vector3.new(5.2, 0.1, windshieldLength), windshieldCF, styles.Glass, { Parent = glassFolder })

	-- Rear glass: roof (y 4.35, z 2.4) -> deck (y 2.85, z 5.4)
	local rearAngle = math.atan2(1.5, 3.0)
	local rearLength = math.sqrt(1.5 * 1.5 + 3.0 * 3.0)
	add(
		"RearGlass",
		Vector3.new(5.0, 0.1, rearLength),
		at(0, 3.6, 3.9) * CFrame.Angles(rearAngle, 0, 0),
		styles.Glass,
		{ Parent = glassFolder }
	)

	add("Roof", Vector3.new(5.4, 0.22, 2.7), at(0, 4.42, 1.05), styles.Paint, { Collide = true })
	add("SharkFin", Vector3.new(0.15, 0.25, 0.6), at(0, 4.655, 2.0), styles.Paint, { Class = "WedgePart" })

	for _, s in SIDES do
		local side = if s < 0 then "L" else "R"
		add(
			"APillar_" .. side,
			Vector3.new(0.2, 0.2, windshieldLength),
			at(s * 2.66, 3.65, -1.45) * CFrame.Angles(-windshieldAngle, 0, 0),
			styles.Paint
		)
		-- Front quarter glass (triangle, tall at the back)
		add(
			"QuarterGlass_" .. side,
			Vector3.new(0.1, 1.46, 2.3),
			at(s * 2.72, 3.58, -1.45),
			styles.Glass,
			{ Class = "WedgePart", Parent = glassFolder }
		)
		add("SideGlass_" .. side, Vector3.new(0.1, 1.46, 2.7), at(s * 2.72, 3.58, 1.05), styles.Glass, { Parent = glassFolder })
		add("BPillar_" .. side, Vector3.new(0.12, 1.46, 0.22), at(s * 2.74, 3.58, 0.9), styles.Trim, { Parent = trimFolder })
		-- Fastback sail panel (tall at the front)
		add(
			"CPillar_" .. side,
			Vector3.new(0.2, 1.46, 3.0),
			at(s * 2.7, 3.58, 3.9) * CFrame.Angles(0, math.rad(180), 0),
			styles.Paint,
			{ Class = "WedgePart" }
		)
		add("WindowTrim_" .. side, Vector3.new(0.06, 0.05, 6.0), at(s * 2.78, 2.88, 0.2), styles.Chrome, { Parent = trimFolder })
	end

	----------------------------------------------------------------------------
	-- Front fascia
	----------------------------------------------------------------------------
	add("Grille", Vector3.new(3.6, 0.55, 0.12), at(0, 1.35, -8.02), PartFactory.style(rgb(14, 14, 15), Enum.Material.DiamondPlate, 0), { Parent = trimFolder })
	add("GrilleSurround", Vector3.new(3.8, 0.06, 0.14), at(0, 1.66, -8.02), styles.Chrome, { Parent = trimFolder })
	add("LowerIntake", Vector3.new(5.6, 0.3, 0.1), at(0, 0.95, -8.02), styles.Trim, { Parent = trimFolder })
	add("Splitter", Vector3.new(6.9, 0.1, 0.9), at(0, 0.68, -7.75), styles.Carbon, { Parent = trimFolder })
	add("FrontPlate", Vector3.new(1.4, 0.4, 0.04), at(0, 1.02, -8.09), styles.Plate, { Parent = trimFolder })

	local headlightLights: { SpotLight } = {}
	local headlightBeams: { Beam } = {}
	local headlightLenses: { BasePart } = {}

	for _, s in SIDES do
		local side = if s < 0 then "L" else "R"
		add("HeadlightHousing_" .. side, Vector3.new(1.5, 0.32, 0.14), at(s * 2.35, 1.78, -8.02), styles.LensDark, { Parent = lightsFolder })
		local drl = add("HeadlightDRL_" .. side, Vector3.new(1.45, 0.07, 0.06), at(s * 2.35, 1.9, -8.07), styles.NeonWhite, { Parent = lightsFolder })
		local projector = add(
			"HeadlightProjector_" .. side,
			Vector3.new(0.1, 0.24, 0.24),
			at(s * 2.0, 1.74, -8.08) * PartFactory.AxisZ,
			styles.NeonWhite,
			{ Shape = Enum.PartType.Cylinder, Parent = lightsFolder }
		)
		table.insert(headlightLenses, drl)
		table.insert(headlightLenses, projector)

		-- Invisible emitter aligned with the car so SpotLight Face=Front = car forward.
		local source = add("HeadlightSource_" .. side, Vector3.new(0.2, 0.2, 0.2), at(s * 2.2, 1.76, -8.2), styles.Invisible, { Parent = lightsFolder })
		local spot = Instance.new("SpotLight")
		spot.Name = "Beam"
		spot.Face = Enum.NormalId.Front
		spot.Angle = 55
		spot.Range = 60
		spot.Brightness = 5
		spot.Color = rgb(255, 244, 225)
		spot.Shadows = true
		spot.Parent = source
		CollectionService:AddTag(spot, "ShadowLight")
		table.insert(headlightLights, spot)

		-- Volumetric cone: camera-facing beam fading into the fog.
		local a0 = Instance.new("Attachment")
		a0.Name = "BeamStart"
		a0.Parent = source
		local a1 = Instance.new("Attachment")
		a1.Name = "BeamEnd"
		a1.Position = Vector3.new(s * 1.5, -1.3, -26)
		a1.Parent = source
		local beam = Instance.new("Beam")
		beam.Name = "VolumetricBeam"
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 0.9
		beam.Width1 = 9
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Segments = 1
		beam.Color = ColorSequence.new(rgb(255, 240, 220))
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(0.35, 0.88),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Parent = source
		CollectionService:AddTag(beam, "VolumetricBeam")
		table.insert(headlightBeams, beam)

		-- Fog lights in the lower intake
		add("FogLight_" .. side, Vector3.new(0.5, 0.12, 0.06), at(s * 2.45, 0.95, -8.07), styles.NeonWhite, { Parent = lightsFolder })
	end

	----------------------------------------------------------------------------
	-- Rear fascia
	----------------------------------------------------------------------------
	local brakeLights: { BasePart } = {}
	local brakeSources: { SurfaceLight } = {}

	local lightBar = add("TailLightBar", Vector3.new(6.0, 0.16, 0.1), at(0, 2.55, 8.03), styles.NeonRed, { Parent = lightsFolder })
	table.insert(brakeLights, lightBar)
	local barGlow = Instance.new("SurfaceLight")
	barGlow.Name = "BrakeGlow"
	barGlow.Face = Enum.NormalId.Back
	barGlow.Angle = 120
	barGlow.Range = 14
	barGlow.Brightness = BRAKE_IDLE_BRIGHTNESS
	barGlow.Color = rgb(255, 30, 36)
	barGlow.Shadows = false
	barGlow.Parent = lightBar
	table.insert(brakeSources, barGlow)

	for _, s in SIDES do
		local side = if s < 0 then "L" else "R"
		add("TailCluster_" .. side, Vector3.new(1.2, 0.38, 0.12), at(s * 2.55, 2.22, 8.02), styles.LensRed, { Parent = lightsFolder })
		local inner = add("TailLamp_" .. side, Vector3.new(1.0, 0.12, 0.05), at(s * 2.55, 2.22, 8.08), styles.NeonRed, { Parent = lightsFolder })
		table.insert(brakeLights, inner)
		add("ReverseLamp_" .. side, Vector3.new(0.3, 0.1, 0.05), at(s * 1.75, 2.22, 8.08), PartFactory.style(rgb(200, 200, 200), Enum.Material.Glass, 0.2, 0.1), { Parent = lightsFolder })
	end

	local rearPlate = add("RearPlate", Vector3.new(1.6, 0.5, 0.05), at(0, 1.6, 8.03), styles.Plate, { Parent = trimFolder })
	local plateGui = Instance.new("SurfaceGui")
	plateGui.Name = "PlateText"
	plateGui.Face = Enum.NormalId.Back
	plateGui.PixelsPerStud = 80
	plateGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	plateGui.LightInfluence = 1
	plateGui.Parent = rearPlate
	local plateLabel = Instance.new("TextLabel")
	plateLabel.BackgroundTransparency = 1
	plateLabel.Size = UDim2.fromScale(1, 1)
	plateLabel.Text = opts.PlateText or "ZBR 077"
	plateLabel.TextScaled = true
	plateLabel.TextColor3 = rgb(24, 26, 30)
	plateLabel.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
	plateLabel.Parent = plateGui

	-- Diffuser with fins
	add("Diffuser", Vector3.new(5.4, 0.12, 1.3), at(0, 0.69, 7.45), styles.Carbon, { Parent = trimFolder })
	for i = -2, 2 do
		add("DiffuserFin" .. (i + 3), Vector3.new(0.07, 0.3, 1.2), at(i * 0.8, 0.6, 7.5), styles.Carbon, { Parent = trimFolder })
	end

	-- Dual exhausts
	local exhausts: { Attachment } = {}
	for _, s in SIDES do
		local side = if s < 0 then "L" else "R"
		add("ExhaustTip_" .. side, Vector3.new(0.7, 0.5, 0.5), at(s * 1.55, 0.92, 8.05) * PartFactory.AxisZ, styles.Chrome, {
			Shape = Enum.PartType.Cylinder,
			Parent = trimFolder,
		})
		add("ExhaustBore_" .. side, Vector3.new(0.72, 0.36, 0.36), at(s * 1.55, 0.92, 8.06) * PartFactory.AxisZ, styles.Trim, {
			Shape = Enum.PartType.Cylinder,
			Parent = trimFolder,
		})

		local attachment = Instance.new("Attachment")
		attachment.Name = "Exhaust_" .. side
		-- Root sits at y 1.8 in car space.
		attachment.Position = Vector3.new(s * 1.55, 0.92 - 1.8, 8.45)
		attachment.Parent = root
		table.insert(exhausts, attachment)

		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "ExhaustSmoke"
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.EmissionDirection = Enum.NormalId.Back
		smoke.Rate = 5
		smoke.Lifetime = NumberRange.new(1.6, 2.6)
		smoke.Speed = NumberRange.new(1.5, 2.5)
		smoke.SpreadAngle = Vector2.new(12, 12)
		smoke.Drag = 1.2
		smoke.Acceleration = Vector3.new(0, 1.2, 0)
		smoke.Rotation = NumberRange.new(0, 360)
		smoke.RotSpeed = NumberRange.new(-40, 40)
		smoke.LightInfluence = 1
		smoke.Color = ColorSequence.new(rgb(150, 150, 155))
		smoke.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 1.6),
		})
		smoke.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.82),
			NumberSequenceKeypoint.new(1, 1),
		})
		smoke.Parent = attachment
		CollectionService:AddTag(smoke, "ExhaustSmoke")
	end

	-- Rear wing on stands with endplates
	for _, s in SIDES do
		local side = if s < 0 then "L" else "R"
		add("WingStand_" .. side, Vector3.new(0.14, 0.55, 0.5), at(s * 2.1, 3.12, 7.35), styles.Trim, { Parent = trimFolder })
		add("WingEndplate_" .. side, Vector3.new(0.08, 0.45, 1.2), at(s * 3.1, 3.4, 7.45), styles.Carbon, { Parent = trimFolder })
	end
	add("Wing", Vector3.new(6.2, 0.1, 1.1), at(0, 3.42, 7.45) * CFrame.Angles(math.rad(6), 0, 0), styles.Carbon, { Parent = trimFolder })

	----------------------------------------------------------------------------
	-- Underglow (Phase 3 toggles it)
	----------------------------------------------------------------------------
	local underglow = add("UnderglowStrip", Vector3.new(4.4, 0.06, 13), at(0, 0.56, 0), styles.NeonUnder, { Parent = lightsFolder })
	local underglowLights: { PointLight } = {}
	for i, z in { -4.5, 0, 4.5 } do
		local glow = Instance.new("PointLight")
		glow.Name = "Underglow" .. i
		glow.Range = 10
		glow.Brightness = 2
		glow.Color = rgb(255, 60, 170)
		glow.Shadows = false
		glow.Enabled = false
		local holder = add("UnderglowEmitter" .. i, Vector3.new(0.2, 0.2, 0.2), at(0, 0.4, z), styles.Invisible, { Parent = lightsFolder })
		glow.Parent = holder
		table.insert(underglowLights, glow)
	end
	model:SetAttribute("Underglow", false)
	model:SetAttribute("Hazards", false)

	----------------------------------------------------------------------------
	-- Interior (visible through tint)
	----------------------------------------------------------------------------
	if includeInterior then
		add("Dashboard", Vector3.new(5.0, 0.5, 0.8), at(0, 3.05, -1.4), styles.Dash, { Parent = interiorFolder })
		add("GaugeCluster", Vector3.new(0.9, 0.22, 0.04), at(-1.3, 3.18, -0.98), styles.NeonGauge, { Parent = interiorFolder })
		add("CenterScreen", Vector3.new(1.0, 0.35, 0.04), at(0.25, 3.12, -0.98), styles.NeonScreen, { Parent = interiorFolder })
		add("AmbientStrip", Vector3.new(4.2, 0.03, 0.03), at(0, 3.3, -1.0), styles.NeonGauge, { Parent = interiorFolder })
		local dashGlowHolder = add("DashGlow", Vector3.new(0.2, 0.2, 0.2), at(-0.5, 3.4, -0.6), styles.Invisible, { Parent = interiorFolder })
		local dashGlow = Instance.new("PointLight")
		dashGlow.Range = 4.5
		dashGlow.Brightness = 0.7
		dashGlow.Color = rgb(70, 190, 255)
		dashGlow.Shadows = false
		dashGlow.Parent = dashGlowHolder

		add(
			"SteeringWheel",
			Vector3.new(0.12, 1.0, 1.0),
			at(-1.3, 3.0, -0.72) * CFrame.Angles(math.rad(-25), 0, 0) * PartFactory.AxisZ,
			styles.Dash,
			{ Shape = Enum.PartType.Cylinder, Parent = interiorFolder }
		)
		add("CenterConsole", Vector3.new(0.6, 0.6, 2.2), at(0, 2.95, 0.2), styles.Dash, { Parent = interiorFolder })
		for _, s in SIDES do
			local side = if s < 0 then "L" else "R"
			add(
				"SeatBack_" .. side,
				Vector3.new(1.3, 1.9, 0.35),
				at(s * 1.3, 2.6, 1.6) * CFrame.Angles(math.rad(14), 0, 0),
				styles.Interior,
				{ Parent = interiorFolder }
			)
			add("SeatBolster_" .. side, Vector3.new(1.45, 1.2, 0.2), at(s * 1.3, 2.9, 1.82) * CFrame.Angles(math.rad(14), 0, 0), styles.Interior, { Parent = interiorFolder })
			add("Headrest_" .. side, Vector3.new(0.9, 0.5, 0.3), at(s * 1.3, 3.85, 1.9) * CFrame.Angles(math.rad(14), 0, 0), styles.Interior, { Parent = interiorFolder })
		end
		add("RollBar", Vector3.new(4.8, 0.14, 0.14), at(0, 4.15, 2.3), styles.Gunmetal, { Parent = interiorFolder })
	end

	----------------------------------------------------------------------------
	-- Wheels
	----------------------------------------------------------------------------
	local wheels: { [string]: Model } = {}
	local wheelDefs = {
		{ Name = "FL", X = -2.95, Z = -5.2 },
		{ Name = "FR", X = 2.95, Z = -5.2 },
		{ Name = "RL", X = -2.95, Z = 5.0 },
		{ Name = "RR", X = 2.95, Z = 5.0 },
	}
	for _, def in wheelDefs do
		local s = if def.X < 0 then -1 else 1
		local wheelModel = Instance.new("Model")
		wheelModel.Name = "Wheel_" .. def.Name
		wheelModel.Parent = wheelsFolder
		local centre = at(def.X, 1.3, def.Z)

		local tire = add("Tire", Vector3.new(1.05, 2.6, 2.6), centre, styles.Rubber, {
			Shape = Enum.PartType.Cylinder,
			Collide = true,
			Parent = wheelModel,
		})
		wheelModel.PrimaryPart = tire
		add("Sidewall", Vector3.new(1.07, 2.25, 2.25), centre, PartFactory.style(rgb(30, 30, 32), RUBBER, 0), {
			Shape = Enum.PartType.Cylinder,
			Parent = wheelModel,
		})
		add("RimBarrel", Vector3.new(1.09, 1.85, 1.85), centre, styles.RimShadow, {
			Shape = Enum.PartType.Cylinder,
			Parent = wheelModel,
		})
		add("RimLip", Vector3.new(0.05, 1.95, 1.95), centre * CFrame.new(s * 0.53, 0, 0), styles.Chrome, {
			Shape = Enum.PartType.Cylinder,
			Parent = wheelModel,
		})
		for i = 0, 4 do
			add(
				"Spoke" .. i,
				Vector3.new(0.08, 0.16, 1.72),
				centre * CFrame.new(s * 0.56, 0, 0) * CFrame.Angles(math.rad(i * 36), 0, 0),
				styles.Gunmetal,
				{ Parent = wheelModel }
			)
		end
		add("Hub", Vector3.new(0.14, 0.55, 0.55), centre * CFrame.new(s * 0.58, 0, 0), styles.Chrome, {
			Shape = Enum.PartType.Cylinder,
			Parent = wheelModel,
		})
		add("CenterCap", Vector3.new(0.16, 0.28, 0.28), centre * CFrame.new(s * 0.6, 0, 0), styles.PaintAccent, {
			Shape = Enum.PartType.Cylinder,
			Parent = wheelModel,
		})
		wheels[def.Name] = wheelModel
	end

	----------------------------------------------------------------------------
	-- Anchors for other systems
	----------------------------------------------------------------------------
	local engineBay = add("EngineBay", Vector3.new(1, 1, 1), at(0, 1.6, -5.5), styles.Invisible, { Parent = model })

	model.Parent = nil
	return {
		Model = model,
		Root = root,
		Wheels = wheels,
		HeadlightLights = headlightLights,
		HeadlightBeams = headlightBeams,
		HeadlightLenses = headlightLenses,
		BrakeLights = brakeLights,
		BrakeLightSources = brakeSources,
		Exhausts = exhausts,
		UnderglowStrip = underglow,
		UnderglowLights = underglowLights,
		EngineBay = engineBay,
		TrunkLid = trunkLid,
	}
end

-- 0 = running lights, 1 = full brake.
function GetawayCarBody.setBrakeIntensity(handles: CarHandles, alpha: number)
	local a = math.clamp(alpha, 0, 1)
	for _, part in handles.BrakeLights do
		part.Transparency = BRAKE_IDLE_TRANSPARENCY * (1 - a)
	end
	for _, light in handles.BrakeLightSources do
		light.Brightness = BRAKE_IDLE_BRIGHTNESS + (BRAKE_FULL_BRIGHTNESS - BRAKE_IDLE_BRIGHTNESS) * a
	end
end

function GetawayCarBody.setHeadlights(handles: CarHandles, on: boolean)
	for _, light in handles.HeadlightLights do
		light.Enabled = on
	end
	for _, beam in handles.HeadlightBeams do
		beam.Enabled = on
	end
	for _, lens in handles.HeadlightLenses do
		lens.Material = if on then Enum.Material.Neon else Enum.Material.Glass
	end
end

function GetawayCarBody.setUnderglow(handles: CarHandles, on: boolean)
	handles.UnderglowStrip.Transparency = if on then 0.2 else 1
	for _, light in handles.UnderglowLights do
		light.Enabled = on
	end
	handles.Model:SetAttribute("Underglow", on)
end

return GetawayCarBody
