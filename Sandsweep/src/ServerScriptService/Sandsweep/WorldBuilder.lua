-- WorldBuilder (ModuleScript) - ServerScriptService/Sandsweep/WorldBuilder
-- Builds the cozy desert: lighting, terrain dunes & mesas, bedrock, retaining
-- open desert, outer dunes, base camp, Glass Furnace, Upgrade Booth, lot board, decor.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Sandsweep")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local PartKit = require(Shared:WaitForChild("PartKit"))
local ToolModels = require(Shared:WaitForChild("ToolModels"))
local Util = require(Shared:WaitForChild("Util"))

local WorldBuilder = {}
WorldBuilder.Refs = {}

local Palette = GameConfig.Palette
local Lot = GameConfig.Lot

local HALF_X = Lot.SizeX / 2
local HALF_Z = Lot.SizeZ / 2
local WORLD_R = Lot.WorldRadius
local CAMP_Y = Lot.CampY
local CAMP_Z = Lot.CenterZ + HALF_Z + Lot.CampDepth / 2
local CAMP_HALF_X = 84
local ROW1_Z = Lot.CenterZ + HALF_Z + 26 -- kiln, booth, garage, spawn
local FACTORY_Z = Lot.CenterZ + HALF_Z + 70 -- conveyor factory row
WorldBuilder.FactoryOrigin = CFrame.new(Lot.CenterX, CAMP_Y, FACTORY_Z)
local RES = 4

local function smoothstep(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Height of the decorative outer desert (never diggable). Matches the dig
-- zone's edge height at the border, rolls into big dunes further out, and is
-- flattened where the base camp sits.
local function outerHeight(x, z)
	local dx = math.max(0, math.abs(x - Lot.CenterX) - HALF_X)
	local dz = math.max(0, math.abs(z - Lot.CenterZ) - HALF_Z)
	local e = math.sqrt(dx * dx + dz * dz)
	local n = math.noise(x * 0.011, z * 0.011, 4.2) + math.noise(x * 0.027, z * 0.027, 9.1) * 0.4
	local dunes = math.clamp(n * 0.6 + 0.5, 0, 1) * 30
	local h = Lot.EdgeHeight + smoothstep(e / 70) * dunes
	-- settle back down near the world rim
	local rim = math.max(math.abs(x - Lot.CenterX), math.abs(z - Lot.CenterZ))
	h += (4 - h) * smoothstep((rim - (WORLD_R - 70)) / 70)
	-- flat ground for the base camp
	local campOut = math.max((math.abs(x - Lot.CenterX) - CAMP_HALF_X) / 24, (math.abs(z - CAMP_Z) - Lot.CampDepth / 2) / 24)
	local campHeight = Lot.EdgeHeight + (CAMP_Y - Lot.EdgeHeight) * smoothstep((z - (Lot.CenterZ + HALF_Z)) / 10)
	h = campHeight + (h - campHeight) * smoothstep(campOut)
	return math.clamp(h, 0.5, 48)
end
WorldBuilder.OuterHeight = outerHeight

local function solid(parent, props)
	props.CanCollide = props.CanCollide ~= false
	props.CanQuery = props.CanQuery ~= false
	props.CanTouch = props.CanTouch ~= false
	return PartKit.Part(parent, props)
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function addSurfaceText(part, face, lines)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Palette.Cream
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 10
	stroke.Color = Palette.Ochre
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = frame
	local labels = {}
	for index, line in ipairs(lines) do
		local label = Instance.new("TextLabel")
		label.Name = line.Name or ("Line" .. index)
		label.LayoutOrder = index
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.94, line.Height or 0.3)
		label.Font = line.Font or Enum.Font.FredokaOne
		label.Text = line.Text
		label.TextScaled = true
		label.TextColor3 = line.Color or Palette.Ink
		label.Parent = frame
		labels[label.Name] = label
	end
	return gui, labels
end

--------------------------------------------------------------------------
-- LIGHTING: warm golden hour
--------------------------------------------------------------------------
function WorldBuilder.SetupLighting()
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.ClockTime = 16.9
	Lighting.GeographicLatitude = 28
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(122, 96, 82)
	Lighting.OutdoorAmbient = Color3.fromRGB(176, 146, 122)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 222, 176)
	Lighting.ColorShift_Bottom = Color3.fromRGB(180, 120, 90)
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.ExposureCompensation = 0.1

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.18
	atmosphere.Color = Color3.fromRGB(242, 206, 160)
	atmosphere.Decay = Color3.fromRGB(196, 120, 84)
	atmosphere.Glare = 0.45
	atmosphere.Haze = 1.7
	atmosphere.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 16
	sky.MoonAngularSize = 8
	sky.StarCount = 1500
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.55
	bloom.Size = 30
	bloom.Threshold = 1.7
	bloom.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.07
	sunRays.Spread = 0.55
	sunRays.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Brightness = 0.02
	color.Contrast = 0.08
	color.Saturation = 0.14
	color.TintColor = Color3.fromRGB(255, 243, 226)
	color.Parent = Lighting

	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.12
	dof.FocusDistance = 60
	dof.InFocusRadius = 120
	dof.NearIntensity = 0
	dof.Parent = Lighting

	local terrain = Workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.42
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(255, 236, 214)
	clouds.Parent = terrain
end

--------------------------------------------------------------------------
-- TERRAIN SURROUNDINGS (outer desert: looks like the same desert, never diggable)
--------------------------------------------------------------------------
local function writeHeightRegion(minX, maxX, minZ, maxZ)
	local terrain = Workspace.Terrain
	local top = 52
	local region = Region3.new(Vector3.new(minX, 0, minZ), Vector3.new(maxX, top, maxZ)):ExpandToGrid(RES)
	local regionMin = region.CFrame.Position - region.Size / 2
	local nx = math.floor(region.Size.X / RES + 0.5)
	local ny = math.floor(region.Size.Y / RES + 0.5)
	local nz = math.floor(region.Size.Z / RES + 0.5)
	local materials, occupancies = {}, {}
	for x = 1, nx do
		local mx, ox = {}, {}
		materials[x], occupancies[x] = mx, ox
		for y = 1, ny do
			mx[y], ox[y] = {}, {}
		end
		for z = 1, nz do
			local worldX = regionMin.X + (x - 0.5) * RES
			local worldZ = regionMin.Z + (z - 0.5) * RES
			local height = outerHeight(worldX, worldZ)
			for y = 1, ny do
				local occupancy = math.clamp((height - (regionMin.Y + (y - 1) * RES)) / RES, 0, 1)
				if occupancy > 0.03 then
					mx[y][z] = Enum.Material.Sand
					ox[y][z] = occupancy
				else
					mx[y][z] = Enum.Material.Air
					ox[y][z] = 0
				end
			end
		end
	end
	terrain:WriteVoxels(region, RES, materials, occupancies)
end

local function buildTerrainSurroundings()
	local terrain = Workspace.Terrain
	terrain:Clear()
	terrain:SetMaterialColor(Enum.Material.Sand, Palette.Sand)
	terrain:SetMaterialColor(Enum.Material.Sandstone, Color3.fromRGB(198, 122, 82))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(150, 110, 90))
	pcall(function()
		terrain.WaterWaveSize = 0
		terrain.Decoration = false
	end)

	local x0, x1 = Lot.CenterX - HALF_X, Lot.CenterX + HALF_X
	local z0, z1 = Lot.CenterZ - HALF_Z, Lot.CenterZ + HALF_Z
	local r = WORLD_R
	-- four strips around the dig zone (the dig zone itself is written by LotService)
	writeHeightRegion(Lot.CenterX - r, Lot.CenterX + r, Lot.CenterZ - r, z0)
	writeHeightRegion(Lot.CenterX - r, Lot.CenterX + r, z1, Lot.CenterZ + r)
	writeHeightRegion(Lot.CenterX - r, x0, z0, z1)
	writeHeightRegion(x1, Lot.CenterX + r, z0, z1)

	-- flat desert to the horizon
	local far = 900
	local span = far - r
	terrain:FillBlock(CFrame.new(Lot.CenterX, 2, Lot.CenterZ - r - span / 2), Vector3.new(far * 2, 4, span), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(Lot.CenterX, 2, Lot.CenterZ + r + span / 2), Vector3.new(far * 2, 4, span), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(Lot.CenterX - r - span / 2, 2, Lot.CenterZ), Vector3.new(span, 4, r * 2), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(Lot.CenterX + r + span / 2, 2, Lot.CenterZ), Vector3.new(span, 4, r * 2), Enum.Material.Sand)

	-- terracotta mesas on the horizon
	local rng = Random.new(1337)
	for _ = 1, 10 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(r + 60, r + 260)
		local height = rng:NextNumber(35, 80)
		local width = rng:NextNumber(60, 120)
		local depth = rng:NextNumber(50, 90)
		local base = CFrame.new(Lot.CenterX + math.cos(angle) * distance, height / 2, Lot.CenterZ + math.sin(angle) * distance)
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		terrain:FillBlock(base, Vector3.new(width, height, depth), Enum.Material.Sandstone)
		terrain:FillBlock(base * CFrame.new(0, height / 2 + 4, 0), Vector3.new(width * 0.7, 8, depth * 0.7), Enum.Material.Sandstone)
		terrain:FillBlock(base * CFrame.new(0, -height / 2 + 6, 0), Vector3.new(width * 1.25, 12, depth * 1.25), Enum.Material.Rock)
	end
end

--------------------------------------------------------------------------
-- DIG ZONE: bedrock floor, edge stakes, world boundary (no walls, no pit)
--------------------------------------------------------------------------
local function buildLotStructure(parent)
	local structure = folder("DigZone", parent)
	local bottom = Lot.BottomY
	local cx, cz = Lot.CenterX, Lot.CenterZ

	-- Unbreakable hardpan floor under the whole desert (a Part, so digging can never reach the void)
	local bedrock = solid(structure, {
		Name = "Bedrock",
		Size = Vector3.new(Lot.SizeX + 24, Lot.BedrockThickness, Lot.SizeZ + 24),
		CFrame = CFrame.new(cx, bottom - Lot.BedrockThickness / 2, cz),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(176, 124, 90),
	})
	solid(structure, {
		Name = "SafetyNet",
		Size = Vector3.new(WORLD_R * 2, 2, WORLD_R * 2),
		CFrame = CFrame.new(cx, bottom - 40, cz),
		Transparency = 1,
		CastShadow = false,
	})

	-- survey stakes with little flags marking the edge of the dig zone
	local stakes = folder("EdgeStakes", structure)
	local spacing = 16
	local function stake(x, z)
		solid(stakes, {
			Name = "Stake",
			Size = Vector3.new(0.4, 7, 0.4),
			CFrame = CFrame.new(x, bottom + 3.5, z),
			Material = Enum.Material.Wood,
			Color = Palette.WoodDark,
			CanCollide = false,
			CanQuery = false,
		})
		PartKit.Part(stakes, {
			Name = "Flag",
			Size = Vector3.new(0.05, 0.8, 1.1),
			CFrame = CFrame.new(x, bottom + 6.4, z + 0.55),
			Material = Enum.Material.Fabric,
			Color = Palette.Terracotta,
			CastShadow = false,
		})
	end
	for t = -HALF_X, HALF_X, spacing do
		stake(cx + t, cz - HALF_Z)
		if math.abs(t) > 10 then
			stake(cx + t, cz + HALF_Z) -- leave the camp entrance open
		end
	end
	for t = -HALF_Z + spacing, HALF_Z - spacing, spacing do
		stake(cx - HALF_X, cz + t)
		stake(cx + HALF_X, cz + t)
	end

	-- invisible world boundary far out in the dunes
	local boundary = folder("WorldBoundary", structure)
	local h = 300
	for _, spec in ipairs({
		{ Vector3.new(WORLD_R * 2, h, 4), Vector3.new(cx, h / 2, cz - WORLD_R) },
		{ Vector3.new(WORLD_R * 2, h, 4), Vector3.new(cx, h / 2, cz + WORLD_R) },
		{ Vector3.new(4, h, WORLD_R * 2), Vector3.new(cx - WORLD_R, h / 2, cz) },
		{ Vector3.new(4, h, WORLD_R * 2), Vector3.new(cx + WORLD_R, h / 2, cz) },
	}) do
		solid(boundary, { Name = "Boundary", Size = spec[1], CFrame = CFrame.new(spec[2]), Transparency = 1, CastShadow = false, CanQuery = false })
	end

	WorldBuilder.Refs.Bedrock = bedrock
end

--------------------------------------------------------------------------
-- DECOR
--------------------------------------------------------------------------
local function buildCactus(parent, position, height, rng)
	local green = Color3.fromRGB(104, 150, 86)
	local model = Instance.new("Model")
	model.Name = "Cactus"
	local trunk = PartKit.Cylinder(model, height, 1.6, CFrame.new(position + Vector3.new(0, height / 2, 0)), "Y", {
		Name = "Trunk",
		Color = green,
		CanCollide = true,
		CanQuery = true,
	})
	PartKit.Ball(model, 1.6, CFrame.new(position + Vector3.new(0, height, 0)), { Color = green })
	for _, side in ipairs({ -1, 1 }) do
		if rng:NextNumber() > 0.3 then
			local armY = height * rng:NextNumber(0.4, 0.65)
			local armLength = rng:NextNumber(1.4, 2.2)
			PartKit.Cylinder(model, armLength, 1.0, CFrame.new(position + Vector3.new(side * armLength / 2, armY, 0)), "X", { Color = green })
			local upLength = rng:NextNumber(1.5, 2.6)
			PartKit.Cylinder(model, upLength, 1.0, CFrame.new(position + Vector3.new(side * armLength, armY + upLength / 2, 0)), "Y", { Color = green })
			PartKit.Ball(model, 1.0, CFrame.new(position + Vector3.new(side * armLength, armY + upLength, 0)), { Color = green })
		end
	end
	PartKit.Ball(model, 0.5, CFrame.new(position + Vector3.new(0.2, height + 0.7, 0)), { Color = Color3.fromRGB(240, 120, 150) })
	model.PrimaryPart = trunk
	model:PivotTo(model:GetPivot() * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = parent
	return model
end

local function buildLamp(parent, position)
	local model = Instance.new("Model")
	model.Name = "Lamp"
	local post = PartKit.Cylinder(model, 9, 0.6, CFrame.new(position + Vector3.new(0, 4.5, 0)), "Y", {
		Name = "Post",
		Material = Enum.Material.Wood,
		Color = Palette.WoodDark,
		CanCollide = true,
		CanQuery = true,
	})
	PartKit.Part(model, { Size = Vector3.new(1.8, 0.3, 0.3), CFrame = CFrame.new(position + Vector3.new(0.6, 8.6, 0)), Material = Enum.Material.Wood, Color = Palette.WoodDark })
	local lantern = PartKit.Part(model, {
		Name = "Lantern",
		Size = Vector3.new(0.8, 1.0, 0.8),
		CFrame = CFrame.new(position + Vector3.new(1.2, 7.9, 0)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 196, 120),
		CastShadow = false,
	})
	PartKit.Part(model, { Size = Vector3.new(1.0, 0.2, 1.0), CFrame = CFrame.new(position + Vector3.new(1.2, 8.45, 0)), Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 50, 44) })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 120)
	light.Brightness = 1.4
	light.Range = 20
	light.Shadows = false
	light.Parent = lantern
	model.PrimaryPart = post
	model.Parent = parent
end

local function inCamp(x, z)
	return math.abs(x - Lot.CenterX) < CAMP_HALF_X + 8 and math.abs(z - CAMP_Z) < Lot.CampDepth / 2 + 8
end

local function nearDigZone(x, z, margin)
	return math.abs(x - Lot.CenterX) < HALF_X + margin and math.abs(z - Lot.CenterZ) < HALF_Z + margin
end

local function buildDecor(parent)
	local decor = folder("Decor", parent)
	local rng = Random.new(4242)
	local placed, attempts = 0, 0
	while placed < 40 and attempts < 800 do
		attempts += 1
		local x = rng:NextNumber(-WORLD_R + 20, WORLD_R - 20)
		local z = rng:NextNumber(-WORLD_R + 20, WORLD_R - 20)
		if not nearDigZone(x, z, 10) and not inCamp(x, z) then
			buildCactus(decor, Vector3.new(x, outerHeight(x, z) - 0.4, z), rng:NextNumber(4, 9), rng)
			placed += 1
		end
	end
	for _ = 1, 60 do
		local x = rng:NextNumber(-WORLD_R + 20, WORLD_R - 20)
		local z = rng:NextNumber(-WORLD_R + 20, WORLD_R - 20)
		if not nearDigZone(x, z, 8) and not inCamp(x, z) then
			local size = Vector3.new(rng:NextNumber(2, 7), rng:NextNumber(1.2, 3.5), rng:NextNumber(2, 7))
			PartKit.Ellipsoid(decor, size, CFrame.new(x, outerHeight(x, z) + size.Y * 0.15, z) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), {
				Name = "Rock",
				Material = Enum.Material.Sandstone,
				Color = Color3.fromRGB(190, 128, 92):Lerp(Palette.Stone, rng:NextNumber(0, 0.6)),
				CanCollide = true,
				CanQuery = true,
			})
		end
	end

	-- camp lamps
	for _, spot in ipairs({ Vector3.new(-12, 0, 10), Vector3.new(12, 0, 10), Vector3.new(-44, 0, -16), Vector3.new(44, 0, -16), Vector3.new(-9, 0, -18), Vector3.new(9, 0, -18) }) do
		buildLamp(decor, Vector3.new(Lot.CenterX + spot.X, CAMP_Y, ROW1_Z + spot.Z))
	end

	-- boardwalks across the camp
	local planks = Color3.fromRGB(170, 120, 76)
	solid(decor, { Name = "Boardwalk", Size = Vector3.new(34, 0.3, 6), CFrame = CFrame.new(Lot.CenterX, CAMP_Y + 0.15, ROW1_Z), Material = Enum.Material.WoodPlanks, Color = planks })
	solid(decor, { Name = "Boardwalk", Size = Vector3.new(6, 0.3, 34), CFrame = CFrame.new(Lot.CenterX, CAMP_Y + 0.15, ROW1_Z - 3), Material = Enum.Material.WoodPlanks, Color = planks })

	-- gateway arch facing the desert
	local archZ = Lot.CenterZ + HALF_Z + 6
	for _, side in ipairs({ -1, 1 }) do
		PartKit.Cylinder(decor, 11, 0.9, CFrame.new(Lot.CenterX + side * 7, CAMP_Y + 5.5, archZ), "Y", {
			Name = "ArchPost",
			Material = Enum.Material.Wood,
			Color = Palette.WoodDark,
			CanCollide = true,
			CanQuery = true,
		})
	end
	local archSign = PartKit.Part(decor, {
		Name = "ArchSign",
		Size = Vector3.new(15, 2.4, 0.4),
		CFrame = CFrame.new(Lot.CenterX, CAMP_Y + 10.2, archZ),
		Color = Palette.Cream,
	})
	addSurfaceText(archSign, Enum.NormalId.Front, {
		{ Text = "BASE CAMP  ⛺", Height = 0.55 },
		{ Text = "Kiln • Upgrade Booth • Garage • Factory", Height = 0.28, Font = Enum.Font.GothamBold, Color = Palette.InkSoft },
	})
	addSurfaceText(archSign, Enum.NormalId.Back, {
		{ Text = string.upper(Lot.Name), Height = 0.55 },
		{ Text = "Leave not a single grain", Height = 0.28, Font = Enum.Font.GothamBold, Color = Palette.InkSoft },
	})

	-- sand sack pile near the weigh station
	for i = 0, 4 do
		PartKit.Ellipsoid(decor, Vector3.new(2.2, 1.6, 1.6), CFrame.new(Lot.CenterX - 36 + (i % 3) * 1.8, CAMP_Y + 0.8 + math.floor(i / 3) * 1.3, ROW1_Z + 16 + (i % 2) * 0.6) * CFrame.Angles(0, i, 0), {
			Name = "Sack",
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(196, 160, 108),
			CanCollide = true,
			CanQuery = true,
		})
	end
end

--------------------------------------------------------------------------
-- GLASS FURNACE (sell zone): sand goes in, glass vases come out
--------------------------------------------------------------------------
local VASE_COLORS = {
	Color3.fromRGB(96, 176, 206),
	Color3.fromRGB(122, 204, 172),
	Color3.fromRGB(236, 152, 92),
	Color3.fromRGB(206, 112, 164),
	Color3.fromRGB(244, 212, 112),
	Color3.fromRGB(146, 154, 226),
}

local function glassProps(color)
	return {
		Material = Enum.Material.Glass,
		Transparency = 0.22,
		Reflectance = 0.12,
		Color = color,
		CastShadow = false,
	}
end

-- A small procedural glass vase (3 shapes), built standing on its own origin.
local function buildVase(color, style)
	local model = Instance.new("Model")
	model.Name = "GlassVase"
	local core
	if style == 1 then
		core = PartKit.Ellipsoid(model, Vector3.new(1.0, 1.1, 1.0), CFrame.new(0, 0.55, 0), glassProps(color))
		PartKit.Cylinder(model, 0.5, 0.36, CFrame.new(0, 1.25, 0), "Y", glassProps(color))
		PartKit.Cylinder(model, 0.08, 0.56, CFrame.new(0, 1.5, 0), "Y", glassProps(color))
	elseif style == 2 then
		core = PartKit.Cylinder(model, 1.3, 0.72, CFrame.new(0, 0.65, 0), "Y", glassProps(color))
		PartKit.Ellipsoid(model, Vector3.new(0.72, 0.42, 0.72), CFrame.new(0, 1.3, 0), glassProps(color))
		PartKit.Cylinder(model, 0.32, 0.3, CFrame.new(0, 1.6, 0), "Y", glassProps(color))
	else
		core = PartKit.Ellipsoid(model, Vector3.new(1.3, 0.7, 1.3), CFrame.new(0, 0.35, 0), glassProps(color))
		PartKit.Cylinder(model, 0.06, 1.12, CFrame.new(0, 0.68, 0), "Y", glassProps(color))
	end
	core.Name = "Body"
	PartKit.Finalize(model, core, true)
	return model
end

local function buildGlassFurnace(parent)
	local station = folder("GlassFurnace", parent)
	local origin = CFrame.new(Lot.CenterX - 26, CAMP_Y, ROW1_Z)
	local brick = Color3.fromRGB(186, 94, 62)
	local brickDark = Color3.fromRGB(138, 70, 50)
	local ember = Color3.fromRGB(255, 140, 60)

	solid(station, {
		Name = "Base",
		Size = Vector3.new(20, 0.6, 18),
		CFrame = origin * CFrame.new(0, 0.3, 1),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(172, 150, 128),
	})
	-- the hot plate players step on to sell
	local pad = solid(station, {
		Name = "SellPad",
		Size = Vector3.new(9, 0.3, 6),
		CFrame = origin * CFrame.new(0, 0.75, -4.6),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(72, 58, 52),
	})
	local trims = {}
	for _, spec in ipairs({
		{ Vector3.new(9.4, 0.32, 0.4), Vector3.new(0, 0.76, -7.6) },
		{ Vector3.new(9.4, 0.32, 0.4), Vector3.new(0, 0.76, -1.6) },
		{ Vector3.new(0.4, 0.32, 6.4), Vector3.new(-4.5, 0.76, -4.6) },
		{ Vector3.new(0.4, 0.32, 6.4), Vector3.new(4.5, 0.76, -4.6) },
	}) do
		table.insert(trims, solid(station, {
			Name = "Trim",
			Size = spec[1],
			CFrame = origin * CFrame.new(spec[2]),
			Material = Enum.Material.Neon,
			Color = ember,
			CastShadow = false,
		}))
	end

	-- brick kiln: base ring + dome
	PartKit.Cylinder(station, 2.4, 12, origin * CFrame.new(0, 1.8, 4), "Y", { Name = "KilnBase", Material = Enum.Material.Brick, Color = brickDark, CanCollide = true, CanQuery = true })
	PartKit.Ellipsoid(station, Vector3.new(12, 13, 10), origin * CFrame.new(0, 5.5, 4), { Name = "KilnDome", Material = Enum.Material.Brick, Color = brick, CanCollide = true, CanQuery = true })
	-- glowing mouth with a brick arch
	PartKit.Ellipsoid(station, Vector3.new(4.6, 3.8, 1.4), origin * CFrame.new(0, 3.0, -0.6), { Name = "Mouth", Color = Color3.fromRGB(34, 22, 18), CastShadow = false })
	local glow = PartKit.Ellipsoid(station, Vector3.new(3.3, 2.3, 0.8), origin * CFrame.new(0, 2.7, -1.0), {
		Name = "Glow",
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 150, 60),
		CastShadow = false,
	})
	for i = 0, 8 do
		local angle = math.rad(i * 22.5)
		PartKit.Part(station, {
			Name = "ArchBrick",
			Size = Vector3.new(0.9, 0.6, 0.9),
			CFrame = origin * CFrame.new(math.cos(angle) * 2.6, 3.0 + math.sin(angle) * 2.2, -1.2) * CFrame.Angles(0, 0, angle - math.pi / 2),
			Material = Enum.Material.Brick,
			Color = Color3.fromRGB(206, 126, 86),
		})
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Brightness = 2.5
	light.Range = 24
	light.Shadows = true
	light.Parent = glow

	-- real fire licking out of the mouth + rising embers
	local firePart = PartKit.Part(station, {
		Name = "FirePart",
		Size = Vector3.new(1, 1, 1),
		CFrame = origin * CFrame.new(0, 2.0, -1.2),
		Transparency = 1,
		CastShadow = false,
	})
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 4
	fire.Color = Color3.fromRGB(255, 150, 50)
	fire.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fire.Parent = firePart
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Embers"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 100, 40))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(1, 2)
	sparks.Speed = NumberRange.new(2, 5)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Acceleration = Vector3.new(0, 3, 0)
	sparks.Rate = 6
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Parent = firePart

	-- chimney with smoke
	PartKit.Cylinder(station, 8, 2, origin * CFrame.new(2.8, 13, 6), "Y", { Name = "Chimney", Material = Enum.Material.Brick, Color = brickDark, CanCollide = true, CanQuery = true })
	PartKit.Cylinder(station, 0.4, 2.6, origin * CFrame.new(2.8, 17.1, 6), "Y", { Name = "ChimneyCap", Color = Color3.fromRGB(70, 56, 50) })
	local smokePart = PartKit.Part(station, { Name = "SmokePart", Size = Vector3.new(1, 1, 1), CFrame = origin * CFrame.new(2.8, 17.6, 6), Transparency = 1, CastShadow = false })
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(130, 118, 110)
	smoke.Opacity = 0.12
	smoke.RiseVelocity = 4
	smoke.Size = 3
	smoke.Parent = smokePart

	-- firewood pile & glassblowing pipe
	for row = 0, 2 do
		for k = 0, 2 - row do
			PartKit.Cylinder(station, 2.6, 0.6, origin * CFrame.new(-7.8, 0.9 + row * 0.55, 0.4 + k * 0.62 + row * 0.31), "X", {
				Name = "Log",
				Material = Enum.Material.Wood,
				Color = Color3.fromRGB(128, 86, 54),
				CanCollide = true,
				CanQuery = true,
			})
		end
	end
	PartKit.Cylinder(station, 5.2, 0.16, origin * CFrame.new(5.4, 2.9, -1.6) * CFrame.Angles(math.rad(-20), 0, math.rad(12)), "Y", { Name = "BlowPipe", Material = Enum.Material.Metal, Color = Color3.fromRGB(90, 90, 96) })

	-- sign
	for _, x in ipairs({ -6.8, 6.8 }) do
		PartKit.Cylinder(station, 12.6, 0.5, origin * CFrame.new(x, 6.3, -2.4), "Y", { Name = "SignPost", Material = Enum.Material.Wood, Color = Palette.WoodDark, CanCollide = true, CanQuery = true })
	end
	local sign = PartKit.Part(station, {
		Name = "Sign",
		Size = Vector3.new(13.6, 2.6, 0.4),
		CFrame = origin * CFrame.new(0, 12.9, -2.4),
		Color = Palette.Cream,
	})
	addSurfaceText(sign, Enum.NormalId.Front, {
		{ Text = "🔥  GLASS FURNACE", Height = 0.55 },
		{ Text = "Step on the hot plate to melt your sand into glass", Height = 0.28, Font = Enum.Font.GothamBold, Color = Palette.InkSoft },
	})

	-- last-melt readout board
	local board = PartKit.Part(station, {
		Name = "ReadoutBoard",
		Size = Vector3.new(5.4, 3.2, 0.3),
		CFrame = origin * CFrame.new(-7.6, 3.4, -5.8),
		Color = Color3.fromRGB(60, 48, 40),
		CanCollide = true,
		CanQuery = true,
	})
	local _, labels = addSurfaceText(board, Enum.NormalId.Front, {
		{ Name = "Title", Text = "LAST MELT", Height = 0.25, Font = Enum.Font.GothamBold, Color = Palette.InkSoft },
		{ Name = "Readout", Text = "0.0 kg", Height = 0.38 },
		{ Name = "Detail", Text = "The furnace is hungry...", Height = 0.22, Font = Enum.Font.GothamBold, Color = Palette.Terracotta },
	})
	for _, x in ipairs({ -2.2, 2.2 }) do
		PartKit.Part(station, { Name = "BoardLeg", Size = Vector3.new(0.4, 1.8, 0.4), CFrame = origin * CFrame.new(-7.6 + x, 0.9, -5.8), Color = Color3.fromRGB(60, 48, 40) })
	end

	-- cooling table where fresh glass appears
	local tableTop = 2.6
	solid(station, { Name = "TableTop", Size = Vector3.new(3.4, 0.3, 9.2), CFrame = origin * CFrame.new(8.2, tableTop, 1.2), Material = Enum.Material.WoodPlanks, Color = Palette.Wood })
	for _, leg in ipairs({ Vector3.new(-1.4, 0, -4.2), Vector3.new(1.4, 0, -4.2), Vector3.new(-1.4, 0, 4.2), Vector3.new(1.4, 0, 4.2) }) do
		PartKit.Part(station, { Name = "TableLeg", Size = Vector3.new(0.35, tableTop, 0.35), CFrame = origin * CFrame.new(8.2 + leg.X, tableTop / 2, 1.2 + leg.Z), Material = Enum.Material.Wood, Color = Palette.WoodDark })
	end
	local slots = {}
	for row = 0, 4 do
		for column = 0, 1 do
			table.insert(slots, origin * CFrame.new(8.2 + (column == 0 and -0.8 or 0.8), tableTop + 0.15, -2.4 + row * 1.8))
		end
	end
	local vaseFolder = folder("Vases", station)
	local placed = {}
	for i = 1, 4 do
		local vase = buildVase(VASE_COLORS[i], (i % 3) + 1)
		vase:PivotTo(slots[i * 2 - 1])
		vase.Parent = vaseFolder
		placed[i * 2 - 1] = vase
	end

	WorldBuilder.Refs.SellPad = pad
	WorldBuilder.Refs.SellTrims = trims
	WorldBuilder.Refs.SellLabels = labels
	WorldBuilder.Refs.Furnace = {
		Fire = fire,
		Light = light,
		Glow = glow,
		Mouth = origin * CFrame.new(0, 2.4, -1.6),
		Slots = slots,
		Placed = placed,
		NextSlot = 2,
		Folder = vaseFolder,
	}
end

--------------------------------------------------------------------------
-- UPGRADE BOOTH
--------------------------------------------------------------------------
local function buildUpgradeBooth(parent)
	local booth = folder("UpgradeBooth", parent)
	local origin = CFrame.new(Lot.CenterX + 26, CAMP_Y, ROW1_Z)
	local wood = Color3.fromRGB(176, 122, 76)

	solid(booth, { Name = "Floor", Size = Vector3.new(14, 0.4, 11), CFrame = origin * CFrame.new(Vector3.new(0, 0.2, 0.5)), Material = Enum.Material.WoodPlanks, Color = wood })
	local counter = solid(booth, {
		Name = "Counter",
		Size = Vector3.new(10, 3.2, 1.8),
		CFrame = origin * CFrame.new(Vector3.new(0, 2.0, -3.2)),
		Material = Enum.Material.WoodPlanks,
		Color = Palette.Wood,
	})
	solid(booth, { Name = "CounterTop", Size = Vector3.new(10.6, 0.3, 2.4), CFrame = origin * CFrame.new(Vector3.new(0, 3.75, -3.2)), Color = Palette.Cream })
	solid(booth, { Name = "BackWall", Size = Vector3.new(12, 9, 0.6), CFrame = origin * CFrame.new(Vector3.new(0, 4.9, 5.2)), Material = Enum.Material.WoodPlanks, Color = wood })
	solid(booth, { Name = "SideWallL", Size = Vector3.new(0.6, 9, 9.8), CFrame = origin * CFrame.new(Vector3.new(-6.3, 4.9, 0.6)), Material = Enum.Material.WoodPlanks, Color = wood })
	solid(booth, { Name = "SideWallR", Size = Vector3.new(0.6, 9, 9.8), CFrame = origin * CFrame.new(Vector3.new(6.3, 4.9, 0.6)), Material = Enum.Material.WoodPlanks, Color = wood })
	for i = 0, 6 do
		PartKit.Part(booth, {
			Name = "Awning",
			Size = Vector3.new(2.0, 0.35, 12),
			CFrame = origin * CFrame.new(Vector3.new(-6 + i * 2, 9.9, -0.6)) * CFrame.Angles(math.rad(-12), 0, 0),
			Color = (i % 2 == 0) and Palette.Ochre or Palette.Cream,
		})
	end
	local sign = PartKit.Part(booth, {
		Name = "Sign",
		Size = Vector3.new(11, 2.4, 0.4),
		CFrame = origin * CFrame.new(Vector3.new(0, 11.9, -6.4)),
		Color = Palette.Cream,
	})
	addSurfaceText(sign, Enum.NormalId.Front, {
		{ Text = "🛠  UPGRADE BOOTH", Height = 0.55 },
		{ Text = "Tools • Bags • Skills", Height = 0.28, Font = Enum.Font.GothamBold, Color = Palette.InkSoft },
	})
	-- shelf with tool displays
	PartKit.Part(booth, { Name = "Shelf", Size = Vector3.new(11, 0.25, 1.4), CFrame = origin * CFrame.new(Vector3.new(0, 4.2, 4.3)), Material = Enum.Material.Wood, Color = Palette.WoodDark })
	PartKit.Part(booth, { Name = "Shelf", Size = Vector3.new(11, 0.25, 1.4), CFrame = origin * CFrame.new(Vector3.new(0, 6.8, 4.3)), Material = Enum.Material.Wood, Color = Palette.WoodDark })
	local shelfTools = {}
	for _, tool in ipairs(GameConfig.Tools) do
		if tool.Id ~= "Hands" then
			table.insert(shelfTools, tool)
		end
	end
	for index, tool in ipairs(shelfTools) do
		local display = ToolModels.Build(tool.Id, true)
		local shelfY = index <= 2 and 4.9 or 7.6
		local x = (index % 2 == 1) and -2.6 or 2.6
		display:PivotTo(origin * CFrame.new(Vector3.new(x, shelfY, 4.3)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(-15), 0, 0))
		PartKit.SetCastShadow(display, true)
		display.Parent = booth
	end
	-- coin jar on the counter
	PartKit.Cylinder(booth, 1.0, 0.8, origin * CFrame.new(Vector3.new(3.5, 4.4, -3.2)), "Y", { Material = Enum.Material.Glass, Transparency = 0.5, Color = Palette.Cream })
	PartKit.Cylinder(booth, 0.5, 0.7, origin * CFrame.new(Vector3.new(3.5, 4.15, -3.2)), "Y", { Material = Enum.Material.Foil, Color = Palette.Gold })

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Browse Upgrades"
	prompt.ObjectText = "Upgrade Booth"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = counter

	WorldBuilder.Refs.ShopPrompt = prompt
end

--------------------------------------------------------------------------
-- TRUCK DUMP BAY (next to the kiln) + GARAGE
--------------------------------------------------------------------------
local function bayPad(parent, name, center, size, title, subtitle, signSide)
	local pad = solid(parent, {
		Name = name,
		Size = Vector3.new(size.X, 0.3, size.Z),
		CFrame = CFrame.new(center + Vector3.new(0, 0.15, 0)),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(120, 112, 104),
	})
	local stripe = Color3.fromRGB(242, 186, 48)
	for _, spec in ipairs({
		{ Vector3.new(size.X, 0.32, 0.5), Vector3.new(0, 0.16, -size.Z / 2) },
		{ Vector3.new(size.X, 0.32, 0.5), Vector3.new(0, 0.16, size.Z / 2) },
		{ Vector3.new(0.5, 0.32, size.Z), Vector3.new(-size.X / 2, 0.16, 0) },
		{ Vector3.new(0.5, 0.32, size.Z), Vector3.new(size.X / 2, 0.16, 0) },
	}) do
		solid(parent, { Name = "Stripe", Size = spec[1], CFrame = CFrame.new(center + spec[2]), Material = Enum.Material.Neon, Color = stripe, CastShadow = false, CanCollide = false })
	end
	local signPos = center + Vector3.new(signSide * (size.X / 2 + 1.5), 0, 0)
	PartKit.Cylinder(parent, 7, 0.5, CFrame.new(signPos + Vector3.new(0, 3.5, 0)), "Y", { Name = "SignPost", Material = Enum.Material.Wood, Color = Palette.WoodDark, CanCollide = true, CanQuery = true })
	local sign = PartKit.Part(parent, { Name = "BaySign", Size = Vector3.new(8, 2.2, 0.3), CFrame = CFrame.new(signPos + Vector3.new(0, 6.6, 0)), Color = Palette.Cream })
	addSurfaceText(sign, Enum.NormalId.Front, {
		{ Text = title, Height = 0.5 },
		{ Text = subtitle, Height = 0.3, Font = Enum.Font.GothamBold, Color = Palette.InkSoft },
	})
	return pad
end

local function buildBaysAndGarage(parent)
	local yard = folder("Yard", parent)
	WorldBuilder.Refs.KilnBay = bayPad(yard, "KilnTruckBay", Vector3.new(Lot.CenterX - 52, CAMP_Y, ROW1_Z), Vector3.new(16, 0, 18), "🚚 KILN DUMP BAY", "Drive in to tip & sell (1x)", 1)

	local garage = folder("Garage", parent)
	local center = Vector3.new(Lot.CenterX + 58, CAMP_Y, ROW1_Z)
	bayPad(garage, "GaragePad", center, Vector3.new(26, 0, 24), "🔧 GARAGE", "Spawn your machines here", -1)
	-- shed at the back of the pad
	solid(garage, { Name = "ShedWall", Size = Vector3.new(26, 9, 0.6), CFrame = CFrame.new(center + Vector3.new(0, 4.5, 13)), Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(150, 120, 100) })
	for _, x in ipairs({ -12.6, 12.6 }) do
		solid(garage, { Name = "ShedPost", Size = Vector3.new(0.8, 9, 0.8), CFrame = CFrame.new(center + Vector3.new(x, 4.5, 6)), Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 60, 64) })
	end
	for i = 0, 6 do
		PartKit.Part(garage, {
			Name = "ShedRoof",
			Size = Vector3.new(3.8, 0.35, 15),
			CFrame = CFrame.new(center + Vector3.new(-11.4 + i * 3.8, 9.3, 6.5)) * CFrame.Angles(math.rad(-6), 0, 0),
			Color = (i % 2 == 0) and Color3.fromRGB(242, 186, 48) or Color3.fromRGB(64, 64, 68),
		})
	end
	local kiosk = solid(garage, { Name = "Kiosk", Size = Vector3.new(2.4, 4, 2.4), CFrame = CFrame.new(center + Vector3.new(-15.5, 2, -8)), Material = Enum.Material.Metal, Color = Color3.fromRGB(242, 186, 48) })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GaragePrompt"
	prompt.ActionText = "Open Garage"
	prompt.ObjectText = "Vehicles"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = kiosk
	WorldBuilder.Refs.GaragePrompt = prompt
	WorldBuilder.Refs.GarageSpawns = {
		CFrame.new(center + Vector3.new(-6, 3.2, -1)),
		CFrame.new(center + Vector3.new(6, 3.2, -1)),
		CFrame.new(center + Vector3.new(0, 3.2, -22)),
		CFrame.new(center + Vector3.new(-14, 3.2, -24)),
	}
end

--------------------------------------------------------------------------
-- LOT PROGRESS BOARD + SPAWN
--------------------------------------------------------------------------
local function buildLotBoard(parent)
	local boardFolder = folder("LotBoard", parent)
	local origin = Vector3.new(Lot.CenterX - 14, CAMP_Y, ROW1_Z - 10)
	for _, x in ipairs({ -3.6, 3.6 }) do
		solid(boardFolder, { Name = "Leg", Size = Vector3.new(0.5, 6, 0.5), CFrame = CFrame.new(origin + Vector3.new(x, 3, 0)), Material = Enum.Material.Wood, Color = Palette.WoodDark })
	end
	local board = solid(boardFolder, {
		Name = "Board",
		Size = Vector3.new(8, 4, 0.4),
		CFrame = CFrame.new(origin + Vector3.new(0, 5, 0)) * CFrame.Angles(0, math.rad(180), 0),
		Color = Palette.Cream,
	})
	local _, labels = addSurfaceText(board, Enum.NormalId.Front, {
		{ Name = "Title", Text = string.upper(Lot.Name), Height = 0.22, Font = Enum.Font.GothamBold, Color = Palette.InkSoft },
		{ Name = "Percent", Text = "0.0% CLEARED", Height = 0.36 },
		{ Name = "Detail", Text = "14 relics buried somewhere below", Height = 0.18, Font = Enum.Font.GothamBold, Color = Palette.Terracotta },
	})
	WorldBuilder.Refs.LotLabels = labels
end

local function buildSpawn(parent)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SandsweepSpawn"
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(Lot.CenterX, CAMP_Y + 0.2, ROW1_Z + 12)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Material = Enum.Material.Sandstone
	spawn.Color = Color3.fromRGB(214, 160, 110)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = parent
	for _, child in ipairs(spawn:GetChildren()) do
		if child:IsA("Decal") then
			child:Destroy()
		end
	end
	WorldBuilder.Refs.Spawn = spawn
end

--------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------
function WorldBuilder.Build()
	local existing = Workspace:FindFirstChild("SandsweepWorld")
	if existing then
		existing:Destroy()
	end
	local root = folder("SandsweepWorld", Workspace)
	local map = folder("Map", root)
	local stations = folder("Stations", root)
	folder("Finds", root)
	WorldBuilder.Refs.Root = root

	StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	StarterPlayer.CharacterWalkSpeed = GameConfig.Economy.BaseWalkSpeed
	pcall(function()
		Workspace.FallenPartsDestroyHeight = -200
	end)

	WorldBuilder.SetupLighting()
	buildTerrainSurroundings()
	buildLotStructure(map)
	buildDecor(map)
	buildGlassFurnace(stations)
	buildUpgradeBooth(stations)
	buildBaysAndGarage(stations)
	buildLotBoard(stations)
	buildSpawn(root)
	return WorldBuilder.Refs
end

-- Is a world position standing on the sell pad?
function WorldBuilder.IsOnSellPad(position)
	local pad = WorldBuilder.Refs.SellPad
	if not pad then
		return false
	end
	local localPos = pad.CFrame:PointToObjectSpace(position)
	return math.abs(localPos.X) <= pad.Size.X / 2 + 0.5
		and math.abs(localPos.Z) <= pad.Size.Z / 2 + 0.5
		and localPos.Y >= -1
		and localPos.Y <= 7
end

local roarToken = 0
function WorldBuilder.AnimateSale(kg, cash, playerName)
	local labels = WorldBuilder.Refs.SellLabels
	if labels then
		labels.Readout.Text = string.format("%s kg", Util.FormatKg(kg))
		labels.Detail.Text = string.format("%s made %s of glass", playerName, Util.FormatCash(cash))
	end
	for _, trim in ipairs(WorldBuilder.Refs.SellTrims or {}) do
		trim.Color = Color3.fromRGB(255, 240, 170)
		TweenService:Create(trim, TweenInfo.new(0.9), { Color = Color3.fromRGB(255, 140, 60) }):Play()
	end
	local furnace = WorldBuilder.Refs.Furnace
	if not furnace then
		return
	end
	-- the furnace roars
	roarToken += 1
	local token = roarToken
	TweenService:Create(furnace.Fire, TweenInfo.new(0.25), { Size = 11, Heat = 10 }):Play()
	TweenService:Create(furnace.Light, TweenInfo.new(0.25), { Brightness = 6, Range = 34 }):Play()
	furnace.Glow.Color = Color3.fromRGB(255, 230, 150)
	TweenService:Create(furnace.Glow, TweenInfo.new(1.2), { Color = Color3.fromRGB(255, 150, 60) }):Play()
	task.delay(1.1, function()
		if token == roarToken then
			TweenService:Create(furnace.Fire, TweenInfo.new(1.2), { Size = 5, Heat = 4 }):Play()
			TweenService:Create(furnace.Light, TweenInfo.new(1.2), { Brightness = 2.5, Range = 24 }):Play()
		end
	end)

	-- a fresh glass vase pops out of the mouth and lands on the cooling table
	local slotIndex = furnace.NextSlot
	furnace.NextSlot = slotIndex % #furnace.Slots + 1
	local old = furnace.Placed[slotIndex]
	if old then
		old:Destroy()
	end
	local vase = buildVase(VASE_COLORS[math.random(1, #VASE_COLORS)], math.random(1, 3))
	local scale = math.clamp(0.7 + math.log10(1 + kg) * 0.22, 0.7, 1.6)
	pcall(function()
		vase:ScaleTo(scale)
	end)
	vase:PivotTo(furnace.Mouth)
	vase.Parent = furnace.Folder
	furnace.Placed[slotIndex] = vase
	local startCF, endCF = furnace.Mouth, furnace.Slots[slotIndex]
	local progress = Instance.new("NumberValue")
	progress.Name = "Flight"
	progress.Parent = vase
	progress.Changed:Connect(function(t)
		if vase.Parent then
			local position = startCF.Position:Lerp(endCF.Position, t) + Vector3.new(0, math.sin(t * math.pi) * 4, 0)
			vase:PivotTo(CFrame.new(position) * endCF.Rotation * CFrame.Angles(0, t * math.pi * 4, 0))
		end
	end)
	local flight = TweenService:Create(progress, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 })
	flight.Completed:Connect(function()
		progress:Destroy()
	end)
	flight:Play()
end

function WorldBuilder.UpdateLotBoard(percent, findsLeft, generating)
	local labels = WorldBuilder.Refs.LotLabels
	if not labels then
		return
	end
	if generating then
		labels.Percent.Text = "FRESH SAND INCOMING"
		labels.Detail.Text = "Stand clear of the pit!"
	else
		labels.Percent.Text = string.format("%s CLEARED", Util.FormatPercent(percent))
		labels.Detail.Text = findsLeft > 0 and string.format("%d relic%s still buried", findsLeft, findsLeft == 1 and "" or "s") or "All relics recovered!"
	end
end

return WorldBuilder
