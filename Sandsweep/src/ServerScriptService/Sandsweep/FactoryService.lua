-- FactoryService (ModuleScript) - ServerScriptService/Sandsweep/FactoryService
-- Sand processing line: Input Hopper -> conveyor belts (anchored parts with
-- AssemblyLinearVelocity) -> Glass Furnace -> Brick Press -> Microchip
-- Refinery -> Auto-Seller. Each chunk belongs to a player; a machine only
-- upgrades chunks whose owner bought it. Payouts are server-side only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Sandsweep")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local PartKit = require(Shared:WaitForChild("PartKit"))

local FactoryService = {}
FactoryService.Hooks = {
	GetData = nil, -- function(player) -> data table or nil
	OnPayout = nil, -- function(player, kg, stage, worldPosition)
	OnHopperDump = nil, -- function(player) (bag -> hopper via prompt)
}
FactoryService.Refs = {}

local Settings = GameConfig.FactorySettings
local Palette = GameConfig.Palette

local BELT_TOP = 2.6
local BELT_START, BELT_END = -46, 62
local HOPPER_X = -52
local SPAWN_X = -45
local SELL_X = 54
local MACHINES = {
	{ Id = "Furnace", X = -26 },
	{ Id = "Press", X = 2 },
	{ Id = "Refinery", X = 30 },
}

local origin = CFrame.identity
local chunkFolder
local chunkCounts = {} -- [userId] = active chunk count
local totalChunks = 0
local spawnCursor = 0

local STAGE_STYLE = {
	[0] = { Size = Vector3.new(1.4, 1.1, 1.4), Material = Enum.Material.Sand, Color = Color3.fromRGB(232, 196, 128), Transparency = 0, Name = "SandChunk" },
	[1] = { Size = Vector3.new(1.8, 0.35, 1.4), Material = Enum.Material.Glass, Color = Color3.fromRGB(120, 222, 236), Transparency = 0.35, Name = "GlassPane" },
	[2] = { Size = Vector3.new(1.6, 1.0, 1.2), Material = Enum.Material.Concrete, Color = Color3.fromRGB(176, 174, 168), Transparency = 0, Name = "ConcreteBlock" },
	[3] = { Size = Vector3.new(1.5, 0.35, 1.5), Material = Enum.Material.Neon, Color = Color3.fromRGB(96, 232, 128), Transparency = 0, Name = "Microchip" },
}

local function L(x, y, z)
	return origin * CFrame.new(x, y, z)
end

local function solid(parent, props)
	props.CanCollide = props.CanCollide ~= false
	props.CanQuery = props.CanQuery ~= false
	props.CanTouch = props.CanTouch ~= false
	return PartKit.Part(parent, props)
end

local function sign(parent, cframe, width, title, subtitle, accent)
	local board = PartKit.Part(parent, { Name = "Sign", Size = Vector3.new(width, 1.9, 0.3), CFrame = cframe, Color = Palette.Cream })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = board
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Palette.Cream
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 8
	stroke.Color = accent or Palette.Ochre
	stroke.Parent = frame
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromScale(0.94, 0.55)
	titleLabel.Position = UDim2.fromScale(0.03, 0.05)
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = Palette.Ink
	titleLabel.Text = title
	titleLabel.Parent = frame
	local subLabel = Instance.new("TextLabel")
	subLabel.BackgroundTransparency = 1
	subLabel.Size = UDim2.fromScale(0.94, 0.3)
	subLabel.Position = UDim2.fromScale(0.03, 0.63)
	subLabel.Font = Enum.Font.GothamBold
	subLabel.TextScaled = true
	subLabel.TextColor3 = Palette.InkSoft
	subLabel.Text = subtitle
	subLabel.Parent = frame
	return board
end

--------------------------------------------------------------------------
-- BUILD
--------------------------------------------------------------------------
local function buildBelt(parent)
	local belt = Instance.new("Folder")
	belt.Name = "Conveyor"
	belt.Parent = parent
	local segment = 12
	local velocity = origin:VectorToWorldSpace(Vector3.new(Settings.BeltSpeed, 0, 0))
	local x = BELT_START
	while x < BELT_END - 0.01 do
		local length = math.min(segment, BELT_END - x)
		local center = x + length / 2
		local part = solid(belt, {
			Name = "Belt",
			Size = Vector3.new(length, 0.6, 3.6),
			CFrame = L(center, BELT_TOP - 0.3, 0),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(46, 46, 50),
			CustomPhysicalProperties = PhysicalProperties.new(1, 1.2, 0, 10, 1),
		})
		part.AssemblyLinearVelocity = velocity
		for _, z in ipairs({ -1.95, 1.95 }) do
			solid(belt, { Name = "Rail", Size = Vector3.new(length, 0.9, 0.3), CFrame = L(center, BELT_TOP + 0.45, z), Material = Enum.Material.Metal, Color = Color3.fromRGB(242, 186, 48) })
		end
		for chevron = 0, math.floor(length / 3) - 1 do
			PartKit.Part(belt, {
				Name = "Chevron",
				Size = Vector3.new(0.25, 0.02, 3.0),
				CFrame = L(x + 1.5 + chevron * 3, BELT_TOP + 0.01, 0),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(90, 88, 84),
				CastShadow = false,
			})
		end
		for _, legX in ipairs({ x + 1, x + length - 1 }) do
			for _, z in ipairs({ -1.5, 1.5 }) do
				PartKit.Part(belt, { Name = "Leg", Size = Vector3.new(0.5, BELT_TOP - 0.6, 0.5), CFrame = L(legX, (BELT_TOP - 0.6) / 2, z), Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 70, 76) })
			end
		end
		x += length
	end
	solid(belt, { Name = "EndStop", Size = Vector3.new(0.4, 2.4, 3.6), CFrame = L(BELT_END + 0.2, BELT_TOP + 1.2, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 70, 76) })
end

local function buildHopper(parent)
	local hopper = Instance.new("Folder")
	hopper.Name = "Hopper"
	hopper.Parent = parent
	local yellow = Color3.fromRGB(242, 186, 48)
	for _, x in ipairs({ -3, 3 }) do
		for _, z in ipairs({ -3, 3 }) do
			solid(hopper, { Name = "Leg", Size = Vector3.new(0.6, 6.4, 0.6), CFrame = L(HOPPER_X + x, 3.2, z), Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 70, 76) })
		end
	end
	for index = 0, 3 do
		local yaw = math.rad(index * 90)
		PartKit.Part(hopper, {
			Name = "FunnelWall",
			Size = Vector3.new(7.4, 5, 0.35),
			CFrame = L(HOPPER_X, 8.6, 0) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -2.7) * CFrame.Angles(math.rad(-28), 0, 0),
			Material = Enum.Material.Metal,
			Color = yellow,
		})
	end
	PartKit.Part(hopper, { Name = "Outlet", Size = Vector3.new(3, 1.6, 3), CFrame = L(HOPPER_X, 5.8, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 70, 76) })
	PartKit.Part(hopper, {
		Name = "Chute",
		Size = Vector3.new(7.2, 0.3, 3),
		CFrame = L((HOPPER_X + SPAWN_X) / 2 + 0.5, 4.3, 0) * CFrame.Angles(0, 0, math.rad(-14)),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(150, 154, 160),
	})
	local sand = PartKit.Part(hopper, {
		Name = "HopperSand",
		Size = Vector3.new(5.6, 1.6, 5.6),
		CFrame = L(HOPPER_X, 8.4, 0),
		Material = Enum.Material.Sand,
		Color = Color3.fromRGB(232, 196, 128),
		Transparency = 1,
	})
	local control = solid(hopper, { Name = "ControlBox", Size = Vector3.new(1.6, 3.2, 1.2), CFrame = L(HOPPER_X + 4.2, 1.6, -4.4), Material = Enum.Material.Metal, Color = yellow })
	PartKit.Part(hopper, { Name = "Button", Size = Vector3.new(0.6, 0.6, 0.2), CFrame = L(HOPPER_X + 4.2, 2.6, -5.05), Material = Enum.Material.Neon, Color = Color3.fromRGB(90, 230, 120), CastShadow = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HopperPrompt"
	prompt.ActionText = "Dump Bag"
	prompt.ObjectText = "Factory Hopper"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = control
	prompt.Triggered:Connect(function(player)
		if FactoryService.Hooks.OnHopperDump then
			FactoryService.Hooks.OnHopperDump(player)
		end
	end)
	sign(hopper, L(HOPPER_X, 12.6, -2.9), 8, "⛏ INPUT HOPPER", "Dump your bag here (E)", Color3.fromRGB(242, 186, 48))

	-- truck dump bay in front of the hopper
	local bayCenter = Vector3.new(HOPPER_X, 0, -17)
	local pad = solid(hopper, { Name = "HopperTruckBay", Size = Vector3.new(16, 0.3, 14), CFrame = L(bayCenter.X, 0.15, bayCenter.Z), Material = Enum.Material.Concrete, Color = Color3.fromRGB(120, 112, 104) })
	for _, spec in ipairs({
		{ Vector3.new(16, 0.32, 0.5), Vector3.new(0, 0, -7) },
		{ Vector3.new(16, 0.32, 0.5), Vector3.new(0, 0, 7) },
		{ Vector3.new(0.5, 0.32, 14), Vector3.new(-8, 0, 0) },
		{ Vector3.new(0.5, 0.32, 14), Vector3.new(8, 0, 0) },
	}) do
		PartKit.Part(hopper, { Name = "Stripe", Size = spec[1], CFrame = L(bayCenter.X + spec[2].X, 0.16, bayCenter.Z + spec[2].Z), Material = Enum.Material.Neon, Color = yellow, CastShadow = false })
	end
	PartKit.Cylinder(hopper, 7, 0.5, L(bayCenter.X - 9.5, 3.5, bayCenter.Z), "Y", { Name = "SignPost", Material = Enum.Material.Wood, Color = Palette.WoodDark, CanCollide = true, CanQuery = true })
	sign(hopper, L(bayCenter.X - 9.5, 6.6, bayCenter.Z), 8, "🚚 HOPPER DUMP BAY", "Drive in to dump into the factory", yellow)

	FactoryService.Refs.HopperPrompt = prompt
	FactoryService.Refs.HopperBay = pad
	FactoryService.Refs.HopperSand = sand
end

local function housingWalls(parent, x, material, color, height)
	for _, z in ipairs({ -2.7, 2.7 }) do
		solid(parent, { Name = "Wall", Size = Vector3.new(8, height, 1.2), CFrame = L(x, BELT_TOP + height / 2 - 0.6, z), Material = material, Color = color })
	end
	solid(parent, { Name = "Roof", Size = Vector3.new(8.4, 1.2, 6.6), CFrame = L(x, BELT_TOP + height - 0.6 + 0.6, 0), Material = material, Color = color })
end

local function buildFurnace(parent)
	local machine = Instance.new("Folder")
	machine.Name = "GlassFurnace"
	machine.Parent = parent
	local x = MACHINES[1].X
	housingWalls(machine, x, Enum.Material.Brick, Color3.fromRGB(176, 88, 60), 5.4)
	for _, z in ipairs({ -3.35, 3.35 }) do
		PartKit.Part(machine, { Name = "HeatWindow", Size = Vector3.new(5.6, 1.2, 0.1), CFrame = L(x, BELT_TOP + 2.2, z), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 140, 50), CastShadow = false })
	end
	local glow = PartKit.Part(machine, { Name = "InnerGlow", Size = Vector3.new(6.6, 0.2, 3.4), CFrame = L(x, BELT_TOP + 4.5, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 150, 60), CastShadow = false })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Brightness = 3
	light.Range = 16
	light.Parent = glow
	local firePart = PartKit.Part(machine, { Name = "FirePart", Size = Vector3.new(1, 1, 1), CFrame = L(x, BELT_TOP + 7.2, -1.6), Transparency = 1, CastShadow = false })
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 150, 50)
	fire.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fire.Parent = firePart
	PartKit.Cylinder(machine, 5, 1.6, L(x + 2.4, BELT_TOP + 9.2, 1.6), "Y", { Name = "Chimney", Material = Enum.Material.Brick, Color = Color3.fromRGB(140, 70, 50) })
	local smokePart = PartKit.Part(machine, { Name = "SmokePart", Size = Vector3.new(1, 1, 1), CFrame = L(x + 2.4, BELT_TOP + 12, 1.6), Transparency = 1, CastShadow = false })
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(120, 112, 106)
	smoke.Opacity = 0.12
	smoke.RiseVelocity = 5
	smoke.Size = 2.5
	smoke.Parent = smokePart
	sign(machine, L(x, BELT_TOP + 7.6, -3.4), 8, "🔥 GLASS FURNACE", "Sand → glass panes · 3x", Color3.fromRGB(255, 140, 50))
end

local function buildPress(parent)
	local machine = Instance.new("Folder")
	machine.Name = "BrickPress"
	machine.Parent = parent
	local x = MACHINES[2].X
	local grey = Color3.fromRGB(110, 110, 116)
	for _, dx in ipairs({ -3.4, 3.4 }) do
		for _, z in ipairs({ -2.7, 2.7 }) do
			solid(machine, { Name = "Post", Size = Vector3.new(0.9, 9.6, 0.9), CFrame = L(x + dx, 4.8, z), Material = Enum.Material.Metal, Color = grey })
		end
	end
	solid(machine, { Name = "TopBeam", Size = Vector3.new(8, 1.6, 6.4), CFrame = L(x, 10.2, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(242, 186, 48) })
	for i = 0, 5 do
		PartKit.Part(machine, {
			Name = "Hazard",
			Size = Vector3.new(0.5, 1.62, 0.05),
			CFrame = L(x - 3.2 + i * 1.3, 10.2, -3.22) * CFrame.Angles(0, 0, math.rad(30)),
			Color = Color3.fromRGB(30, 30, 32),
		})
	end
	solid(machine, { Name = "Guard", Size = Vector3.new(7, 2.2, 0.6), CFrame = L(x, BELT_TOP + 1.1, -2.6), Material = Enum.Material.Concrete, Color = grey })
	solid(machine, { Name = "Guard", Size = Vector3.new(7, 2.2, 0.6), CFrame = L(x, BELT_TOP + 1.1, 2.6), Material = Enum.Material.Concrete, Color = grey })
	local cylinder = PartKit.Cylinder(machine, 2.6, 2.4, L(x, 8.1, 0), "Y", { Name = "Cylinder", Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 70, 76) })
	local rod = PartKit.Cylinder(machine, 3.0, 0.8, L(x, 6.0, 0), "Y", { Name = "Rod", Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 204, 210) })
	local ram = PartKit.Part(machine, { Name = "Ram", Size = Vector3.new(3.2, 0.6, 3.2), CFrame = L(x, 4.5, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 154, 160) })
	sign(machine, L(x, 12.2, -3.3), 8, "🧱 BRICK PRESS", "Stamps concrete blocks · 6x", grey)

	-- stamping loop
	local rodBase, ramBase = rod.CFrame, ram.CFrame
	local offset = Instance.new("NumberValue")
	offset.Name = "Stroke"
	offset.Parent = machine
	offset.Changed:Connect(function(value)
		rod.CFrame = rodBase * CFrame.new(-value, 0, 0) -- rod is a Y cylinder: its local X axis points up
		ram.CFrame = ramBase * CFrame.new(0, -value, 0)
	end)
	task.spawn(function()
		while machine.Parent do
			local down = TweenService:Create(offset, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 0.95 })
			down:Play()
			down.Completed:Wait()
			task.wait(0.12)
			local up = TweenService:Create(offset, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Value = 0 })
			up:Play()
			up.Completed:Wait()
			task.wait(0.55)
		end
	end)
	FactoryService.Refs.PressCylinder = cylinder
end

local function buildRefinery(parent)
	local machine = Instance.new("Folder")
	machine.Name = "MicrochipRefinery"
	machine.Parent = parent
	local x = MACHINES[3].X
	local dark = Color3.fromRGB(40, 44, 56)
	for _, z in ipairs({ -2.7, 2.7 }) do
		solid(machine, { Name = "GlassWall", Size = Vector3.new(8, 5.4, 0.6), CFrame = L(x, BELT_TOP + 2.1, z), Material = Enum.Material.Glass, Transparency = 0.45, Color = Color3.fromRGB(130, 190, 230) })
		for _, dx in ipairs({ -4, 4 }) do
			solid(machine, { Name = "Frame", Size = Vector3.new(0.6, 5.6, 0.8), CFrame = L(x + dx, BELT_TOP + 2.2, z), Material = Enum.Material.Metal, Color = dark })
		end
	end
	local roof = solid(machine, { Name = "Roof", Size = Vector3.new(8.6, 1.2, 6.8), CFrame = L(x, BELT_TOP + 5.4, 0), Material = Enum.Material.Metal, Color = dark })
	for _, z in ipairs({ -3.42, 3.42 }) do
		PartKit.Part(machine, { Name = "NeonStrip", Size = Vector3.new(8, 0.25, 0.1), CFrame = L(x, BELT_TOP + 5.4, z), Material = Enum.Material.Neon, Color = Color3.fromRGB(80, 180, 255), CastShadow = false })
	end
	local laserFloor = PartKit.Part(machine, { Name = "LaserFloor", Size = Vector3.new(6, 0.1, 3), CFrame = L(x, BELT_TOP + 0.05, 0), Transparency = 1, CastShadow = false })
	for _, dx in ipairs({ -2.4, 0, 2.4 }) do
		local top = Instance.new("Attachment")
		top.Parent = roof
		top.WorldPosition = L(x + dx, BELT_TOP + 4.75, 0).Position
		local bottom = Instance.new("Attachment")
		bottom.Parent = laserFloor
		bottom.WorldPosition = L(x + dx, BELT_TOP + 0.05, 0).Position
		local beam = Instance.new("Beam")
		beam.Attachment0 = top
		beam.Attachment1 = bottom
		beam.Color = ColorSequence.new(Color3.fromRGB(110, 210, 255))
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Width0 = 0.18
		beam.Width1 = 0.12
		beam.FaceCamera = true
		beam.Transparency = NumberSequence.new(0.1)
		beam.Parent = roof
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(90, 180, 255)
	light.Brightness = 3
	light.Range = 18
	light.Parent = roof
	PartKit.Part(machine, { Name = "Antenna", Size = Vector3.new(0.3, 3, 0.3), CFrame = L(x + 3, BELT_TOP + 7.5, 2), Material = Enum.Material.Metal, Color = dark })
	PartKit.Ball(machine, 0.6, L(x + 3, BELT_TOP + 9.1, 2), { Name = "AntennaTip", Material = Enum.Material.Neon, Color = Color3.fromRGB(80, 180, 255), CastShadow = false })
	sign(machine, L(x, BELT_TOP + 7.4, -3.5), 9, "💾 MICROCHIP REFINERY", "Silicon → microchips · 15x", Color3.fromRGB(80, 180, 255))
end

local function buildSeller(parent)
	local seller = Instance.new("Folder")
	seller.Name = "AutoSeller"
	seller.Parent = parent
	local green = Color3.fromRGB(90, 220, 120)
	for _, z in ipairs({ -3, 3 }) do
		solid(seller, { Name = "GatePost", Size = Vector3.new(0.9, 8, 0.9), CFrame = L(SELL_X + 2, 4, z), Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 60, 64) })
	end
	solid(seller, { Name = "GateTop", Size = Vector3.new(1.4, 1, 7), CFrame = L(SELL_X + 2, 8.3, 0), Material = Enum.Material.Neon, Color = green })
	PartKit.Part(seller, { Name = "Scanner", Size = Vector3.new(0.1, 5, 3.6), CFrame = L(SELL_X + 2, BELT_TOP + 2.5, 0), Material = Enum.Material.Neon, Color = green, Transparency = 0.75, CastShadow = false })
	solid(seller, { Name = "Bin", Size = Vector3.new(7, 2.4, 6), CFrame = L(BELT_END - 2.5, 1.2, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 70, 76) })
	sign(seller, L(SELL_X + 2, 10.2, -3.6), 8, "💰 AUTO-SELLER", "Finished goods pay out here", green)
end

function FactoryService.Build(parent, originCFrame)
	origin = originCFrame
	local factory = Instance.new("Folder")
	factory.Name = "Factory"
	factory.Parent = parent
	solid(factory, { Name = "Slab", Size = Vector3.new(130, 0.4, 30), CFrame = L(4, 0.2, -2), Material = Enum.Material.Concrete, Color = Color3.fromRGB(160, 154, 146) })
	buildBelt(factory)
	buildHopper(factory)
	buildFurnace(factory)
	buildPress(factory)
	buildRefinery(factory)
	buildSeller(factory)
	chunkFolder = Instance.new("Folder")
	chunkFolder.Name = "Chunks"
	chunkFolder.Parent = factory
	FactoryService.Refs.Chunks = chunkFolder
	return FactoryService.Refs
end

--------------------------------------------------------------------------
-- CHUNKS
--------------------------------------------------------------------------
local function styleChunk(part, stage)
	local style = STAGE_STYLE[stage] or STAGE_STYLE[0]
	part.Size = style.Size
	part.Material = style.Material
	part.Color = style.Color
	part.Transparency = style.Transparency
	part.Name = style.Name
end

local function spawnChunk(player, kg)
	local part = Instance.new("Part")
	styleChunk(part, 0)
	part.CFrame = L(SPAWN_X, BELT_TOP + 1.2, (math.random() - 0.5) * 1.2) * CFrame.Angles(0, math.random() * math.pi, 0)
	part.Anchored = false
	part.CanCollide = true
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CustomPhysicalProperties = PhysicalProperties.new(1, 0.9, 0, 5, 1)
	part:SetAttribute("Owner", player.UserId)
	part:SetAttribute("Kg", kg)
	part:SetAttribute("Stage", 0)
	part:SetAttribute("Born", os.clock())
	part.Parent = chunkFolder
	pcall(function()
		part:SetNetworkOwner(nil)
	end)
	chunkCounts[player.UserId] = (chunkCounts[player.UserId] or 0) + 1
	totalChunks += 1
end

local function removeChunk(part, pay)
	local owner = part:GetAttribute("Owner")
	chunkCounts[owner] = math.max(0, (chunkCounts[owner] or 1) - 1)
	totalChunks = math.max(0, totalChunks - 1)
	if pay then
		local player = Players:GetPlayerByUserId(owner)
		if player and FactoryService.Hooks.OnPayout then
			FactoryService.Hooks.OnPayout(player, part:GetAttribute("Kg") or 0, part:GetAttribute("Stage") or 0, part.Position)
		end
	end
	part:Destroy()
end

local function ownsMachine(player, machineId)
	local data = player and FactoryService.Hooks.GetData and FactoryService.Hooks.GetData(player)
	return data ~= nil and data.Factory ~= nil and data.Factory[machineId] == true
end

local function machineStage(machineId)
	local machine = GameConfig.GetMachine(machineId)
	return machine and machine.Stage or 0
end

local function processChunks()
	local now = os.clock()
	for _, part in ipairs(chunkFolder:GetChildren()) do
		if part:IsA("BasePart") then
			local localPos = origin:PointToObjectSpace(part.Position)
			local stage = part:GetAttribute("Stage") or 0
			local owner = Players:GetPlayerByUserId(part:GetAttribute("Owner") or 0)
			if not owner then
				removeChunk(part, false)
			elseif
				localPos.X >= SELL_X -- reached the Auto-Seller
				-- or fell off / got stuck: pay what it is worth now so nothing is ever lost
				or localPos.Y < BELT_TOP - 2.5
				or math.abs(localPos.Z) > 4
				or localPos.X < BELT_START - 6
				or now - (part:GetAttribute("Born") or now) > Settings.ChunkLifetime
			then
				removeChunk(part, true)
			else
				for _, machine in ipairs(MACHINES) do
					local targetStage = machineStage(machine.Id)
					if stage < targetStage and math.abs(localPos.X - machine.X) < 3.2 and ownsMachine(owner, machine.Id) then
						stage = targetStage
						part:SetAttribute("Stage", stage)
						styleChunk(part, stage)
						part.AssemblyLinearVelocity += Vector3.new(0, 4, 0)
					end
				end
			end
		end
	end
end

local function spawnNext()
	if totalChunks >= Settings.MaxChunksTotal then
		return
	end
	local players = Players:GetPlayers()
	local count = #players
	if count == 0 then
		return
	end
	for step = 1, count do
		local player = players[((spawnCursor + step - 1) % count) + 1]
		local data = FactoryService.Hooks.GetData and FactoryService.Hooks.GetData(player)
		if data and data.Factory and data.Factory.Hopper and (data.FactoryBufferKg or 0) > 0.01 and (chunkCounts[player.UserId] or 0) < Settings.MaxChunksPerPlayer then
			local buffer = data.FactoryBufferKg
			local kg = math.min(buffer, math.max(Settings.MinChunkKg, buffer / 10))
			data.FactoryBufferKg = buffer - kg
			if data.FactoryBufferKg < 0.01 then
				data.FactoryBufferKg = 0
			end
			spawnChunk(player, kg)
			spawnCursor = (spawnCursor + step) % count
			return
		end
	end
end

function FactoryService.Start()
	local spawnTimer, processTimer, visualTimer = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		if not chunkFolder then
			return
		end
		spawnTimer += dt
		processTimer += dt
		visualTimer += dt
		if spawnTimer >= Settings.ChunkInterval then
			spawnTimer = 0
			spawnNext()
		end
		if processTimer >= 0.1 then
			processTimer = 0
			processChunks()
		end
		if visualTimer >= 1 then
			visualTimer = 0
			local anyBuffer = false
			for _, player in ipairs(Players:GetPlayers()) do
				local data = FactoryService.Hooks.GetData and FactoryService.Hooks.GetData(player)
				if data and (data.FactoryBufferKg or 0) > 0.01 then
					anyBuffer = true
					break
				end
			end
			if FactoryService.Refs.HopperSand then
				FactoryService.Refs.HopperSand.Transparency = anyBuffer and 0 or 1
			end
		end
	end)
end

function FactoryService.IsOnPad(pad, position, margin)
	if not pad then
		return false
	end
	margin = margin or 1
	local localPos = pad.CFrame:PointToObjectSpace(position)
	return math.abs(localPos.X) <= pad.Size.X / 2 + margin and math.abs(localPos.Z) <= pad.Size.Z / 2 + margin and localPos.Y >= -2 and localPos.Y <= 12
end

return FactoryService
