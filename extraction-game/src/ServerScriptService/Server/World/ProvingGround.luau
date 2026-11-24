--!strict
--[[
	ProvingGround
	Opens the north end of the safehouse alley onto a fog-soaked industrial
	lot for driving (Phase 4 turns this space into the raid zone):

	  • gate pillars + overhead sign where the alley end wall used to be
	  • 300 × 400 wet asphalt lot with painted lanes, perimeter jersey walls
	  • cone slalom, launch ramp, painted drift circle with tyre stacks
	  • rusted shipping containers as cover / obstacles
	  • sodium high-mast lights (no shadows, for performance) with light shafts
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local PartFactory = require(Shared.Builders.PartFactory)

local ProvingGround = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local S = {
	Asphalt = PartFactory.style(rgb(34, 35, 38), Enum.Material.Asphalt, 0.05),
	Paint = PartFactory.style(rgb(200, 196, 180), Enum.Material.SmoothPlastic, 0, 0.25, false),
	PaintYellow = PartFactory.style(rgb(210, 170, 50), Enum.Material.SmoothPlastic, 0, 0.25, false),
	Concrete = PartFactory.style(rgb(110, 108, 104), Enum.Material.Concrete),
	ConcreteDark = PartFactory.style(rgb(60, 60, 64), Enum.Material.Concrete),
	Metal = PartFactory.style(rgb(44, 46, 50), Enum.Material.Metal, 0.05),
	ConeOrange = PartFactory.style(rgb(230, 100, 30), Enum.Material.SmoothPlastic),
	ConeBand = PartFactory.style(rgb(230, 230, 230), Enum.Material.SmoothPlastic, 0.2),
	Rubber = PartFactory.style(rgb(22, 22, 22), PartFactory.material("Rubber", Enum.Material.SmoothPlastic)),
	Sodium = PartFactory.style(rgb(255, 186, 120), Enum.Material.Neon, 0, 0, false),
	Puddle = PartFactory.style(rgb(16, 18, 21), Enum.Material.SmoothPlastic, 0.42, 0, false),
	Invisible = PartFactory.style(rgb(0, 0, 0), Enum.Material.SmoothPlastic, 0, 1, false),
}

local CONTAINER_COLORS = { rgb(120, 46, 32), rgb(40, 70, 90), rgb(70, 80, 50), rgb(130, 100, 40) }

local LOT_WIDTH = 300
local LOT_LENGTH = 400
local LOT_START = 75 -- alley ends at z = 75

function ProvingGround.build(safehouse: Model)
	local origin = Config.World.Origin
	local rng = Random.new(11)
	local existing = safehouse:FindFirstChild("ProvingGround")
	if existing then
		existing:Destroy()
	end
	local folder = PartFactory.folder("ProvingGround", safehouse)

	local function part(name: string, size: Vector3, cf: CFrame, style: PartFactory.Style, collide: boolean?, parent: Instance?, shape: Enum.PartType?, class: ("Part" | "WedgePart")?): BasePart
		return PartFactory.make({
			Name = name,
			Size = size,
			CFrame = origin * cf,
			Style = style,
			CanCollide = collide == true,
			Parent = parent or folder,
			Shape = shape,
			Class = class,
		})
	end

	-- Open the alley's north end.
	local buildings = safehouse:FindFirstChild("Buildings")
	if buildings then
		for _, d in buildings:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "EndWall_L_N" or d.Name == "EndWall_R_N") then
				d:Destroy()
			end
		end
	end

	-- Gate
	local zc = LOT_START
	for _, x in { -14.2, 14.2 } do
		part("GatePillar", Vector3.new(1.6, 12, 1.6), CFrame.new(x, 6, zc), S.ConcreteDark, true)
		part("GateStripe", Vector3.new(1.62, 0.5, 1.62), CFrame.new(x, 2, zc), S.PaintYellow)
	end
	local sign = part("GateSign", Vector3.new(29, 2, 0.4), CFrame.new(0, 11.4, zc), S.Metal, true)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.3
	gui.Brightness = 1.5
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "PROVING GROUND  ·  SECTOR 7"
	label.TextScaled = true
	label.TextColor3 = rgb(255, 168, 86)
	label.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
	label.Parent = gui

	-- Lot surface + perimeter
	local zMid = LOT_START + LOT_LENGTH / 2
	part("LotAsphalt", Vector3.new(LOT_WIDTH, 2, LOT_LENGTH), CFrame.new(0, -1, zMid), S.Asphalt, true)
	local zEnd = LOT_START + LOT_LENGTH
	local walls = PartFactory.folder("Perimeter", folder)
	part("WallN", Vector3.new(LOT_WIDTH, 5, 2), CFrame.new(0, 2.5, zEnd), S.Concrete, true, walls)
	for _, side in { -1, 1 } do
		part("WallSide", Vector3.new(2, 5, LOT_LENGTH), CFrame.new(side * LOT_WIDTH / 2, 2.5, zMid), S.Concrete, true, walls)
		part("WallSouth", Vector3.new(LOT_WIDTH / 2 - 15, 5, 2), CFrame.new(side * (15 + (LOT_WIDTH / 2 - 15) / 2), 2.5, LOT_START), S.Concrete, true, walls)
	end

	-- Painted main road (centre dashes + edge lines)
	local paint = PartFactory.folder("Markings", folder)
	for z = LOT_START + 8, zEnd - 10, 14 do
		part("CentreDash", Vector3.new(0.4, 0.02, 7), CFrame.new(0, 0.011, z), S.PaintYellow, false, paint)
	end
	for _, x in { -11, 11 } do
		part("EdgeLine", Vector3.new(0.35, 0.02, LOT_LENGTH - 20), CFrame.new(x, 0.011, zMid), S.Paint, false, paint)
	end

	-- Cone slalom (left lane)
	local cones = PartFactory.folder("Slalom", folder)
	for i = 0, 7 do
		local x = -40 + (if i % 2 == 0 then -3 else 3)
		local z = 150 + i * 20
		local cone = Instance.new("Model")
		cone.Name = "Cone"
		cone.Parent = cones
		part("Base", Vector3.new(1.4, 0.15, 1.4), CFrame.new(x, 0.075, z), S.ConeOrange, true, cone)
		part("Body", Vector3.new(1.8, 0.7, 0.7), CFrame.new(x, 1.05, z) * PartFactory.AxisY, S.ConeOrange, true, cone, Enum.PartType.Cylinder)
		part("Band", Vector3.new(0.35, 0.74, 0.74), CFrame.new(x, 1.2, z) * PartFactory.AxisY, S.ConeBand, false, cone, Enum.PartType.Cylinder)
	end

	-- Launch ramp (right lane)
	local ramp = PartFactory.folder("Ramp", folder)
	part("RampWedge", Vector3.new(14, 3.5, 22), CFrame.new(45, 1.75, 210), S.ConcreteDark, true, ramp, nil, "WedgePart")
	part("RampDeck", Vector3.new(14, 3.5, 8), CFrame.new(45, 1.75, 225), S.ConcreteDark, true, ramp)
	part("RampLanding", Vector3.new(14, 3.5, 22), CFrame.new(45, 1.75, 270) * CFrame.Angles(0, math.pi, 0), S.ConcreteDark, true, ramp, nil, "WedgePart")
	for _, x in { 38.2, 51.8 } do
		part("RampStripe", Vector3.new(0.4, 0.05, 22), CFrame.new(x, 1.78, 210) * CFrame.Angles(-math.atan2(3.5, 22), 0, 0), S.PaintYellow, false, ramp)
	end

	-- Drift circle with tyre stacks
	local drift = PartFactory.folder("DriftPad", folder)
	local centre = Vector3.new(-70, 0, 340)
	local segments = 36
	for i = 0, segments - 1 do
		local a0 = i / segments * 2 * math.pi
		local a1 = (i + 0.6) / segments * 2 * math.pi
		local p0 = centre + Vector3.new(math.cos(a0) * 32, 0.011, math.sin(a0) * 32)
		local p1 = centre + Vector3.new(math.cos(a1) * 32, 0.011, math.sin(a1) * 32)
		part("CircleDash", Vector3.new(0.5, 0.02, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), S.Paint, false, drift)
	end
	for i = 0, 5 do
		local a = i / 6 * 2 * math.pi
		local base = centre + Vector3.new(math.cos(a) * 8, 0, math.sin(a) * 8)
		for level = 0, 2 do
			part("Tyre", Vector3.new(0.7, 2.4, 2.4), CFrame.new(base.X, 0.35 + level * 0.7, base.Z) * PartFactory.AxisY, S.Rubber, true, drift, Enum.PartType.Cylinder)
		end
	end

	-- Shipping containers
	local containers = PartFactory.folder("Containers", folder)
	local spots = {
		{ CFrame.new(90, 0, 120), 0 },
		{ CFrame.new(98, 0, 150), 8 },
		{ CFrame.new(-95, 0, 190), 90 },
		{ CFrame.new(100, 0, 330), 4 },
		{ CFrame.new(-110, 0, 420), 0 },
		{ CFrame.new(20, 0, 400), 90 },
	}
	for i, spot in spots do
		local base = (spot[1] :: CFrame) * CFrame.Angles(0, math.rad(spot[2] :: number), 0)
		local color = CONTAINER_COLORS[(i - 1) % #CONTAINER_COLORS + 1]
		local style = PartFactory.style(color, Enum.Material.CorrodedMetal)
		local model = Instance.new("Model")
		model.Name = "Container"
		model.Parent = containers
		part("Box", Vector3.new(8, 8.5, 20), base * CFrame.new(0, 4.25, 0), style, true, model)
		for r = -8, 8, 2 do
			part("RibL", Vector3.new(0.2, 8.1, 0.35), base * CFrame.new(-4.05, 4.25, r), style, false, model)
			part("RibR", Vector3.new(0.2, 8.1, 0.35), base * CFrame.new(4.05, 4.25, r), style, false, model)
		end
		part("DoorBars", Vector3.new(7.6, 8, 0.2), base * CFrame.new(0, 4.25, 10.05), PartFactory.style(color:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.CorrodedMetal), false, model)
		if i % 2 == 0 then
			-- Stack a second one on every other spot.
			part("BoxTop", Vector3.new(8, 8.5, 20), base * CFrame.new(0, 12.75, 1) * CFrame.Angles(0, math.rad(rng:NextNumber(-4, 4)), 0), PartFactory.style(CONTAINER_COLORS[(i % #CONTAINER_COLORS) + 1], Enum.Material.CorrodedMetal), true, model)
		end
	end

	-- Puddles
	for i = 1, 40 do
		local d = rng:NextNumber(3, 9)
		part("Puddle" .. i, Vector3.new(0.02, d, d), CFrame.new(rng:NextNumber(-130, 130), 0.012, rng:NextNumber(LOT_START + 10, zEnd - 10)) * PartFactory.AxisY, S.Puddle, false, paint, Enum.PartType.Cylinder)
	end

	-- High-mast sodium lights
	local lights = PartFactory.folder("Lights", folder)
	for i = 0, 7 do
		local x = if i % 2 == 0 then -16 else 16
		local z = LOT_START + 30 + i * 48
		part("Mast", Vector3.new(26, 0.7, 0.7), CFrame.new(x, 13, z) * PartFactory.AxisY, S.Metal, true, lights, Enum.PartType.Cylinder)
		part("MastBase", Vector3.new(1.6, 0.8, 1.6), CFrame.new(x, 0.4, z), S.ConcreteDark, true, lights)
		part("Head", Vector3.new(3, 0.6, 1.4), CFrame.new(x, 26, z), S.Metal, false, lights)
		part("Lens", Vector3.new(2.6, 0.08, 1.1), CFrame.new(x, 25.66, z), S.Sodium, false, lights)
		local source = part("Source", Vector3.new(0.2, 0.2, 0.2), CFrame.new(x, 25.4, z), S.Invisible, false, lights)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 100
		spot.Range = 60
		spot.Brightness = 3
		spot.Color = rgb(255, 178, 110)
		spot.Shadows = false
		spot.Parent = source
		local a0 = Instance.new("Attachment")
		a0.Parent = source
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -25, 0)
		a1.Parent = source
		local beam = Instance.new("Beam")
		beam.Name = "VolumetricBeam"
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 2
		beam.Width1 = 24
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(rgb(255, 178, 110))
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.86),
			NumberSequenceKeypoint.new(0.7, 0.93),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Parent = source
		CollectionService:AddTag(beam, "VolumetricBeam")
	end

end

return ProvingGround
