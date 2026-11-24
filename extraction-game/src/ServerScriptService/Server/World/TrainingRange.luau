--!strict
--[[
	TrainingRange
	Shooting lane down the alley for testing gunplay before Phase 4 brings real
	threats. Three armoured mannequins (Humanoid-driven: headshots, kills,
	falloff all work through the real CombatService path), distance boards and
	a steel gong plate for impact sparks.

	Mannequins flash on hit, regenerate when left alone, collapse on death and
	respawn after Config.Combat.TrainingDummyRespawn seconds.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local PartFactory = require(Shared.Builders.PartFactory)

local TrainingRange = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local S = {
	Mannequin = PartFactory.style(rgb(184, 172, 152), Enum.Material.SmoothPlastic, 0.02),
	Joint = PartFactory.style(rgb(60, 60, 64), Enum.Material.Metal, 0.05),
	Carrier = PartFactory.style(rgb(74, 80, 58), Enum.Material.Fabric),
	Pouch = PartFactory.style(rgb(62, 68, 48), Enum.Material.Fabric),
	Steel = PartFactory.style(rgb(80, 82, 86), Enum.Material.Metal, 0.1),
	SteelDark = PartFactory.style(rgb(40, 42, 46), Enum.Material.DiamondPlate),
	Board = PartFactory.style(rgb(30, 30, 32), Enum.Material.SmoothPlastic),
	Invisible = PartFactory.style(rgb(0, 0, 0), Enum.Material.SmoothPlastic, 0, 1, false),
}

local function rings(part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Target"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 1
	gui.Parent = part
	for i, size in { 90, 60, 30 } do
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.45)
		ring.Size = UDim2.fromOffset(size, size)
		ring.BackgroundTransparency = if i == 3 then 0.1 else 1
		ring.BackgroundColor3 = rgb(200, 60, 40)
		ring.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = ring
		local stroke = Instance.new("UIStroke")
		stroke.Color = rgb(200, 60, 40)
		stroke.Thickness = 3
		stroke.Parent = ring
		ring.Parent = gui
	end
end

local function buildDummy(parent: Instance, base: CFrame, index: number)
	local model = Instance.new("Model")
	model.Name = "TrainingDummy" .. index

	local function add(name: string, size: Vector3, offset: CFrame, style: PartFactory.Style, anchored: boolean?): BasePart
		return PartFactory.make({
			Name = name,
			Size = size,
			CFrame = base * offset,
			Style = style,
			CanCollide = true,
			Anchored = anchored == true,
			Parent = model,
		})
	end

	-- Stand (separate, stays when the mannequin collapses)
	local stand = Instance.new("Model")
	stand.Name = "DummyStand" .. index
	stand.Parent = parent
	PartFactory.make({ Name = "StandPlate", Size = Vector3.new(2.2, 0.2, 2.2), CFrame = base * CFrame.new(0, 0.1, 0), Style = S.SteelDark, CanCollide = true, Parent = stand })

	local root = add("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 3.1, 0), S.Invisible, true)
	root.CanCollide = false
	model.PrimaryPart = root

	local limbs: { BasePart } = {}
	local function limb(name: string, size: Vector3, offset: CFrame, style: PartFactory.Style): BasePart
		local part = add(name, size, offset, style)
		PartFactory.weld(root, part)
		table.insert(limbs, part)
		return part
	end

	limb("LeftLeg", Vector3.new(0.85, 2.0, 0.85), CFrame.new(-0.5, 1.2, 0), S.Mannequin)
	limb("RightLeg", Vector3.new(0.85, 2.0, 0.85), CFrame.new(0.5, 1.2, 0), S.Mannequin)
	local torso = limb("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3.2, 0), S.Mannequin)
	limb("LeftArm", Vector3.new(0.85, 1.9, 0.85), CFrame.new(-1.45, 3.15, 0), S.Mannequin)
	limb("RightArm", Vector3.new(0.85, 1.9, 0.85), CFrame.new(1.45, 3.15, 0), S.Mannequin)
	limb("Neck", Vector3.new(0.45, 0.3, 0.45), CFrame.new(0, 4.35, 0), S.Joint)
	limb("Head", Vector3.new(1.1, 1.15, 1.1), CFrame.new(0, 4.95, 0), S.Mannequin)
	limb("PlateCarrier", Vector3.new(2.12, 1.45, 1.14), CFrame.new(0, 3.3, 0), S.Carrier)
	for i, x in { -0.6, 0, 0.6 } do
		limb("MagPouch" .. i, Vector3.new(0.45, 0.55, 0.2), CFrame.new(x, 2.95, -0.66), S.Pouch)
	end
	rings(torso)

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = Config.Combat.TrainingDummyHealth
	humanoid.Health = Config.Combat.TrainingDummyHealth
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	local flash = Instance.new("Highlight")
	flash.FillColor = rgb(255, 255, 255)
	flash.FillTransparency = 1
	flash.OutlineTransparency = 1
	flash.DepthMode = Enum.HighlightDepthMode.Occluded
	flash.Parent = model

	model.Parent = parent

	local lastHealth = humanoid.Health
	local lastHit = 0
	humanoid.HealthChanged:Connect(function(health: number)
		if health < lastHealth then
			lastHit = os.clock()
			flash.FillTransparency = 0.55
			task.delay(0.07, function()
				flash.FillTransparency = 1
			end)
		end
		lastHealth = health
	end)

	-- Regenerate when left alone.
	task.spawn(function()
		while model.Parent and humanoid.Health > 0 do
			task.wait(0.5)
			if humanoid.Health > 0 and os.clock() - lastHit > 3 and humanoid.Health < humanoid.MaxHealth then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * 0.25)
			end
		end
	end)

	humanoid.Died:Once(function()
		for _, part in limbs do
			for _, weld in part:GetChildren() do
				if weld:IsA("WeldConstraint") then
					weld:Destroy()
				end
			end
			part.Anchored = false
			part.AssemblyLinearVelocity = Vector3.new(math.random(-6, 6), 4, math.random(4, 10))
		end
		task.delay(Config.Combat.TrainingDummyRespawn, function()
			model:Destroy()
			stand:Destroy()
			buildDummy(parent, base, index)
		end)
	end)
end

local function distanceBoard(parent: Instance, origin: CFrame, position: Vector3, text: string)
	local board = PartFactory.make({
		Name = "DistanceBoard",
		Size = Vector3.new(0.2, 1.2, 3),
		CFrame = origin * CFrame.new(position),
		Style = S.Board,
		CanCollide = true,
		Parent = parent,
	})
	PartFactory.make({
		Name = "BoardPost",
		Size = Vector3.new(0.2, position.Y, 0.2),
		CFrame = origin * CFrame.new(position.X, position.Y / 2, position.Z),
		Style = S.Steel,
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.6
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = rgb(255, 168, 86)
	label.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
	label.Parent = gui
end

function TrainingRange.build(safehouse: Model)
	local existing = safehouse:FindFirstChild("TrainingRange")
	if existing then
		existing:Destroy()
	end
	local folder = PartFactory.folder("TrainingRange", safehouse)
	local origin = Config.World.Origin

	-- Dummies face -Z, toward the deploy points.
	local spots = { Vector3.new(0, 0, 24), Vector3.new(-6, 0, 40), Vector3.new(5, 0, 56) }
	for i, p in spots do
		buildDummy(folder, origin * CFrame.new(p), i)
	end

	-- Distance boards on the left sidewalk, readable from the deploy area.
	for _, z in { 24, 40, 56 } do
		distanceBoard(folder, origin, Vector3.new(-11.8, 2.4, z), string.format("%dm", math.floor((z + 2) * 0.28 + 0.5)))
	end

	-- Steel gong for impact sparks at the end of the lane.
	local gongCF = origin * CFrame.new(-1, 3.4, 68)
	PartFactory.make({ Name = "GongPlate", Size = Vector3.new(2.4, 2.4, 0.3), CFrame = gongCF, Style = S.Steel, CanCollide = true, Parent = folder })
	PartFactory.make({ Name = "GongChainL", Size = Vector3.new(0.08, 2.6, 0.08), CFrame = gongCF * CFrame.new(-0.9, 2.5, 0), Style = S.SteelDark, Parent = folder })
	PartFactory.make({ Name = "GongChainR", Size = Vector3.new(0.08, 2.6, 0.08), CFrame = gongCF * CFrame.new(0.9, 2.5, 0), Style = S.SteelDark, Parent = folder })
	PartFactory.make({ Name = "GongBeam", Size = Vector3.new(4.4, 0.3, 0.3), CFrame = gongCF * CFrame.new(0, 3.8, 0), Style = S.SteelDark, CanCollide = true, Parent = folder })
	for _, x in { -2.1, 2.1 } do
		PartFactory.make({ Name = "GongPost", Size = Vector3.new(0.3, 7.4, 0.3), CFrame = origin * CFrame.new(-1 + x, 3.7, 68), Style = S.SteelDark, CanCollide = true, Parent = folder })
	end
end

return TrainingRange
