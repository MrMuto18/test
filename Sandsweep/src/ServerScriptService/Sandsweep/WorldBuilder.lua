-- WorldBuilder (ModuleScript) - ServerScriptService/Sandsweep/WorldBuilder
-- Builds the cozy desert: lighting, terrain dunes & mesas, bedrock, retaining
-- walls, fencing, ladders, plaza, Weigh Station, Upgrade Booth, lot board, decor.

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
local CAMP_HALF_X = 56
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
		buildLamp(decor, Vector3.new(Lot.CenterX + spot.X, CAMP_Y, CAMP_Z + spot.Z))
	end

	-- boardwalks across the camp
	local planks = Color3.fromRGB(170, 120, 76)
	solid(decor, { Name = "Boardwalk", Size = Vector3.new(72, 0.3, 6), CFrame = CFrame.new(Lot.CenterX, CAMP_Y + 0.15, CAMP_Z), Material = Enum.Material.WoodPlanks, Color = planks })
	solid(decor, { Name = "Boardwalk", Size = Vector3.new(6, 0.3, 34), CFrame = CFrame.new(Lot.CenterX, CAMP_Y + 0.15, CAMP_Z - 3), Material = Enum.Material.WoodPlanks, Color = planks })

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
		{ Text = "Weigh Station • Upgrade Booth", Height = 0.28, Font = Enum.Font.GothamBold, Color = Palette.InkSoft },
	})
	addSurfaceText(archSign, Enum.NormalId.Back, {
		{ Text = string.upper(Lot.Name), Height = 0.55 },
		{ Text = "Leave not a single grain", Height = 0.28, Font = Enum.Font.GothamBold, Color = Palette.InkSoft },
	})

	-- sand sack pile near the weigh station
	for i = 0, 4 do
		PartKit.Ellipsoid(decor, Vector3.new(2.2, 1.6, 1.6), CFrame.new(Lot.CenterX - 44 + (i % 3) * 1.8, CAMP_Y + 0.8 + math.floor(i / 3) * 1.3, CAMP_Z + 4 + (i % 2) * 0.6) * CFrame.Angles(0, i, 0), {
			Name = "Sack",
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(196, 160, 108),
			CanCollide = true,
			CanQuery = true,
		})
	end
end

--------------------------------------------------------------------------
-- WEIGH STATION (sell zone)
--------------------------------------------------------------------------
local function buildWeighStation(parent)
	local station = folder("WeighStation", parent)
	local origin = CFrame.new(Lot.CenterX - 26, CAMP_Y, CAMP_Z)

	solid(station, {
		Name = "Base",
		Size = Vector3.new(14, 0.6, 14),
		CFrame = origin * CFrame.new(Vector3.new(0, 0.3, 0)),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(214, 194, 164),
	})
	local pad = solid(station, {
		Name = "SellPad",
		Size = Vector3.new(10, 0.3, 10),
		CFrame = origin * CFrame.new(Vector3.new(0, 0.75, 0)),
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(170, 176, 184),
	})
	local trims = {}
	for _, spec in ipairs({
		{ Vector3.new(10.4, 0.32, 0.4), Vector3.new(0, 0.76, -5) },
		{ Vector3.new(10.4, 0.32, 0.4), Vector3.new(0, 0.76, 5) },
		{ Vector3.new(0.4, 0.32, 10.4), Vector3.new(-5, 0.76, 0) },
		{ Vector3.new(0.4, 0.32, 10.4), Vector3.new(5, 0.76, 0) },
	}) do
		table.insert(trims, solid(station, {
			Name = "Trim",
			Size = spec[1],
			CFrame = origin * CFrame.new(spec[2]),
			Material = Enum.Material.Neon,
			Color = Palette.Ochre,
			CastShadow = false,
		}))
	end
	for _, corner in ipairs({ Vector3.new(-6.3, 0, -6.3), Vector3.new(6.3, 0, -6.3), Vector3.new(-6.3, 0, 6.3), Vector3.new(6.3, 0, 6.3) }) do
		PartKit.Cylinder(station, 9.4, 0.7, origin * CFrame.new(corner + Vector3.new(0, 5.3, 0)), "Y", {
			Name = "Post",
			Material = Enum.Material.Wood,
			Color = Palette.WoodDark,
			CanCollide = true,
			CanQuery = true,
		})
	end
	-- striped canopy
	for i = 0, 6 do
		PartKit.Part(station, {
			Name = "Canopy",
			Size = Vector3.new(2.1, 0.35, 15),
			CFrame = origin * CFrame.new(Vector3.new(-6.3 + i * 2.1, 10.1, 0)) * CFrame.Angles(math.rad(-6), 0, 0),
			Color = (i % 2 == 0) and Palette.Terracotta or Palette.Cream,
		})
	end
	-- sign
	local sign = PartKit.Part(station, {
		Name = "Sign",
		Size = Vector3.new(12, 2.6, 0.4),
		CFrame = origin * CFrame.new(Vector3.new(0, 12.2, -6.6)),
		Color = Palette.Cream,
	})
	addSurfaceText(sign, Enum.NormalId.Front, {
		{ Text = "⚖  WEIGH STATION", Height = 0.55 },
		{ Text = "Step on the scale to sell your sand", Height = 0.28, Font = Enum.Font.GothamBold, Color = Palette.InkSoft },
	})
	-- readout board at the back of the pad
	local board = PartKit.Part(station, {
		Name = "ReadoutBoard",
		Size = Vector3.new(7, 3.4, 0.4),
		CFrame = origin * CFrame.new(Vector3.new(0, 3.6, 6.2)),
		Color = Color3.fromRGB(60, 48, 40),
		CanCollide = true,
		CanQuery = true,
	})
	local _, labels = addSurfaceText(board, Enum.NormalId.Front, {
		{ Name = "Title", Text = "LAST WEIGH-IN", Height = 0.25, Font = Enum.Font.GothamBold, Color = Palette.InkSoft },
		{ Name = "Readout", Text = "0.0 kg", Height = 0.38 },
		{ Name = "Detail", Text = "Waiting for sand...", Height = 0.22, Font = Enum.Font.GothamBold, Color = Palette.Terracotta },
	})
	PartKit.Part(station, { Name = "BoardLegs", Size = Vector3.new(0.5, 3.4, 0.5), CFrame = origin * CFrame.new(Vector3.new(-3, 1.7, 6.2)), Color = Color3.fromRGB(60, 48, 40) })
	PartKit.Part(station, { Name = "BoardLegs", Size = Vector3.new(0.5, 3.4, 0.5), CFrame = origin * CFrame.new(Vector3.new(3, 1.7, 6.2)), Color = Color3.fromRGB(60, 48, 40) })
	-- dial with needle
	local dialCenter = origin * CFrame.new(Vector3.new(0, 7.4, 6.2))
	PartKit.Cylinder(station, 0.3, 3.2, dialCenter, "Z", { Name = "Dial", Color = Palette.Cream })
	PartKit.Cylinder(station, 0.32, 3.5, dialCenter * CFrame.new(0, 0, 0.02), "Z", { Name = "DialRim", Material = Enum.Material.Metal, Color = Palette.Ochre })
	PartKit.Cylinder(station, 0.34, 3.0, dialCenter * CFrame.new(0, 0, -0.01), "Z", { Name = "DialFace", Color = Palette.Paper })
	for i = 0, 8 do
		local a = math.rad(-120 + i * 30)
		PartKit.Part(station, {
			Name = "Tick",
			Size = Vector3.new(0.08, 0.35, 0.05),
			CFrame = dialCenter * CFrame.new(0, 0, -0.2) * CFrame.Angles(0, 0, -a) * CFrame.new(0, 1.25, 0),
			Color = Palette.Ink,
		})
	end
	local needle = PartKit.Part(station, {
		Name = "Needle",
		Size = Vector3.new(0.12, 1.3, 0.06),
		CFrame = dialCenter * CFrame.new(0, 0, -0.25) * CFrame.Angles(0, 0, math.rad(120)) * CFrame.new(0, 0.6, 0),
		Material = Enum.Material.Neon,
		Color = Palette.Terracotta,
		CastShadow = false,
	})
	PartKit.Cylinder(station, 0.2, 0.35, dialCenter * CFrame.new(0, 0, -0.25), "Z", { Name = "Pin", Material = Enum.Material.Metal, Color = Palette.Ink })
	PartKit.Part(station, { Name = "DialPost", Size = Vector3.new(0.5, 2.2, 0.4), CFrame = origin * CFrame.new(Vector3.new(0, 5.4, 6.4)), Color = Color3.fromRGB(60, 48, 40) })

	local needleAngle = Instance.new("NumberValue")
	needleAngle.Name = "NeedleAngle"
	needleAngle.Value = 120
	needleAngle.Parent = station
	needleAngle.Changed:Connect(function(value)
		needle.CFrame = dialCenter * CFrame.new(0, 0, -0.25) * CFrame.Angles(0, 0, math.rad(value)) * CFrame.new(0, 0.6, 0)
	end)

	WorldBuilder.Refs.SellPad = pad
	WorldBuilder.Refs.SellTrims = trims
	WorldBuilder.Refs.SellLabels = labels
	WorldBuilder.Refs.NeedleAngle = needleAngle
end

--------------------------------------------------------------------------
-- UPGRADE BOOTH
--------------------------------------------------------------------------
local function buildUpgradeBooth(parent)
	local booth = folder("UpgradeBooth", parent)
	local origin = CFrame.new(Lot.CenterX + 26, CAMP_Y, CAMP_Z)
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
	for index, tool in ipairs(GameConfig.Tools) do
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
-- LOT PROGRESS BOARD + SPAWN
--------------------------------------------------------------------------
local function buildLotBoard(parent)
	local boardFolder = folder("LotBoard", parent)
	local origin = Vector3.new(Lot.CenterX - 14, CAMP_Y, CAMP_Z - 10)
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
	spawn.CFrame = CFrame.new(Lot.CenterX, CAMP_Y + 0.2, CAMP_Z + 12)
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
	buildWeighStation(stations)
	buildUpgradeBooth(stations)
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

function WorldBuilder.AnimateSale(kg, cash, playerName)
	local labels = WorldBuilder.Refs.SellLabels
	if labels then
		labels.Readout.Text = string.format("%s kg", Util.FormatKg(kg))
		labels.Detail.Text = string.format("%s sold for %s", playerName, Util.FormatCash(cash))
	end
	local needle = WorldBuilder.Refs.NeedleAngle
	if needle then
		local capacityRef = GameConfig.Bags[#GameConfig.Bags].Capacity
		local fraction = math.clamp(math.log10(1 + kg) / math.log10(1 + capacityRef), 0.05, 1)
		local target = 120 - fraction * 240
		local swingOut = TweenService:Create(needle, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = target })
		swingOut:Play()
		task.delay(2.2, function()
			TweenService:Create(needle, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Value = 120 }):Play()
		end)
	end
	for _, trim in ipairs(WorldBuilder.Refs.SellTrims or {}) do
		trim.Color = Palette.Sage
		TweenService:Create(trim, TweenInfo.new(0.9), { Color = Palette.Ochre }):Play()
	end
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
