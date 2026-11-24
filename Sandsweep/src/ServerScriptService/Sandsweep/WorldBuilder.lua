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

local LOT_TOP = Lot.BottomY + Lot.Depth
local HALF_X = Lot.SizeX / 2
local HALF_Z = Lot.SizeZ / 2
local WALL = Lot.WallThickness
local PLAZA = Lot.PlazaRadius

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
-- TERRAIN SURROUNDINGS (outside the lot: never part of the dig site)
--------------------------------------------------------------------------
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

	local far = 480
	local span = far - PLAZA
	local midY = LOT_TOP - 4
	-- desert floor around the plaza (top flush with plaza at LOT_TOP)
	terrain:FillBlock(CFrame.new(0, midY, -(PLAZA + span / 2)), Vector3.new(far * 2, 8, span), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, midY, PLAZA + span / 2), Vector3.new(far * 2, 8, span), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(-(PLAZA + span / 2), midY, 0), Vector3.new(span, 8, PLAZA * 2), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(PLAZA + span / 2, midY, 0), Vector3.new(span, 8, PLAZA * 2), Enum.Material.Sand)

	local rng = Random.new(1337)
	-- rolling dunes
	for _ = 1, 34 do
		local radius = rng:NextNumber(18, 48)
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(PLAZA + radius + 20, far - radius)
		local center = Vector3.new(math.cos(angle) * distance, LOT_TOP - radius * rng:NextNumber(0.5, 0.75), math.sin(angle) * distance)
		terrain:FillBall(center, radius, Enum.Material.Sand)
	end
	-- terracotta mesas on the horizon
	for _ = 1, 8 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(300, 420)
		local height = rng:NextNumber(30, 70)
		local width = rng:NextNumber(50, 100)
		local depth = rng:NextNumber(40, 80)
		local base = CFrame.new(math.cos(angle) * distance, LOT_TOP + height / 2 - 4, math.sin(angle) * distance)
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		terrain:FillBlock(base, Vector3.new(width, height, depth), Enum.Material.Sandstone)
		terrain:FillBlock(base * CFrame.new(0, height / 2 + 4, 0), Vector3.new(width * 0.7, 8, depth * 0.7), Enum.Material.Sandstone)
		terrain:FillBlock(base * CFrame.new(0, -height / 2 + 6, 0), Vector3.new(width * 1.25, 12, depth * 1.25), Enum.Material.Rock)
	end
end

--------------------------------------------------------------------------
-- LOT STRUCTURE: bedrock, retaining walls, fence, ladders, plaza
--------------------------------------------------------------------------
local function buildLotStructure(parent)
	local structure = folder("LotStructure", parent)
	local bottom = Lot.BottomY
	local cx, cz = Lot.CenterX, Lot.CenterZ

	-- Unbreakable bedrock floor (a Part, so terrain digging can never reach the void)
	local bedrock = solid(structure, {
		Name = "Bedrock",
		Size = Vector3.new(Lot.SizeX + WALL * 2, Lot.BedrockThickness, Lot.SizeZ + WALL * 2),
		CFrame = CFrame.new(cx, bottom - Lot.BedrockThickness / 2, cz),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(122, 100, 86),
	})
	-- safety net far below
	solid(structure, {
		Name = "SafetyNet",
		Size = Vector3.new(Lot.SizeX + 40, 2, Lot.SizeZ + 40),
		CFrame = CFrame.new(cx, bottom - 30, cz),
		Transparency = 1,
		CastShadow = false,
	})

	-- Retaining walls (wood planks) lining the pit
	local wallBottom = bottom - Lot.BedrockThickness
	local wallHeight = LOT_TOP - wallBottom
	local wallY = wallBottom + wallHeight / 2
	local wallColor = Color3.fromRGB(160, 110, 70)
	local walls = {
		{ Vector3.new(Lot.SizeX + WALL * 2, wallHeight, WALL), Vector3.new(cx, wallY, cz - HALF_Z - WALL / 2) },
		{ Vector3.new(Lot.SizeX + WALL * 2, wallHeight, WALL), Vector3.new(cx, wallY, cz + HALF_Z + WALL / 2) },
		{ Vector3.new(WALL, wallHeight, Lot.SizeZ), Vector3.new(cx - HALF_X - WALL / 2, wallY, cz) },
		{ Vector3.new(WALL, wallHeight, Lot.SizeZ), Vector3.new(cx + HALF_X + WALL / 2, wallY, cz) },
	}
	for index, wall in ipairs(walls) do
		solid(structure, {
			Name = "RetainingWall" .. index,
			Size = wall[1],
			CFrame = CFrame.new(wall[2]),
			Material = Enum.Material.WoodPlanks,
			Color = wallColor,
		})
		-- top curb
		solid(structure, {
			Name = "Curb" .. index,
			Size = Vector3.new(wall[1].X + 0.2, 0.5, wall[1].Z + 0.2),
			CFrame = CFrame.new(wall[2].X, LOT_TOP + 0.25, wall[2].Z),
			Material = Enum.Material.Wood,
			Color = Palette.WoodDark,
		})
	end

	-- Vertical support beams on the inner wall faces (cozy detail)
	for i = -3, 3 do
		local offset = i * (Lot.SizeX / 7)
		for _, side in ipairs({ -1, 1 }) do
			solid(structure, {
				Name = "Beam",
				Size = Vector3.new(1, wallHeight, 0.6),
				CFrame = CFrame.new(cx + offset, wallY, cz + side * (HALF_Z + 0.3)),
				Material = Enum.Material.Wood,
				Color = Palette.WoodDark,
				CanCollide = false,
				CanQuery = false,
			})
			solid(structure, {
				Name = "Beam",
				Size = Vector3.new(0.6, wallHeight, 1),
				CFrame = CFrame.new(cx + side * (HALF_X + 0.3), wallY, cz + offset),
				Material = Enum.Material.Wood,
				Color = Palette.WoodDark,
				CanCollide = false,
				CanQuery = false,
			})
		end
	end

	-- Plaza (flat sandy ground at the top of the walls)
	local inner = HALF_X + WALL
	local plazaThickness = 4
	local plazaY = LOT_TOP - plazaThickness / 2
	local plazaColor = Color3.fromRGB(228, 194, 138)
	local outerSpan = PLAZA - inner
	local plazas = {
		{ Vector3.new(PLAZA * 2, plazaThickness, outerSpan), Vector3.new(cx, plazaY, cz - inner - outerSpan / 2) },
		{ Vector3.new(PLAZA * 2, plazaThickness, outerSpan), Vector3.new(cx, plazaY, cz + inner + outerSpan / 2) },
		{ Vector3.new(outerSpan, plazaThickness, inner * 2), Vector3.new(cx - inner - outerSpan / 2, plazaY, cz) },
		{ Vector3.new(outerSpan, plazaThickness, inner * 2), Vector3.new(cx + inner + outerSpan / 2, plazaY, cz) },
	}
	for index, plaza in ipairs(plazas) do
		solid(structure, {
			Name = "Plaza" .. index,
			Size = plaza[1],
			CFrame = CFrame.new(plaza[2]),
			Material = Enum.Material.Sand,
			Color = plazaColor,
		})
	end

	-- Fence on the curb with gates in the middle of each side
	local fence = folder("Fence", structure)
	local fenceColor = Color3.fromRGB(176, 124, 78)
	local gateHalf = 5
	local fenceSpan = HALF_X + WALL / 2
	local postSpacing = (fenceSpan * 2) / math.max(1, math.floor(fenceSpan * 2 / 6 + 0.5))
	local fenceLine = HALF_X + WALL / 2
	local function fenceSide(alongX, fixed)
		local span = fenceSpan
		local points = {}
		local t = -span
		while t <= span + 0.01 do
			if math.abs(t) >= gateHalf then
				table.insert(points, t)
			end
			t += postSpacing
		end
		for index, along in ipairs(points) do
			local position = alongX and Vector3.new(cx + along, LOT_TOP + 2.25, cz + fixed) or Vector3.new(cx + fixed, LOT_TOP + 2.25, cz + along)
			solid(fence, {
				Name = "Post",
				Size = Vector3.new(0.7, 3.5, 0.7),
				CFrame = CFrame.new(position),
				Material = Enum.Material.Wood,
				Color = Palette.WoodDark,
			})
			local nextAlong = points[index + 1]
			if nextAlong and (nextAlong - along) <= postSpacing + 0.01 then
				local mid = (along + nextAlong) / 2
				local length = nextAlong - along
				for _, height in ipairs({ 1.4, 2.9 }) do
					local railPos = alongX and Vector3.new(cx + mid, LOT_TOP + 0.5 + height, cz + fixed) or Vector3.new(cx + fixed, LOT_TOP + 0.5 + height, cz + mid)
					local railSize = alongX and Vector3.new(length, 0.35, 0.3) or Vector3.new(0.3, 0.35, length)
					solid(fence, {
						Name = "Rail",
						Size = railSize,
						CFrame = CFrame.new(railPos),
						Material = Enum.Material.Wood,
						Color = fenceColor,
					})
				end
			end
		end
	end
	fenceSide(true, -fenceLine)
	fenceSide(true, fenceLine)
	fenceSide(false, -fenceLine)
	fenceSide(false, fenceLine)

	-- Ladders down into the pit at each gate
	local ladders = folder("Ladders", structure)
	local ladderHeight = Lot.Depth + 2
	local ladderSpots = {
		Vector3.new(cx, bottom + ladderHeight / 2, cz - HALF_Z + 1),
		Vector3.new(cx, bottom + ladderHeight / 2, cz + HALF_Z - 1),
		Vector3.new(cx - HALF_X + 1, bottom + ladderHeight / 2, cz),
		Vector3.new(cx + HALF_X - 1, bottom + ladderHeight / 2, cz),
	}
	for index, spot in ipairs(ladderSpots) do
		local truss = Instance.new("TrussPart")
		truss.Name = "Ladder" .. index
		truss.Size = Vector3.new(2, ladderHeight, 2)
		truss.CFrame = CFrame.new(spot)
		truss.Anchored = true
		truss.Material = Enum.Material.Wood
		truss.Color = Palette.WoodDark
		truss.Parent = ladders
	end

	WorldBuilder.Refs.Bedrock = bedrock
	WorldBuilder.Refs.Ladders = ladders
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

local function buildDecor(parent)
	local decor = folder("Decor", parent)
	local rng = Random.new(4242)
	local placed = 0
	local attempts = 0
	while placed < 22 and attempts < 400 do
		attempts += 1
		local x = rng:NextNumber(-150, 150)
		local z = rng:NextNumber(-150, 150)
		local nearLot = math.abs(x) < HALF_X + WALL + 10 and math.abs(z) < HALF_Z + WALL + 10
		local nearStations = z > 40 and z < 75 and math.abs(x) < 38
		if not nearLot and not nearStations then
			buildCactus(decor, Vector3.new(x, LOT_TOP, z), rng:NextNumber(4, 8), rng)
			placed += 1
		end
	end
	-- rocks
	for _ = 1, 26 do
		local x = rng:NextNumber(-170, 170)
		local z = rng:NextNumber(-170, 170)
		local nearLot = math.abs(x) < HALF_X + WALL + 8 and math.abs(z) < HALF_Z + WALL + 8
		local nearStations = z > 40 and z < 75 and math.abs(x) < 38
		if not nearLot and not nearStations then
			local size = Vector3.new(rng:NextNumber(2, 6), rng:NextNumber(1.2, 3.2), rng:NextNumber(2, 6))
			PartKit.Ellipsoid(decor, size, CFrame.new(x, LOT_TOP + size.Y * 0.25, z) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), {
				Name = "Rock",
				Material = Enum.Material.Sandstone,
				Color = Color3.fromRGB(190, 128, 92):Lerp(Palette.Stone, rng:NextNumber(0, 0.6)),
				CanCollide = true,
				CanQuery = true,
			})
		end
	end
	-- lamps around the lot & stations
	local edge = HALF_X + WALL + 3
	for _, corner in ipairs({ Vector3.new(-edge, 0, -edge), Vector3.new(edge, 0, -edge), Vector3.new(-edge, 0, edge), Vector3.new(edge, 0, edge) }) do
		buildLamp(decor, Vector3.new(Lot.CenterX + corner.X, LOT_TOP, Lot.CenterZ + corner.Z))
	end
	buildLamp(decor, Vector3.new(-8, LOT_TOP, 64))
	buildLamp(decor, Vector3.new(8, LOT_TOP, 64))

	-- boardwalk paths
	local planks = Color3.fromRGB(170, 120, 76)
	solid(decor, { Name = "Boardwalk", Size = Vector3.new(6, 0.2, 22), CFrame = CFrame.new(0, LOT_TOP + 0.1, 49), Material = Enum.Material.WoodPlanks, Color = planks })
	solid(decor, { Name = "Boardwalk", Size = Vector3.new(12, 0.2, 5), CFrame = CFrame.new(-9, LOT_TOP + 0.1, 56), Material = Enum.Material.WoodPlanks, Color = planks })
	solid(decor, { Name = "Boardwalk", Size = Vector3.new(12, 0.2, 5), CFrame = CFrame.new(9, LOT_TOP + 0.1, 56), Material = Enum.Material.WoodPlanks, Color = planks })

	-- sand sack pile near the weigh station
	for i = 0, 4 do
		PartKit.Ellipsoid(decor, Vector3.new(2.2, 1.6, 1.6), CFrame.new(-33 + (i % 2) * 0.6, LOT_TOP + 0.8 + math.floor(i / 3) * 1.3, 52 + (i % 3) * 1.8) * CFrame.Angles(0, i, 0), {
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
	local origin = CFrame.new(-22, LOT_TOP, 56) * CFrame.Angles(0, math.rad(-90), 0)

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
	local origin = CFrame.new(22, LOT_TOP, 56) * CFrame.Angles(0, math.rad(90), 0)
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
	local origin = Vector3.new(-12, LOT_TOP, 44)
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
	spawn.CFrame = CFrame.new(0, LOT_TOP + 0.2, 64)
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
