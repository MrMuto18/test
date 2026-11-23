--!strict
--[[
	SafehouseBuilder
	Procedurally builds the rain-slicked safehouse alley used by the main menu
	and as the post-raid hub:

	  • wet asphalt with layered puddles, curbs, drains, manhole, steam vent
	  • two brick mid-rises with lit/dark windows, floor bands, cornices,
	    drainpipes, AC units, a fire escape and overhead sagging cables
	  • sodium + LED streetlamps with shadowed SpotLights and volumetric beams
	  • magenta/cyan neon sign + rim strips for colour contrast on the car
	  • roll-up garage, security flood light, dumpster, crates, barrels
	  • weapon workbench (Phase 2 mounts weapons on WeaponDisplays anchors)
	  • ground mist emitters, CameraRig shots, DeployPoints
	  • the matte-black "Zabour" getaway car (GetawayCarBody)

	Run in edit mode from the Command Bar to preview/bake (see tools/), or let
	the server Bootstrap build it at runtime when Workspace has no Safehouse.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local PartFactory = require(Shared.Builders.PartFactory)
local GetawayCarBody = require(Shared.Builders.GetawayCarBody)

type Style = PartFactory.Style

local SafehouseBuilder = {}

local ALLEY_LENGTH = 150
local HALF_LENGTH = ALLEY_LENGTH / 2
local WALL_FACE = 15 -- inner face of both buildings (x = ±15)
local BUILDING_HEIGHT = 48
local FLOOR_CENTRES = { 9, 16.5, 24, 31.5, 39 }
local FLOOR_BANDS = { 6.6, 14.1, 21.6, 29.1, 36.6 }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local PAVEMENT = PartFactory.material("Pavement", Enum.Material.Concrete)
local CARDBOARD = PartFactory.material("Cardboard", Enum.Material.Fabric)

local S: { [string]: Style } = {
	Asphalt = PartFactory.style(rgb(36, 37, 40), Enum.Material.Asphalt, 0.04),
	Puddle = PartFactory.style(rgb(16, 18, 21), Enum.Material.SmoothPlastic, 0.42, 0, false),
	Curb = PartFactory.style(rgb(88, 88, 92), Enum.Material.Concrete),
	Sidewalk = PartFactory.style(rgb(66, 66, 70), PAVEMENT),
	BrickL = PartFactory.style(rgb(74, 50, 42), Enum.Material.Brick),
	BrickR = PartFactory.style(rgb(62, 56, 54), Enum.Material.Brick),
	Concrete = PartFactory.style(rgb(78, 78, 82), Enum.Material.Concrete),
	ConcreteDark = PartFactory.style(rgb(50, 50, 54), Enum.Material.Concrete),
	WindowDark = PartFactory.style(rgb(12, 14, 17), Enum.Material.SmoothPlastic, 0.3),
	WindowLitWarm = PartFactory.style(rgb(150, 96, 52), Enum.Material.Neon, 0, 0.15, false),
	WindowLitCool = PartFactory.style(rgb(70, 110, 150), Enum.Material.Neon, 0, 0.3, false),
	Blinds = PartFactory.style(rgb(20, 18, 16), Enum.Material.SmoothPlastic),
	MetalDark = PartFactory.style(rgb(44, 46, 50), Enum.Material.Metal, 0.05),
	MetalLight = PartFactory.style(rgb(118, 120, 118), Enum.Material.Metal, 0.05),
	MetalRust = PartFactory.style(rgb(96, 72, 58), Enum.Material.CorrodedMetal),
	Shutter = PartFactory.style(rgb(70, 72, 76), Enum.Material.CorrodedMetal),
	Diamond = PartFactory.style(rgb(58, 60, 64), Enum.Material.DiamondPlate),
	DiamondDark = PartFactory.style(rgb(30, 31, 34), Enum.Material.DiamondPlate),
	Wood = PartFactory.style(rgb(92, 70, 50), Enum.Material.WoodPlanks),
	Pegboard = PartFactory.style(rgb(118, 96, 72), Enum.Material.Wood),
	Cardboard = PartFactory.style(rgb(150, 118, 80), CARDBOARD),
	FabricDark = PartFactory.style(rgb(34, 36, 40), Enum.Material.Fabric),
	Olive = PartFactory.style(rgb(64, 72, 48), Enum.Material.Metal, 0.03),
	Dumpster = PartFactory.style(rgb(34, 56, 44), Enum.Material.Metal, 0.03),
	TrashBag = PartFactory.style(rgb(14, 14, 16), Enum.Material.SmoothPlastic, 0.12),
	Cable = PartFactory.style(rgb(10, 10, 10), Enum.Material.SmoothPlastic),
	Sodium = PartFactory.style(rgb(255, 186, 120), Enum.Material.Neon, 0, 0, false),
	LedCool = PartFactory.style(rgb(210, 225, 255), Enum.Material.Neon, 0, 0, false),
	NeonCyan = PartFactory.style(rgb(60, 220, 255), Enum.Material.Neon, 0, 0, false),
	NeonMagenta = PartFactory.style(rgb(255, 70, 175), Enum.Material.Neon, 0, 0, false),
	ScreenGlow = PartFactory.style(rgb(40, 140, 180), Enum.Material.Neon, 0, 0.2, false),
	Invisible = PartFactory.style(rgb(0, 0, 0), Enum.Material.SmoothPlastic, 0, 1, false),
}

local SODIUM_LIGHT = rgb(255, 178, 110)
local LED_LIGHT = rgb(210, 225, 255)
local WARM_LIGHT = rgb(255, 205, 150)

--------------------------------------------------------------------------------
-- Context helpers
--------------------------------------------------------------------------------
type Ctx = {
	Origin: CFrame,
	Rng: Random,
	part: (name: string, size: Vector3, localCF: CFrame, style: Style, parent: Instance, extra: Extra?) -> BasePart,
	segment: (name: string, a: Vector3, b: Vector3, thickness: number, style: Style, parent: Instance) -> BasePart,
}

type Extra = {
	Class: ("Part" | "WedgePart" | "CornerWedgePart")?,
	Shape: Enum.PartType?,
	Collide: boolean?,
}

local function makeCtx(origin: CFrame, seed: number): Ctx
	local ctx: Ctx
	ctx = {
		Origin = origin,
		Rng = Random.new(seed),
		part = function(name: string, size: Vector3, localCF: CFrame, style: Style, parent: Instance, extra: Extra?): BasePart
			local e: Extra = extra or {}
			return PartFactory.make({
				Name = name,
				Size = size,
				CFrame = origin * localCF,
				Style = style,
				Class = e.Class,
				Shape = e.Shape,
				CanCollide = e.Collide,
				Parent = parent,
			})
		end,
		segment = function(name: string, a: Vector3, b: Vector3, thickness: number, style: Style, parent: Instance): BasePart
			return PartFactory.segment(name, origin * a, origin * b, thickness, style, parent)
		end,
	}
	return ctx
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function addSpot(parent: BasePart, props: {
	Face: Enum.NormalId,
	Angle: number,
	Range: number,
	Brightness: number,
	Color: Color3,
	Shadows: boolean,
}): SpotLight
	local light = Instance.new("SpotLight")
	light.Face = props.Face
	light.Angle = props.Angle
	light.Range = props.Range
	light.Brightness = props.Brightness
	light.Color = props.Color
	light.Shadows = props.Shadows
	light.Parent = parent
	if props.Shadows then
		CollectionService:AddTag(light, "ShadowLight")
	end
	return light
end

local function addPoint(parent: BasePart, range: number, brightness: number, color: Color3): PointLight
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = color
	light.Shadows = false
	light.Parent = parent
	return light
end

local function addDownBeam(source: BasePart, length: number, width0: number, width1: number, color: Color3): Beam
	local a0 = Instance.new("Attachment")
	a0.Name = "BeamStart"
	a0.Parent = source
	local a1 = Instance.new("Attachment")
	a1.Name = "BeamEnd"
	a1.Position = Vector3.new(0, -length, 0)
	a1.Parent = source
	local beam = Instance.new("Beam")
	beam.Name = "VolumetricBeam"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = width0
	beam.Width1 = width1
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Segments = 1
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.84),
		NumberSequenceKeypoint.new(0.7, 0.92),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Parent = source
	CollectionService:AddTag(beam, "VolumetricBeam")
	return beam
end

local function smokeEmitter(parent: Instance, props: {
	Name: string,
	Rate: number,
	Lifetime: NumberRange,
	Speed: NumberRange,
	Size: NumberSequence,
	Transparency: NumberSequence,
	Color: Color3,
	Direction: Enum.NormalId,
	Spread: Vector2,
	Acceleration: Vector3,
	Drag: number,
}): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = props.Name
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Rate = props.Rate
	emitter.Lifetime = props.Lifetime
	emitter.Speed = props.Speed
	emitter.Size = props.Size
	emitter.Transparency = props.Transparency
	emitter.Color = ColorSequence.new(props.Color)
	emitter.EmissionDirection = props.Direction
	emitter.SpreadAngle = props.Spread
	emitter.Acceleration = props.Acceleration
	emitter.Drag = props.Drag
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-8, 8)
	emitter.LightInfluence = 1
	emitter.LightEmission = 0
	emitter.Parent = parent
	return emitter
end

--------------------------------------------------------------------------------
-- Ground
--------------------------------------------------------------------------------
local function buildGround(ctx: Ctx, parent: Instance)
	local folder = PartFactory.folder("Ground", parent)
	ctx.part("Asphalt", Vector3.new(2 * WALL_FACE + 4, 2, ALLEY_LENGTH), at(0, -1, 0), S.Asphalt, folder, { Collide = true })

	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		ctx.part("Curb_" .. tag, Vector3.new(0.6, 0.45, ALLEY_LENGTH), at(side * 12.3, 0.225, 0), S.Curb, folder, { Collide = true })
		ctx.part("Sidewalk_" .. tag, Vector3.new(2.4, 0.4, ALLEY_LENGTH), at(side * 13.8, 0.2, 0), S.Sidewalk, folder, { Collide = true })
		for _, z in { -50, -20, 10, 40 } do
			ctx.part("Drain_" .. tag .. z, Vector3.new(1.1, 0.04, 2.2), at(side * 11.5, 0.02, z), S.DiamondDark, folder)
		end
	end

	-- Puddles: clusters of 2-3 overlapping discs read as organic shapes.
	local rng = ctx.Rng
	for i = 1, 16 do
		local cx = rng:NextNumber(-10, 10)
		local cz = rng:NextNumber(-34, 44)
		local blobs = rng:NextInteger(2, 3)
		for b = 1, blobs do
			local d = rng:NextNumber(1.6, 4.6)
			local ox = rng:NextNumber(-1.4, 1.4)
			local oz = rng:NextNumber(-1.8, 1.8)
			ctx.part(
				string.format("Puddle_%d_%d", i, b),
				Vector3.new(0.02, d, d),
				at(cx + ox, 0.011 + b * 0.001, cz + oz) * PartFactory.AxisY,
				S.Puddle,
				folder,
				{ Shape = Enum.PartType.Cylinder }
			)
		end
	end

	-- Manhole
	ctx.part("ManholeRing", Vector3.new(0.05, 2.9, 2.9), at(-6, 0.02, -16) * PartFactory.AxisY, S.MetalDark, folder, { Shape = Enum.PartType.Cylinder })
	ctx.part("Manhole", Vector3.new(0.06, 2.6, 2.6), at(-6, 0.03, -16) * PartFactory.AxisY, S.DiamondDark, folder, { Shape = Enum.PartType.Cylinder })

	-- Steam vent
	ctx.part("SteamGrate", Vector3.new(0.06, 2.4, 2.4), at(5, 0.03, 22) * PartFactory.AxisY, S.DiamondDark, folder, { Shape = Enum.PartType.Cylinder })
	local steamSource = ctx.part("SteamSource", Vector3.new(1.8, 0.2, 1.8), at(5, 0.2, 22), S.Invisible, folder)
	local steam = smokeEmitter(steamSource, {
		Name = "Steam",
		Rate = 7,
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(3, 5),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 6) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0.78),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Color = rgb(200, 200, 205),
		Direction = Enum.NormalId.Top,
		Spread = Vector2.new(10, 10),
		Acceleration = Vector3.new(1.5, 0.5, 0.6),
		Drag = 0.4,
	})
	CollectionService:AddTag(steam, "SteamVent")
end

--------------------------------------------------------------------------------
-- Buildings
--------------------------------------------------------------------------------
local function windowSkipped(side: number, floorIndex: number, z: number): boolean
	if floorIndex ~= 1 then
		return false
	end
	if side > 0 and z >= 14 and z <= 36 then
		return true -- garage header
	end
	if side < 0 and z >= 2 and z <= 14 then
		return true -- neon sign
	end
	return false
end

local function buildWindow(ctx: Ctx, folder: Instance, side: number, y: number, z: number)
	local face = side * WALL_FACE
	local inward = -side -- direction pointing into the alley
	local roll = ctx.Rng:NextNumber()
	local lit = roll < 0.14
	local style = if lit then (if ctx.Rng:NextNumber() < 0.25 then S.WindowLitCool else S.WindowLitWarm) else S.WindowDark
	local name = string.format("Window_%s_%d_%d", if side < 0 then "L" else "R", math.floor(y), math.floor(z))

	ctx.part(name, Vector3.new(0.12, 4.2, 3.2), at(face + inward * 0.06, y, z), style, folder)
	ctx.part(name .. "_Mullion", Vector3.new(0.08, 4.2, 0.1), at(face + inward * 0.12, y, z), S.ConcreteDark, folder)
	ctx.part(name .. "_Sill", Vector3.new(0.45, 0.25, 3.8), at(face + inward * 0.22, y - 2.25, z), S.Concrete, folder)
	ctx.part(name .. "_Lintel", Vector3.new(0.3, 0.3, 3.6), at(face + inward * 0.15, y + 2.25, z), S.Concrete, folder)

	if lit then
		-- Half-drawn blinds
		for slat = 0, 3 do
			ctx.part(name .. "_Blind" .. slat, Vector3.new(0.04, 0.08, 3.1), at(face + inward * 0.14, y + 1.9 - slat * 0.32, z), S.Blinds, folder)
		end
	end
end

local function buildBuilding(ctx: Ctx, parent: Instance, side: number)
	local tag = if side < 0 then "L" else "R"
	local folder = PartFactory.folder("Building_" .. tag, parent)
	local wallStyle = if side < 0 then S.BrickL else S.BrickR
	local face = side * WALL_FACE
	local inward = -side

	ctx.part("Wall", Vector3.new(3, BUILDING_HEIGHT, ALLEY_LENGTH), at(face + side * 1.5, BUILDING_HEIGHT / 2, 0), wallStyle, folder, { Collide = true })
	ctx.part("Plinth", Vector3.new(0.4, 3, ALLEY_LENGTH), at(face + inward * 0.2, 1.5, 0), S.ConcreteDark, folder, { Collide = true })
	ctx.part("Cornice", Vector3.new(1.2, 0.8, ALLEY_LENGTH), at(face + inward * 0.4, BUILDING_HEIGHT - 1.6, 0), S.Concrete, folder)
	ctx.part("CorniceCap", Vector3.new(1.6, 0.3, ALLEY_LENGTH), at(face + inward * 0.5, BUILDING_HEIGHT - 1.05, 0), S.ConcreteDark, folder)
	for i, y in FLOOR_BANDS do
		ctx.part("FloorBand" .. i, Vector3.new(0.3, 0.35, ALLEY_LENGTH), at(face + inward * 0.15, y, 0), S.Concrete, folder)
	end

	local windows = PartFactory.folder("Windows", folder)
	for floorIndex, y in FLOOR_CENTRES do
		for z = -60, 60, 10 do
			if not windowSkipped(side, floorIndex, z) then
				buildWindow(ctx, windows, side, y, z)
			end
		end
	end

	-- Drainpipes
	local pipeZs = if side < 0 then { -18, 30 } else { -34, 38 }
	for _, z in pipeZs do
		ctx.part("Drainpipe_" .. z, Vector3.new(BUILDING_HEIGHT - 2, 0.5, 0.5), at(face + inward * 0.35, (BUILDING_HEIGHT - 2) / 2, z) * PartFactory.AxisY, S.MetalDark, folder, {
			Shape = Enum.PartType.Cylinder,
		})
		ctx.part("DrainShoe_" .. z, Vector3.new(0.8, 0.5, 0.5), at(face + inward * 0.6, 0.45, z) * CFrame.Angles(0, 0, math.rad(side * 30)), S.MetalDark, folder, {
			Shape = Enum.PartType.Cylinder,
		})
		for _, y in { 8, 20, 32 } do
			ctx.part("PipeClamp_" .. z .. "_" .. y, Vector3.new(0.5, 0.12, 0.7), at(face + inward * 0.3, y, z), S.MetalDark, folder)
		end
	end

	-- AC units (right building only)
	if side > 0 then
		for i, spot in { { 12.5, -40 }, { 20, -12 }, { 12.5, 42 }, { 27.5, 8 }, { 20, 52 } } do
			local y, z = spot[1], spot[2]
			ctx.part("ACUnit" .. i, Vector3.new(1.6, 1.4, 2.2), at(face - 0.8, y, z), S.MetalLight, folder)
			ctx.part("ACGrille" .. i, Vector3.new(0.05, 1.1, 1.9), at(face - 1.62, y, z), S.Diamond, folder)
			ctx.part("ACBracket" .. i, Vector3.new(1.4, 0.1, 0.1), at(face - 0.7, y - 0.8, z - 0.9), S.MetalDark, folder)
			ctx.part("ACBracketB" .. i, Vector3.new(1.4, 0.1, 0.1), at(face - 0.7, y - 0.8, z + 0.9), S.MetalDark, folder)
		end
	end

	-- Back door + caged bulb (left building)
	if side < 0 then
		ctx.part("BackDoorFrame", Vector3.new(0.3, 7.6, 4.2), at(face + 0.15, 3.8, -12), S.ConcreteDark, folder)
		ctx.part("BackDoor", Vector3.new(0.2, 7, 3.6), at(face + 0.3, 3.5, -12), S.MetalRust, folder, { Collide = true })
		ctx.part("DoorBar", Vector3.new(0.12, 0.12, 2.6), at(face + 0.45, 3.4, -12), S.MetalDark, folder)
		local bulb = ctx.part("CagedBulb", Vector3.new(0.35, 0.35, 0.35), at(face + 0.5, 8.1, -12), S.Sodium, folder, { Shape = Enum.PartType.Ball })
		ctx.part("BulbCage", Vector3.new(0.5, 0.55, 0.5), at(face + 0.5, 8.1, -12), PartFactory.style(rgb(30, 30, 30), Enum.Material.SmoothPlastic, 0, 0.7), folder)
		addPoint(bulb, 12, 1.3, SODIUM_LIGHT)
		CollectionService:AddTag(bulb, "FlickerLight")
	end

	-- End caps so the alley never shows the void
	ctx.part("EndWall_" .. tag .. "_N", Vector3.new(WALL_FACE + 2, BUILDING_HEIGHT, 3), at(side * (WALL_FACE / 2 + 1), BUILDING_HEIGHT / 2, HALF_LENGTH + 1.5), wallStyle, folder, { Collide = true })
	ctx.part("EndWall_" .. tag .. "_S", Vector3.new(WALL_FACE + 2, BUILDING_HEIGHT, 3), at(side * (WALL_FACE / 2 + 1), BUILDING_HEIGHT / 2, -HALF_LENGTH - 1.5), wallStyle, folder, { Collide = true })
end

local function buildFireEscape(ctx: Ctx, parent: Instance)
	local folder = PartFactory.folder("FireEscape", parent)
	local zc = -30
	local x0 = -WALL_FACE
	local levels = { 6.6, 14.1, 21.6, 29.1 }

	for i, y in levels do
		ctx.part("Platform" .. i, Vector3.new(3.2, 0.18, 9), at(x0 + 1.6, y, zc), S.Diamond, folder, { Collide = true })
		ctx.part("RailTop" .. i, Vector3.new(0.12, 0.12, 9), at(x0 + 3.1, y + 3.1, zc), S.MetalDark, folder)
		ctx.part("RailMid" .. i, Vector3.new(0.08, 0.08, 9), at(x0 + 3.1, y + 1.6, zc), S.MetalDark, folder)
		for p = 0, 5 do
			ctx.part(string.format("Post%d_%d", i, p), Vector3.new(0.12, 3.1, 0.12), at(x0 + 3.1, y + 1.55, zc - 4.4 + p * 1.76), S.MetalDark, folder)
		end
		for _, endZ in { zc - 4.45, zc + 4.45 } do
			ctx.part("RailEnd" .. i .. "_" .. endZ, Vector3.new(3.0, 0.12, 0.12), at(x0 + 1.6, y + 3.1, endZ), S.MetalDark, folder)
		end
		-- Wall braces
		for _, braceZ in { zc - 3.8, zc + 3.8 } do
			ctx.segment("Brace" .. i .. "_" .. braceZ, Vector3.new(x0, y - 2.2, braceZ), Vector3.new(x0 + 3.0, y - 0.1, braceZ), 0.14, S.MetalDark, folder)
		end
		-- Stairs up to the next level
		local nextY = levels[i + 1]
		if nextY then
			local startP = Vector3.new(x0 + 2.3, y, zc - 3)
			local endP = Vector3.new(x0 + 2.3, nextY, zc + 3)
			local rise = nextY - y
			local run = 6
			local angle = math.atan2(rise, run)
			local length = math.sqrt(rise * rise + run * run)
			local mid = (startP + endP) / 2
			for _, offset in { -0.72, 0.72 } do
				ctx.part(
					"Stringer" .. i .. "_" .. offset,
					Vector3.new(0.08, 0.45, length),
					at(mid.X + offset, mid.Y, mid.Z) * CFrame.Angles(-angle, 0, 0),
					S.MetalDark,
					folder
				)
			end
			for step = 1, 8 do
				local p = startP:Lerp(endP, step / 9)
				ctx.part(string.format("Tread%d_%d", i, step), Vector3.new(1.4, 0.08, 0.5), at(p.X, p.Y + 0.1, p.Z), S.Diamond, folder)
			end
		end
	end

	-- Drop ladder below the first platform
	for _, lz in { zc + 3.6, zc + 4.3 } do
		ctx.part("LadderRail_" .. lz, Vector3.new(0.08, 4, 0.08), at(x0 + 2.8, levels[1] - 2.1, lz), S.MetalDark, folder)
	end
	for r = 0, 5 do
		ctx.part("LadderRung" .. r, Vector3.new(0.06, 0.06, 0.7), at(x0 + 2.8, levels[1] - 0.5 - r * 0.65, zc + 3.95), S.MetalDark, folder)
	end
end

--------------------------------------------------------------------------------
-- Lighting fixtures
--------------------------------------------------------------------------------
type LampDef = { X: number, Z: number, Side: number, Led: boolean, Flicker: boolean }

local function buildStreetlamps(ctx: Ctx, parent: Instance)
	local folder = PartFactory.folder("Streetlamps", parent)
	local lamps: { LampDef } = {
		{ X = -13.2, Z = 2, Side = -1, Led = false, Flicker = false },
		{ X = 13.2, Z = 26, Side = 1, Led = false, Flicker = true },
		{ X = -13.2, Z = 50, Side = -1, Led = false, Flicker = false },
		{ X = 13.2, Z = -22, Side = 1, Led = false, Flicker = false },
		{ X = -13.2, Z = -46, Side = -1, Led = true, Flicker = false },
	}
	for i, lamp in lamps do
		local model = Instance.new("Model")
		model.Name = "Streetlamp" .. i
		model.Parent = folder
		local headX = lamp.X - lamp.Side * 3.4
		local lensStyle = if lamp.Led then S.LedCool else S.Sodium
		local lightColor = if lamp.Led then LED_LIGHT else SODIUM_LIGHT

		ctx.part("Base", Vector3.new(1.1, 0.6, 1.1), at(lamp.X, 0.7, lamp.Z), S.ConcreteDark, model, { Collide = true })
		ctx.part("Pole", Vector3.new(14, 0.45, 0.45), at(lamp.X, 7.4, lamp.Z) * PartFactory.AxisY, S.MetalDark, model, {
			Shape = Enum.PartType.Cylinder,
			Collide = true,
		})
		ctx.segment("Arm", Vector3.new(lamp.X, 14, lamp.Z), Vector3.new(headX, 14, lamp.Z), 0.22, S.MetalDark, model)
		ctx.segment("ArmBrace", Vector3.new(lamp.X, 12.6, lamp.Z), Vector3.new(lamp.X - lamp.Side * 1.6, 14, lamp.Z), 0.12, S.MetalDark, model)
		ctx.part("Head", Vector3.new(1.6, 0.45, 0.9), at(headX, 13.8, lamp.Z), S.MetalDark, model)
		ctx.part("Lens", Vector3.new(1.3, 0.06, 0.6), at(headX, 13.55, lamp.Z), lensStyle, model)

		local source = ctx.part("LightSource", Vector3.new(0.2, 0.2, 0.2), at(headX, 13.4, lamp.Z), S.Invisible, model)
		addSpot(source, {
			Face = Enum.NormalId.Bottom,
			Angle = 75,
			Range = 40,
			Brightness = if lamp.Led then 2.8 else 3.5,
			Color = lightColor,
			Shadows = true,
		})
		addDownBeam(source, 13, 1.2, 11, lightColor)
		if lamp.Flicker then
			CollectionService:AddTag(model, "FlickerLight")
		end
	end
end

local function buildNeon(ctx: Ctx, parent: Instance)
	local folder = PartFactory.folder("Neon", parent)

	-- Magenta sign on the left wall above the car.
	local sign = Instance.new("Model")
	sign.Name = "NeonSign"
	sign.Parent = folder
	local x = -WALL_FACE + 0.25
	local panel = ctx.part("Panel", Vector3.new(0.3, 2.6, 9), at(x, 8.2, 8), S.MetalDark, sign)
	ctx.part("TubeTop", Vector3.new(0.12, 0.12, 9.2), at(x + 0.2, 9.55, 8), S.NeonCyan, sign)
	ctx.part("TubeBottom", Vector3.new(0.12, 0.12, 9.2), at(x + 0.2, 6.85, 8), S.NeonCyan, sign)
	ctx.part("TubeEndA", Vector3.new(0.12, 2.82, 0.12), at(x + 0.2, 8.2, 3.45), S.NeonCyan, sign)
	ctx.part("TubeEndB", Vector3.new(0.12, 2.82, 0.12), at(x + 0.2, 8.2, 12.55), S.NeonCyan, sign)
	for _, bz in { 4.5, 11.5 } do
		ctx.part("Bracket_" .. bz, Vector3.new(0.5, 0.14, 0.14), at(x - 0.1, 9.7, bz), S.MetalDark, sign)
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignText"
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 2.5
	gui.Parent = panel
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.92, 0.8)
	label.Position = UDim2.fromScale(0.04, 0.1)
	label.Text = Config.Branding.SignText
	label.TextScaled = true
	label.TextColor3 = rgb(255, 70, 175)
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(255, 150, 210)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.4
	stroke.Parent = label

	local glow = ctx.part("Glow", Vector3.new(0.2, 0.2, 0.2), at(x + 2.2, 8.2, 8), S.Invisible, sign)
	addPoint(glow, 24, 2.2, rgb(255, 70, 175))
	CollectionService:AddTag(sign, "FlickerLight")
	sign:SetAttribute("FlickerStyle", "Sign")

	-- Cyan rim strips framing the garage (rim-light the car from behind/right).
	for i, z in { 16.9, 33.1 } do
		ctx.part("RimStrip" .. i, Vector3.new(0.15, 7.2, 0.15), at(WALL_FACE - 0.25, 3.8, z), S.NeonCyan, folder)
		local holder = ctx.part("RimGlow" .. i, Vector3.new(0.2, 0.2, 0.2), at(WALL_FACE - 1.5, 3.8, z), S.Invisible, folder)
		addPoint(holder, 16, 1.4, rgb(60, 220, 255))
	end

	-- Hanging bulb on a wire over the car.
	ctx.segment("BulbWire", Vector3.new(-2, 19, 6), Vector3.new(-2, 11.2, 6), 0.05, S.Cable, folder)
	local bulb = ctx.part("HangingBulb", Vector3.new(0.4, 0.4, 0.4), at(-2, 11, 6), S.Sodium, folder, { Shape = Enum.PartType.Ball })
	ctx.part("BulbShade", Vector3.new(0.3, 1.0, 1.0), at(-2, 11.3, 6) * PartFactory.AxisY, S.MetalDark, folder, { Shape = Enum.PartType.Cylinder })
	addPoint(bulb, 11, 0.9, WARM_LIGHT)
end

--------------------------------------------------------------------------------
-- Garage
--------------------------------------------------------------------------------
local function buildGarage(ctx: Ctx, parent: Instance)
	local folder = PartFactory.folder("Garage", parent)
	local x = WALL_FACE
	ctx.part("PillarA", Vector3.new(0.9, 8.6, 0.9), at(x - 0.4, 4.3, 17.4), S.Concrete, folder, { Collide = true })
	ctx.part("PillarB", Vector3.new(0.9, 8.6, 0.9), at(x - 0.4, 4.3, 32.6), S.Concrete, folder, { Collide = true })
	ctx.part("Header", Vector3.new(0.9, 1.0, 16.1), at(x - 0.4, 9.1, 25), S.Concrete, folder)
	ctx.part("Shutter", Vector3.new(0.3, 8.2, 14.4), at(x - 0.15, 4.3, 25), S.Shutter, folder, { Collide = true })
	for i = 0, 11 do
		ctx.part("Rib" .. i, Vector3.new(0.12, 0.1, 14.4), at(x - 0.34, 0.6 + i * 0.66, 25), S.Shutter, folder)
	end
	ctx.part("BottomBar", Vector3.new(0.3, 0.3, 14.4), at(x - 0.3, 0.35, 25), S.MetalDark, folder)
	ctx.part("Handle", Vector3.new(0.15, 0.15, 1.2), at(x - 0.4, 1.2, 25), S.MetalLight, folder)
	-- Hazard chevrons on the pillars
	for i = 0, 3 do
		local y = 0.5 + i * 0.9
		ctx.part("HazardA" .. i, Vector3.new(0.92, 0.35, 0.05), at(x - 0.4, y, 16.93) * CFrame.Angles(0, 0, math.rad(35)), PartFactory.style(rgb(200, 150, 30), Enum.Material.SmoothPlastic), folder)
		ctx.part("HazardB" .. i, Vector3.new(0.92, 0.35, 0.05), at(x - 0.4, y, 33.07) * CFrame.Angles(0, 0, math.rad(35)), PartFactory.style(rgb(200, 150, 30), Enum.Material.SmoothPlastic), folder)
	end

	-- Security flood light angled down into the alley.
	ctx.part("FloodHousing", Vector3.new(0.8, 0.5, 1.2), at(x - 0.6, 10.3, 25), S.MetalDark, folder)
	ctx.part("FloodLens", Vector3.new(0.5, 0.06, 1.0), at(x - 0.75, 10.03, 25), S.Sodium, folder)
	local srcPos = Vector3.new(x - 1.0, 10.0, 25)
	local source = PartFactory.make({
		Name = "FloodSource",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = ctx.Origin * CFrame.lookAt(srcPos, srcPos + Vector3.new(-1, -1.6, 0)),
		Style = S.Invisible,
		Parent = folder,
	})
	addSpot(source, {
		Face = Enum.NormalId.Front,
		Angle = 80,
		Range = 32,
		Brightness = 2.6,
		Color = WARM_LIGHT,
		Shadows = true,
	})
end

--------------------------------------------------------------------------------
-- Workbench (LOADOUT shot)
--------------------------------------------------------------------------------
local function buildWorkbench(ctx: Ctx, parent: Instance)
	local folder = PartFactory.folder("Workbench", parent)
	local zc = 10

	ctx.part("Top", Vector3.new(2.6, 0.25, 7), at(13.6, 3.1, zc), S.Wood, folder, { Collide = true })
	ctx.part("FrontLip", Vector3.new(0.1, 0.25, 7), at(12.28, 3.1, zc), S.MetalDark, folder)
	for _, lx in { 12.45, 14.75 } do
		for _, lz in { zc - 3.3, zc + 3.3 } do
			ctx.part("Leg", Vector3.new(0.22, 2.95, 0.22), at(lx, 1.5, lz), S.MetalDark, folder, { Collide = true })
		end
	end
	ctx.part("Shelf", Vector3.new(2.4, 0.12, 6.6), at(13.6, 0.9, zc), S.Wood, folder)
	ctx.part("Pegboard", Vector3.new(0.12, 4.2, 7), at(WALL_FACE - 0.12, 5.6, zc), S.Pegboard, folder)
	ctx.part("PegboardFrameTop", Vector3.new(0.16, 0.12, 7.1), at(WALL_FACE - 0.14, 7.7, zc), S.MetalDark, folder)
	ctx.part("PegboardFrameBottom", Vector3.new(0.16, 0.12, 7.1), at(WALL_FACE - 0.14, 3.5, zc), S.MetalDark, folder)

	-- Tools on the pegboard
	local px = WALL_FACE - 0.22
	ctx.part("Wrench", Vector3.new(0.06, 1.3, 0.16), at(px, 6.0, zc - 2.4), S.MetalLight, folder)
	ctx.part("WrenchHead", Vector3.new(0.06, 0.22, 0.38), at(px, 6.68, zc - 2.4), S.MetalLight, folder)
	ctx.part("HammerHandle", Vector3.new(0.08, 1.0, 0.12), at(px, 5.8, zc - 1.6), S.Wood, folder)
	ctx.part("HammerHead", Vector3.new(0.1, 0.18, 0.5), at(px, 6.35, zc - 1.6), S.MetalDark, folder)
	ctx.part("Screwdriver", Vector3.new(0.05, 0.9, 0.05), at(px, 6.1, zc - 0.9), S.MetalLight, folder)
	ctx.part("ScrewdriverGrip", Vector3.new(0.09, 0.35, 0.09), at(px, 6.65, zc - 0.9), PartFactory.style(rgb(170, 40, 30), Enum.Material.SmoothPlastic), folder)
	ctx.part("TapeRoll", Vector3.new(0.18, 0.5, 0.5), at(px - 0.05, 6.2, zc + 2.6), S.FabricDark, folder, { Shape = Enum.PartType.Cylinder })
	ctx.part("Clipboard", Vector3.new(0.04, 0.9, 0.65), at(px, 5.2, zc + 1.6), PartFactory.style(rgb(200, 196, 182), Enum.Material.SmoothPlastic), folder)

	-- Upper shelf with boxes
	ctx.part("UpperShelf", Vector3.new(1.4, 0.12, 7), at(14.3, 8.0, zc), S.Wood, folder)
	for i, bz in { zc - 2.4, zc - 0.9, zc + 2.2 } do
		ctx.part("Box" .. i, Vector3.new(1.0, 0.8, 1.2), at(14.35, 8.46, bz) * CFrame.Angles(0, math.rad((i - 2) * 4), 0), S.Cardboard, folder)
	end

	-- Work lamp
	ctx.segment("LampArm", Vector3.new(WALL_FACE - 0.1, 9.0, zc), Vector3.new(13.2, 9.0, zc), 0.12, S.MetalDark, folder)
	ctx.part("LampShade", Vector3.new(0.9, 0.45, 0.9), at(13.2, 8.7, zc), S.MetalDark, folder)
	ctx.part("LampBulb", Vector3.new(0.4, 0.12, 0.4), at(13.2, 8.45, zc), S.Sodium, folder)
	local lampSource = ctx.part("LampSource", Vector3.new(0.2, 0.2, 0.2), at(13.2, 8.35, zc), S.Invisible, folder)
	addSpot(lampSource, {
		Face = Enum.NormalId.Bottom,
		Angle = 80,
		Range = 16,
		Brightness = 3,
		Color = WARM_LIGHT,
		Shadows = true,
	})
	addDownBeam(lampSource, 5, 0.7, 4.5, WARM_LIGHT)

	-- Bench items
	ctx.part("WeaponMat", Vector3.new(1.9, 0.03, 4.2), at(13.5, 3.24, zc - 0.6), S.FabricDark, folder)
	ctx.part("LaptopBase", Vector3.new(1.0, 0.05, 0.7), at(13.9, 3.25, zc + 2.4), S.MetalDark, folder)
	local screenCF = at(14.38, 3.6, zc + 2.4) * CFrame.Angles(0, 0, math.rad(-12))
	ctx.part("LaptopLid", Vector3.new(0.04, 0.7, 1.0), screenCF, S.MetalDark, folder)
	local screen = ctx.part("LaptopScreen", Vector3.new(0.02, 0.6, 0.9), screenCF * CFrame.new(-0.03, 0, 0), S.ScreenGlow, folder)
	local screenGui = Instance.new("SurfaceGui")
	screenGui.Face = Enum.NormalId.Left
	screenGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	screenGui.PixelsPerStud = 120
	screenGui.LightInfluence = 0
	screenGui.Brightness = 1.4
	screenGui.Parent = screen
	local screenText = Instance.new("TextLabel")
	screenText.BackgroundTransparency = 1
	screenText.Size = UDim2.fromScale(0.86, 0.7)
	screenText.Position = UDim2.fromScale(0.07, 0.15)
	screenText.Text = "STASH TERMINAL\nAWAITING EXTRACTION"
	screenText.TextScaled = true
	screenText.TextColor3 = rgb(170, 240, 255)
	screenText.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)
	screenText.Parent = screenGui
	addPoint(screen, 4, 0.8, rgb(60, 170, 220))

	for i, y in { 3.6, 4.37 } do
		ctx.part("AmmoCan" .. i, Vector3.new(0.5, 0.75, 1.1), at(13.85, y, zc + 3.0 - (i - 1) * 0.08), S.Olive, folder)
		ctx.part("AmmoHandle" .. i, Vector3.new(0.08, 0.06, 0.6), at(13.85, y + 0.41, zc + 3.0 - (i - 1) * 0.08), S.MetalDark, folder)
	end

	-- Duffel bag on the floor
	ctx.part("Duffel", Vector3.new(1.6, 1.1, 2.4), at(12.4, 0.75, zc + 5.2), S.FabricDark, folder, { Collide = true })
	for _, ez in { zc + 4.0, zc + 6.4 } do
		ctx.part("DuffelEnd", Vector3.new(0.12, 1.1, 1.1), at(12.4, 0.75, ez) * PartFactory.AxisZ, S.FabricDark, folder, { Shape = Enum.PartType.Cylinder })
	end
	ctx.part("DuffelStrap", Vector3.new(1.65, 0.06, 0.14), at(12.4, 1.32, zc + 5.2), S.MetalDark, folder)

	-- Mounting anchors for Phase 2 weapon models.
	local displays = PartFactory.folder("WeaponDisplays", folder)
	ctx.part("Display_Primary", Vector3.new(0.2, 0.2, 0.2), at(13.4, 3.32, zc - 1.4), S.Invisible, displays)
	ctx.part("Display_Secondary", Vector3.new(0.2, 0.2, 0.2), at(13.3, 3.3, zc + 0.9), S.Invisible, displays)
end

--------------------------------------------------------------------------------
-- Props
--------------------------------------------------------------------------------
local function buildProps(ctx: Ctx, parent: Instance)
	local folder = PartFactory.folder("Props", parent)
	local rng = ctx.Rng

	-- Dumpster
	local dz = 20
	local dx = -13.0
	ctx.part("DumpsterBody", Vector3.new(2.8, 3.0, 5.8), at(dx, 1.7, dz), S.Dumpster, folder, { Collide = true })
	ctx.part("DumpsterLid", Vector3.new(3.0, 0.15, 6.0), at(dx, 3.3, dz) * CFrame.Angles(0, 0, math.rad(-8)), S.Dumpster, folder)
	ctx.part("DumpsterRust", Vector3.new(0.05, 1.2, 2.0), at(dx + 1.42, 1.4, dz + 1.2), S.MetalRust, folder)
	for _, pz in { dz - 1.5, dz + 1.5 } do
		ctx.part("LiftPocket", Vector3.new(0.3, 0.5, 1.2), at(dx + 1.5, 2.3, pz), S.MetalDark, folder)
	end
	for _, wx in { dx - 1.1, dx + 1.1 } do
		for _, wz in { dz - 2.5, dz + 2.5 } do
			ctx.part("Caster", Vector3.new(0.25, 0.4, 0.4), at(wx, 0.2, wz), S.MetalDark, folder, { Shape = Enum.PartType.Cylinder })
		end
	end
	for i = 1, 5 do
		local d = rng:NextNumber(1.3, 1.8)
		ctx.part("TrashBag" .. i, Vector3.new(d, d, d), at(rng:NextNumber(-11.4, -10.4), d / 2 - 0.15, dz - 4 + i * 1.3), S.TrashBag, folder, {
			Shape = Enum.PartType.Ball,
			Collide = true,
		})
	end

	-- Crate stack
	local cratePositions = {
		at(11.2, 1.2, -16),
		at(11.3, 1.2, -18.6),
		at(11.25, 3.6, -17.2) * CFrame.Angles(0, math.rad(12), 0),
	}
	for i, cf in cratePositions do
		ctx.part("Crate" .. i, Vector3.new(2.4, 2.4, 2.4), cf, S.Wood, folder, { Collide = true })
		ctx.part("CrateStrapA" .. i, Vector3.new(2.46, 0.12, 0.08), cf * CFrame.new(0, 0, 0.6), S.MetalDark, folder)
		ctx.part("CrateStrapB" .. i, Vector3.new(2.46, 0.12, 0.08), cf * CFrame.new(0, 0, -0.6), S.MetalDark, folder)
	end

	-- Barrels
	local barrelColors = { rgb(52, 70, 96), rgb(110, 60, 40), rgb(60, 62, 58) }
	for i, pos in { Vector3.new(11.8, 0, -27), Vector3.new(10.2, 0, -28.4), Vector3.new(11.9, 0, -29.6) } do
		local barrelStyle = PartFactory.style(barrelColors[i], Enum.Material.CorrodedMetal)
		ctx.part("Barrel" .. i, Vector3.new(3.0, 2.0, 2.0), at(pos.X, 1.5, pos.Z) * PartFactory.AxisY, barrelStyle, folder, {
			Shape = Enum.PartType.Cylinder,
			Collide = true,
		})
		for _, ry in { 1.0, 2.0 } do
			ctx.part("BarrelRib" .. i .. "_" .. ry, Vector3.new(0.12, 2.06, 2.06), at(pos.X, ry, pos.Z) * PartFactory.AxisY, barrelStyle, folder, {
				Shape = Enum.PartType.Cylinder,
			})
		end
		ctx.part("BarrelLid" .. i, Vector3.new(0.05, 1.9, 1.9), at(pos.X, 3.01, pos.Z) * PartFactory.AxisY, S.MetalDark, folder, { Shape = Enum.PartType.Cylinder })
	end

	-- Pallets leaning on the right wall
	for i, pz in { -6, -8.4 } do
		local cf = at(WALL_FACE - 0.6 - i * 0.25, 1.8, pz) * CFrame.Angles(0, 0, math.rad(10 + i * 3))
		ctx.part("PalletBack" .. i, Vector3.new(0.12, 3.6, 4.0), cf, S.Wood, folder, { Collide = true })
		for slat = -1, 1 do
			ctx.part("PalletSlat" .. i .. "_" .. slat, Vector3.new(0.18, 3.6, 0.35), cf * CFrame.new(-0.12, 0, slat * 1.7), S.Wood, folder)
		end
	end

	-- Overhead cables with sag
	local cables = {
		{ Y = 19, Z = -40, Sag = 1.8 },
		{ Y = 21.5, Z = -18, Sag = 2.2 },
		{ Y = 24, Z = 0, Sag = 1.6 },
		{ Y = 19.5, Z = 12, Sag = 2.4 },
		{ Y = 26, Z = 34, Sag = 1.9 },
		{ Y = 22, Z = 56, Sag = 2.1 },
	}
	for i, cable in cables do
		local drift = rng:NextNumber(-1.2, 1.2)
		local a = Vector3.new(-WALL_FACE, cable.Y, cable.Z)
		local m = Vector3.new(0, cable.Y - cable.Sag, cable.Z + drift)
		local b = Vector3.new(WALL_FACE, cable.Y + rng:NextNumber(-0.8, 0.8), cable.Z + drift * 2)
		ctx.segment("CableA" .. i, a, m, 0.08, S.Cable, folder)
		ctx.segment("CableB" .. i, m, b, 0.08, S.Cable, folder)
	end
end

--------------------------------------------------------------------------------
-- FX, cameras, spawn points
--------------------------------------------------------------------------------
local function buildMist(ctx: Ctx, parent: Instance)
	local folder = PartFactory.folder("GroundMist", parent)
	for i, z in { -40, -6, 28, 62 } do
		local volume = ctx.part("MistVolume" .. i, Vector3.new(26, 0.5, 34), at(0, 0.6, z), S.Invisible, folder)
		local mist = smokeEmitter(volume, {
			Name = "Mist",
			Rate = 2.5,
			Lifetime = NumberRange.new(10, 14),
			Speed = NumberRange.new(0.2, 0.6),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 9), NumberSequenceKeypoint.new(1, 14) }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.9),
				NumberSequenceKeypoint.new(0.7, 0.92),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = rgb(170, 176, 186),
			Direction = Enum.NormalId.Top,
			Spread = Vector2.new(60, 60),
			Acceleration = Vector3.new(0.25, 0.02, 0.1),
			Drag = 0.2,
		})
		CollectionService:AddTag(mist, "GroundMist")
	end
end

type ShotDef = { Name: string, From: Vector3, To: Vector3, Fov: number, Focus: number, Radius: number }

local function buildCameraRig(ctx: Ctx, parent: Instance)
	local folder = PartFactory.folder("CameraRig", parent)
	local shots: { ShotDef } = {
		{ Name = "MenuShot", From = Vector3.new(12.5, 3.7, -9.5), To = Vector3.new(0.6, 2.3, 7.6), Fov = 38, Focus = 20.6, Radius = 9 },
		{ Name = "LoadoutShot", From = Vector3.new(7.0, 5.6, 4.4), To = Vector3.new(12.4, 3.5, 11.55), Fov = 44, Focus = 9.1, Radius = 3.5 },
		{ Name = "SettingsShot", From = Vector3.new(-7.5, 1.6, -9.5), To = Vector3.new(-2.25, 1.9, -1.63), Fov = 30, Focus = 9.2, Radius = 2.6 },
	}
	for _, shot in shots do
		local part = PartFactory.make({
			Name = shot.Name,
			Size = Vector3.new(0.4, 0.4, 0.8),
			CFrame = ctx.Origin * CFrame.lookAt(shot.From, shot.To),
			Style = S.Invisible,
			Parent = folder,
		})
		part:SetAttribute("FieldOfView", shot.Fov)
		part:SetAttribute("FocusDistance", shot.Focus)
		part:SetAttribute("InFocusRadius", shot.Radius)
	end
end

local function buildDeployPoints(ctx: Ctx, parent: Instance)
	local folder = PartFactory.folder("DeployPoints", parent)
	for i, p in { Vector3.new(5, 0.1, -2), Vector3.new(7.5, 0.1, -0.8), Vector3.new(2.6, 0.1, -0.4), Vector3.new(9.5, 0.1, -3.2) } do
		PartFactory.make({
			Name = "DeployPoint" .. i,
			Size = Vector3.new(2, 0.2, 2),
			CFrame = ctx.Origin * CFrame.lookAt(p, p + Vector3.zAxis),
			Style = S.Invisible,
			Parent = folder,
		})
	end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
function SafehouseBuilder.build(): Model
	local origin = Config.World.Origin
	local ctx = makeCtx(origin, 7)

	local model = Instance.new("Model")
	model.Name = Config.World.SafehouseName
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	buildGround(ctx, model)
	local buildings = PartFactory.folder("Buildings", model)
	buildBuilding(ctx, buildings, -1)
	buildBuilding(ctx, buildings, 1)
	buildFireEscape(ctx, buildings)
	buildStreetlamps(ctx, model)
	buildNeon(ctx, model)
	buildGarage(ctx, model)
	buildWorkbench(ctx, model)
	buildProps(ctx, model)
	buildMist(ctx, model)
	buildCameraRig(ctx, model)
	buildDeployPoints(ctx, model)

	local car = GetawayCarBody.build(origin * Config.World.CarPose, {
		Name = Config.World.CarName,
		Anchored = true,
		PlateText = Config.Branding.PlateText,
	})
	car.Model.Parent = model

	model.PrimaryPart = nil
	model.Parent = Workspace
	return model
end

-- Returns the existing Safehouse (e.g. one baked in edit mode) or builds it.
function SafehouseBuilder.ensure(rebuild: boolean?): Model
	local existing = Workspace:FindFirstChild(Config.World.SafehouseName)
	if existing and existing:IsA("Model") then
		if not rebuild then
			return existing
		end
		existing:Destroy()
	end
	local started = os.clock()
	local model = SafehouseBuilder.build()
	local count = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	print(string.format("[Safehouse] built %d parts in %.1f ms", count, (os.clock() - started) * 1000))
	return model
end

return SafehouseBuilder
