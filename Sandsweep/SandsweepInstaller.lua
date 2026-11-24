-- =====================================================================
--  SANDSWEEP - one-paste Roblox Studio installer
--  Paste this whole file into View > Command Bar, press Enter, then Play.
--  Re-running it cleanly replaces a previous Sandsweep install.
-- =====================================================================
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local Lighting = game:GetService("Lighting")

pcall(function() ChangeHistoryService:SetWaypoint("Before Sandsweep install") end)

for _, old in ipairs({
	ReplicatedStorage:FindFirstChild("Sandsweep"),
	ServerScriptService:FindFirstChild("Sandsweep"),
	StarterPlayerScripts:FindFirstChild("SandsweepClient"),
}) do
	if old then old:Destroy() end
end

local function make(className, name, parent)
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local Containers = {
	RS = make("Folder", "Sandsweep", ReplicatedStorage),
	SSS = make("Folder", "Sandsweep", ServerScriptService),
	SPS = StarterPlayerScripts,
}
local remotes = make("Folder", "Remotes", Containers.RS)
make("RemoteEvent", "DigRequest", remotes)
make("RemoteEvent", "DigResult", remotes)
make("RemoteEvent", "DigFx", remotes)
make("RemoteEvent", "StateUpdate", remotes)
make("RemoteEvent", "LotUpdate", remotes)
make("RemoteEvent", "Notify", remotes)
make("RemoteEvent", "OpenMenu", remotes)
make("RemoteFunction", "Purchase", remotes)
make("RemoteFunction", "GetState", remotes)

local created = {}

-- ModuleScript: ReplicatedStorage/Sandsweep/GameConfig.lua
created["GameConfig"] = make("ModuleScript", "GameConfig", Containers.RS)
created["GameConfig"].Source = [======[
-- GameConfig (ModuleScript) - ReplicatedStorage/Sandsweep/GameConfig
-- Single source of truth for every tunable number in Sandsweep.
-- Shared by server and client so stats always agree.

local GameConfig = {}

GameConfig.GameName = "Sandsweep"
GameConfig.Version = "1.0.0"

--------------------------------------------------------------------------
-- PALETTE (warm cozy desert)
--------------------------------------------------------------------------
GameConfig.Palette = {
	Sand = Color3.fromRGB(232, 196, 128),
	SandLight = Color3.fromRGB(244, 218, 164),
	SandDark = Color3.fromRGB(198, 156, 96),
	Ochre = Color3.fromRGB(214, 152, 72),
	Terracotta = Color3.fromRGB(196, 96, 62),
	Clay = Color3.fromRGB(170, 84, 58),
	Sky = Color3.fromRGB(132, 190, 220),
	Sage = Color3.fromRGB(132, 168, 104),
	Cream = Color3.fromRGB(253, 245, 230),
	Paper = Color3.fromRGB(255, 250, 241),
	Ink = Color3.fromRGB(78, 54, 40),
	InkSoft = Color3.fromRGB(138, 108, 86),
	Wood = Color3.fromRGB(150, 102, 62),
	WoodDark = Color3.fromRGB(112, 74, 46),
	Stone = Color3.fromRGB(126, 104, 88),
	Gold = Color3.fromRGB(240, 192, 70),
	Locked = Color3.fromRGB(190, 178, 164),
}

--------------------------------------------------------------------------
-- THE LOT (Smooth Terrain dig site). All values multiples of 4 (voxel grid).
--------------------------------------------------------------------------
GameConfig.Lot = {
	Name = "Sunbaked Desert",
	CenterX = 0,
	CenterZ = 0,
	BottomY = 0, -- top of the hard bedrock floor under the whole desert
	SizeX = 160, -- the diggable desert (every grain inside counts)
	SizeZ = 160,
	Depth = 28, -- tallest possible dune above the bedrock
	SurfaceMin = 7, -- dune valleys (studs above bedrock)
	SurfaceMax = 22, -- dune crests
	EdgeHeight = 2, -- sand height where the dig zone meets the outer desert
	EdgeFalloff = 26, -- studs over which dunes taper down to the edge (no walls!)
	NoiseScale = 0.022,
	BedrockThickness = 6,
	CampY = 4, -- ground height of the base camp (south of the dig zone)
	CampDepth = 52, -- how far south of the dig zone the camp extends
	WorldRadius = 320, -- outer decorative dunes (not diggable) extend this far
	ClearedThreshold = 0.995, -- "every grain" threshold (99.5% counts as fully cleared)
	RemnantThreshold = 0.2, -- leftover voxel occupancy that gets swept automatically
	RegenDelay = 12, -- seconds after clearing before fresh sand is delivered
	ClearBonusBase = 2000,
	ClearBonusPerKg = 0.35,
}

--------------------------------------------------------------------------
-- ECONOMY
--------------------------------------------------------------------------
GameConfig.Economy = {
	SandDensity = 0.08, -- kg per cubic stud of removed sand
	BaseSellPrice = 1.0, -- $ per kg
	StartingCash = 0,
	SellCooldown = 0.6,
	DuplicateFindMultiplier = 0.35, -- re-finding an already-journaled relic
	MinServerCooldown = 0.06,
	CooldownTolerance = 0.8, -- server accepts digs at 80% of cooldown (latency jitter)
	RangeTolerance = 5,
	BaseWalkSpeed = 16,
	AutosaveInterval = 90,
}

--------------------------------------------------------------------------
-- TOOLS (ordered by tier)
-- Mode: "Click" = one dig per click, "Hold" = repeats while held, "Stream" = continuous suction
--------------------------------------------------------------------------
GameConfig.Tools = {
	{
		Id = "Hands",
		Name = "Bare Hands",
		Short = "Hands",
		Tier = 1,
		Price = 0,
		Radius = 1.4,
		Cooldown = 0.55,
		Range = 11,
		Mode = "Click",
		Shake = 0.04,
		Accent = Color3.fromRGB(234, 184, 146),
		Description = "Day one. Just you, your palms and a whole lot of sand.",
	},
	{
		Id = "Spoon",
		Name = "Rusty Spoon",
		Short = "Spoon",
		Tier = 2,
		Price = 40,
		Radius = 1.8,
		Cooldown = 0.45,
		Range = 14,
		Mode = "Click",
		Shake = 0.05,
		Accent = Color3.fromRGB(190, 196, 204),
		Description = "Finally, a utensil! One heroic spoonful at a time.",
	},
	{
		Id = "Shovel",
		Name = "Trusty Shovel",
		Short = "Shovel",
		Tier = 3,
		Price = 250,
		Radius = 3.2,
		Cooldown = 0.35,
		Range = 14,
		Mode = "Hold",
		Shake = 0.12,
		Accent = Color3.fromRGB(150, 102, 62),
		Description = "A proper tool. Click or hold to keep scooping.",
	},
	{
		Id = "HandVac",
		Name = "Hand Vacuum",
		Short = "Vac",
		Tier = 4,
		Price = 2500,
		Radius = 3.8,
		Cooldown = 0.12,
		Range = 16,
		Mode = "Stream",
		Shake = 0.03,
		Accent = Color3.fromRGB(196, 96, 62),
		Description = "Hold to suck a steady stream of sand straight into the tank.",
	},
	{
		Id = "TurbineVac",
		Name = "Turbine Vacuum",
		Short = "Turbo",
		Tier = 5,
		Price = 15000,
		Radius = 6.0,
		Cooldown = 0.08,
		Range = 20,
		Mode = "Stream",
		Shake = 0.07,
		Accent = Color3.fromRGB(240, 190, 60),
		Description = "Industrial jet turbine. The desert fears this machine.",
	},
}

--------------------------------------------------------------------------
-- BAGS / TANKS (ordered by tier, must be bought in order)
--------------------------------------------------------------------------
GameConfig.Bags = {
	{ Tier = 1, Name = "Pocket Pouch", Capacity = 15, Price = 0, Icon = "👝", Description = "Holds a few spoonfuls. Barely." },
	{ Tier = 2, Name = "Canvas Sack", Capacity = 40, Price = 100, Icon = "🛍", Description = "A sturdy sack with a drawstring." },
	{ Tier = 3, Name = "Burlap Bag", Capacity = 100, Price = 450, Icon = "🎒", Description = "Smells like coffee beans. Holds a lot." },
	{ Tier = 4, Name = "Duffel Hauler", Capacity = 250, Price = 1500, Icon = "💼", Description = "Double-stitched for serious hauling." },
	{ Tier = 5, Name = "Steel Tank", Capacity = 600, Price = 5000, Icon = "🛢", Description = "A pressurized tank for vacuum work." },
	{ Tier = 6, Name = "Industrial Tank", Capacity = 1500, Price = 16000, Icon = "🏭", Description = "Rated for an entire dune." },
	{ Tier = 7, Name = "Silo Pack", Capacity = 4000, Price = 45000, Icon = "🗼", Description = "Basically a grain silo on your back." },
}

--------------------------------------------------------------------------
-- SKILL TREE (passive upgrades, each a linear branch from the root)
--------------------------------------------------------------------------
GameConfig.SkillRoot = {
	Name = "Digger's Instinct",
	Description = "The root of all digging wisdom. Every branch grows from here.",
}

GameConfig.Skills = {
	{
		Id = "DigSpeed",
		Name = "Dig Speed",
		Icon = "⚡",
		Color = Color3.fromRGB(132, 190, 220),
		MaxLevel = 6,
		BaseCost = 200,
		CostGrowth = 1.9,
		PerLevel = 0.07, -- -7% tool cooldown per level
		Description = "Dig and vacuum faster. Reduces tool cooldown.",
	},
	{
		Id = "DigRadius",
		Name = "Dig Radius",
		Icon = "◎",
		Color = Color3.fromRGB(214, 152, 72),
		MaxLevel = 6,
		BaseCost = 300,
		CostGrowth = 2.0,
		PerLevel = 0.05, -- +5% radius per level
		Description = "Every scoop and suck reaches further.",
	},
	{
		Id = "SandValue",
		Name = "Sand Value",
		Icon = "$",
		Color = Color3.fromRGB(132, 168, 104),
		MaxLevel = 8,
		BaseCost = 250,
		CostGrowth = 1.75,
		PerLevel = 0.2, -- +20% sell value per level
		Description = "Blow finer glass at the furnace. Sand sells for more.",
	},
	{
		Id = "WalkSpeed",
		Name = "Walk Speed",
		Icon = "➜",
		Color = Color3.fromRGB(196, 96, 62),
		MaxLevel = 5,
		BaseCost = 150,
		CostGrowth = 1.8,
		PerLevel = 2, -- +2 walk speed per level
		Description = "Comfy boots. Shorter trips to the scale.",
	},
}

--------------------------------------------------------------------------
-- BURIED FINDS (14 relics). Depth = studs below the local sand surface.
--------------------------------------------------------------------------
GameConfig.Rarities = {
	Common = Color3.fromRGB(150, 130, 110),
	Uncommon = Color3.fromRGB(110, 160, 90),
	Rare = Color3.fromRGB(80, 150, 210),
	Epic = Color3.fromRGB(170, 100, 200),
	Legendary = Color3.fromRGB(236, 168, 40),
}

GameConfig.Finds = {
	{ Id = "PocketWatch", Name = "Rusty Pocket Watch", Rarity = "Common", Bonus = 120, DepthMin = 3.6, DepthMax = 6, Description = "Stopped at 4:17. Somebody was late for something." },
	{ Id = "AncientCoin", Name = "Ancient Coin", Rarity = "Common", Bonus = 150, DepthMin = 3.6, DepthMax = 6.5, Description = "Square-holed bronze coin, worn smooth by the wind." },
	{ Id = "GlassBottle", Name = "Message Bottle", Rarity = "Common", Bonus = 180, DepthMin = 4, DepthMax = 7, Description = "Blue glass with a rolled note inside. It just says 'hi'." },
	{ Id = "Sunglasses", Name = "Lost Sunglasses", Rarity = "Common", Bonus = 200, DepthMin = 3.6, DepthMax = 6, Description = "Tortoiseshell frames. Still very cool." },
	{ Id = "ToyRobot", Name = "Tin Toy Robot", Rarity = "Uncommon", Bonus = 260, DepthMin = 5, DepthMax = 8, Description = "Wind-up key is missing, but its eyes still glow." },
	{ Id = "Amphora", Name = "Clay Amphora", Rarity = "Uncommon", Bonus = 350, DepthMin = 6, DepthMax = 9, Description = "A two-handled clay jar. Once held olive oil, now holds sand." },
	{ Id = "DesertRose", Name = "Desert Rose", Rarity = "Uncommon", Bonus = 420, DepthMin = 6, DepthMax = 10, Description = "Gypsum crystals that bloomed like petals over centuries." },
	{ Id = "GoldRing", Name = "Ruby Gold Ring", Rarity = "Rare", Bonus = 600, DepthMin = 7, DepthMax = 11, Description = "Engraved inside: 'forever & a day'." },
	{ Id = "BrassCompass", Name = "Brass Compass", Rarity = "Rare", Bonus = 750, DepthMin = 8, DepthMax = 11.5, Description = "The needle still points somewhere. Probably north." },
	{ Id = "Ammonite", Name = "Ammonite Fossil", Rarity = "Rare", Bonus = 900, DepthMin = 9, DepthMax = 12.5, Description = "This desert was a sea, once. Proof in a spiral." },
	{ Id = "Harmonica", Name = "Old Harmonica", Rarity = "Epic", Bonus = 1100, DepthMin = 9, DepthMax = 13, Description = "Blow gently and it plays a dusty, lonesome note." },
	{ Id = "Scarab", Name = "Scarab Amulet", Rarity = "Epic", Bonus = 1500, DepthMin = 10, DepthMax = 13.5, Description = "Turquoise beetle set in gold. Feels oddly warm." },
	{ Id = "DinoSkull", Name = "Raptor Skull", Rarity = "Epic", Bonus = 2500, DepthMin = 11, DepthMax = 14, Description = "A toothy fossil grin, buried for 70 million years." },
	{ Id = "GoldenIdol", Name = "Golden Idol", Rarity = "Legendary", Bonus = 5000, DepthMin = 12, DepthMax = 14.4, Description = "The legend of the lot. Heavy, gleaming, priceless." },
}

--------------------------------------------------------------------------
-- SOUNDS (Roblox built-in engine sounds only - no uploaded assets)
--------------------------------------------------------------------------
GameConfig.Sounds = {
	Dig = "rbxasset://sounds/action_footsteps_plastic.mp3",
	Scoop = "rbxasset://sounds/action_jump_land.mp3",
	Swing = "rbxasset://sounds/swoosh.wav",
	VacuumLoop = "rbxasset://sounds/action_falling.mp3",
	Sell = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/button.wav",
	Error = "rbxasset://sounds/action_get_up.mp3",
	Chime = "rbxasset://sounds/electronicpingshort.wav",
	Splash = "rbxasset://sounds/impact_water.mp3",
}

--------------------------------------------------------------------------
-- LOOKUPS
--------------------------------------------------------------------------
local toolsById, skillsById, findsById = {}, {}, {}
for index, tool in ipairs(GameConfig.Tools) do
	tool.Index = index
	toolsById[tool.Id] = tool
end
for index, skill in ipairs(GameConfig.Skills) do
	skill.Index = index
	skillsById[skill.Id] = skill
end
for index, find in ipairs(GameConfig.Finds) do
	find.Index = index
	findsById[find.Id] = find
end

function GameConfig.GetTool(id)
	return toolsById[id]
end

function GameConfig.GetBag(tier)
	return GameConfig.Bags[tier]
end

function GameConfig.GetSkill(id)
	return skillsById[id]
end

function GameConfig.GetFind(id)
	return findsById[id]
end

local function roundNice(value)
	if value < 100 then
		return math.floor(value / 5 + 0.5) * 5
	elseif value < 1000 then
		return math.floor(value / 10 + 0.5) * 10
	elseif value < 10000 then
		return math.floor(value / 50 + 0.5) * 50
	end
	return math.floor(value / 100 + 0.5) * 100
end

-- Cost to go from `level` to `level + 1`
function GameConfig.GetSkillCost(id, level)
	local skill = skillsById[id]
	if not skill or level >= skill.MaxLevel then
		return nil
	end
	return roundNice(skill.BaseCost * (skill.CostGrowth ^ level))
end

-- Human readable effect of a skill at a given level
function GameConfig.DescribeSkillEffect(id, level)
	local skill = skillsById[id]
	if not skill then
		return ""
	end
	if id == "DigSpeed" then
		return string.format("-%d%% cooldown", math.floor(skill.PerLevel * level * 100 + 0.5))
	elseif id == "DigRadius" then
		return string.format("+%d%% radius", math.floor(skill.PerLevel * level * 100 + 0.5))
	elseif id == "SandValue" then
		return string.format("x%.1f sell value", 1 + skill.PerLevel * level)
	elseif id == "WalkSpeed" then
		return string.format("%d walk speed", GameConfig.Economy.BaseWalkSpeed + skill.PerLevel * level)
	end
	return ""
end

-- Derived stats from a player's data table (identical on server & client)
function GameConfig.ComputeStats(data)
	local tool = toolsById[data.EquippedTool] or GameConfig.Tools[1]
	local bag = GameConfig.Bags[data.BagTier] or GameConfig.Bags[1]
	local skills = data.Skills or {}

	local speedLevel = math.clamp(skills.DigSpeed or 0, 0, skillsById.DigSpeed.MaxLevel)
	local radiusLevel = math.clamp(skills.DigRadius or 0, 0, skillsById.DigRadius.MaxLevel)
	local valueLevel = math.clamp(skills.SandValue or 0, 0, skillsById.SandValue.MaxLevel)
	local walkLevel = math.clamp(skills.WalkSpeed or 0, 0, skillsById.WalkSpeed.MaxLevel)

	local cooldown = tool.Cooldown * (1 - skillsById.DigSpeed.PerLevel * speedLevel)
	cooldown = math.max(cooldown, GameConfig.Economy.MinServerCooldown)

	return {
		ToolId = tool.Id,
		Mode = tool.Mode,
		Radius = tool.Radius * (1 + skillsById.DigRadius.PerLevel * radiusLevel),
		Cooldown = cooldown,
		Range = tool.Range,
		Capacity = bag.Capacity,
		ValueMultiplier = 1 + skillsById.SandValue.PerLevel * valueLevel,
		WalkSpeed = GameConfig.Economy.BaseWalkSpeed + skillsById.WalkSpeed.PerLevel * walkLevel,
		SellPrice = GameConfig.Economy.BaseSellPrice,
	}
end

-- Default save data (DataService deep-copies & reconciles against this)
GameConfig.DefaultData = {
	Version = 1,
	Cash = GameConfig.Economy.StartingCash,
	BagKg = 0,
	OwnedTools = { Hands = true },
	EquippedTool = "Hands",
	BagTier = 1,
	Skills = { DigSpeed = 0, DigRadius = 0, SandValue = 0, WalkSpeed = 0 },
	Finds = {},
	Stats = { TotalKg = 0, TotalEarned = 0, LotsCleared = 0, FindsCollected = 0 },
}

return GameConfig
]======]

-- ModuleScript: ReplicatedStorage/Sandsweep/Util.lua
created["Util"] = make("ModuleScript", "Util", Containers.RS)
created["Util"].Source = [======[
-- Util (ModuleScript) - ReplicatedStorage/Sandsweep/Util
-- Small shared helpers: number formatting, table copy, vector validation.

local Util = {}

function Util.Commas(number)
	local negative = number < 0
	local formatted = tostring(math.floor(math.abs(number)))
	while true do
		local replaced, count = string.gsub(formatted, "^(%d+)(%d%d%d)", "%1,%2")
		formatted = replaced
		if count == 0 then
			break
		end
	end
	return (negative and "-" or "") .. formatted
end

function Util.FormatCash(number)
	number = math.floor(number + 0.5)
	if number >= 1e9 then
		return string.format("$%.2fB", number / 1e9)
	elseif number >= 1e7 then
		return string.format("$%.2fM", number / 1e6)
	end
	return "$" .. Util.Commas(number)
end

function Util.FormatKg(number)
	if number >= 10000 then
		return Util.Commas(number)
	end
	return string.format("%.1f", number)
end

function Util.FormatPercent(fraction)
	return string.format("%.1f%%", math.clamp(fraction, 0, 1) * 100)
end

function Util.DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in pairs(value) do
		copy[key] = Util.DeepCopy(inner)
	end
	return copy
end

-- Fill in missing keys from template (recursively), keeping existing values.
function Util.Reconcile(target, template)
	for key, inner in pairs(template) do
		if target[key] == nil then
			target[key] = Util.DeepCopy(inner)
		elseif type(inner) == "table" and type(target[key]) == "table" then
			Util.Reconcile(target[key], inner)
		end
	end
	return target
end

function Util.CountKeys(dictionary)
	local count = 0
	for _ in pairs(dictionary) do
		count += 1
	end
	return count
end

local function isFiniteNumber(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function Util.IsFiniteVector(v)
	return typeof(v) == "Vector3" and isFiniteNumber(v.X) and isFiniteNumber(v.Y) and isFiniteNumber(v.Z)
end

function Util.Lerp(a, b, t)
	return a + (b - a) * t
end

return Util
]======]

-- ModuleScript: ReplicatedStorage/Sandsweep/PartKit.lua
created["PartKit"] = make("ModuleScript", "PartKit", Containers.RS)
created["PartKit"].Source = [======[
-- PartKit (ModuleScript) - ReplicatedStorage/Sandsweep/PartKit
-- Tiny procedural-geometry toolkit used by the tool, relic and world builders.

local PartKit = {}

local DEFAULTS = {
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	CastShadow = true,
	Material = Enum.Material.SmoothPlastic,
	Color = Color3.fromRGB(200, 200, 200),
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
}

local SPECIAL = {
	ClassName = true,
	Mesh = true,
	MeshScale = true,
	Parent = true,
}

-- PartKit.Part(parent, { Size=, CFrame=, Color=, Material=, Shape=, Mesh=, ... })
function PartKit.Part(parent, props)
	local part = Instance.new(props.ClassName or "Part")
	for key, value in pairs(DEFAULTS) do
		part[key] = value
	end
	for key, value in pairs(props) do
		if not SPECIAL[key] then
			part[key] = value
		end
	end
	if props.Mesh then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = props.Mesh
		mesh.Scale = props.MeshScale or Vector3.one
		mesh.Parent = part
	end
	part.Parent = parent
	return part
end

-- Cylinder whose length runs along the given local axis ("X", "Y" or "Z").
function PartKit.Cylinder(parent, length, diameter, cframe, axis, props)
	props = props or {}
	local rotation = CFrame.identity
	if axis == "Y" then
		rotation = CFrame.Angles(0, 0, math.rad(90))
	elseif axis == "Z" then
		rotation = CFrame.Angles(0, math.rad(90), 0)
	end
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(length, diameter, diameter)
	props.CFrame = cframe * rotation
	return PartKit.Part(parent, props)
end

-- Ellipsoid (sphere mesh stretched to `size`).
function PartKit.Ellipsoid(parent, size, cframe, props)
	props = props or {}
	props.Size = size
	props.CFrame = cframe
	props.Mesh = Enum.MeshType.Sphere
	return PartKit.Part(parent, props)
end

function PartKit.Ball(parent, diameter, cframe, props)
	props = props or {}
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(diameter, diameter, diameter)
	props.CFrame = cframe
	return PartKit.Part(parent, props)
end

-- Make a model ready for use. anchored=false welds all parts to the primary part.
-- The model's pivot is the origin it was designed around (not the primary part's own frame).
function PartKit.Finalize(model, primaryPart, anchored)
	model.PrimaryPart = primaryPart
	primaryPart.PivotOffset = primaryPart.CFrame:Inverse()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
			descendant.Massless = true
			if not anchored and descendant ~= primaryPart then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primaryPart
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
	return model
end

function PartKit.SetCollision(model, canCollide, canQuery, canTouch)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = canCollide
			descendant.CanQuery = canQuery
			descendant.CanTouch = canTouch
		end
	end
end

function PartKit.SetCastShadow(model, castShadow)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CastShadow = castShadow
		end
	end
end

return PartKit
]======]

-- ModuleScript: ReplicatedStorage/Sandsweep/ToolModels.lua
created["ToolModels"] = make("ModuleScript", "ToolModels", Containers.RS)
created["ToolModels"].Source = [======[
-- ToolModels (ModuleScript) - ReplicatedStorage/Sandsweep/ToolModels
-- Procedural models for the 4 digging tools. Tools point along -Z.
-- Every model has PrimaryPart "Handle", an Attachment "Tip" at the business end,
-- optional "SandFill" part (fill gauge) and optional "Fan" folder (spinning blades).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PartKit = require(ReplicatedStorage:WaitForChild("Sandsweep"):WaitForChild("PartKit"))

local ToolModels = {}

local METAL = Enum.Material.Metal
local WOOD = Enum.Material.Wood
local GLASS = Enum.Material.Glass
local NEON = Enum.Material.Neon

local SAND = Color3.fromRGB(232, 196, 128)

-- First-person placement relative to the camera
ToolModels.ViewOffsets = {
	Hands = CFrame.new(0, -1.15, -2.0) * CFrame.Angles(math.rad(18), 0, 0),
	Spoon = CFrame.new(0.85, -0.8, -1.7) * CFrame.Angles(math.rad(10), math.rad(-10), math.rad(-4)),
	Shovel = CFrame.new(1.05, -1.15, -1.6) * CFrame.Angles(math.rad(14), math.rad(-10), math.rad(-8)),
	HandVac = CFrame.new(0.95, -0.95, -1.7) * CFrame.Angles(math.rad(6), math.rad(-7), 0),
	TurbineVac = CFrame.new(1.15, -1.35, -2.5) * CFrame.Angles(math.rad(5), math.rad(-6), 0),
}

-- Grip point (tool space) that sits in the character's hand
ToolModels.Grips = {
	Hands = Vector3.new(0, 0, 0),
	Spoon = Vector3.new(0, 0, 0.45),
	Shovel = Vector3.new(0, 0, 1.15),
	HandVac = Vector3.new(0, 0.55, 0.4),
	TurbineVac = Vector3.new(0.8, 0, 0.2),
}

-- First-person hands: where each hand grips the tool (tool space) and which arm it is
ToolModels.Hands = {
	Hands = {
		{ Position = Vector3.new(0.34, -0.05, -0.45), Side = "Right", Cupped = true },
		{ Position = Vector3.new(-0.34, -0.05, -0.45), Side = "Left", Cupped = true },
	},
	Spoon = { { Position = Vector3.new(0, 0, 0.5), Side = "Right" } },
	Shovel = { { Position = Vector3.new(0, 0, 1.3), Side = "Right" }, { Position = Vector3.new(0, 0, -0.55), Side = "Left" } },
	HandVac = { { Position = Vector3.new(0, 0.58, 0.45), Side = "Right" } },
	TurbineVac = { { Position = Vector3.new(0.82, 0, 0.25), Side = "Right" }, { Position = Vector3.new(-0.2, 0.8, 0.6), Side = "Left" } },
}

local function addTip(handle, position)
	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = position
	tip.Parent = handle
	return tip
end

local builders = {}

-- Bare hands: the visible palms are added by the first-person viewmodel;
-- the model only carries an invisible handle, the sand scoop and the tip.
builders.Hands = function(model)
	local handle = PartKit.Part(model, {
		Name = "Handle",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(0, 0, 0),
		Transparency = 1,
		CastShadow = false,
	})
	PartKit.Ellipsoid(model, Vector3.new(0.7, 0.32, 0.6), CFrame.new(0, 0.12, -0.5), {
		Name = "SandScoop",
		Color = SAND,
		Material = Enum.Material.Sand,
		Transparency = 1,
	})
	addTip(handle, Vector3.new(0, 0, -0.9))
	return handle
end

builders.Spoon = function(model)
	local silver = Color3.fromRGB(196, 200, 208)
	local handle = PartKit.Part(model, {
		Name = "Handle",
		Size = Vector3.new(0.2, 0.07, 1.25),
		CFrame = CFrame.new(0, 0, 0.1),
		Material = METAL,
		Color = silver,
	})
	PartKit.Part(model, {
		Name = "Rust",
		Size = Vector3.new(0.22, 0.08, 0.3),
		CFrame = CFrame.new(0, 0, 0.62),
		Material = Enum.Material.CorrodedMetal,
		Color = Color3.fromRGB(176, 104, 64),
	})
	PartKit.Part(model, {
		Name = "Neck",
		Size = Vector3.new(0.12, 0.06, 0.45),
		CFrame = CFrame.new(0, 0.03, -0.72) * CFrame.Angles(math.rad(-8), 0, 0),
		Material = METAL,
		Color = silver,
	})
	PartKit.Ellipsoid(model, Vector3.new(0.55, 0.16, 0.75), CFrame.new(0, 0.06, -1.25), {
		Name = "Bowl",
		Material = METAL,
		Color = silver,
	})
	PartKit.Ellipsoid(model, Vector3.new(0.42, 0.1, 0.55), CFrame.new(0, 0.12, -1.25), {
		Name = "SandScoop",
		Color = SAND,
		Material = Enum.Material.Sand,
	})
	addTip(handle, Vector3.new(0, 0.05, -1.55))
	return handle
end

builders.Shovel = function(model)
	local woodColor = Color3.fromRGB(156, 106, 64)
	local steel = Color3.fromRGB(150, 156, 164)
	local handle = PartKit.Cylinder(model, 2.7, 0.2, CFrame.new(0, 0, 0), "Z", {
		Name = "Handle",
		Material = WOOD,
		Color = woodColor,
	})
	-- D-grip
	PartKit.Cylinder(model, 0.55, 0.14, CFrame.new(0, 0, 1.6), "X", { Name = "GripBar", Material = WOOD, Color = woodColor })
	PartKit.Part(model, {
		Name = "GripL",
		Size = Vector3.new(0.08, 0.08, 0.4),
		CFrame = CFrame.new(-0.22, 0, 1.42) * CFrame.Angles(0, math.rad(-25), 0),
		Material = METAL,
		Color = steel,
	})
	PartKit.Part(model, {
		Name = "GripR",
		Size = Vector3.new(0.08, 0.08, 0.4),
		CFrame = CFrame.new(0.22, 0, 1.42) * CFrame.Angles(0, math.rad(25), 0),
		Material = METAL,
		Color = steel,
	})
	PartKit.Cylinder(model, 0.45, 0.27, CFrame.new(0, 0, -1.45), "Z", { Name = "Collar", Material = METAL, Color = steel })
	PartKit.Part(model, {
		Name = "Blade",
		Size = Vector3.new(0.95, 0.07, 1.05),
		CFrame = CFrame.new(0, -0.02, -2.15),
		Material = METAL,
		Color = steel,
	})
	PartKit.Part(model, {
		Name = "BladeTip",
		Size = Vector3.new(0.67, 0.07, 0.67),
		CFrame = CFrame.new(0, -0.02, -2.62) * CFrame.Angles(0, math.rad(45), 0),
		Material = METAL,
		Color = steel,
	})
	PartKit.Part(model, {
		Name = "LipL",
		Size = Vector3.new(0.06, 0.16, 1.0),
		CFrame = CFrame.new(-0.46, 0.05, -2.12),
		Material = METAL,
		Color = steel,
	})
	PartKit.Part(model, {
		Name = "LipR",
		Size = Vector3.new(0.06, 0.16, 1.0),
		CFrame = CFrame.new(0.46, 0.05, -2.12),
		Material = METAL,
		Color = steel,
	})
	PartKit.Ellipsoid(model, Vector3.new(0.7, 0.18, 0.8), CFrame.new(0, 0.06, -2.2), {
		Name = "SandScoop",
		Color = SAND,
		Material = Enum.Material.Sand,
	})
	addTip(handle, Vector3.new(0, 0, -2.9))
	return handle
end

builders.HandVac = function(model)
	local body = Color3.fromRGB(214, 110, 70)
	local dark = Color3.fromRGB(62, 52, 46)
	local steel = Color3.fromRGB(170, 174, 180)
	local handle = PartKit.Part(model, {
		Name = "Handle",
		Size = Vector3.new(0.7, 0.66, 1.1),
		CFrame = CFrame.new(0, 0, 0.35),
		Color = body,
	})
	PartKit.Part(model, { Name = "Grip", Size = Vector3.new(0.24, 0.26, 0.95), CFrame = CFrame.new(0, 0.58, 0.45), Color = dark })
	PartKit.Part(model, { Name = "GripPostF", Size = Vector3.new(0.2, 0.32, 0.18), CFrame = CFrame.new(0, 0.38, 0.05), Color = dark })
	PartKit.Part(model, { Name = "GripPostB", Size = Vector3.new(0.2, 0.32, 0.18), CFrame = CFrame.new(0, 0.38, 0.85), Color = dark })
	PartKit.Cylinder(model, 0.95, 0.8, CFrame.new(0, 0, -0.55), "Z", {
		Name = "Canister",
		Material = GLASS,
		Transparency = 0.55,
		Color = Color3.fromRGB(240, 232, 214),
		CastShadow = false,
	})
	PartKit.Cylinder(model, 0.9, 0.62, CFrame.new(0, -0.06, -0.55), "Z", {
		Name = "SandFill",
		Material = Enum.Material.Sand,
		Color = SAND,
	}):SetAttribute("FillAxis", "X")
	PartKit.Cylinder(model, 0.1, 0.86, CFrame.new(0, 0, -1.04), "Z", { Name = "CapRing", Color = dark })
	PartKit.Cylinder(model, 1.25, 0.34, CFrame.new(0, -0.06, -1.7), "Z", { Name = "Nozzle", Material = METAL, Color = steel })
	PartKit.Cylinder(model, 0.14, 0.48, CFrame.new(0, -0.06, -2.3), "Z", { Name = "Mouth", Color = dark })
	PartKit.Part(model, {
		Name = "Glow",
		Size = Vector3.new(0.04, 0.1, 0.6),
		CFrame = CFrame.new(0.36, 0.12, 0.35),
		Material = NEON,
		Color = Color3.fromRGB(132, 200, 230),
		CastShadow = false,
	})
	PartKit.Part(model, { Name = "Vent", Size = Vector3.new(0.5, 0.06, 0.3), CFrame = CFrame.new(0, 0.34, 0.75), Color = dark })
	addTip(handle, Vector3.new(0, -0.06, -2.75))
	return handle
end

builders.TurbineVac = function(model)
	local yellow = Color3.fromRGB(240, 190, 60)
	local dark = Color3.fromRGB(64, 62, 66)
	local steel = Color3.fromRGB(160, 164, 170)
	local handle = PartKit.Cylinder(model, 1.25, 1.3, CFrame.new(0, 0, 0.2), "Z", {
		Name = "Handle",
		Color = yellow,
	})
	PartKit.Cylinder(model, 0.12, 1.38, CFrame.new(0, 0, -0.32), "Z", { Name = "BandF", Color = dark })
	PartKit.Cylinder(model, 0.12, 1.38, CFrame.new(0, 0, 0.62), "Z", { Name = "BandB", Color = dark })
	PartKit.Cylinder(model, 0.07, 1.36, CFrame.new(0, 0, -0.44), "Z", {
		Name = "NeonRing",
		Material = NEON,
		Color = Color3.fromRGB(120, 200, 240),
		CastShadow = false,
	})
	-- hazard stripes on top
	for index = 0, 3 do
		PartKit.Part(model, {
			Name = "Stripe",
			Size = Vector3.new(0.5, 0.05, 0.12),
			CFrame = CFrame.new(0, 0.66, -0.15 + index * 0.25) * CFrame.Angles(0, math.rad(35), 0),
			Color = dark,
		})
	end
	-- turbine housing at the back (faces the camera) with spinning fan
	PartKit.Cylinder(model, 0.4, 1.5, CFrame.new(0, 0, 1.0), "Z", { Name = "Housing", Material = METAL, Color = dark })
	local fan = Instance.new("Folder")
	fan.Name = "Fan"
	fan.Parent = model
	local hub = PartKit.Cylinder(fan, 0.12, 0.34, CFrame.new(0, 0, 1.23), "Z", { Name = "FanHub", Material = METAL, Color = steel })
	hub:SetAttribute("FanHub", true)
	for index = 0, 5 do
		PartKit.Part(fan, {
			Name = "Blade",
			Size = Vector3.new(0.14, 0.62, 0.04),
			CFrame = CFrame.new(0, 0, 1.22) * CFrame.Angles(0, 0, math.rad(index * 60)) * CFrame.new(0, 0.34, 0) * CFrame.Angles(0, math.rad(25), 0),
			Material = METAL,
			Color = steel,
		})
	end
	-- sand window on top
	PartKit.Part(model, {
		Name = "Window",
		Size = Vector3.new(0.4, 0.14, 1.0),
		CFrame = CFrame.new(-0.42, 0.55, 0.15) * CFrame.Angles(0, 0, math.rad(40)),
		Material = GLASS,
		Transparency = 0.5,
		Color = Color3.fromRGB(240, 232, 214),
		CastShadow = false,
	})
	PartKit.Part(model, {
		Name = "SandFill",
		Size = Vector3.new(0.32, 0.1, 0.94),
		CFrame = CFrame.new(-0.4, 0.53, 0.15) * CFrame.Angles(0, 0, math.rad(40)),
		Material = Enum.Material.Sand,
		Color = SAND,
	}):SetAttribute("FillAxis", "Z")
	-- nozzle
	PartKit.Cylinder(model, 1.5, 0.62, CFrame.new(0, -0.12, -1.15), "Z", { Name = "Nozzle", Material = METAL, Color = steel })
	PartKit.Cylinder(model, 0.28, 0.95, CFrame.new(0, -0.12, -2.0), "Z", { Name = "Mouth", Color = Color3.fromRGB(214, 110, 70) })
	PartKit.Cylinder(model, 0.06, 1.0, CFrame.new(0, -0.12, -2.16), "Z", { Name = "MouthLip", Color = dark })
	-- side grips
	PartKit.Part(model, { Name = "SideGrip", Size = Vector3.new(0.22, 0.22, 0.9), CFrame = CFrame.new(0.8, 0, 0.2), Color = dark })
	PartKit.Part(model, { Name = "SideGripTop", Size = Vector3.new(0.9, 0.18, 0.22), CFrame = CFrame.new(0, 0.78, 0.6), Color = dark })
	addTip(handle, Vector3.new(0, -0.12, -2.25))
	return handle
end

-- Build a tool model. anchored=true for viewmodels/displays, false for welding to a character.
function ToolModels.Build(toolId, anchored)
	local builder = builders[toolId] or builders.Spoon
	local model = Instance.new("Model")
	model.Name = toolId
	local handle = builder(model)
	PartKit.Finalize(model, handle, anchored)
	model:SetAttribute("ToolId", toolId)
	return model
end

return ToolModels
]======]

-- ModuleScript: ReplicatedStorage/Sandsweep/FindModels.lua
created["FindModels"] = make("ModuleScript", "FindModels", Containers.RS)
created["FindModels"].Source = [======[
-- FindModels (ModuleScript) - ReplicatedStorage/Sandsweep/FindModels
-- Procedural models for the 14 buried relics. Used by the server (world) and
-- the client (journal / celebration ViewportFrames). PrimaryPart is "Core".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PartKit = require(ReplicatedStorage:WaitForChild("Sandsweep"):WaitForChild("PartKit"))

local FindModels = {}

local P = PartKit.Part
local Cyl = PartKit.Cylinder
local Ell = PartKit.Ellipsoid
local Ball = PartKit.Ball

local METAL = Enum.Material.Metal
local SMOOTH = Enum.Material.SmoothPlastic
local GLASS = Enum.Material.Glass
local NEON = Enum.Material.Neon
local FOIL = Enum.Material.Foil

local GOLD = Color3.fromRGB(236, 186, 64)
local DARK = Color3.fromRGB(56, 44, 36)

local builders = {}

builders.PocketWatch = function(m)
	local rust = Color3.fromRGB(184, 128, 62)
	local core = Cyl(m, 0.3, 1.5, CFrame.new(0, 0, 0), "Y", { Name = "Core", Material = Enum.Material.CorrodedMetal, Color = rust })
	Cyl(m, 0.32, 1.22, CFrame.new(0, 0.01, 0), "Y", { Material = SMOOTH, Color = Color3.fromRGB(246, 236, 212) })
	Cyl(m, 0.34, 1.08, CFrame.new(0, 0.02, 0), "Y", { Material = GLASS, Transparency = 0.6, Color = Color3.fromRGB(220, 235, 240) })
	P(m, { Size = Vector3.new(0.06, 0.04, 0.42), CFrame = CFrame.new(0, 0.18, -0.16), Color = DARK })
	P(m, { Size = Vector3.new(0.3, 0.04, 0.06), CFrame = CFrame.new(0.12, 0.18, 0) * CFrame.Angles(0, math.rad(30), 0), Color = DARK })
	for i = 0, 11 do
		local a = math.rad(i * 30)
		P(m, { Size = Vector3.new(0.04, 0.03, 0.1), CFrame = CFrame.new(math.sin(a) * 0.48, 0.17, math.cos(a) * 0.48) * CFrame.Angles(0, a, 0), Color = DARK })
	end
	Cyl(m, 0.22, 0.24, CFrame.new(0, 0, -0.84), "Z", { Material = METAL, Color = rust })
	for i = 0, 7 do
		local a = math.rad(i * 45)
		P(m, { Size = Vector3.new(0.08, 0.08, 0.12), CFrame = CFrame.new(math.sin(a) * 0.2, math.cos(a) * 0.2, -1.12) * CFrame.Angles(0, 0, -a), Material = METAL, Color = GOLD })
	end
	return core
end

builders.AncientCoin = function(m)
	local bronze = Color3.fromRGB(200, 146, 70)
	local core = Cyl(m, 0.2, 1.7, CFrame.new(0, 0, 0), "Y", { Name = "Core", Material = FOIL, Color = bronze })
	Cyl(m, 0.24, 1.25, CFrame.new(0, 0, 0), "Y", { Material = METAL, Color = Color3.fromRGB(170, 120, 56) })
	P(m, { Size = Vector3.new(0.36, 0.3, 0.36), CFrame = CFrame.new(0, 0, 0), Color = DARK })
	for i = 0, 3 do
		local a = math.rad(i * 90 + 45)
		P(m, { Size = Vector3.new(0.18, 0.27, 0.08), CFrame = CFrame.new(math.sin(a) * 0.42, 0, math.cos(a) * 0.42) * CFrame.Angles(0, a, 0), Material = FOIL, Color = GOLD })
	end
	return core
end

builders.GlassBottle = function(m)
	local blue = Color3.fromRGB(90, 160, 205)
	local core = Cyl(m, 1.8, 0.85, CFrame.new(0, 0, 0), "X", { Name = "Core", Material = GLASS, Transparency = 0.35, Color = blue })
	Cyl(m, 0.3, 0.55, CFrame.new(1.02, 0, 0), "X", { Material = GLASS, Transparency = 0.35, Color = blue })
	Cyl(m, 0.55, 0.36, CFrame.new(1.4, 0, 0), "X", { Material = GLASS, Transparency = 0.3, Color = blue })
	Cyl(m, 0.25, 0.3, CFrame.new(1.74, 0, 0), "X", { Material = Enum.Material.Wood, Color = Color3.fromRGB(150, 104, 62) })
	Cyl(m, 1.1, 0.32, CFrame.new(-0.1, -0.12, 0), "X", { Color = Color3.fromRGB(246, 232, 200) })
	Cyl(m, 0.12, 0.34, CFrame.new(-0.1, -0.12, 0), "X", { Color = Color3.fromRGB(196, 96, 62) })
	return core
end

builders.Sunglasses = function(m)
	local frame = Color3.fromRGB(120, 72, 40)
	local core = P(m, { Name = "Core", Size = Vector3.new(0.4, 0.1, 0.1), CFrame = CFrame.new(0, 0.12, 0), Color = frame })
	for _, side in ipairs({ -1, 1 }) do
		Cyl(m, 0.08, 0.7, CFrame.new(side * 0.5, 0, 0), "Z", { Color = frame })
		Cyl(m, 0.1, 0.6, CFrame.new(side * 0.5, 0, -0.01), "Z", { Material = GLASS, Transparency = 0.15, Color = Color3.fromRGB(30, 26, 30), Reflectance = 0.3 })
		P(m, { Size = Vector3.new(0.06, 0.08, 1.3), CFrame = CFrame.new(side * 0.85, 0.1, 0.62) * CFrame.Angles(0, side * math.rad(-6), 0), Color = frame })
		P(m, { Size = Vector3.new(0.06, 0.08, 0.3), CFrame = CFrame.new(side * 0.88, -0.02, 1.32) * CFrame.Angles(math.rad(-40), 0, 0), Color = frame })
	end
	return core
end

builders.ToyRobot = function(m)
	local blue = Color3.fromRGB(110, 170, 210)
	local tin = Color3.fromRGB(190, 194, 200)
	local core = P(m, { Name = "Core", Size = Vector3.new(0.95, 1.0, 0.65), CFrame = CFrame.new(0, 0, 0), Material = METAL, Color = blue })
	P(m, { Size = Vector3.new(0.72, 0.58, 0.58), CFrame = CFrame.new(0, 0.82, 0), Material = METAL, Color = tin })
	for _, side in ipairs({ -1, 1 }) do
		Ball(m, 0.16, CFrame.new(side * 0.17, 0.88, -0.29), { Material = NEON, Color = Color3.fromRGB(255, 200, 90), CastShadow = false })
		P(m, { Size = Vector3.new(0.22, 0.75, 0.24), CFrame = CFrame.new(side * 0.6, 0.02, 0) * CFrame.Angles(0, 0, side * math.rad(12)), Material = METAL, Color = tin })
		P(m, { Size = Vector3.new(0.28, 0.5, 0.32), CFrame = CFrame.new(side * 0.24, -0.74, 0), Material = METAL, Color = tin })
	end
	Cyl(m, 0.35, 0.06, CFrame.new(0, 1.28, 0), "Y", { Material = METAL, Color = tin })
	Ball(m, 0.16, CFrame.new(0, 1.48, 0), { Material = NEON, Color = Color3.fromRGB(230, 90, 70), CastShadow = false })
	P(m, { Size = Vector3.new(0.5, 0.3, 0.05), CFrame = CFrame.new(0, 0.05, -0.34), Material = SMOOTH, Color = Color3.fromRGB(240, 190, 60) })
	return core
end

builders.Amphora = function(m)
	local clay = Color3.fromRGB(196, 104, 66)
	local core = Ell(m, Vector3.new(1.4, 1.9, 1.4), CFrame.new(0, 0, 0), { Name = "Core", Color = clay })
	Cyl(m, 0.7, 0.5, CFrame.new(0, 1.15, 0), "Y", { Color = clay })
	Cyl(m, 0.14, 0.7, CFrame.new(0, 1.5, 0), "Y", { Color = clay })
	Cyl(m, 0.34, 0.36, CFrame.new(0, -1.0, 0), "Y", { Color = clay })
	for _, side in ipairs({ -1, 1 }) do
		P(m, { Size = Vector3.new(0.14, 0.62, 0.14), CFrame = CFrame.new(side * 0.5, 1.12, 0) * CFrame.Angles(0, 0, side * math.rad(-28)), Color = clay })
	end
	Cyl(m, 0.06, 1.44, CFrame.new(0, 0.25, 0), "Y", { Color = Color3.fromRGB(60, 40, 30) })
	Cyl(m, 0.06, 1.38, CFrame.new(0, -0.15, 0), "Y", { Color = Color3.fromRGB(240, 200, 140) })
	P(m, { Size = Vector3.new(0.05, 0.5, 0.05), CFrame = CFrame.new(0.4, 0.35, -0.55) * CFrame.Angles(0, 0, math.rad(20)), Color = DARK })
	m:SetAttribute("LieAngle", 70)
	return core
end

builders.DesertRose = function(m)
	local rose = Color3.fromRGB(222, 170, 140)
	local core = Cyl(m, 0.12, 1.3, CFrame.new(0, 0, 0), "Y", { Name = "Core", Material = Enum.Material.Sandstone, Color = rose })
	local petals = {
		{ 0, 0.25, 0, 20, 0 },
		{ 0.3, 0.2, 0.1, 50, 60 },
		{ -0.3, 0.25, -0.1, 55, 160 },
		{ 0.05, 0.45, -0.3, 40, 250 },
		{ -0.15, 0.4, 0.3, 65, 320 },
		{ 0.2, 0.55, 0.15, 35, 110 },
	}
	for _, petal in ipairs(petals) do
		Cyl(m, 0.1, 1.0, CFrame.new(petal[1], petal[2], petal[3]) * CFrame.Angles(0, math.rad(petal[5]), math.rad(petal[4])), "Y", {
			Material = Enum.Material.Sandstone,
			Color = rose,
		})
	end
	Ball(m, 0.22, CFrame.new(0.1, 0.62, 0), { Material = GLASS, Transparency = 0.3, Color = Color3.fromRGB(255, 220, 230) })
	return core
end

builders.GoldRing = function(m)
	local core = P(m, { Name = "Core", Size = Vector3.new(0.3, 0.12, 0.3), CFrame = CFrame.new(0, 0.42, 0), Material = FOIL, Color = GOLD })
	for i = 0, 13 do
		local a = math.rad(i * (360 / 14))
		P(m, {
			Size = Vector3.new(0.24, 0.18, 0.12),
			CFrame = CFrame.new(math.sin(a) * 0.48, math.cos(a) * 0.48, 0) * CFrame.Angles(0, 0, -a),
			Material = FOIL,
			Color = GOLD,
		})
	end
	Ball(m, 0.34, CFrame.new(0, 0.66, 0), { Material = GLASS, Color = Color3.fromRGB(220, 40, 70), Reflectance = 0.2 })
	for _, side in ipairs({ -1, 1 }) do
		P(m, { Size = Vector3.new(0.05, 0.22, 0.05), CFrame = CFrame.new(side * 0.13, 0.58, 0), Material = FOIL, Color = GOLD })
	end
	m:SetAttribute("LieAngle", 80)
	return core
end

builders.BrassCompass = function(m)
	local brass = Color3.fromRGB(196, 150, 72)
	local core = Cyl(m, 0.28, 1.3, CFrame.new(0, 0, 0), "Y", { Name = "Core", Material = METAL, Color = brass })
	Cyl(m, 0.3, 1.08, CFrame.new(0, 0.01, 0), "Y", { Color = Color3.fromRGB(246, 236, 212) })
	Cyl(m, 0.32, 1.06, CFrame.new(0, 0.02, 0), "Y", { Material = GLASS, Transparency = 0.65, Color = Color3.fromRGB(220, 235, 240) })
	P(m, { ClassName = "WedgePart", Size = Vector3.new(0.08, 0.04, 0.4), CFrame = CFrame.new(0, 0.17, -0.2) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.Angles(0, 0, 0), Color = Color3.fromRGB(210, 50, 50) })
	P(m, { Size = Vector3.new(0.08, 0.04, 0.4), CFrame = CFrame.new(0, 0.17, 0.2), Color = Color3.fromRGB(240, 240, 240) })
	Cyl(m, 0.08, 1.3, CFrame.new(0, 0.62, 0.72) * CFrame.Angles(math.rad(-75), 0, 0), "Y", { Material = METAL, Color = brass })
	Cyl(m, 0.2, 0.22, CFrame.new(0, 0, -0.74), "Z", { Material = METAL, Color = brass })
	return core
end

builders.Ammonite = function(m)
	local stone = Color3.fromRGB(206, 186, 150)
	local core = Ball(m, 0.5, CFrame.new(0, 0, 0), { Name = "Core", Material = Enum.Material.Limestone, Color = stone })
	local angle, radius, size = 0, 0.2, 0.38
	for i = 1, 22 do
		angle += math.rad(30)
		radius *= 1.075
		size *= 1.06
		Ball(m, size, CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), {
			Material = Enum.Material.Limestone,
			Color = (i % 2 == 0) and stone or Color3.fromRGB(184, 160, 124),
		})
	end
	m:SetAttribute("LieAngle", 75)
	return core
end

builders.Harmonica = function(m)
	local silver = Color3.fromRGB(200, 204, 212)
	local core = P(m, { Name = "Core", Size = Vector3.new(1.6, 0.14, 0.42), CFrame = CFrame.new(0, 0.16, 0), Material = METAL, Color = silver })
	P(m, { Size = Vector3.new(1.6, 0.14, 0.42), CFrame = CFrame.new(0, -0.16, 0), Material = METAL, Color = silver })
	P(m, { Size = Vector3.new(1.5, 0.2, 0.4), CFrame = CFrame.new(0, 0, 0.01), Material = Enum.Material.Wood, Color = Color3.fromRGB(150, 96, 56) })
	for i = 0, 9 do
		P(m, { Size = Vector3.new(0.08, 0.1, 0.05), CFrame = CFrame.new(-0.63 + i * 0.14, 0, -0.2), Color = DARK })
	end
	P(m, { Size = Vector3.new(0.7, 0.02, 0.2), CFrame = CFrame.new(0, 0.24, 0), Material = FOIL, Color = GOLD })
	return core
end

builders.Scarab = function(m)
	local turquoise = Color3.fromRGB(60, 176, 170)
	local core = Ell(m, Vector3.new(0.9, 0.4, 1.2), CFrame.new(0, 0, 0), { Name = "Core", Material = GLASS, Color = turquoise, Reflectance = 0.1 })
	Ell(m, Vector3.new(0.5, 0.3, 0.38), CFrame.new(0, 0, -0.68), { Material = GLASS, Color = Color3.fromRGB(40, 140, 140) })
	P(m, { Size = Vector3.new(0.05, 0.42, 1.05), CFrame = CFrame.new(0, 0.02, 0.05), Material = FOIL, Color = GOLD })
	Cyl(m, 0.08, 1.05, CFrame.new(0, -0.05, 0.05), "Y", { Material = FOIL, Color = GOLD })
	for _, side in ipairs({ -1, 1 }) do
		for leg = -1, 1 do
			P(m, { Size = Vector3.new(0.4, 0.06, 0.06), CFrame = CFrame.new(side * 0.55, -0.1, leg * 0.32) * CFrame.Angles(0, side * leg * math.rad(20), 0), Material = FOIL, Color = GOLD })
		end
		Ell(m, Vector3.new(0.5, 0.14, 0.9), CFrame.new(side * 0.62, 0.02, 0.15) * CFrame.Angles(0, side * math.rad(15), 0), { Material = FOIL, Color = GOLD })
	end
	for i = 0, 7 do
		local a = math.rad(i * 45)
		Ball(m, 0.1, CFrame.new(math.sin(a) * 0.18, 0.08, -1.05 - math.cos(a) * 0.18), { Material = FOIL, Color = GOLD })
	end
	return core
end

builders.DinoSkull = function(m)
	local bone = Color3.fromRGB(230, 214, 182)
	local boneDark = Color3.fromRGB(196, 176, 140)
	local core = Ell(m, Vector3.new(1.7, 1.4, 2.0), CFrame.new(0, 0.2, 0.6), { Name = "Core", Color = bone })
	Ell(m, Vector3.new(1.1, 0.8, 2.2), CFrame.new(0, 0.05, -0.9), { Color = bone })
	P(m, { ClassName = "WedgePart", Size = Vector3.new(0.9, 0.35, 1.8), CFrame = CFrame.new(0, -0.55, -0.5) * CFrame.Angles(0, math.rad(180), math.rad(180)), Color = boneDark })
	for _, side in ipairs({ -1, 1 }) do
		Ball(m, 0.5, CFrame.new(side * 0.55, 0.45, 0.35), { Color = DARK })
		Ball(m, 0.25, CFrame.new(side * 0.35, 0.25, -1.75), { Color = DARK })
		for t = 0, 5 do
			P(m, {
				ClassName = "WedgePart",
				Size = Vector3.new(0.08, 0.28, 0.12),
				CFrame = CFrame.new(side * 0.42, -0.4, -1.75 + t * 0.32) * CFrame.Angles(math.rad(180), 0, 0),
				Color = Color3.fromRGB(250, 244, 226),
			})
		end
		P(m, { ClassName = "WedgePart", Size = Vector3.new(0.18, 0.5, 0.5), CFrame = CFrame.new(side * 0.6, 0.95, 1.1) * CFrame.Angles(math.rad(-30), 0, 0), Color = boneDark })
	end
	Ell(m, Vector3.new(1.2, 0.5, 0.5), CFrame.new(0, -0.15, 1.45), { Color = boneDark })
	return core
end

builders.GoldenIdol = function(m)
	local core = P(m, { Name = "Core", Size = Vector3.new(1.1, 0.35, 1.1), CFrame = CFrame.new(0, -1.05, 0), Material = FOIL, Color = GOLD })
	Cyl(m, 1.2, 0.8, CFrame.new(0, -0.3, 0), "Y", { Material = FOIL, Color = GOLD })
	Ball(m, 0.8, CFrame.new(0, 0.62, 0), { Material = FOIL, Color = GOLD })
	for _, side in ipairs({ -1, 1 }) do
		P(m, { Size = Vector3.new(0.2, 0.75, 0.2), CFrame = CFrame.new(side * 0.42, -0.2, -0.15) * CFrame.Angles(math.rad(-50), 0, side * math.rad(-15)), Material = FOIL, Color = GOLD })
		Ball(m, 0.16, CFrame.new(side * 0.16, 0.7, -0.36), { Material = NEON, Color = Color3.fromRGB(90, 230, 140), CastShadow = false })
		P(m, { ClassName = "WedgePart", Size = Vector3.new(0.1, 0.35, 0.25), CFrame = CFrame.new(side * 0.28, 1.1, 0) * CFrame.Angles(0, math.rad(90), 0), Material = FOIL, Color = GOLD })
	end
	P(m, { ClassName = "WedgePart", Size = Vector3.new(0.1, 0.45, 0.25), CFrame = CFrame.new(0, 1.15, 0) * CFrame.Angles(0, math.rad(90), 0), Material = FOIL, Color = GOLD })
	Cyl(m, 0.1, 0.86, CFrame.new(0, 0.95, 0), "Y", { Material = FOIL, Color = Color3.fromRGB(250, 214, 110) })
	P(m, { Size = Vector3.new(1.3, 0.1, 1.3), CFrame = CFrame.new(0, -1.22, 0), Material = Enum.Material.Sandstone, Color = Color3.fromRGB(180, 130, 90) })
	return core
end

function FindModels.Build(findId, anchored)
	local builder = builders[findId]
	assert(builder, "Unknown find: " .. tostring(findId))
	local model = Instance.new("Model")
	model.Name = findId
	local core = builder(model)
	PartKit.Finalize(model, core, anchored ~= false)
	model:SetAttribute("FindId", findId)
	return model
end

return FindModels
]======]

-- ModuleScript: ServerScriptService/Sandsweep/WorldBuilder.lua
created["WorldBuilder"] = make("ModuleScript", "WorldBuilder", Containers.SSS)
created["WorldBuilder"].Source = [======[
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
	solid(decor, { Name = "Boardwalk", Size = Vector3.new(34, 0.3, 6), CFrame = CFrame.new(Lot.CenterX, CAMP_Y + 0.15, CAMP_Z), Material = Enum.Material.WoodPlanks, Color = planks })
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
		{ Text = "Glass Furnace • Upgrade Booth", Height = 0.28, Font = Enum.Font.GothamBold, Color = Palette.InkSoft },
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
	local origin = CFrame.new(Lot.CenterX - 26, CAMP_Y, CAMP_Z)
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
	buildGlassFurnace(stations)
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
]======]

-- ModuleScript: ServerScriptService/Sandsweep/LotService.lua
created["LotService"] = make("ModuleScript", "LotService", Containers.SSS)
created["LotService"].Source = [======[
-- LotService (ModuleScript) - ServerScriptService/Sandsweep/LotService
-- Owns the Smooth Terrain dig site: generation, voxel-accurate digging,
-- remnant sweeping, cover checks for buried finds and % cleared tracking.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Sandsweep"):WaitForChild("GameConfig"))

local LotService = {}

local Lot = GameConfig.Lot
local terrain = Workspace.Terrain
local SAND = Enum.Material.Sand
local AIR = Enum.Material.Air
local RES = 4
local VOXEL_VOLUME = RES * RES * RES

local LOT_MIN = Vector3.new(Lot.CenterX - Lot.SizeX / 2, Lot.BottomY, Lot.CenterZ - Lot.SizeZ / 2)
local LOT_MAX = Vector3.new(Lot.CenterX + Lot.SizeX / 2, Lot.BottomY + Lot.Depth, Lot.CenterZ + Lot.SizeZ / 2)
local LOT_REGION = Region3.new(LOT_MIN, LOT_MAX):ExpandToGrid(RES)

LotService.Min = LOT_MIN
LotService.Max = LOT_MAX
LotService.Top = LOT_MAX.Y
LotService.InitialVolume = 1
LotService.CurrentVolume = 1
LotService.Percent = 0
LotService.Generating = false
LotService.Seed = 0
LotService.Dirty = false

local function clampVector(v, minV, maxV)
	return Vector3.new(math.clamp(v.X, minV.X, maxV.X), math.clamp(v.Y, minV.Y, maxV.Y), math.clamp(v.Z, minV.Z, maxV.Z))
end

local function sumSand(materials, occupancies)
	local size = materials.Size
	local total = 0
	for x = 1, size.X do
		local mx, ox = materials[x], occupancies[x]
		for y = 1, size.Y do
			local my, oy = mx[y], ox[y]
			for z = 1, size.Z do
				if my[z] == SAND then
					total += oy[z]
				end
			end
		end
	end
	return total * VOXEL_VOLUME
end

-- Surface height (studs above bedrock) for the dunes. Dunes taper down to
-- Lot.EdgeHeight at the border so the dig zone blends into the open desert.
local function smoothstep(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function surfaceHeight(worldX, worldZ, seed)
	local n1 = math.noise(worldX * Lot.NoiseScale, worldZ * Lot.NoiseScale, seed)
	local n2 = math.noise(worldX * Lot.NoiseScale * 2.6, worldZ * Lot.NoiseScale * 2.6, seed + 17.3) * 0.35
	local n = math.clamp((n1 + n2) * 0.95 + 0.5, 0, 1)
	local dunes = Lot.SurfaceMin + (Lot.SurfaceMax - Lot.SurfaceMin) * n
	local edgeDistance = math.min(Lot.SizeX / 2 - math.abs(worldX - Lot.CenterX), Lot.SizeZ / 2 - math.abs(worldZ - Lot.CenterZ))
	local taper = smoothstep(edgeDistance / Lot.EdgeFalloff)
	return Lot.EdgeHeight + (dunes - Lot.EdgeHeight) * taper
end

LotService.SurfaceHeight = surfaceHeight

function LotService.Generate(seed)
	LotService.Generating = true
	LotService.Seed = seed or math.random(1, 100000)
	local seedValue = LotService.Seed * 0.013 + 0.37

	local size = LOT_REGION.Size / RES
	local nx, ny, nz = math.floor(size.X + 0.5), math.floor(size.Y + 0.5), math.floor(size.Z + 0.5)
	local regionMin = LOT_REGION.CFrame.Position - LOT_REGION.Size / 2
	local materials, occupancies = {}, {}
	for x = 1, nx do
		materials[x], occupancies[x] = {}, {}
		for y = 1, ny do
			materials[x][y], occupancies[x][y] = {}, {}
		end
		for z = 1, nz do
			local worldX = regionMin.X + (x - 0.5) * RES
			local worldZ = regionMin.Z + (z - 0.5) * RES
			local height = surfaceHeight(worldX, worldZ, seedValue)
			for y = 1, ny do
				local layerBottom = (regionMin.Y - Lot.BottomY) + (y - 1) * RES
				local occupancy = math.clamp((height - layerBottom) / RES, 0, 1)
				if occupancy > 0.03 then
					materials[x][y][z] = SAND
					occupancies[x][y][z] = occupancy
				else
					materials[x][y][z] = AIR
					occupancies[x][y][z] = 0
				end
			end
		end
	end
	terrain:WriteVoxels(LOT_REGION, RES, materials, occupancies)

	local readMaterials, readOccupancies = terrain:ReadVoxels(LOT_REGION, RES)
	LotService.InitialVolume = math.max(1, sumSand(readMaterials, readOccupancies))
	LotService.CurrentVolume = LotService.InitialVolume
	LotService.Percent = 0
	LotService.Dirty = false
	LotService.Generating = false
	return LotService.InitialVolume
end

function LotService.IsInside(position, margin)
	margin = margin or 0
	return position.X >= LOT_MIN.X - margin
		and position.X <= LOT_MAX.X + margin
		and position.Z >= LOT_MIN.Z - margin
		and position.Z <= LOT_MAX.Z + margin
		and position.Y >= LOT_MIN.Y - margin
		and position.Y <= LOT_MAX.Y + margin + 2
end

local SMALL_TOOL_RADIUS = 2.8
local MIN_REMOVAL = 0.08 -- voxel occupancy every successful dig is guaranteed to remove

local function isInsideColumn(position)
	return position.X > LOT_MIN.X and position.X < LOT_MAX.X and position.Z > LOT_MIN.Z and position.Z < LOT_MAX.Z
end

-- Remove sand in a ball. Returns the exact sand volume (cubic studs) removed,
-- measured by reading voxels before and after. Air is never counted.
-- Big tools carve with Terrain:FillBall; tiny tools (spoon) carve the voxels
-- directly so a scoop always bites, even when the ball is smaller than a voxel.
-- Anything outside the dig zone is restored, so the outer desert never changes.
function LotService.Dig(center, radius)
	if LotService.Generating then
		return 0
	end
	local pad = radius + RES
	local low = Vector3.new(center.X - pad, math.max(LOT_MIN.Y, center.Y - pad), center.Z - pad)
	local high = Vector3.new(center.X + pad, math.max(LOT_MIN.Y + RES, center.Y + pad), center.Z + pad)
	local region = Region3.new(low, high):ExpandToGrid(RES)
	local regionMin = region.CFrame.Position - region.Size / 2

	local beforeMaterials, beforeOccupancies = terrain:ReadVoxels(region, RES)
	local smallTool = radius < SMALL_TOOL_RADIUS
	if not smallTool then
		terrain:FillBall(center, radius, AIR)
	end
	local afterMaterials, afterOccupancies = terrain:ReadVoxels(region, RES)

	local size = beforeMaterials.Size
	local removed = 0
	local rewrite = false
	local sweepDistance = radius + RES * 0.75
	local nearest, nearestDistance = nil, math.huge

	local function setAfter(x, y, z, value)
		if value <= 0.001 then
			afterMaterials[x][y][z] = AIR
			afterOccupancies[x][y][z] = 0
		else
			afterMaterials[x][y][z] = SAND
			afterOccupancies[x][y][z] = value
		end
		rewrite = true
	end

	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				local voxelPosition = regionMin + Vector3.new((x - 0.5) * RES, (y - 0.5) * RES, (z - 0.5) * RES)
				local beforeMaterial = beforeMaterials[x][y][z]
				local beforeOccupancy = beforeOccupancies[x][y][z]
				if not isInsideColumn(voxelPosition) or (beforeMaterial ~= SAND and beforeMaterial ~= AIR) then
					-- protect the outer desert and any non-sand terrain
					if afterMaterials[x][y][z] ~= beforeMaterial or afterOccupancies[x][y][z] ~= beforeOccupancy then
						afterMaterials[x][y][z] = beforeMaterial
						afterOccupancies[x][y][z] = beforeOccupancy
						rewrite = true
					end
				else
					local before = (beforeMaterial == SAND) and beforeOccupancy or 0
					local after = (afterMaterials[x][y][z] == SAND) and afterOccupancies[x][y][z] or 0
					local distance = (voxelPosition - center).Magnitude
					if smallTool and after > 0 then
						local carve = math.clamp((radius + 1 - distance) / RES, 0, 1)
						if carve > 0 then
							after = math.max(0, after - carve)
							setAfter(x, y, z, after)
						end
					end
					-- sweep tiny remnants next to the dig so "every grain" is reachable
					if after > 0 and after < Lot.RemnantThreshold and before > 0 and distance <= sweepDistance then
						after = 0
						setAfter(x, y, z, 0)
					end
					if after > 0 and distance < nearestDistance then
						nearest, nearestDistance = Vector3.new(x, y, z), distance
					end
					if before > after then
						removed += before - after
					end
				end
			end
		end
	end

	-- guarantee every scoop bites into the closest sand
	if removed < MIN_REMOVAL and nearest and nearestDistance <= radius + RES then
		local x, y, z = nearest.X, nearest.Y, nearest.Z
		local current = afterOccupancies[x][y][z]
		local bite = math.min(current, MIN_REMOVAL * 2)
		local remaining = current - bite
		if remaining < Lot.RemnantThreshold then
			bite = current
			remaining = 0
		end
		setAfter(x, y, z, remaining)
		removed += bite
	end

	if rewrite then
		terrain:WriteVoxels(region, RES, afterMaterials, afterOccupancies)
	end
	if removed > 0 then
		LotService.Dirty = true
	end
	return removed * VOXEL_VOLUME
end

-- Recount remaining sand and update the cleared fraction.
function LotService.Recount()
	local materials, occupancies = terrain:ReadVoxels(LOT_REGION, RES)
	LotService.CurrentVolume = sumSand(materials, occupancies)
	LotService.Percent = math.clamp(1 - LotService.CurrentVolume / LotService.InitialVolume, 0, 1)
	LotService.Dirty = false
	return LotService.Percent
end

function LotService.IsCleared()
	return LotService.Percent >= Lot.ClearedThreshold
end

-- Average sand occupancy in the voxel column covering a point (from its
-- bottom up to `above` studs over it). Used to confirm a find is uncovered.
function LotService.CoverOccupancy(position, above)
	local low = clampVector(position - Vector3.new(0.5, 0.5, 0.5), LOT_MIN, LOT_MAX)
	local high = clampVector(position + Vector3.new(0.5, above, 0.5), LOT_MIN, LOT_MAX)
	if high.Y - low.Y < 0.01 then
		return 0
	end
	local region = Region3.new(low, high):ExpandToGrid(RES)
	local materials, occupancies = terrain:ReadVoxels(region, RES)
	local size = materials.Size
	local total, count = 0, 0
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				count += 1
				if materials[x][y][z] == SAND then
					total += occupancies[x][y][z]
				end
			end
		end
	end
	return count > 0 and total / count or 0
end

-- Raycast check: is there sand directly above a point?
local coverParams = RaycastParams.new()
coverParams.FilterType = Enum.RaycastFilterType.Include
coverParams.FilterDescendantsInstances = { terrain }

function LotService.IsCoveredAbove(position, clearance)
	local origin = Vector3.new(position.X, LOT_MAX.Y + 20, position.Z)
	local targetY = position.Y + clearance
	if targetY >= origin.Y then
		return false
	end
	local result = Workspace:Raycast(origin, Vector3.new(0, targetY - origin.Y, 0), coverParams)
	return result ~= nil and result.Material == SAND
end

-- World Y of the sand surface at (x, z), or nil when there is no sand above bedrock.
function LotService.SurfaceY(x, z)
	local origin = Vector3.new(x, LOT_MAX.Y + 40, z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -(origin.Y - LOT_MIN.Y + 1), 0), coverParams)
	if result and result.Material == SAND then
		return result.Position.Y
	end
	return nil
end

return LotService
]======]

-- ModuleScript: ServerScriptService/Sandsweep/FindsService.lua
created["FindsService"] = make("ModuleScript", "FindsService", Containers.SSS)
created["FindsService"].Source = [======[
-- FindsService (ModuleScript) - ServerScriptService/Sandsweep/FindsService
-- Spawns the 14 buried relics inside the sand, detects when the sand above
-- them has been cleared (voxel + raycast check), then enables collection.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Sandsweep")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local FindModels = require(Shared:WaitForChild("FindModels"))
local PartKit = require(Shared:WaitForChild("PartKit"))

local LotService = require(script.Parent:WaitForChild("LotService"))

local FindsService = {}
FindsService.Active = {} -- [findId] = entry
FindsService.OnCollect = nil -- function(player, findId) -> boolean
FindsService.OnUncovered = nil -- function(findId)

local Lot = GameConfig.Lot
local COVER_OCCUPANCY = 0.3
local MIN_SPACING = 18
local EDGE_MARGIN = Lot.EdgeFalloff

local function getFolder()
	local root = Workspace:WaitForChild("SandsweepWorld")
	return root:WaitForChild("Finds")
end

local function clearAll()
	for _, entry in pairs(FindsService.Active) do
		if entry.Model then
			entry.Model:Destroy()
		end
	end
	FindsService.Active = {}
	local finds = getFolder()
	finds:ClearAllChildren()
end

local function revealEffects(entry)
	local model = entry.Model
	local core = model.PrimaryPart
	local rarityColor = GameConfig.Rarities[entry.Config.Rarity] or Color3.new(1, 1, 1)

	local highlight = Instance.new("Highlight")
	highlight.FillColor = rarityColor
	highlight.FillTransparency = 0.82
	highlight.OutlineColor = Color3.fromRGB(255, 230, 160)
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	local light = Instance.new("PointLight")
	light.Color = rarityColor:Lerp(Color3.new(1, 1, 1), 0.4)
	light.Brightness = 2
	light.Range = 10
	light.Parent = core

	local attachment = Instance.new("Attachment")
	attachment.Name = "SparkleAttachment"
	attachment.Parent = core
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 240, 190), rarityColor)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.Rate = 10
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = attachment

	-- soft light pillar so it can be spotted across the lot
	local pillar = PartKit.Part(model, {
		Name = "Pillar",
		Size = Vector3.new(0.5, 14, 0.5),
		CFrame = CFrame.new(core.Position + Vector3.new(0, 7.5, 0)),
		Material = Enum.Material.Neon,
		Color = rarityColor:Lerp(Color3.new(1, 1, 1), 0.5),
		Transparency = 0.75,
		CastShadow = false,
	})
	TweenService:Create(pillar, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.92 }):Play()
end

local function collect(entry, player)
	if entry.Collected or not entry.Uncovered then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - entry.Position).Magnitude > 14 then
		return
	end
	entry.Collected = true
	entry.Prompt.Enabled = false
	local ok = true
	if FindsService.OnCollect then
		ok = FindsService.OnCollect(player, entry.Id)
	end
	if not ok then
		entry.Collected = false
		entry.Prompt.Enabled = true
		return
	end
	-- float up & fade out
	local model = entry.Model
	local startPivot = model:GetPivot()
	local progress = Instance.new("NumberValue")
	progress.Name = "CollectProgress"
	progress.Value = 0
	progress.Parent = model
	progress.Changed:Connect(function(value)
		if model.Parent then
			model:PivotTo(startPivot * CFrame.new(0, value * 3, 0) * CFrame.Angles(0, value * math.pi * 2, 0))
		end
	end)
	local tween = TweenService:Create(progress, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 })
	tween.Completed:Connect(function()
		progress:Destroy()
		if model.Parent then
			model:Destroy()
		end
	end)
	tween:Play()
end

function FindsService.Spawn(seed)
	clearAll()
	local folder = getFolder()
	local rng = Random.new(seed or os.time())
	local placed = {}
	local halfX = Lot.SizeX / 2 - EDGE_MARGIN
	local halfZ = Lot.SizeZ / 2 - EDGE_MARGIN

	for _, config in ipairs(GameConfig.Finds) do
		local position
		for attempt = 1, 120 do
			local x = Lot.CenterX + rng:NextNumber(-halfX, halfX)
			local z = Lot.CenterZ + rng:NextNumber(-halfZ, halfZ)
			local surface = LotService.SurfaceY(x, z)
			local ok = surface ~= nil
			if ok then
				-- later attempts accept shallower burial if the dunes are too low
				local depth = rng:NextNumber(config.DepthMin, config.DepthMax) * (attempt > 80 and 0.6 or 1)
				local y = surface - depth
				ok = y >= Lot.BottomY + 1.2 and y <= surface - 2
				for _, other in ipairs(placed) do
					if (Vector2.new(other.X, other.Z) - Vector2.new(x, z)).Magnitude < MIN_SPACING then
						ok = false
						break
					end
				end
				if ok then
					position = Vector3.new(x, y, z)
					break
				end
			end
		end
		if not position then
			local x = Lot.CenterX + rng:NextNumber(-halfX, halfX)
			local z = Lot.CenterZ + rng:NextNumber(-halfZ, halfZ)
			local surface = LotService.SurfaceY(x, z) or (Lot.BottomY + 4)
			position = Vector3.new(x, math.max(Lot.BottomY + 1.2, surface - 2.5), z)
		end
		table.insert(placed, position)

		local model = FindModels.Build(config.Id, true)
		local lieAngle = model:GetAttribute("LieAngle") or 0
		model:PivotTo(CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(math.rad(lieAngle), 0, 0))
		PartKit.SetCollision(model, false, false, false)
		model.Parent = folder

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "CollectPrompt"
		prompt.ActionText = "Collect"
		prompt.ObjectText = config.Name
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Enabled = false
		prompt.Parent = model.PrimaryPart

		local entry = {
			Id = config.Id,
			Config = config,
			Model = model,
			Prompt = prompt,
			Position = position,
			Uncovered = false,
			Collected = false,
			NeedsCheck = true,
		}
		prompt.Triggered:Connect(function(player)
			collect(entry, player)
		end)
		FindsService.Active[config.Id] = entry
	end
end

-- Flag finds near a dig so they get re-checked next update.
function FindsService.MarkNear(position, radius)
	for _, entry in pairs(FindsService.Active) do
		if not entry.Uncovered and (entry.Position - position).Magnitude <= radius then
			entry.NeedsCheck = true
		end
	end
end

local function isUncovered(entry)
	local position = entry.Position
	-- 1) Voxel check: the sand in the voxel column at & just above the find is mostly gone
	local occupancy = LotService.CoverOccupancy(position, 2.5)
	if occupancy > COVER_OCCUPANCY then
		return false
	end
	-- 2) Raycast check: at least 3 of 5 vertical rays reach the find without hitting sand
	local clear = 0
	for _, offset in ipairs({ Vector3.zero, Vector3.new(0.6, 0, 0), Vector3.new(-0.6, 0, 0), Vector3.new(0, 0, 0.6), Vector3.new(0, 0, -0.6) }) do
		if not LotService.IsCoveredAbove(position + offset, 0.6) then
			clear += 1
		end
	end
	return clear >= 3
end

-- Run uncover checks. full=true checks every buried find.
function FindsService.Update(full)
	for _, entry in pairs(FindsService.Active) do
		if not entry.Uncovered and not entry.Collected and (full or entry.NeedsCheck) then
			entry.NeedsCheck = false
			if isUncovered(entry) then
				entry.Uncovered = true
				entry.Prompt.Enabled = true
				revealEffects(entry)
				if FindsService.OnUncovered then
					FindsService.OnUncovered(entry.Id)
				end
			end
		end
	end
end

function FindsService.CountRemaining()
	local count = 0
	for _, entry in pairs(FindsService.Active) do
		if not entry.Collected then
			count += 1
		end
	end
	return count
end

return FindsService
]======]

-- ModuleScript: ServerScriptService/Sandsweep/DataService.lua
created["DataService"] = make("ModuleScript", "DataService", Containers.SSS)
created["DataService"].Source = [======[
-- DataService (ModuleScript) - ServerScriptService/Sandsweep/DataService
-- DataStore persistence with retries, pcall safety, session locking-lite and
-- an automatic in-memory fallback when Studio has no API access.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Sandsweep")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Util = require(Shared:WaitForChild("Util"))

local DataService = {}
DataService.StoreName = "SandsweepData_v1"
DataService.Mode = "Pending" -- "DataStore" | "Memory"

local store = nil
local MAX_RETRIES = 3

local function keyFor(player)
	return "Player_" .. tostring(player.UserId)
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DataService.StoreName)
	end)
	if ok and result then
		store = result
		DataService.Mode = "DataStore"
	else
		DataService.Mode = "Memory"
		warn("[Sandsweep] DataStore unavailable, using in-memory saves this session:", result)
	end
end

local function switchToMemory(reason)
	if DataService.Mode ~= "Memory" then
		DataService.Mode = "Memory"
		warn("[Sandsweep] Switching to in-memory saves:", reason)
		if RunService:IsStudio() then
			warn("[Sandsweep] Tip: Game Settings > Security > Enable Studio Access to API Services to test real saving.")
		end
	end
end

local function isApiAccessError(message)
	message = tostring(message)
	return string.find(message, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(message, "403", 1, true) ~= nil
		or string.find(message, "must publish", 1, true) ~= nil
		or string.find(message, "not allowed", 1, true) ~= nil
end

-- Sanitize loaded data so a corrupted save can never break the game.
local function sanitize(data)
	Util.Reconcile(data, GameConfig.DefaultData)
	data.Cash = math.max(0, tonumber(data.Cash) or 0)
	data.BagTier = math.clamp(math.floor(tonumber(data.BagTier) or 1), 1, #GameConfig.Bags)
	data.BagKg = math.clamp(tonumber(data.BagKg) or 0, 0, GameConfig.Bags[data.BagTier].Capacity)
	local owned = {}
	for toolId, value in pairs(data.OwnedTools) do
		if value and GameConfig.GetTool(toolId) then
			owned[toolId] = true
		end
	end
	owned.Hands = true
	data.OwnedTools = owned
	if not (GameConfig.GetTool(data.EquippedTool) and owned[data.EquippedTool]) then
		data.EquippedTool = "Hands"
	end
	for _, skill in ipairs(GameConfig.Skills) do
		data.Skills[skill.Id] = math.clamp(math.floor(tonumber(data.Skills[skill.Id]) or 0), 0, skill.MaxLevel)
	end
	local finds = {}
	for findId, value in pairs(data.Finds) do
		if value and GameConfig.GetFind(findId) then
			finds[findId] = true
		end
	end
	data.Finds = finds
	return data
end

-- Returns data table and whether it is safe to save back later.
function DataService.Load(player)
	if DataService.Mode ~= "DataStore" or not store then
		return sanitize(Util.DeepCopy(GameConfig.DefaultData)), true
	end
	local key = keyFor(player)
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			local data = type(result) == "table" and result or Util.DeepCopy(GameConfig.DefaultData)
			return sanitize(data), true
		end
		if isApiAccessError(result) then
			switchToMemory(result)
			return sanitize(Util.DeepCopy(GameConfig.DefaultData)), true
		end
		warn(string.format("[Sandsweep] Load attempt %d failed for %s: %s", attempt, player.Name, tostring(result)))
		task.wait(1.5 * attempt)
	end
	-- Could not load: play with defaults but never overwrite the real save.
	return sanitize(Util.DeepCopy(GameConfig.DefaultData)), false
end

local function serialize(data)
	return {
		Version = 1,
		Cash = math.floor(data.Cash),
		BagKg = math.floor(data.BagKg * 1000) / 1000,
		OwnedTools = Util.DeepCopy(data.OwnedTools),
		EquippedTool = data.EquippedTool,
		BagTier = data.BagTier,
		Skills = Util.DeepCopy(data.Skills),
		Finds = Util.DeepCopy(data.Finds),
		Stats = {
			TotalKg = math.floor((data.Stats.TotalKg or 0) * 100) / 100,
			TotalEarned = math.floor(data.Stats.TotalEarned or 0),
			LotsCleared = data.Stats.LotsCleared or 0,
			FindsCollected = data.Stats.FindsCollected or 0,
		},
		SavedAt = os.time(),
	}
end

function DataService.Save(player, data, canSave)
	if not canSave or DataService.Mode ~= "DataStore" or not store or not data then
		return false
	end
	local key = keyFor(player)
	local payload = serialize(data)
	for attempt = 1, MAX_RETRIES do
		local ok, err = pcall(function()
			store:UpdateAsync(key, function()
				return payload
			end)
		end)
		if ok then
			return true
		end
		if isApiAccessError(err) then
			switchToMemory(err)
			return false
		end
		warn(string.format("[Sandsweep] Save attempt %d failed for %s: %s", attempt, player.Name, tostring(err)))
		task.wait(attempt)
	end
	return false
end

return DataService
]======]

-- Script: ServerScriptService/Sandsweep/Main.server.lua
created["Main"] = make("Script", "Main", Containers.SSS)
created["Main"].Source = [======[
-- Main (Script) - ServerScriptService/Sandsweep/Main
-- Authoritative game server: world boot, player sessions, digging validation,
-- bag weight, selling, purchases, finds rewards, lot clearing & saving.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Sandsweep")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ToolModels = require(Shared:WaitForChild("ToolModels"))
local Util = require(Shared:WaitForChild("Util"))

local Modules = script.Parent
local WorldBuilder = require(Modules:WaitForChild("WorldBuilder"))
local LotService = require(Modules:WaitForChild("LotService"))
local FindsService = require(Modules:WaitForChild("FindsService"))
local DataService = require(Modules:WaitForChild("DataService"))

local Economy = GameConfig.Economy
local LotConfig = GameConfig.Lot

--------------------------------------------------------------------------
-- REMOTES (created here if the installer did not create them)
--------------------------------------------------------------------------
local remotesFolder = Shared:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = Shared
end

local function ensureRemote(className, name)
	local remote = remotesFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotesFolder
	end
	return remote
end

local Remotes = {
	DigRequest = ensureRemote("RemoteEvent", "DigRequest"),
	DigResult = ensureRemote("RemoteEvent", "DigResult"),
	DigFx = ensureRemote("RemoteEvent", "DigFx"),
	StateUpdate = ensureRemote("RemoteEvent", "StateUpdate"),
	LotUpdate = ensureRemote("RemoteEvent", "LotUpdate"),
	Notify = ensureRemote("RemoteEvent", "Notify"),
	OpenMenu = ensureRemote("RemoteEvent", "OpenMenu"),
	Purchase = ensureRemote("RemoteFunction", "Purchase"),
	GetState = ensureRemote("RemoteFunction", "GetState"),
}

--------------------------------------------------------------------------
-- WORLD BOOT
--------------------------------------------------------------------------
DataService.Init()
WorldBuilder.Build()
LotService.Generate(math.random(1, 100000))
FindsService.Spawn(math.random(1, 100000))
WorldBuilder.UpdateLotBoard(0, FindsService.CountRemaining(), false)

local Sessions = {} -- [player] = session

--------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------
local function notify(player, payload)
	Remotes.Notify:FireClient(player, payload)
end

local function notifyAll(payload)
	Remotes.Notify:FireAllClients(payload)
end

local function buildSnapshot(session)
	local data = session.Data
	local stats = GameConfig.ComputeStats(data)
	return {
		Loaded = true,
		Cash = data.Cash,
		BagKg = data.BagKg,
		BagTier = data.BagTier,
		EquippedTool = data.EquippedTool,
		OwnedTools = data.OwnedTools,
		Skills = data.Skills,
		Finds = data.Finds,
		Stats = data.Stats,
		Derived = stats,
		DataMode = DataService.Mode,
		ContributedKg = session.ContributedKg,
		Lot = {
			Name = LotConfig.Name,
			Percent = LotService.Percent,
			Generating = LotService.Generating,
			FindsRemaining = FindsService.CountRemaining(),
		},
	}
end

local function pushState(player)
	local session = Sessions[player]
	if not session or not session.Loaded then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local cashValue = leaderstats and leaderstats:FindFirstChild("Cash")
	if cashValue then
		cashValue.Value = math.floor(session.Data.Cash)
	end
	local findsValue = leaderstats and leaderstats:FindFirstChild("Finds")
	if findsValue then
		findsValue.Value = Util.CountKeys(session.Data.Finds)
	end
	Remotes.StateUpdate:FireClient(player, buildSnapshot(session))
end

local function getRoot(player)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil, nil
	end
	return root, humanoid
end

--------------------------------------------------------------------------
-- CHARACTER TOOL (third-person model welded to the hand)
--------------------------------------------------------------------------
local function attachTool(player)
	local session = Sessions[player]
	local character = player.Character
	if not session or not character then
		return
	end
	local old = character:FindFirstChild("SandsweepTool")
	if old then
		old:Destroy()
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then
		return
	end
	local toolId = session.Data.EquippedTool
	local model = ToolModels.Build(toolId, false)
	model.Name = "SandsweepTool"
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		end
	end
	local grip = ToolModels.Grips[toolId] or Vector3.zero
	local handOffset = hand.Name == "RightHand" and CFrame.new(0, -0.25, 0) or CFrame.new(0, -1.0, 0)
	local handle = model.PrimaryPart
	model:PivotTo(hand.CFrame * handOffset * CFrame.new(-grip))
	local weld = Instance.new("Weld")
	weld.Name = "GripWeld"
	weld.Part0 = hand
	weld.Part1 = handle
	weld.C0 = handOffset * CFrame.new(-grip)
	weld.C1 = handle.CFrame:ToObjectSpace(hand.CFrame * weld.C0)
	weld.Parent = handle
	model.Parent = character
	player:SetAttribute("EquippedTool", toolId)
end

local function applyWalkSpeed(player)
	local session = Sessions[player]
	local _, humanoid = getRoot(player)
	if session and humanoid then
		humanoid.WalkSpeed = GameConfig.ComputeStats(session.Data).WalkSpeed
	end
end

--------------------------------------------------------------------------
-- PLAYER LIFECYCLE
--------------------------------------------------------------------------
local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid then
		return
	end
	character:WaitForChild("RightHand", 3)
	task.wait()
	applyWalkSpeed(player)
	attachTool(player)
end

local function onPlayerAdded(player)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	if WorldBuilder.Refs.Spawn then
		player.RespawnLocation = WorldBuilder.Refs.Spawn
	end

	local session = {
		Player = player,
		Loaded = false,
		CanSave = false,
		Data = nil,
		LastDig = 0,
		LastSell = 0,
		LastPurchase = 0,
		LastBagFullNotice = 0,
		ContributedKg = 0,
	}
	Sessions[player] = session

	local data, canSave = DataService.Load(player)
	if not player.Parent then
		Sessions[player] = nil
		return
	end
	session.Data = data
	session.CanSave = canSave
	session.Loaded = true

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = math.floor(data.Cash)
	cash.Parent = leaderstats
	local finds = Instance.new("IntValue")
	finds.Name = "Finds"
	finds.Value = Util.CountKeys(data.Finds)
	finds.Parent = leaderstats
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	pushState(player)
	if not canSave then
		notify(player, { Kind = "Toast", Text = "Couldn't reach saves - progress this session won't be saved.", Color = "Terracotta" })
	elseif DataService.Mode == "Memory" then
		notify(player, { Kind = "Toast", Text = "Studio mode: saving is in-memory only.", Color = "Sky" })
	end
end

local function onPlayerRemoving(player)
	local session = Sessions[player]
	if session and session.Loaded then
		DataService.Save(player, session.Data, session.CanSave)
	end
	Sessions[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	local pending = 0
	for player, session in pairs(Sessions) do
		if session.Loaded then
			pending += 1
			task.spawn(function()
				DataService.Save(player, session.Data, session.CanSave)
				pending -= 1
			end)
		end
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 25 do
		task.wait(0.1)
	end
end)

task.spawn(function()
	while true do
		task.wait(Economy.AutosaveInterval)
		for player, session in pairs(Sessions) do
			if session.Loaded then
				task.spawn(DataService.Save, player, session.Data, session.CanSave)
			end
		end
	end
end)

--------------------------------------------------------------------------
-- DIGGING (server authoritative)
--------------------------------------------------------------------------
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude

local function updateLosFilter()
	local exclude = { WorldBuilder.Refs.Root:FindFirstChild("Finds") }
	if WorldBuilder.Refs.Ladders then
		table.insert(exclude, WorldBuilder.Refs.Ladders)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	losParams.FilterDescendantsInstances = exclude
end

local function onDigRequest(player, hitPosition, direction)
	local session = Sessions[player]
	if not session or not session.Loaded or LotService.Generating then
		return
	end
	if not Util.IsFiniteVector(hitPosition) or not Util.IsFiniteVector(direction) then
		return
	end
	local magnitude = direction.Magnitude
	if magnitude < 0.5 or magnitude > 1.5 then
		return
	end
	direction = direction.Unit

	local data = session.Data
	local stats = GameConfig.ComputeStats(data)
	local now = os.clock()
	if now - session.LastDig < stats.Cooldown * Economy.CooldownTolerance then
		return
	end

	local root = getRoot(player)
	if not root then
		return
	end
	local head = player.Character:FindFirstChild("Head") or root
	local eye = head.Position
	if (eye - hitPosition).Magnitude > stats.Range + Economy.RangeTolerance then
		return
	end
	if not LotService.IsInside(hitPosition, 1) then
		return
	end

	-- line of sight: nothing solid (walls, stations) between the player and the sand
	updateLosFilter()
	local toHit = hitPosition - eye
	if toHit.Magnitude > 0.5 then
		local result = Workspace:Raycast(eye, toHit.Unit * math.max(0, toHit.Magnitude - 1), losParams)
		if result and result.Instance ~= Workspace.Terrain then
			return
		end
	end

	local remainingKg = stats.Capacity - data.BagKg
	if remainingKg <= 0.01 then
		if now - session.LastBagFullNotice > 2 then
			session.LastBagFullNotice = now
			notify(player, { Kind = "BagFull" })
		end
		return
	end
	session.LastDig = now

	-- shrink the scoop if the bag can't hold a full one
	local radius = stats.Radius
	local maxVolume = remainingKg / Economy.SandDensity
	local typicalVolume = (4 / 3) * math.pi * radius ^ 3 * 0.55
	if typicalVolume > maxVolume then
		radius = math.max(0.9, radius * (maxVolume / typicalVolume) ^ (1 / 3))
	end

	local center = hitPosition + direction * (radius * 0.3)
	-- anti-void: never carve below the bedrock line
	center = Vector3.new(center.X, math.max(center.Y, LotService.Min.Y + 0.25), center.Z)

	local removedVolume = LotService.Dig(center, radius)
	local kg = math.min(removedVolume * Economy.SandDensity, remainingKg)
	if kg < 0.0005 then
		return
	end

	data.BagKg = math.min(stats.Capacity, data.BagKg + kg)
	data.Stats.TotalKg += kg
	session.ContributedKg += kg

	FindsService.MarkNear(center, radius + 6)
	Remotes.DigResult:FireClient(player, kg, data.BagKg, stats.Capacity, center)
	Remotes.DigFx:FireAllClients(player, center, stats.ToolId, kg)
end

Remotes.DigRequest.OnServerEvent:Connect(onDigRequest)

--------------------------------------------------------------------------
-- SELLING (Glass Furnace)
--------------------------------------------------------------------------
local function trySell(player, session)
	local data = session.Data
	if data.BagKg <= 0.001 then
		return
	end
	local now = os.clock()
	if now - session.LastSell < Economy.SellCooldown then
		return
	end
	session.LastSell = now
	local stats = GameConfig.ComputeStats(data)
	local kg = data.BagKg
	local value = math.max(1, math.floor(kg * stats.SellPrice * stats.ValueMultiplier + 0.5))
	data.BagKg = 0
	data.Cash += value
	data.Stats.TotalEarned += value
	WorldBuilder.AnimateSale(kg, value, player.DisplayName)
	notify(player, { Kind = "Sell", Kg = kg, Cash = value, Multiplier = stats.ValueMultiplier })
	pushState(player)
end

local sellAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	sellAccumulator += dt
	if sellAccumulator < 0.2 then
		return
	end
	sellAccumulator = 0
	for player, session in pairs(Sessions) do
		if session.Loaded then
			local root = getRoot(player)
			if root then
				if WorldBuilder.IsOnSellPad(root.Position) then
					trySell(player, session)
				end
				-- void safety: anyone who somehow falls gets returned to spawn
				if root.Position.Y < LotService.Min.Y - 12 and WorldBuilder.Refs.Spawn then
					player.Character:PivotTo(WorldBuilder.Refs.Spawn.CFrame + Vector3.new(0, 4, 0))
				end
			end
		end
	end
end)

--------------------------------------------------------------------------
-- PURCHASES (server validated)
--------------------------------------------------------------------------
local function equipTool(player, session, toolId)
	session.Data.EquippedTool = toolId
	attachTool(player)
end

local function handlePurchase(player, kind, id)
	local session = Sessions[player]
	if not session or not session.Loaded then
		return false, "Still loading..."
	end
	if type(kind) ~= "string" then
		return false, "Invalid request"
	end
	local now = os.clock()
	if now - session.LastPurchase < 0.15 then
		return false, "Slow down!"
	end
	session.LastPurchase = now
	local data = session.Data

	if kind == "Tool" or kind == "Equip" then
		if type(id) ~= "string" then
			return false, "Invalid tool"
		end
		local tool = GameConfig.GetTool(id)
		if not tool then
			return false, "Unknown tool"
		end
		if data.OwnedTools[id] then
			if data.EquippedTool == id then
				return true, tool.Name .. " already equipped"
			end
			equipTool(player, session, id)
			pushState(player)
			return true, "Equipped " .. tool.Name
		end
		if kind == "Equip" then
			return false, "You don't own that yet"
		end
		local previous = GameConfig.Tools[tool.Tier - 1]
		if previous and not data.OwnedTools[previous.Id] then
			return false, "Unlock the " .. previous.Name .. " first"
		end
		if data.Cash < tool.Price then
			return false, "Not enough cash"
		end
		data.Cash -= tool.Price
		data.OwnedTools[id] = true
		equipTool(player, session, id)
		pushState(player)
		return true, "Bought the " .. tool.Name .. "!"
	elseif kind == "Bag" then
		local tier = tonumber(id)
		if not tier then
			return false, "Invalid bag"
		end
		tier = math.floor(tier)
		local bag = GameConfig.GetBag(tier)
		if not bag then
			return false, "Unknown bag"
		end
		if tier <= data.BagTier then
			return false, "Already owned"
		end
		if tier ~= data.BagTier + 1 then
			return false, "Upgrade your bag in order"
		end
		if data.Cash < bag.Price then
			return false, "Not enough cash"
		end
		data.Cash -= bag.Price
		data.BagTier = tier
		pushState(player)
		return true, "Upgraded to the " .. bag.Name .. "!"
	elseif kind == "Skill" then
		if type(id) ~= "string" then
			return false, "Invalid skill"
		end
		local skill = GameConfig.GetSkill(id)
		if not skill then
			return false, "Unknown skill"
		end
		local level = data.Skills[id] or 0
		local cost = GameConfig.GetSkillCost(id, level)
		if not cost then
			return false, "Already maxed"
		end
		if data.Cash < cost then
			return false, "Not enough cash"
		end
		data.Cash -= cost
		data.Skills[id] = level + 1
		if id == "WalkSpeed" then
			applyWalkSpeed(player)
		end
		pushState(player)
		return true, string.format("%s upgraded to level %d!", skill.Name, level + 1)
	end
	return false, "Unknown purchase"
end

Remotes.Purchase.OnServerInvoke = function(player, kind, id)
	local ok, success, message = pcall(handlePurchase, player, kind, id)
	if not ok then
		warn("[Sandsweep] Purchase error:", success)
		return false, "Something went wrong"
	end
	return success, message
end

Remotes.GetState.OnServerInvoke = function(player)
	local session = Sessions[player]
	if not session or not session.Loaded then
		return { Loaded = false }
	end
	return buildSnapshot(session)
end

if WorldBuilder.Refs.ShopPrompt then
	WorldBuilder.Refs.ShopPrompt.Triggered:Connect(function(player)
		Remotes.OpenMenu:FireClient(player, "Shop")
	end)
end

--------------------------------------------------------------------------
-- FINDS
--------------------------------------------------------------------------
FindsService.OnCollect = function(player, findId)
	local session = Sessions[player]
	if not session or not session.Loaded then
		return false
	end
	local find = GameConfig.GetFind(findId)
	if not find then
		return false
	end
	local data = session.Data
	local isNew = not data.Finds[findId]
	local bonus = isNew and find.Bonus or math.floor(find.Bonus * Economy.DuplicateFindMultiplier)
	data.Finds[findId] = true
	data.Cash += bonus
	data.Stats.TotalEarned += bonus
	data.Stats.FindsCollected += 1
	notify(player, {
		Kind = "Find",
		FindId = findId,
		Bonus = bonus,
		IsNew = isNew,
		Count = Util.CountKeys(data.Finds),
		Total = #GameConfig.Finds,
	})
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			notify(other, { Kind = "Toast", Text = string.format("%s dug up the %s!", player.DisplayName, find.Name), Color = "Ochre" })
		end
	end
	pushState(player)
	WorldBuilder.UpdateLotBoard(LotService.Percent, FindsService.CountRemaining(), LotService.Generating)
	return true
end

FindsService.OnUncovered = function(findId)
	local find = GameConfig.GetFind(findId)
	if find then
		notifyAll({ Kind = "FindUncovered", FindId = findId, Rarity = find.Rarity })
	end
end

--------------------------------------------------------------------------
-- LOT PROGRESS, CLEARING & REGENERATION
--------------------------------------------------------------------------
local function broadcastLot()
	local payload = {
		Name = LotConfig.Name,
		Percent = LotService.Percent,
		Generating = LotService.Generating,
		FindsRemaining = FindsService.CountRemaining(),
	}
	Remotes.LotUpdate:FireAllClients(payload)
	WorldBuilder.UpdateLotBoard(payload.Percent, payload.FindsRemaining, payload.Generating)
end

local regenerating = false
local function regenerateLot()
	if regenerating then
		return
	end
	regenerating = true
	LotService.Generating = true
	for player, session in pairs(Sessions) do
		if session.Loaded then
			local bonus = 0
			if session.ContributedKg > 0 then
				bonus = math.floor(LotConfig.ClearBonusBase + session.ContributedKg * LotConfig.ClearBonusPerKg)
				session.Data.Cash += bonus
				session.Data.Stats.TotalEarned += bonus
				session.Data.Stats.LotsCleared += 1
			end
			notify(player, { Kind = "LotCleared", Bonus = bonus, Contributed = session.ContributedKg, Delay = LotConfig.RegenDelay })
			session.ContributedKg = 0
			pushState(player)
		end
	end
	broadcastLot()
	task.wait(LotConfig.RegenDelay)

	-- lift anyone standing in the pit before the sand returns
	for _, player in ipairs(Players:GetPlayers()) do
		local root = getRoot(player)
		if root and LotService.IsInside(root.Position, 0.5) and root.Position.Y < LotService.Top + 3 and WorldBuilder.Refs.Spawn then
			player.Character:PivotTo(WorldBuilder.Refs.Spawn.CFrame + Vector3.new(0, 4, 0))
		end
	end
	task.wait(0.2)
	LotService.Generate(math.random(1, 100000))
	FindsService.Spawn(math.random(1, 100000))
	broadcastLot()
	notifyAll({ Kind = "LotReady" })
	for player in pairs(Sessions) do
		pushState(player)
	end
	regenerating = false
end

task.spawn(function()
	local fullCheckTimer = 0
	while true do
		task.wait(0.35)
		if not LotService.Generating then
			FindsService.Update(false)
			fullCheckTimer += 0.35
			if fullCheckTimer >= 3 then
				fullCheckTimer = 0
				FindsService.Update(true)
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		if not LotService.Generating and LotService.Dirty then
			LotService.Recount()
			broadcastLot()
			if LotService.IsCleared() then
				task.spawn(regenerateLot)
			end
		end
	end
end)

print(string.format("[Sandsweep] Server ready - %s generated (%.0f cubic studs of sand). Data mode: %s", LotConfig.Name, LotService.InitialVolume, DataService.Mode))
]======]

-- LocalScript: StarterPlayerScripts/SandsweepClient/init.client.lua
created["SandsweepClient"] = make("LocalScript", "SandsweepClient", Containers.SPS)
created["SandsweepClient"].Source = [======[
-- SandsweepClient (LocalScript) - StarterPlayer/StarterPlayerScripts/SandsweepClient
-- Client entry point. Child ModuleScripts: ClientState, Effects, DigController, Interface.

local ClientState = require(script:WaitForChild("ClientState"))
local Effects = require(script:WaitForChild("Effects"))
local DigController = require(script:WaitForChild("DigController"))
local Interface = require(script:WaitForChild("Interface"))

ClientState.Init()
Effects.Init()
Interface.Init({
	OnDigPress = DigController.Press,
})
DigController.Init()
]======]

-- ModuleScript: StarterPlayerScripts/SandsweepClient/ClientState.lua
created["ClientState"] = make("ModuleScript", "ClientState", created["SandsweepClient"])
created["ClientState"].Source = [======[
-- ClientState (ModuleScript) - StarterPlayerScripts/SandsweepClient/ClientState
-- Client mirror of the server-owned state + tiny signal helpers.
-- The client NEVER decides cash, weight or purchases; it only displays them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Sandsweep")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = Shared:WaitForChild("Remotes")

local ClientState = {}

ClientState.State = {
	Loaded = false,
	Cash = 0,
	BagKg = 0,
	BagTier = 1,
	EquippedTool = "Hands",
	OwnedTools = { Hands = true },
	Skills = { DigSpeed = 0, DigRadius = 0, SandValue = 0, WalkSpeed = 0 },
	Finds = {},
	Stats = {},
	Derived = GameConfig.ComputeStats(GameConfig.DefaultData),
	DataMode = "Pending",
}
ClientState.Lot = { Name = GameConfig.Lot.Name, Percent = 0, Generating = false, FindsRemaining = #GameConfig.Finds }
ClientState.UIOpen = false
ClientState.DigHeld = false -- set by the mobile DIG button
ClientState.Crosshair = "idle" -- "idle" | "valid" | "full" | "far" | "outside"

-- Pure-Lua signal (no table copying, safe to pass any value)
local function newSignal()
	local listeners = {}
	local signal = {}
	function signal:Connect(fn)
		listeners[fn] = true
		return {
			Disconnect = function()
				listeners[fn] = nil
			end,
		}
	end
	function signal:Fire(...)
		for fn in pairs(listeners) do
			task.spawn(fn, ...)
		end
	end
	return signal
end

ClientState.Changed = newSignal() -- (state)
ClientState.LotChanged = newSignal() -- (lot)
ClientState.BagChanged = newSignal() -- (bagKg, capacity)
ClientState.Notified = newSignal() -- (payload)
ClientState.DigResult = newSignal() -- (kg, bagKg, capacity, position)
ClientState.MenuRequested = newSignal() -- (menuName)

local function applySnapshot(snapshot)
	if type(snapshot) ~= "table" or not snapshot.Loaded then
		return
	end
	local previousTool = ClientState.State.EquippedTool
	ClientState.State = snapshot
	if snapshot.Lot then
		ClientState.Lot = snapshot.Lot
		ClientState.LotChanged:Fire(ClientState.Lot)
	end
	ClientState.Changed:Fire(snapshot, previousTool)
	ClientState.BagChanged:Fire(snapshot.BagKg, snapshot.Derived.Capacity)
end

function ClientState.Init()
	Remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(applySnapshot)
	Remotes:WaitForChild("LotUpdate").OnClientEvent:Connect(function(lot)
		if type(lot) == "table" then
			ClientState.Lot = lot
			ClientState.LotChanged:Fire(lot)
		end
	end)
	Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			ClientState.Notified:Fire(payload)
		end
	end)
	Remotes:WaitForChild("DigResult").OnClientEvent:Connect(function(kg, bagKg, capacity, position)
		ClientState.State.BagKg = bagKg
		if ClientState.State.Derived then
			ClientState.State.Derived.Capacity = capacity
		end
		ClientState.DigResult:Fire(kg, bagKg, capacity, position)
		ClientState.BagChanged:Fire(bagKg, capacity)
	end)
	Remotes:WaitForChild("OpenMenu").OnClientEvent:Connect(function(menuName)
		ClientState.MenuRequested:Fire(menuName)
	end)

	task.spawn(function()
		local getState = Remotes:WaitForChild("GetState")
		for _ = 1, 60 do
			local ok, snapshot = pcall(function()
				return getState:InvokeServer()
			end)
			if ok and type(snapshot) == "table" and snapshot.Loaded then
				applySnapshot(snapshot)
				return
			end
			task.wait(1)
		end
	end)
end

-- Ask the server to buy/equip something. Returns success, message.
function ClientState.Purchase(kind, id)
	local ok, success, message = pcall(function()
		return Remotes:WaitForChild("Purchase"):InvokeServer(kind, id)
	end)
	if not ok then
		return false, "Connection hiccup - try again"
	end
	return success == true, message or ""
end

function ClientState.GetStats()
	return ClientState.State.Derived or GameConfig.ComputeStats(GameConfig.DefaultData)
end

function ClientState.BagFraction()
	local stats = ClientState.GetStats()
	if stats.Capacity <= 0 then
		return 0
	end
	return math.clamp(ClientState.State.BagKg / stats.Capacity, 0, 1)
end

return ClientState
]======]

-- ModuleScript: StarterPlayerScripts/SandsweepClient/Effects.lua
created["Effects"] = make("ModuleScript", "Effects", created["SandsweepClient"])
created["Effects"].Source = [======[
-- Effects (ModuleScript) - StarterPlayerScripts/SandsweepClient/Effects
-- All client-side juice: sand bursts, suction stream, floating "+kg" text,
-- camera shake, procedural sound shaping, fanfares and ambient desert dust.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Sandsweep")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Util = require(Shared:WaitForChild("Util"))

local Effects = {}

local Palette = GameConfig.Palette
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local fxFolder
local anchorPart
local textAnchor
local burstAttachment
local grainEmitter, dustEmitter
local suctionAttachment, suctionEmitter, suctionDust, suctionBeam
local ambientPart
local soundFolder
local templates = {}
local vacuumSound
local trauma = 0
local shakeTime = 0

local BURST = {
	Hands = { Grains = 8, Dust = 2, Speed = 7 },
	Spoon = { Grains = 10, Dust = 2, Speed = 9 },
	Shovel = { Grains = 24, Dust = 5, Speed = 13 },
	HandVac = { Grains = 5, Dust = 2, Speed = 6 },
	TurbineVac = { Grains = 10, Dust = 4, Speed = 9 },
}

local function newPart(name)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Parent = fxFolder
	return part
end

local function makeSound(name, soundId, volume, effects)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume
	for _, effect in ipairs(effects or {}) do
		effect.Parent = sound
	end
	sound.Parent = soundFolder
	templates[name] = sound
	return sound
end

local function eq(low, mid, high)
	local effect = Instance.new("EqualizerSoundEffect")
	effect.LowGain = low
	effect.MidGain = mid
	effect.HighGain = high
	return effect
end

local function distortion(level)
	local effect = Instance.new("DistortionSoundEffect")
	effect.Level = level
	return effect
end

function Effects.Init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "SandsweepFX_Local"
	fxFolder.Parent = Workspace

	anchorPart = newPart("FxAnchor")
	anchorPart.CFrame = CFrame.new(0, -500, 0)
	textAnchor = newPart("TextAnchor")
	textAnchor.CFrame = CFrame.identity

	-- burst emitters (moved to the hit point, then Emit())
	burstAttachment = Instance.new("Attachment")
	burstAttachment.Name = "Burst"
	burstAttachment.Parent = anchorPart

	grainEmitter = Instance.new("ParticleEmitter")
	grainEmitter.Name = "Grains"
	grainEmitter.Texture = SMOKE
	grainEmitter.Enabled = false
	grainEmitter.Color = ColorSequence.new(Palette.SandLight, Palette.SandDark)
	grainEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0.12) })
	grainEmitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
	grainEmitter.Lifetime = NumberRange.new(0.5, 0.9)
	grainEmitter.Speed = NumberRange.new(6, 12)
	grainEmitter.SpreadAngle = Vector2.new(55, 55)
	grainEmitter.Acceleration = Vector3.new(0, -45, 0)
	grainEmitter.Drag = 1
	grainEmitter.EmissionDirection = Enum.NormalId.Top
	grainEmitter.LightInfluence = 1
	grainEmitter.Parent = burstAttachment

	dustEmitter = Instance.new("ParticleEmitter")
	dustEmitter.Name = "Dust"
	dustEmitter.Texture = SMOKE
	dustEmitter.Enabled = false
	dustEmitter.Color = ColorSequence.new(Palette.SandLight)
	dustEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.4) })
	dustEmitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	dustEmitter.Lifetime = NumberRange.new(0.8, 1.4)
	dustEmitter.Speed = NumberRange.new(1, 3)
	dustEmitter.SpreadAngle = Vector2.new(80, 80)
	dustEmitter.Drag = 2
	dustEmitter.RotSpeed = NumberRange.new(-40, 40)
	dustEmitter.Rotation = NumberRange.new(0, 360)
	dustEmitter.EmissionDirection = Enum.NormalId.Top
	dustEmitter.LightInfluence = 1
	dustEmitter.Parent = burstAttachment

	-- suction stream (vacuums)
	local suctionPart = newPart("Suction")
	suctionAttachment = Instance.new("Attachment")
	suctionAttachment.Name = "SuctionTarget"
	suctionAttachment.Parent = suctionPart

	suctionEmitter = Instance.new("ParticleEmitter")
	suctionEmitter.Name = "Stream"
	suctionEmitter.Texture = SMOKE
	suctionEmitter.Enabled = false
	suctionEmitter.Color = ColorSequence.new(Palette.SandLight, Palette.Sand)
	suctionEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.08) })
	suctionEmitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.6) })
	suctionEmitter.Lifetime = NumberRange.new(0.25, 0.3)
	suctionEmitter.Speed = NumberRange.new(20, 26)
	suctionEmitter.SpreadAngle = Vector2.new(6, 6)
	suctionEmitter.Rate = 80
	suctionEmitter.EmissionDirection = Enum.NormalId.Top
	suctionEmitter.Shape = Enum.ParticleEmitterShape.Sphere
	suctionEmitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	suctionEmitter.LightInfluence = 1
	suctionEmitter.Parent = suctionAttachment

	suctionDust = Instance.new("ParticleEmitter")
	suctionDust.Name = "Swirl"
	suctionDust.Texture = SMOKE
	suctionDust.Enabled = false
	suctionDust.Color = ColorSequence.new(Palette.SandLight)
	suctionDust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0.4) })
	suctionDust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) })
	suctionDust.Lifetime = NumberRange.new(0.4, 0.7)
	suctionDust.Speed = NumberRange.new(0.5, 2)
	suctionDust.SpreadAngle = Vector2.new(180, 180)
	suctionDust.RotSpeed = NumberRange.new(-180, 180)
	suctionDust.Rate = 18
	suctionDust.LightInfluence = 1
	suctionDust.Parent = suctionAttachment

	suctionBeam = Instance.new("Beam")
	suctionBeam.Name = "SuctionBeam"
	suctionBeam.Enabled = false
	suctionBeam.Attachment1 = suctionAttachment
	suctionBeam.Color = ColorSequence.new(Palette.SandLight, Palette.Sand)
	suctionBeam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.85) })
	suctionBeam.Width0 = 0.3
	suctionBeam.Width1 = 1.4
	suctionBeam.FaceCamera = true
	suctionBeam.Segments = 8
	suctionBeam.LightInfluence = 0.6
	suctionBeam.Parent = suctionPart

	-- ambient drifting desert dust around the camera
	ambientPart = newPart("AmbientDust")
	ambientPart.Size = Vector3.new(70, 14, 70)
	local ambient = Instance.new("ParticleEmitter")
	ambient.Name = "Wisps"
	ambient.Texture = SMOKE
	ambient.Color = ColorSequence.new(Palette.SandLight)
	ambient.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 2.5), NumberSequenceKeypoint.new(1, 4) })
	ambient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.88), NumberSequenceKeypoint.new(1, 1) })
	ambient.Lifetime = NumberRange.new(5, 8)
	ambient.Speed = NumberRange.new(0.5, 1.5)
	ambient.Acceleration = Vector3.new(2.5, 0, 1.2)
	ambient.Rate = 5
	ambient.RotSpeed = NumberRange.new(-15, 15)
	ambient.Shape = Enum.ParticleEmitterShape.Box
	ambient.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	ambient.LightInfluence = 1
	ambient.Parent = ambientPart

	-- sounds (built-in engine sounds shaped with EQ/distortion)
	soundFolder = Instance.new("Folder")
	soundFolder.Name = "SandsweepSounds"
	soundFolder.Parent = SoundService
	local S = GameConfig.Sounds
	makeSound("Dig", S.Dig, 0.7, { eq(6, -2, -14) })
	makeSound("Scoop", S.Scoop, 0.5, { eq(4, 0, -10) })
	makeSound("Swing", S.Swing, 0.35, { eq(0, 0, -6) })
	makeSound("Sell", S.Sell, 0.6)
	makeSound("Click", S.Click, 0.4)
	makeSound("Error", S.Error, 0.5, { eq(2, -4, -10) })
	makeSound("Chime", S.Chime, 0.55)
	makeSound("Splash", S.Splash, 0.35, { eq(4, -6, -20) })

	vacuumSound = Instance.new("Sound")
	vacuumSound.Name = "VacuumLoop"
	vacuumSound.SoundId = S.VacuumLoop
	vacuumSound.Looped = true
	vacuumSound.Volume = 0
	eq(-4, 2, -2).Parent = vacuumSound
	local vacuumDistortion = distortion(0)
	vacuumDistortion.Name = "Grit"
	vacuumDistortion.Parent = vacuumSound
	vacuumSound.Parent = soundFolder
end

--------------------------------------------------------------------------
-- SOUND
--------------------------------------------------------------------------
function Effects.Play(name, volumeScale, pitch)
	local template = templates[name]
	if not template then
		return
	end
	local sound = template:Clone()
	sound.Volume = template.Volume * (volumeScale or 1)
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = soundFolder
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	task.delay(4, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

function Effects.Fanfare()
	for index, pitch in ipairs({ 1, 1.26, 1.5, 2 }) do
		task.delay((index - 1) * 0.09, function()
			Effects.Play("Chime", 0.9, pitch)
		end)
	end
end

function Effects.CashRegister()
	Effects.Play("Sell", 1, 1)
	task.delay(0.08, function()
		Effects.Play("Sell", 0.8, 1.5)
	end)
end

--------------------------------------------------------------------------
-- BURSTS & TEXT
--------------------------------------------------------------------------
function Effects.DigBurst(position, toolId, isLocal, volumeScale)
	local preset = BURST[toolId] or BURST.Spoon
	anchorPart.CFrame = CFrame.new(position)
	grainEmitter.Speed = NumberRange.new(preset.Speed * 0.6, preset.Speed)
	grainEmitter:Emit(preset.Grains)
	dustEmitter:Emit(preset.Dust)
	if not isLocal then
		local camera = Workspace.CurrentCamera
		local distance = camera and (camera.CFrame.Position - position).Magnitude or 0
		local volume = math.clamp(1 - distance / 90, 0, 1) * (volumeScale or 0.5)
		if volume > 0.02 then
			Effects.Play("Dig", volume, 0.8 + math.random() * 0.3)
		end
	end
end

function Effects.FloatingText(position, text, color)
	local attachment = Instance.new("Attachment")
	attachment.Parent = textAnchor
	attachment.WorldPosition = position + Vector3.new((math.random() - 0.5) * 0.8, 0.6, (math.random() - 0.5) * 0.8)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 44)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	billboard.Adornee = attachment
	billboard.Parent = attachment

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color or Palette.Cream
	label.TextStrokeColor3 = Palette.Ink
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard

	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(billboard, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 2.4, 0) }):Play()
	task.delay(0.55, function()
		TweenService:Create(label, TweenInfo.new(0.55), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(1.2, function()
		attachment:Destroy()
	end)
end

function Effects.FloatingKg(position, kg)
	Effects.FloatingText(position, string.format("+%s kg", Util.FormatKg(kg)), Palette.Cream)
end

--------------------------------------------------------------------------
-- SUCTION STREAM
--------------------------------------------------------------------------
local vacuumActive = false
function Effects.SetVacuum(active, toolId, tipAttachment, hitPosition)
	local isTurbine = toolId == "TurbineVac"
	if active and tipAttachment and hitPosition then
		local tipPosition = tipAttachment.WorldPosition
		local toTip = tipPosition - hitPosition
		local distance = math.max(0.5, toTip.Magnitude)
		-- orient so the emitter's +Y faces the nozzle
		local look = CFrame.lookAt(hitPosition, tipPosition)
		suctionAttachment.Parent.CFrame = look * CFrame.Angles(-math.pi / 2, 0, 0)
		local lifetime = 0.28
		suctionEmitter.Lifetime = NumberRange.new(lifetime * 0.9, lifetime)
		suctionEmitter.Speed = NumberRange.new(distance / lifetime * 0.9, distance / lifetime)
		suctionEmitter.Rate = isTurbine and 160 or 70
		suctionEmitter.SpreadAngle = isTurbine and Vector2.new(10, 10) or Vector2.new(5, 5)
		suctionEmitter.Size = isTurbine
				and NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.12) })
			or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.08) })
		suctionDust.Rate = isTurbine and 40 or 15
		suctionBeam.Attachment0 = tipAttachment
		suctionBeam.Width0 = isTurbine and 0.7 or 0.3
		suctionBeam.Width1 = isTurbine and 3.2 or 1.4
		suctionBeam.TextureSpeed = 4
		if not vacuumActive then
			vacuumActive = true
			suctionEmitter.Enabled = true
			suctionDust.Enabled = true
			suctionBeam.Enabled = true
		end
	elseif vacuumActive then
		vacuumActive = false
		suctionEmitter.Enabled = false
		suctionDust.Enabled = false
		suctionBeam.Enabled = false
	end
end

-- Motor hum: runs while a vacuum trigger is held (even with no sand in reach)
function Effects.UpdateVacuumSound(running, toolId, loaded, dt)
	if not vacuumSound then
		return
	end
	local isTurbine = toolId == "TurbineVac"
	local targetVolume = running and (isTurbine and 0.55 or 0.35) or 0
	local targetPitch = running and ((isTurbine and 0.95 or 1.55) + (loaded and -0.08 or 0.06)) or 0.6
	vacuumSound.Volume += (targetVolume - vacuumSound.Volume) * math.min(1, dt * 8)
	vacuumSound.PlaybackSpeed += (targetPitch - vacuumSound.PlaybackSpeed) * math.min(1, dt * 5)
	local grit = vacuumSound:FindFirstChild("Grit")
	if grit then
		grit.Level = isTurbine and 0.38 or 0.12
	end
	if vacuumSound.Volume > 0.01 then
		if not vacuumSound.IsPlaying then
			vacuumSound:Play()
		end
	elseif vacuumSound.IsPlaying then
		vacuumSound:Stop()
	end
end

--------------------------------------------------------------------------
-- CAMERA SHAKE (trauma based)
--------------------------------------------------------------------------
function Effects.Shake(amount)
	trauma = math.clamp(trauma + amount, 0, 1)
end

function Effects.GetShake(dt)
	trauma = math.max(0, trauma - dt * 1.8)
	if trauma <= 0 then
		return CFrame.identity
	end
	shakeTime += dt * 28
	local power = trauma * trauma
	local pitch = math.noise(shakeTime, 0.3, 0) * 0.035 * power
	local yaw = math.noise(0.7, shakeTime, 0) * 0.035 * power
	local roll = math.noise(0, 0.4, shakeTime) * 0.025 * power
	return CFrame.Angles(pitch, yaw, roll)
end

function Effects.UpdateAmbient(cameraPosition)
	if ambientPart then
		ambientPart.CFrame = CFrame.new(cameraPosition + Vector3.new(-12, 2, -6))
	end
end

function Effects.GetFolder()
	return fxFolder
end

return Effects
]======]

-- ModuleScript: StarterPlayerScripts/SandsweepClient/DigController.lua
created["DigController"] = make("ModuleScript", "DigController", created["SandsweepClient"])
created["DigController"].Source = [======[
-- DigController (ModuleScript) - StarterPlayerScripts/SandsweepClient/DigController
-- First-person digging: input, camera-centre raycast, request throttling,
-- procedural viewmodel (bob, sway, swing, suction recoil, spinning turbine).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Sandsweep")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ToolModels = require(Shared:WaitForChild("ToolModels"))
local PartKit = require(Shared:WaitForChild("PartKit"))
local Remotes = Shared:WaitForChild("Remotes")

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local DigController = {}

local player = Players.LocalPlayer
local Lot = GameConfig.Lot
local LOT_MIN = Vector3.new(Lot.CenterX - Lot.SizeX / 2, Lot.BottomY, Lot.CenterZ - Lot.SizeZ / 2)
local LOT_MAX = Vector3.new(Lot.CenterX + Lot.SizeX / 2, Lot.BottomY + Lot.Depth, Lot.CenterZ + Lot.SizeZ / 2)

local digRequest
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- input state
local mouseHeld = false
local pressQueued = false
local pressTime = 0
local lastDig = 0
local lastBagWarning = 0

-- viewmodel state
local vm = nil
local swingTime = 1
local swingDuration = 0.3
local equipProgress = 1
local bobTime = 0
local swayPitch, swayYaw = 0, 0
local lastCameraCFrame = nil
local fanAngle, fanSpeed = 0, 0
local suckBlend = 0
local scoopVisibleUntil = 0
local lastFill = -1

-- aggregated floating text for streaming tools
local pendingKg, pendingPosition, pendingTimer = 0, nil, 0

local function easeOutBack(t)
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function insideLot(position)
	return position.X >= LOT_MIN.X - 1 and position.X <= LOT_MAX.X + 1
		and position.Z >= LOT_MIN.Z - 1 and position.Z <= LOT_MAX.Z + 1
		and position.Y >= LOT_MIN.Y - 1 and position.Y <= LOT_MAX.Y + 3
end

--------------------------------------------------------------------------
-- VIEWMODEL
--------------------------------------------------------------------------
local function destroyViewmodel()
	if vm and vm.Model then
		vm.Model:Destroy()
	end
	vm = nil
	Effects.SetVacuum(false)
end

local SLEEVE = Color3.fromRGB(92, 128, 168)
local CUFF = Color3.fromRGB(236, 222, 196)
local DEFAULT_SKIN = Color3.fromRGB(234, 184, 146)
-- direction each forearm runs in CAMERA space (back toward the bottom corners of the screen)
local ARM_DIRECTIONS = {
	Right = Vector3.new(0.5, -0.75, 1).Unit,
	Left = Vector3.new(-0.65, -0.7, 1).Unit,
}

local function skinColor(side)
	local character = player.Character
	local bodyColors = character and character:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		return side == "Left" and bodyColors.LeftArmColor3 or bodyColors.RightArmColor3
	end
	local hand = character and (character:FindFirstChild(side .. "Hand") or character:FindFirstChild(side .. " Arm"))
	return hand and hand.Color or DEFAULT_SKIN
end

-- Procedural first-person arms holding the tool (fist, thumb, wrist, forearm, sleeve)
local function addHands(model, toolId)
	local hands = ToolModels.Hands[toolId]
	local viewOffset = ToolModels.ViewOffsets[toolId]
	if not hands or not viewOffset then
		return
	end
	local base = model:GetPivot()
	for _, hand in ipairs(hands) do
		local skin = skinColor(hand.Side)
		local mirror = hand.Side == "Left" and -1 or 1
		local grip = base * CFrame.new(hand.Position)
		local armDirection = base:VectorToWorldSpace(viewOffset:VectorToObjectSpace(ARM_DIRECTIONS[hand.Side]))
		if hand.Cupped then
			-- open palm, tilted inward like a scoop, with four fingers and a thumb
			local palm = grip * CFrame.Angles(0, 0, math.rad(-22) * mirror)
			PartKit.Ellipsoid(model, Vector3.new(0.62, 0.22, 0.7), palm, { Name = "Palm", Color = skin, CastShadow = false })
			for index = 0, 3 do
				local x = (-0.22 + index * 0.145) * mirror
				local length = (index == 1 or index == 2) and 0.5 or 0.42
				PartKit.Cylinder(model, length, 0.13, palm * CFrame.new(x, 0.03, -0.32 - length / 2) * CFrame.Angles(math.rad(14), 0, 0), "Z", {
					Name = "Finger",
					Color = skin,
					CastShadow = false,
				})
			end
			PartKit.Cylinder(model, 0.4, 0.15, palm * CFrame.new(-0.36 * mirror, 0.06, -0.12) * CFrame.Angles(0, math.rad(-35) * mirror, 0), "Z", {
				Name = "Thumb",
				Color = skin,
				CastShadow = false,
			})
		else
			-- fist wrapped around the handle
			PartKit.Ellipsoid(model, Vector3.new(0.56, 0.58, 0.64), grip, { Name = "Fist", Color = skin, CastShadow = false })
			for index = 0, 3 do
				PartKit.Ellipsoid(model, Vector3.new(0.2, 0.2, 0.17), grip * CFrame.new(-0.2 * mirror, 0.08 - index * 0.06, -0.22 + index * 0.15), {
					Name = "Knuckle",
					Color = skin:Lerp(Color3.new(0, 0, 0), 0.06),
					CastShadow = false,
				})
			end
			PartKit.Ellipsoid(model, Vector3.new(0.2, 0.2, 0.46), grip * CFrame.new(0.1 * mirror, 0.27, -0.12) * CFrame.Angles(math.rad(-12), 0, 0), {
				Name = "Thumb",
				Color = skin,
				CastShadow = false,
			})
		end
		-- forearm, cuff and sleeve running back toward the camera
		local wrist = grip.Position + armDirection * 0.25
		local function along(distance)
			return CFrame.lookAt(wrist + armDirection * distance, wrist + armDirection * (distance + 1))
		end
		PartKit.Cylinder(model, 1.5, 0.42, along(0.75), "Z", { Name = "Forearm", Color = skin, CastShadow = false })
		PartKit.Cylinder(model, 0.3, 0.6, along(1.55), "Z", { Name = "Cuff", Color = CUFF, CastShadow = false })
		PartKit.Cylinder(model, 2.6, 0.62, along(2.95), "Z", { Name = "Sleeve", Material = Enum.Material.Fabric, Color = SLEEVE, CastShadow = false })
	end
end

local function buildViewmodel(toolId)
	destroyViewmodel()
	local camera = Workspace.CurrentCamera
	local model = ToolModels.Build(toolId, true)
	model.Name = "SandsweepViewmodel"
	addHands(model, toolId)
	local pivot = model:GetPivot()
	local entry = {
		ToolId = toolId,
		Model = model,
		Parts = {},
		Offsets = {},
		FanParts = {},
		FanRel = {},
		HubOffset = nil,
		Fill = nil,
		Scoop = model:FindFirstChild("SandScoop"),
		Tip = model.PrimaryPart:FindFirstChild("Tip"),
	}
	local fanFolder = model:FindFirstChild("Fan")
	if fanFolder then
		for _, part in ipairs(fanFolder:GetChildren()) do
			if part:GetAttribute("FanHub") then
				entry.HubOffset = pivot:ToObjectSpace(part.CFrame)
			end
		end
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CastShadow = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			local offset = pivot:ToObjectSpace(part.CFrame)
			if fanFolder and part:IsDescendantOf(fanFolder) and entry.HubOffset then
				table.insert(entry.FanParts, part)
				table.insert(entry.FanRel, entry.HubOffset:Inverse() * offset)
			else
				table.insert(entry.Parts, part)
				table.insert(entry.Offsets, offset)
			end
			local axis = part:GetAttribute("FillAxis")
			if part.Name == "SandFill" and axis then
				entry.Fill = {
					Part = part,
					Index = #entry.Parts,
					Axis = axis,
					OriginalSize = part.Size,
					OriginalOffset = offset,
				}
			end
		end
	end
	if entry.Scoop then
		entry.Scoop.Transparency = 1
	end
	model.Parent = camera
	vm = entry
	equipProgress = 0
	lastFill = -1
end

local function updateFill()
	if not vm or not vm.Fill then
		return
	end
	local fill = ClientState.BagFraction()
	if math.abs(fill - lastFill) < 0.01 then
		return
	end
	lastFill = fill
	local info = vm.Fill
	local size = info.OriginalSize
	local axisVector = info.Axis == "X" and Vector3.xAxis or Vector3.zAxis
	local length = info.Axis == "X" and size.X or size.Z
	local newLength = math.max(0.02, length * fill)
	if info.Axis == "X" then
		info.Part.Size = Vector3.new(newLength, size.Y, size.Z)
	else
		info.Part.Size = Vector3.new(size.X, size.Y, newLength)
	end
	info.Part.Transparency = fill < 0.02 and 1 or 0
	vm.Offsets[info.Index] = info.OriginalOffset * CFrame.new(axisVector * ((length - newLength) / 2))
end

local function swingPose(toolId, t)
	if t >= 1 then
		return CFrame.identity
	end
	local a = math.sin(t * math.pi)
	if toolId == "Hands" then
		-- dive down into the sand and scoop back up
		return CFrame.new(0, -0.45 * a, -0.55 * a) * CFrame.Angles(-0.75 * a, 0, 0)
	elseif toolId == "Spoon" then
		return CFrame.new(-0.05 * a, -0.18 * a, -0.4 * a) * CFrame.Angles(-0.95 * a, 0.1 * a, 0.2 * a)
	elseif toolId == "Shovel" then
		-- thrust down & forward, then lift the scoop back up
		local thrust = math.sin(math.min(1, t * 1.6) * math.pi * 0.5)
		local lift = t > 0.55 and math.sin((t - 0.55) / 0.45 * math.pi) or 0
		return CFrame.new(-0.1 * a, -0.5 * thrust + 0.35 * lift, -0.7 * a)
			* CFrame.Angles(-1.0 * thrust + 0.9 * lift, 0.15 * a, 0.3 * a)
	end
	return CFrame.identity
end

local function updateViewmodel(dt, camera)
	if not vm then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		vm.Model.Parent = nil
		return
	end
	if vm.Model.Parent ~= camera then
		vm.Model.Parent = camera
	end

	-- walk bob & idle breathing
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local amplitude = math.min(speed / 16, 1.5)
	bobTime += dt * (4 + speed * 0.45)
	local breathe = math.sin(os.clock() * 1.6) * 0.012
	local bob = CFrame.new(math.cos(bobTime) * 0.035 * amplitude, math.abs(math.sin(bobTime)) * 0.05 * amplitude + breathe, 0)
		* CFrame.Angles(0, 0, math.cos(bobTime) * 0.012 * amplitude)

	-- sway from camera rotation
	if lastCameraCFrame then
		local delta = lastCameraCFrame:ToObjectSpace(camera.CFrame)
		local rx, ry = delta:ToOrientation()
		local alpha = math.min(1, dt * 12)
		swayPitch += (math.clamp(-rx * 2.5, -0.12, 0.12) - swayPitch) * alpha
		swayYaw += (math.clamp(-ry * 2.5, -0.15, 0.15) - swayYaw) * alpha
	end
	lastCameraCFrame = camera.CFrame
	local sway = CFrame.Angles(swayPitch, swayYaw, swayYaw * 0.6)

	-- swing animation
	if swingTime < 1 then
		swingTime = math.min(1, swingTime + dt / swingDuration)
	end
	local swing = swingPose(vm.ToolId, swingTime)
	if vm.Scoop then
		local visible = swingTime > 0.5 and swingTime < 1 or os.clock() < scoopVisibleUntil
		vm.Scoop.Transparency = visible and 0 or 1
	end

	-- suction recoil / vibration
	local tool = GameConfig.GetTool(vm.ToolId)
	local streaming = tool and tool.Mode == "Stream"
	local intensity = vm.ToolId == "TurbineVac" and 2.2 or 1
	local shakeX = (math.noise(os.clock() * 40, 1.3) * 0.012) * suckBlend * intensity
	local shakeY = (math.noise(2.1, os.clock() * 40) * 0.012) * suckBlend * intensity
	local suck = CFrame.new(shakeX, shakeY, 0.06 * suckBlend * intensity) * CFrame.Angles(0.03 * suckBlend, 0, 0)

	-- equip raise
	if equipProgress < 1 then
		equipProgress = math.min(1, equipProgress + dt / 0.35)
	end
	local e = 1 - easeOutBack(equipProgress)
	local equip = CFrame.new(0, -1.1 * e, 0.4 * e) * CFrame.Angles(-0.7 * e, 0, 0)

	local base = camera.CFrame * (ToolModels.ViewOffsets[vm.ToolId] or CFrame.new(1, -1, -2)) * bob * sway * equip * swing * suck

	updateFill()
	local parts, cframes = {}, {}
	for index, part in ipairs(vm.Parts) do
		parts[index] = part
		cframes[index] = base * vm.Offsets[index]
	end
	if vm.HubOffset and #vm.FanParts > 0 then
		local target = streaming and (ClientState.DigHeld or mouseHeld) and not ClientState.UIOpen and 40 or 3
		fanSpeed += (target - fanSpeed) * math.min(1, dt * 2.5)
		fanAngle = (fanAngle + fanSpeed * dt) % (math.pi * 2)
		local hub = base * vm.HubOffset * CFrame.Angles(fanAngle, 0, 0)
		for index, part in ipairs(vm.FanParts) do
			table.insert(parts, part)
			table.insert(cframes, hub * vm.FanRel[index])
		end
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

--------------------------------------------------------------------------
-- DIGGING
--------------------------------------------------------------------------
local function refreshFilter(camera)
	local exclude = { camera }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local fx = Effects.GetFolder()
	if fx then
		table.insert(exclude, fx)
	end
	local world = Workspace:FindFirstChild("SandsweepWorld")
	if world then
		local finds = world:FindFirstChild("Finds")
		if finds then
			table.insert(exclude, finds)
		end
		local ladders = world:FindFirstChild("Ladders", true)
		if ladders then
			table.insert(exclude, ladders)
		end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Character then
			table.insert(exclude, other.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude
end

-- Returns hit position, ray direction, status ("valid", "far", "idle")
local function aim(camera, stats)
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	refreshFilter(camera)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * (stats.Range + 4), rayParams)
	if not result then
		return nil, ray.Direction, "idle"
	end
	if result.Instance ~= Workspace.Terrain or result.Material ~= Enum.Material.Sand then
		return nil, ray.Direction, "idle"
	end
	if not insideLot(result.Position) then
		return nil, ray.Direction, "outside"
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local eye = head and head.Position or ray.Origin
	if (result.Position - eye).Magnitude > stats.Range then
		return nil, ray.Direction, "far"
	end
	return result.Position, ray.Direction, "valid"
end

local function flushFloatingText(force)
	if pendingKg > 0 and pendingPosition and (force or pendingTimer >= 0.35) then
		Effects.FloatingKg(pendingPosition, pendingKg)
		pendingKg, pendingPosition, pendingTimer = 0, nil, 0
	end
end

local function onDigResult(kg, _, _, position)
	local stats = ClientState.GetStats()
	if stats.Mode == "Stream" then
		pendingKg += kg
		pendingPosition = position
		Effects.Play("Dig", 0.25, 1.3 + math.random() * 0.3)
	else
		Effects.FloatingKg(position, kg)
		Effects.Play("Dig", 0.9, 0.75 + math.random() * 0.25)
		Effects.Play("Scoop", 0.6, 0.8 + math.random() * 0.2)
		scoopVisibleUntil = os.clock() + 0.25
	end
end

local function step(dt)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	-- camera shake applied after the default camera update
	camera.CFrame = camera.CFrame * Effects.GetShake(dt)
	Effects.UpdateAmbient(camera.CFrame.Position)

	local state = ClientState.State
	local stats = ClientState.GetStats()
	if not vm or vm.ToolId ~= state.EquippedTool then
		buildViewmodel(state.EquippedTool)
	end

	-- hide our own third-person tool in first person
	local character = player.Character
	local thirdPerson = character and character:FindFirstChild("SandsweepTool")
	if thirdPerson then
		for _, part in ipairs(thirdPerson:GetDescendants()) do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
			end
		end
	end

	local now = os.clock()
	local blocked = ClientState.UIOpen or not state.Loaded
	local holding = (mouseHeld or ClientState.DigHeld) and not blocked
	if pressQueued and now - pressTime > 0.3 then
		pressQueued = false
	end

	local hitPosition, direction, status = aim(camera, stats)
	local full = ClientState.BagFraction() >= 0.999
	if blocked then
		ClientState.Crosshair = "idle"
	elseif status == "valid" and full then
		ClientState.Crosshair = "full"
	else
		ClientState.Crosshair = status
	end

	local streaming = stats.Mode == "Stream"
	local wants = (stats.Mode == "Click" and pressQueued) or (stats.Mode ~= "Click" and (holding or pressQueued))
	if blocked then
		wants = false
	end
	local sucking = streaming and holding and status == "valid" and not full
	suckBlend += ((sucking and 1 or (streaming and holding and 0.35 or 0)) - suckBlend) * math.min(1, dt * 10)

	if wants and now - lastDig >= stats.Cooldown then
		if status == "valid" then
			pressQueued = false
			if full then
				if now - lastBagWarning > 1.2 then
					lastBagWarning = now
					Effects.Play("Error", 0.7, 0.9)
					ClientState.Notified:Fire({ Kind = "BagFull", Local = true })
				end
			else
				lastDig = now
				digRequest:FireServer(hitPosition, direction.Unit)
				local tool = GameConfig.GetTool(stats.ToolId)
				Effects.DigBurst(hitPosition, stats.ToolId, true)
				Effects.Shake(tool and tool.Shake or 0.05)
				if not streaming then
					swingDuration = math.clamp(stats.Cooldown * 0.9, 0.18, 0.4)
					swingTime = 0
					Effects.Play("Swing", 0.8, 0.9 + math.random() * 0.25)
				end
			end
		elseif stats.Mode ~= "Stream" and pressQueued and now - pressTime < 0.05 then
			-- swing at nothing (still feels responsive)
			pressQueued = false
			if swingTime >= 1 then
				swingDuration = math.clamp(stats.Cooldown * 0.9, 0.18, 0.4)
				swingTime = 0
				Effects.Play("Swing", 0.5, 1.1)
			end
		end
	end

	-- suction VFX & motor sound
	Effects.SetVacuum(sucking, stats.ToolId, vm and vm.Tip, hitPosition)
	Effects.UpdateVacuumSound(streaming and holding, stats.ToolId, sucking, dt)

	pendingTimer += dt
	flushFloatingText(false)

	updateViewmodel(dt, camera)
end

--------------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------------
local function isDigInput(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2
end

local EQUIP_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
}

function DigController.Press()
	pressQueued = true
	pressTime = os.clock()
end

function DigController.Init()
	digRequest = Remotes:WaitForChild("DigRequest")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if isDigInput(input) then
			mouseHeld = true
			if not ClientState.UIOpen then
				DigController.Press()
			end
		elseif EQUIP_KEYS[input.KeyCode] then
			local tool = GameConfig.Tools[EQUIP_KEYS[input.KeyCode]]
			if tool and ClientState.State.OwnedTools[tool.Id] and ClientState.State.EquippedTool ~= tool.Id then
				task.spawn(function()
					local ok, message = ClientState.Purchase("Equip", tool.Id)
					if not ok then
						ClientState.Notified:Fire({ Kind = "Toast", Text = message, Color = "Terracotta" })
					end
				end)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isDigInput(input) then
			mouseHeld = false
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		mouseHeld = false
	end)

	ClientState.DigResult:Connect(onDigResult)
	ClientState.Changed:Connect(function(state, previousTool)
		if previousTool and previousTool ~= state.EquippedTool then
			Effects.Play("Click", 1, 0.8)
		end
	end)

	Remotes:WaitForChild("DigFx").OnClientEvent:Connect(function(digger, position, toolId)
		if digger ~= player and typeof(position) == "Vector3" then
			Effects.DigBurst(position, toolId, false, 0.45)
		end
	end)

	player.CharacterAdded:Connect(function()
		lastCameraCFrame = nil
		equipProgress = 0
		mouseHeld = false
	end)

	RunService:BindToRenderStep("SandsweepDig", Enum.RenderPriority.Camera.Value + 1, step)
end

return DigController
]======]

-- ModuleScript: StarterPlayerScripts/SandsweepClient/Interface.lua
created["Interface"] = make("ModuleScript", "Interface", created["SandsweepClient"])
created["Interface"].Source = [======[
-- Interface (ModuleScript) - StarterPlayerScripts/SandsweepClient/Interface
-- Minimalist warm UI: HUD (cash, bag, lot %, tool), toasts, sell pops, find
-- celebrations, and one tabbed window: Upgrade Shop, Skill Tree, Finds Journal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Sandsweep")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ToolModels = require(Shared:WaitForChild("ToolModels"))
local FindModels = require(Shared:WaitForChild("FindModels"))
local Util = require(Shared:WaitForChild("Util"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local Interface = {}

local player = Players.LocalPlayer
local C = GameConfig.Palette
local TITLE = Enum.Font.FredokaOne
local BODY = Enum.Font.GothamMedium
local BOLD = Enum.Font.GothamBold

local hud = {}
local menu = {}
local shop = { Tab = "Tools", ToolCards = {}, BagCards = {} }
local skills = { Nodes = {}, Lines = {}, Selected = nil }
local journal = { Cards = {}, Selected = nil }
local currentTab = nil
local displayedCash = 0
local displayedBag = 0
local onDigPress = nil

--------------------------------------------------------------------------
-- GUI HELPERS
--------------------------------------------------------------------------
local function new(className, props, children)
	local instance = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

local function stroke(color, thickness, transparency)
	return new("UIStroke", {
		Color = color or C.Ochre,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function padding(all)
	local px = UDim.new(0, all)
	return new("UIPadding", { PaddingTop = px, PaddingBottom = px, PaddingLeft = px, PaddingRight = px })
end

local function text(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or BODY
	props.TextColor3 = props.TextColor3 or C.Ink
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
	if props.TextScaled == nil and props.TextSize == nil then
		props.TextSize = 16
	end
	return new("TextLabel", props)
end

local function card(props, children)
	local radius = props.Radius or 14
	props.Radius = nil
	props.BackgroundColor3 = props.BackgroundColor3 or C.Paper
	props.BorderSizePixel = 0
	local frame = new("Frame", props, children)
	corner(radius).Parent = frame
	return frame
end

local function colorByName(name)
	if typeof(name) == "Color3" then
		return name
	end
	return C[name] or GameConfig.Rarities[name] or C.Ochre
end

local function pressFeedback(button)
	local scale = button:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.95 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.04 }):Play()
	end)
end

local function makeButton(props)
	local button = new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.Color or C.Ochre,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Font = props.Font or BOLD,
		Text = props.Text or "",
		TextColor3 = props.TextColor or C.Cream,
		TextSize = props.TextSize or 16,
		TextScaled = props.TextScaled or false,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	corner(props.Radius or 10).Parent = button
	pressFeedback(button)
	return button
end

local function progressBar(parent, props)
	local track = card({
		Name = props.Name or "Bar",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.Track or Color3.fromRGB(236, 222, 198),
		Radius = props.Radius or 8,
		Parent = parent,
	})
	local fill = card({
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = props.Fill or C.Ochre,
		Radius = props.Radius or 8,
		Parent = track,
	})
	new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(225, 225, 225)),
		Rotation = 90,
		Parent = fill,
	})
	return track, fill
end

-- ViewportFrame showing a model, auto-framed
local function makeViewport(parent, model, props)
	local viewport = new("ViewportFrame", {
		Name = props.Name or "Viewport",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 184, 160),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-1, -1.4, -0.8),
		LayoutOrder = props.LayoutOrder or 0,
		Parent = parent,
	})
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	model.Parent = viewport
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * (props.Zoom or 1.05)
	local direction = (props.Direction or Vector3.new(1, 0.9, 1.2)).Unit
	camera.CFrame = CFrame.lookAt(cf.Position + direction * distance, cf.Position)
	viewport:SetAttribute("Distance", distance)
	return viewport, camera, cf.Position
end

--------------------------------------------------------------------------
-- TOASTS & POPS
--------------------------------------------------------------------------
function Interface.Toast(message, color, icon, duration)
	if not hud.Toasts then
		return
	end
	local accent = colorByName(color)
	local toast = card({
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Paper,
		BackgroundTransparency = 0.02,
		Parent = hud.Toasts,
	}, { stroke(accent, 2), padding(10) })
	toast.LayoutOrder = -math.floor(os.clock() * 100)
	new("Frame", {
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = toast,
	}, { corner(2) })
	text({
		Size = UDim2.new(1, -14, 0, 0),
		Position = UDim2.fromOffset(14, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = (icon and (icon .. "  ") or "") .. tostring(message),
		TextWrapped = true,
		Font = BOLD,
		TextSize = 15,
		Parent = toast,
	})
	local scale = new("UIScale", { Scale = 0.6, Parent = toast })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(duration or 3.2, function()
		if toast.Parent then
			TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
			task.wait(0.22)
			toast:Destroy()
		end
	end)
end

local function popText(message, color, size)
	local label = text({
		Size = UDim2.fromOffset(420, size or 56),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -70),
		Text = message,
		Font = TITLE,
		TextSize = size or 46,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = color or C.Gold,
		TextStrokeColor3 = C.Ink,
		TextStrokeTransparency = 0.3,
		ZIndex = 20,
		Parent = hud.Gui,
	})
	local scale = new("UIScale", { Scale = 0.3, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(label, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.5, -150) }):Play()
	task.delay(0.8, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(1.4, function()
		label:Destroy()
	end)
end

local function confetti(count)
	local colors = { C.Ochre, C.Terracotta, C.Sky, C.Sage, C.Gold, C.Cream }
	local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	for _ = 1, count do
		local piece = new("Frame", {
			Size = UDim2.fromOffset(math.random(6, 12), math.random(10, 18)),
			Position = UDim2.fromOffset(math.random(0, math.floor(viewport.X)), -20),
			BackgroundColor3 = colors[math.random(1, #colors)],
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 30,
			Parent = hud.Gui,
		})
		local duration = 1.6 + math.random() * 1.4
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(piece.Position.X.Offset + math.random(-160, 160), math.floor(viewport.Y) + 30),
			Rotation = piece.Rotation + math.random(-540, 540),
		}):Play()
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

--------------------------------------------------------------------------
-- HUD
--------------------------------------------------------------------------
local function buildHUD(playerGui)
	local gui = new("ScreenGui", {
		Name = "SandsweepHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		Parent = playerGui,
	})
	hud.Gui = gui
	hud.Scale = new("UIScale", { Parent = gui })

	-- CASH
	local cashCard = card({ Name = "Cash", Size = UDim2.fromOffset(236, 66), Position = UDim2.fromOffset(16, 66), Parent = gui }, { stroke(C.Ochre, 2) })
	new("Frame", { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(12, 11), BackgroundColor3 = C.Gold, BorderSizePixel = 0, Parent = cashCard }, {
		corner(22),
		stroke(C.Ochre, 3),
		text({ Size = UDim2.fromScale(1, 1), Text = "$", Font = TITLE, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Ink }),
	})
	text({ Size = UDim2.fromOffset(160, 16), Position = UDim2.fromOffset(66, 10), Text = "CASH", Font = BOLD, TextSize = 12, TextColor3 = C.InkSoft, Parent = cashCard })
	hud.CashLabel = text({ Size = UDim2.fromOffset(164, 34), Position = UDim2.fromOffset(66, 24), Text = "$0", Font = TITLE, TextSize = 30, Parent = cashCard })

	-- FINDS CHIP (opens journal)
	local findsChip = makeButton({ Name = "FindsChip", Size = UDim2.fromOffset(160, 32), Position = UDim2.fromOffset(16, 140), Color = C.Paper, TextColor = C.Ink, Text = "📜  Finds 0/14", TextSize = 14, Parent = gui })
	stroke(C.Ochre, 2).Parent = findsChip
	findsChip.MouseButton1Click:Connect(function()
		Interface.Open("Journal")
	end)
	hud.FindsChip = findsChip

	-- LOT PROGRESS
	local lotCard = card({ Name = "Lot", Size = UDim2.fromOffset(340, 58), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Parent = gui }, { stroke(C.Ochre, 2) })
	hud.LotTitle = text({ Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 6), Text = string.upper(GameConfig.Lot.Name), Font = BOLD, TextSize = 13, TextColor3 = C.InkSoft, Parent = lotCard })
	hud.LotPercent = text({ Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 6), Text = "0.0% cleared", Font = TITLE, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Right, Parent = lotCard })
	local _, lotFill = progressBar(lotCard, { Size = UDim2.new(1, -24, 0, 12), Position = UDim2.fromOffset(12, 34), Fill = C.Sage })
	hud.LotFill = lotFill

	-- BAG
	local bagCard = card({ Name = "Bag", Size = UDim2.fromOffset(460, 72), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Parent = gui }, { stroke(C.Ochre, 2) })
	hud.BagName = text({ Size = UDim2.new(0.6, 0, 0, 22), Position = UDim2.fromOffset(14, 8), Text = "👝  Pocket Pouch", Font = BOLD, TextSize = 16, Parent = bagCard })
	hud.BagWeight = text({ Size = UDim2.new(0.5, 0, 0, 22), Position = UDim2.new(0.5, -14, 0, 8), Text = "0.0 / 15.0 kg", Font = TITLE, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, Parent = bagCard })
	local bagTrack, bagFill = progressBar(bagCard, { Size = UDim2.new(1, -28, 0, 20), Position = UDim2.fromOffset(14, 40), Fill = C.Ochre, Radius = 10 })
	hud.BagTrack = bagTrack
	hud.BagFill = bagFill
	hud.BagCard = bagCard
	hud.BagStroke = bagCard:FindFirstChildOfClass("UIStroke")
	local fullPill = card({ Name = "FullPill", Size = UDim2.fromOffset(330, 32), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8), BackgroundColor3 = C.Terracotta, Radius = 16, Visible = false, Parent = bagCard })
	text({ Size = UDim2.fromScale(1, 1), Text = "BAG FULL - melt it at the Glass Furnace 🔥", Font = BOLD, TextSize = 14, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Center, Parent = fullPill })
	hud.FullPill = fullPill

	-- TOOL
	local toolCard = card({ Name = "Tool", Size = UDim2.fromOffset(260, 72), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -20), Parent = gui }, { stroke(C.Ochre, 2) })
	hud.ToolName = text({ Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 7), Text = "Bare Hands", Font = TITLE, TextSize = 19, Parent = toolCard })
	hud.ToolHint = text({ Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 30), Text = "Click sand to dig", Font = BOLD, TextSize = 12, TextColor3 = C.InkSoft, Parent = toolCard })
	hud.ToolStats = text({ Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 48), Text = "", Font = BODY, TextSize = 12, TextColor3 = C.InkSoft, Parent = toolCard })
	local hotbar = new("Frame", { Name = "Hotbar", Size = UDim2.fromOffset(350, 34), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -100), BackgroundTransparency = 1, Parent = gui }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	hud.Hotbar = {}
	for index, tool in ipairs(GameConfig.Tools) do
		local slot = makeButton({ Name = tool.Id, Size = UDim2.fromOffset(66, 34), Color = C.Paper, TextColor = C.InkSoft, Text = tostring(index), TextSize = 12, LayoutOrder = index, Parent = hotbar })
		stroke(C.Locked, 2).Parent = slot
		slot.MouseButton1Click:Connect(function()
			if ClientState.State.OwnedTools[tool.Id] then
				local ok, message = ClientState.Purchase("Equip", tool.Id)
				if not ok then
					Interface.Toast(message, "Terracotta")
				end
			else
				Interface.Open("Shop")
			end
		end)
		hud.Hotbar[tool.Id] = slot
	end

	-- MENU BUTTONS (right edge on PC; a top-right row on touch so they never cover DIG/Jump)
	local touch = UserInputService.TouchEnabled
	local side = new("Frame", {
		Name = "SideButtons",
		Size = touch and UDim2.fromOffset(230, 70) or UDim2.fromOffset(70, 236),
		AnchorPoint = touch and Vector2.new(1, 0) or Vector2.new(1, 0.5),
		Position = touch and UDim2.new(1, -16, 0, 12) or UDim2.new(1, -16, 0.5, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = touch and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		}),
	})
	for index, spec in ipairs({ { "Shop", "🛠", "B" }, { "Skills", "✦", "K" }, { "Journal", "📖", "J" } }) do
		local button = makeButton({ Name = spec[1], Size = UDim2.fromOffset(70, 70), Color = C.Paper, TextColor = C.Ink, Text = "", LayoutOrder = index, Parent = side })
		stroke(C.Ochre, 2).Parent = button
		text({ Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 6), Text = spec[2], Font = TITLE, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Parent = button })
		text({ Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 44), Text = spec[1] .. "  [" .. spec[3] .. "]", Font = BOLD, TextSize = 11, TextColor3 = C.InkSoft, TextXAlignment = Enum.TextXAlignment.Center, Parent = button })
		button.MouseButton1Click:Connect(function()
			Interface.Toggle(spec[1])
		end)
	end

	-- CROSSHAIR
	local cross = new("Frame", { Name = "Crosshair", Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.Cream, BorderSizePixel = 0, Parent = gui }, {
		corner(5),
		stroke(C.Ink, 1.5, 0.3),
	})
	local ring = new("Frame", { Name = "Ring", Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = gui }, {
		corner(15),
		stroke(C.Cream, 2, 0.2),
	})
	hud.Cross = cross
	hud.Ring = ring
	hud.RingStroke = ring:FindFirstChildOfClass("UIStroke")
	hud.CrossHint = text({ Size = UDim2.fromOffset(240, 18), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 24), Text = "", Font = BOLD, TextSize = 13, TextColor3 = C.Cream, TextStrokeTransparency = 0.4, TextStrokeColor3 = C.Ink, TextXAlignment = Enum.TextXAlignment.Center, Parent = gui })

	-- TOASTS
	hud.Toasts = new("Frame", { Name = "Toasts", Size = UDim2.fromOffset(300, 400), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, touch and 96 or 66), BackgroundTransparency = 1, Parent = gui }, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})

	-- BANNER (lot cleared / fresh sand)
	local banner = card({ Name = "Banner", Size = UDim2.fromOffset(520, 92), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -120), BackgroundColor3 = C.Paper, Parent = gui }, { stroke(C.Gold, 3) })
	hud.BannerTitle = text({ Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 10), Text = "", Font = TITLE, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, Parent = banner })
	hud.BannerBody = text({ Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 52), Text = "", Font = BOLD, TextSize = 15, TextColor3 = C.InkSoft, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Parent = banner })
	hud.Banner = banner

	-- FIND CELEBRATION
	local celebration = card({ Name = "FindCelebration", Size = UDim2.fromOffset(360, 330), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Visible = false, ZIndex = 10, Parent = gui }, { stroke(C.Gold, 4) })
	hud.CelebrationScale = new("UIScale", { Parent = celebration })
	hud.CelebrationHeader = text({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 12), Text = "NEW FIND!", Font = TITLE, TextSize = 28, TextColor3 = C.Terracotta, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = celebration })
	hud.CelebrationView = new("Frame", { Name = "ViewHolder", Size = UDim2.fromOffset(200, 160), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), BackgroundColor3 = C.Cream, BorderSizePixel = 0, ZIndex = 11, Parent = celebration }, { corner(100) })
	hud.CelebrationName = text({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 210), Text = "", Font = TITLE, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = celebration })
	hud.CelebrationRarity = text({ Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 240), Text = "", Font = BOLD, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = celebration })
	hud.CelebrationBonus = text({ Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 262), Text = "", Font = TITLE, TextSize = 26, TextColor3 = C.Sage, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = celebration })
	hud.CelebrationCount = text({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 296), Text = "", Font = BOLD, TextSize = 13, TextColor3 = C.InkSoft, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = celebration })
	hud.Celebration = celebration

	-- MOBILE DIG BUTTON
	if UserInputService.TouchEnabled then
		-- sits above Roblox's Jump button (which occupies roughly the bottom-right 180x150 px)
		local digButton = makeButton({ Name = "DigButton", Size = UDim2.fromOffset(100, 100), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -56, 1, -190), Color = C.Ochre, TextColor = C.Cream, Text = "DIG", Font = TITLE, TextSize = 28, Radius = 48, Parent = gui })
		stroke(C.Cream, 3).Parent = digButton
		digButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				ClientState.DigHeld = true
				if onDigPress then
					onDigPress()
				end
			end
		end)
		digButton.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				ClientState.DigHeld = false
			end
		end)
	end
end

local function refreshHUD(state)
	local stats = state.Derived or ClientState.GetStats()
	local tool = GameConfig.GetTool(state.EquippedTool) or GameConfig.Tools[1]
	local bag = GameConfig.GetBag(state.BagTier) or GameConfig.Bags[1]
	hud.ToolName.Text = string.format("%s  ·  Tier %d", tool.Name, tool.Tier)
	if tool.Mode == "Click" then
		hud.ToolHint.Text = "Click sand to dig  ·  1-5 swap tools"
	elseif tool.Mode == "Hold" then
		hud.ToolHint.Text = "Click or hold to dig  ·  1-5 swap tools"
	else
		hud.ToolHint.Text = "Hold to vacuum  ·  1-5 swap tools"
	end
	hud.ToolStats.Text = string.format("Radius %.1f  ·  %.2fs  ·  x%.1f value", stats.Radius, stats.Cooldown, stats.ValueMultiplier)
	hud.BagName.Text = string.format("%s  %s", bag.Icon, bag.Name)
	hud.FindsChip.Text = string.format("📜  Finds %d/%d", Util.CountKeys(state.Finds or {}), #GameConfig.Finds)
	for _, item in ipairs(GameConfig.Tools) do
		local slot = hud.Hotbar[item.Id]
		local owned = state.OwnedTools and state.OwnedTools[item.Id]
		local equipped = state.EquippedTool == item.Id
		slot.Text = owned and string.format("%d %s", item.Index, item.Short or item.Id) or string.format("%d 🔒", item.Index)
		slot.TextColor3 = equipped and C.Cream or (owned and C.Ink or C.InkSoft)
		slot.BackgroundColor3 = equipped and C.Ochre or C.Paper
		local slotStroke = slot:FindFirstChildOfClass("UIStroke")
		if slotStroke then
			slotStroke.Color = equipped and C.Ink or (owned and C.Ochre or C.Locked)
		end
	end
	if menu.CashLabel then
		menu.CashLabel.Text = Util.FormatCash(state.Cash)
	end
end

local function refreshLot(lot)
	if lot.Generating then
		hud.LotPercent.Text = "fresh sand incoming..."
		TweenService:Create(hud.LotFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(0, 1) }):Play()
		return
	end
	hud.LotPercent.Text = string.format("%s cleared", Util.FormatPercent(lot.Percent >= GameConfig.Lot.ClearedThreshold and 1 or lot.Percent))
	TweenService:Create(hud.LotFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(lot.Percent, 0, 1), 1) }):Play()
end

local function showBanner(title, body, color, duration)
	hud.BannerTitle.Text = title
	hud.BannerTitle.TextColor3 = colorByName(color or "Ink")
	hud.BannerBody.Text = body
	TweenService:Create(hud.Banner, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 84) }):Play()
	task.delay(duration or 4, function()
		TweenService:Create(hud.Banner, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -120) }):Play()
	end)
end

--------------------------------------------------------------------------
-- MENU WINDOW (tabs: Shop, Skills, Journal)
--------------------------------------------------------------------------
local function buildMenu(playerGui)
	local gui = new("ScreenGui", {
		Name = "SandsweepMenus",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Enabled = true,
		Parent = playerGui,
	})
	menu.Gui = gui
	-- Modal backdrop frees the mouse from first-person lock while a menu is open
	local backdrop = new("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.55,
		AutoButtonColor = false,
		Text = "",
		Modal = true,
		Visible = false,
		Parent = gui,
	})
	backdrop.MouseButton1Click:Connect(function()
		Interface.Close()
	end)
	menu.Backdrop = backdrop

	local window = card({ Name = "Window", Size = UDim2.fromOffset(780, 540), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.Cream, Radius = 20, Visible = false, Parent = gui }, { stroke(C.Ochre, 3) })
	menu.Window = window
	menu.Scale = new("UIScale", { Parent = window })
	-- swallow clicks so they don't reach the backdrop
	new("TextButton", { Name = "Blocker", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = window })

	local header = new("Frame", { Name = "Header", Size = UDim2.new(1, -32, 0, 56), Position = UDim2.fromOffset(16, 12), BackgroundTransparency = 1, Parent = window })
	menu.Title = text({ Size = UDim2.fromOffset(260, 30), Position = UDim2.fromOffset(0, 0), Text = "Upgrade Shop", Font = TITLE, TextSize = 28, Parent = header })
	menu.Subtitle = text({ Size = UDim2.fromOffset(300, 18), Position = UDim2.fromOffset(0, 32), Text = "", Font = BOLD, TextSize = 13, TextColor3 = C.InkSoft, Parent = header })

	local tabs = new("Frame", { Name = "Tabs", Size = UDim2.fromOffset(330, 40), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 30, 0, 6), BackgroundTransparency = 1, Parent = header }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	menu.TabButtons = {}
	for index, spec in ipairs({ { "Shop", "🛠 Shop" }, { "Skills", "✦ Skills" }, { "Journal", "📖 Journal" } }) do
		local tabButton = makeButton({ Name = spec[1], Size = UDim2.fromOffset(104, 38), Color = C.Paper, TextColor = C.Ink, Text = spec[2], TextSize = 15, LayoutOrder = index, Parent = tabs })
		stroke(C.Ochre, 2).Parent = tabButton
		tabButton.MouseButton1Click:Connect(function()
			Interface.Open(spec[1])
		end)
		menu.TabButtons[spec[1]] = tabButton
	end

	local cashPill = card({ Name = "CashPill", Size = UDim2.fromOffset(130, 36), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -50, 0, 8), BackgroundColor3 = C.Gold, Radius = 18, Parent = header }, { stroke(C.Ochre, 2) })
	menu.CashLabel = text({ Size = UDim2.fromScale(1, 1), Text = "$0", Font = TITLE, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Parent = cashPill })
	local close = makeButton({ Name = "Close", Size = UDim2.fromOffset(38, 38), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 7), Color = C.Terracotta, Text = "✕", TextSize = 18, Radius = 19, Parent = header })
	close.MouseButton1Click:Connect(function()
		Interface.Close()
	end)

	local content = new("Frame", { Name = "Content", Size = UDim2.new(1, -32, 1, -88), Position = UDim2.fromOffset(16, 76), BackgroundTransparency = 1, Parent = window })
	menu.Content = content
	menu.Pages = {}
	for _, name in ipairs({ "Shop", "Skills", "Journal" }) do
		menu.Pages[name] = new("Frame", { Name = name .. "Page", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = content })
	end
end

--------------------------------------------------------------------------
-- SHOP PAGE
--------------------------------------------------------------------------
local function buildShop()
	local page = menu.Pages.Shop
	local subTabs = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = page }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	shop.SubButtons = {}
	for index, spec in ipairs({ { "Tools", "Tools" }, { "Bags", "Bags & Tanks" } }) do
		local button = makeButton({ Name = spec[1], Size = UDim2.fromOffset(130, 32), Color = C.Paper, TextColor = C.Ink, Text = spec[2], TextSize = 14, LayoutOrder = index, Parent = subTabs })
		button.MouseButton1Click:Connect(function()
			shop.Tab = spec[1]
			Effects.Play("Click", 0.8, 1.1)
			Interface.RefreshShop()
		end)
		shop.SubButtons[spec[1]] = button
	end

	local function makeList(name)
		return new("ScrollingFrame", {
			Name = name,
			Size = UDim2.new(1, 0, 1, -44),
			Position = UDim2.fromOffset(0, 44),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = C.Ochre,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = page,
		}, {
			new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
			new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6) }),
		})
	end
	shop.ToolList = makeList("ToolList")
	shop.BagList = makeList("BagList")

	for index, tool in ipairs(GameConfig.Tools) do
		local row = card({ Name = tool.Id, Size = UDim2.new(1, 0, 0, 108), LayoutOrder = index, BackgroundColor3 = C.Paper, Parent = shop.ToolList }, { stroke(C.Ochre, 2) })
		local holder = new("Frame", { Size = UDim2.fromOffset(92, 92), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C.Cream, BorderSizePixel = 0, Parent = row }, { corner(46) })
		if tool.Id == "Hands" then
			text({ Size = UDim2.fromScale(1, 1), Text = "✋", Font = TITLE, TextSize = 46, TextXAlignment = Enum.TextXAlignment.Center, Parent = holder })
		else
			makeViewport(holder, ToolModels.Build(tool.Id, true), { Size = UDim2.fromScale(1, 1), Direction = Vector3.new(1.4, 0.8, 0.3), Zoom = 0.9 })
		end
		text({ Size = UDim2.new(1, -280, 0, 26), Position = UDim2.fromOffset(112, 8), Text = tool.Name, Font = TITLE, TextSize = 22, Parent = row })
		local modeText = tool.Mode == "Click" and "Click to dig" or (tool.Mode == "Hold" and "Click / hold" or "Hold to vacuum")
		text({ Size = UDim2.new(1, -280, 0, 18), Position = UDim2.fromOffset(112, 36), Text = string.format("Tier %d  ·  Radius %.1f  ·  every %.2fs  ·  %s", tool.Tier, tool.Radius, tool.Cooldown, modeText), Font = BOLD, TextSize = 13, TextColor3 = C.Terracotta, Parent = row })
		text({ Size = UDim2.new(1, -280, 0, 36), Position = UDim2.fromOffset(112, 58), Text = tool.Description, TextWrapped = true, TextSize = 13, TextColor3 = C.InkSoft, TextYAlignment = Enum.TextYAlignment.Top, Parent = row })
		local action = makeButton({ Name = "Action", Size = UDim2.fromOffset(150, 46), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Text = "", TextSize = 16, Parent = row })
		action.MouseButton1Click:Connect(function()
			local state = ClientState.State
			local kind = state.OwnedTools[tool.Id] and "Equip" or "Tool"
			local ok, message = ClientState.Purchase(kind, tool.Id)
			if ok then
				Effects.Play(kind == "Tool" and "Sell" or "Click", 0.9, kind == "Tool" and 1.3 or 1)
				if kind == "Tool" then
					confetti(30)
				end
				Interface.Toast(message, "Sage", "✓")
			else
				Effects.Play("Error", 0.6, 1)
				Interface.Toast(message, "Terracotta")
			end
		end)
		shop.ToolCards[tool.Id] = { Row = row, Action = action }
	end

	for index, bag in ipairs(GameConfig.Bags) do
		local row = card({ Name = bag.Name, Size = UDim2.new(1, 0, 0, 84), LayoutOrder = index, BackgroundColor3 = C.Paper, Parent = shop.BagList }, { stroke(C.Ochre, 2) })
		new("Frame", { Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = C.Cream, BorderSizePixel = 0, Parent = row }, {
			corner(32),
			text({ Size = UDim2.fromScale(1, 1), Text = bag.Icon, Font = TITLE, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center }),
		})
		text({ Size = UDim2.new(1, -260, 0, 24), Position = UDim2.fromOffset(88, 10), Text = bag.Name, Font = TITLE, TextSize = 20, Parent = row })
		text({ Size = UDim2.new(1, -260, 0, 18), Position = UDim2.fromOffset(88, 36), Text = string.format("Tier %d  ·  Holds %s kg", bag.Tier, Util.Commas(bag.Capacity)), Font = BOLD, TextSize = 13, TextColor3 = C.Terracotta, Parent = row })
		text({ Size = UDim2.new(1, -260, 0, 18), Position = UDim2.fromOffset(88, 56), Text = bag.Description, TextSize = 13, TextColor3 = C.InkSoft, Parent = row })
		local action = makeButton({ Name = "Action", Size = UDim2.fromOffset(150, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Text = "", TextSize = 16, Parent = row })
		action.MouseButton1Click:Connect(function()
			local ok, message = ClientState.Purchase("Bag", bag.Tier)
			if ok then
				Effects.Play("Sell", 0.9, 1.3)
				confetti(24)
				Interface.Toast(message, "Sage", "✓")
			else
				Effects.Play("Error", 0.6, 1)
				Interface.Toast(message, "Terracotta")
			end
		end)
		shop.BagCards[bag.Tier] = { Row = row, Action = action }
	end
end

local function styleAction(button, label, color, textColor, enabled)
	button.Text = label
	button.BackgroundColor3 = color
	button.TextColor3 = textColor or C.Cream
	button.Active = enabled
	button.AutoButtonColor = false
end

function Interface.RefreshShop()
	if not shop.ToolList then
		return
	end
	local state = ClientState.State
	shop.ToolList.Visible = shop.Tab == "Tools"
	shop.BagList.Visible = shop.Tab == "Bags"
	for name, button in pairs(shop.SubButtons) do
		local active = name == shop.Tab
		button.BackgroundColor3 = active and C.Ochre or C.Paper
		button.TextColor3 = active and C.Cream or C.Ink
	end
	for _, tool in ipairs(GameConfig.Tools) do
		local entry = shop.ToolCards[tool.Id]
		local owned = state.OwnedTools[tool.Id]
		local previous = GameConfig.Tools[tool.Tier - 1]
		local unlocked = not previous or state.OwnedTools[previous.Id]
		if owned and state.EquippedTool == tool.Id then
			styleAction(entry.Action, "Equipped ✓", C.Sage, C.Cream, false)
		elseif owned then
			styleAction(entry.Action, "Equip", C.Sky, C.Ink, true)
		elseif not unlocked then
			styleAction(entry.Action, "🔒 " .. Util.FormatCash(tool.Price), C.Locked, C.Ink, false)
		elseif state.Cash >= tool.Price then
			styleAction(entry.Action, "Buy " .. Util.FormatCash(tool.Price), C.Ochre, C.Cream, true)
		else
			styleAction(entry.Action, Util.FormatCash(tool.Price), Color3.fromRGB(226, 206, 176), C.InkSoft, true)
		end
	end
	for _, bag in ipairs(GameConfig.Bags) do
		local entry = shop.BagCards[bag.Tier]
		if bag.Tier < state.BagTier then
			styleAction(entry.Action, "Owned ✓", C.Locked, C.Ink, false)
		elseif bag.Tier == state.BagTier then
			styleAction(entry.Action, "Current ✓", C.Sage, C.Cream, false)
		elseif bag.Tier == state.BagTier + 1 then
			if state.Cash >= bag.Price then
				styleAction(entry.Action, "Upgrade " .. Util.FormatCash(bag.Price), C.Ochre, C.Cream, true)
			else
				styleAction(entry.Action, Util.FormatCash(bag.Price), Color3.fromRGB(226, 206, 176), C.InkSoft, true)
			end
		else
			styleAction(entry.Action, "🔒 " .. Util.FormatCash(bag.Price), C.Locked, C.Ink, false)
		end
	end
end

--------------------------------------------------------------------------
-- SKILL TREE PAGE
--------------------------------------------------------------------------
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

local function drawLine(parent, a, b, thickness, color)
	local delta = b - a
	local line = new("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		Size = UDim2.fromOffset(delta.Magnitude, thickness),
		Rotation = math.deg(math.atan2(delta.Y, delta.X)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = parent,
	}, { corner(thickness / 2) })
	return line
end

local function buildSkills()
	local page = menu.Pages.Skills
	local canvas = card({ Name = "Canvas", Size = UDim2.new(1, 0, 1, -122), BackgroundColor3 = C.Paper, Parent = page }, { stroke(C.Ochre, 2) })
	skills.Canvas = canvas
	-- subtle dotted backdrop
	for gx = 0, 14 do
		for gy = 0, 6 do
			new("Frame", { Size = UDim2.fromOffset(3, 3), Position = UDim2.fromOffset(18 + gx * 50, 16 + gy * 46), BackgroundColor3 = Color3.fromRGB(236, 222, 198), BorderSizePixel = 0, Parent = canvas }, { corner(2) })
		end
	end

	local rootPos = Vector2.new(64, 160)
	local rowYs = { 44, 122, 200, 278 }
	local startX, spacing = 170, 56
	local NODE = 44

	-- lines first (under nodes)
	for index, skill in ipairs(GameConfig.Skills) do
		local y = rowYs[index]
		skills.Lines[skill.Id] = {}
		local firstPos = Vector2.new(startX, y)
		skills.Lines[skill.Id][1] = drawLine(canvas, rootPos, firstPos, 5, C.Locked)
		for level = 2, skill.MaxLevel do
			local a = Vector2.new(startX + (level - 2) * spacing, y)
			local b = Vector2.new(startX + (level - 1) * spacing, y)
			skills.Lines[skill.Id][level] = drawLine(canvas, a, b, 5, C.Locked)
		end
	end

	-- root node
	local root = makeButton({ Name = "Root", Size = UDim2.fromOffset(72, 72), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(rootPos.X, rootPos.Y), Color = C.Gold, TextColor = C.Ink, Text = "🌵", Font = TITLE, TextSize = 32, Radius = 36, Parent = canvas })
	root.ZIndex = 3
	stroke(C.Ochre, 3).Parent = root
	root.MouseButton1Click:Connect(function()
		skills.Selected = nil
		Effects.Play("Click", 0.7, 1.2)
		Interface.RefreshSkills()
	end)

	for index, skill in ipairs(GameConfig.Skills) do
		local y = rowYs[index]
		skills.Nodes[skill.Id] = {}
		for level = 1, skill.MaxLevel do
			local x = startX + (level - 1) * spacing
			local node = makeButton({
				Name = skill.Id .. level,
				Size = UDim2.fromOffset(NODE, NODE),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(x, y),
				Color = C.Cream,
				TextColor = C.InkSoft,
				Text = ROMAN[level] or tostring(level),
				Font = TITLE,
				TextSize = 16,
				Radius = NODE / 2,
				Parent = canvas,
			})
			node.ZIndex = 3
			stroke(C.Locked, 3).Parent = node
			node.MouseButton1Click:Connect(function()
				skills.Selected = { Id = skill.Id, Level = level }
				Effects.Play("Click", 0.7, 1 + level * 0.05)
				Interface.RefreshSkills()
			end)
			skills.Nodes[skill.Id][level] = node
		end
		local labelX = startX + (skill.MaxLevel - 1) * spacing + 32
		skills.Nodes[skill.Id].Label = text({
			Size = UDim2.fromOffset(150, 40),
			Position = UDim2.fromOffset(labelX, y - 20),
			Text = "",
			Font = BOLD,
			TextSize = 13,
			RichText = true,
			Parent = canvas,
		})
	end

	-- details panel
	local details = card({ Name = "Details", Size = UDim2.new(1, 0, 0, 110), Position = UDim2.new(0, 0, 1, -110), BackgroundColor3 = C.Paper, Parent = page }, { stroke(C.Ochre, 2) })
	skills.DetailTitle = text({ Size = UDim2.new(1, -220, 0, 28), Position = UDim2.fromOffset(16, 10), Text = "", Font = TITLE, TextSize = 22, Parent = details })
	skills.DetailBody = text({ Size = UDim2.new(1, -220, 0, 40), Position = UDim2.fromOffset(16, 40), Text = "", TextWrapped = true, TextSize = 14, TextColor3 = C.InkSoft, TextYAlignment = Enum.TextYAlignment.Top, Parent = details })
	skills.DetailEffect = text({ Size = UDim2.new(1, -220, 0, 20), Position = UDim2.fromOffset(16, 80), Text = "", Font = BOLD, TextSize = 14, TextColor3 = C.Terracotta, RichText = true, Parent = details })
	local unlock = makeButton({ Name = "Unlock", Size = UDim2.fromOffset(180, 52), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Text = "", TextSize = 16, Parent = details })
	unlock.MouseButton1Click:Connect(function()
		local selected = skills.Selected
		if not selected then
			return
		end
		local current = ClientState.State.Skills[selected.Id] or 0
		if selected.Level ~= current + 1 then
			return
		end
		local ok, message = ClientState.Purchase("Skill", selected.Id)
		if ok then
			Effects.Fanfare()
			confetti(20)
			Interface.Toast(message, "Sage", "✦")
			local skill = GameConfig.GetSkill(selected.Id)
			if skill and selected.Level < skill.MaxLevel then
				skills.Selected = { Id = selected.Id, Level = selected.Level + 1 }
			end
		else
			Effects.Play("Error", 0.6, 1)
			Interface.Toast(message, "Terracotta")
		end
		Interface.RefreshSkills()
	end)
	skills.Unlock = unlock
end

function Interface.RefreshSkills()
	if not skills.Canvas then
		return
	end
	local state = ClientState.State
	for _, skill in ipairs(GameConfig.Skills) do
		local current = state.Skills[skill.Id] or 0
		for level = 1, skill.MaxLevel do
			local node = skills.Nodes[skill.Id][level]
			local nodeStroke = node:FindFirstChildOfClass("UIStroke")
			local line = skills.Lines[skill.Id][level]
			local selected = skills.Selected and skills.Selected.Id == skill.Id and skills.Selected.Level == level
			if level <= current then
				node.BackgroundColor3 = skill.Color
				node.TextColor3 = C.Cream
				nodeStroke.Color = selected and C.Ink or C.Ochre
				line.BackgroundColor3 = skill.Color
			elseif level == current + 1 then
				local cost = GameConfig.GetSkillCost(skill.Id, current)
				node.BackgroundColor3 = C.Cream
				node.TextColor3 = C.Ink
				nodeStroke.Color = selected and C.Ink or skill.Color
				line.BackgroundColor3 = (cost and state.Cash >= cost) and skill.Color:Lerp(C.Cream, 0.4) or C.Locked
			else
				node.BackgroundColor3 = Color3.fromRGB(236, 228, 216)
				node.TextColor3 = C.Locked
				nodeStroke.Color = selected and C.Ink or C.Locked
				line.BackgroundColor3 = C.Locked
			end
			nodeStroke.Thickness = selected and 4 or 3
		end
		skills.Nodes[skill.Id].Label.Text = string.format("%s %s\n<font color=\"#8A6C56\">%s</font>", skill.Icon, skill.Name, current > 0 and GameConfig.DescribeSkillEffect(skill.Id, current) or "not learned")
	end

	local selected = skills.Selected
	if not selected then
		local total, maxTotal = 0, 0
		for _, skill in ipairs(GameConfig.Skills) do
			total += state.Skills[skill.Id] or 0
			maxTotal += skill.MaxLevel
		end
		skills.DetailTitle.Text = GameConfig.SkillRoot.Name
		skills.DetailBody.Text = GameConfig.SkillRoot.Description .. " Pick a node to see its upgrade."
		skills.DetailEffect.Text = string.format("%d / %d nodes unlocked", total, maxTotal)
		styleAction(skills.Unlock, "Select a node", C.Locked, C.Ink, false)
		return
	end
	local skill = GameConfig.GetSkill(selected.Id)
	local current = state.Skills[skill.Id] or 0
	skills.DetailTitle.Text = string.format("%s %s %s", skill.Icon, skill.Name, ROMAN[selected.Level] or tostring(selected.Level))
	skills.DetailBody.Text = skill.Description
	skills.DetailEffect.Text = string.format("Now: %s   →   At %s: <b>%s</b>", current > 0 and GameConfig.DescribeSkillEffect(skill.Id, current) or "none", ROMAN[selected.Level] or tostring(selected.Level), GameConfig.DescribeSkillEffect(skill.Id, selected.Level))
	if selected.Level <= current then
		styleAction(skills.Unlock, "Learned ✓", C.Sage, C.Cream, false)
	elseif selected.Level == current + 1 then
		local cost = GameConfig.GetSkillCost(skill.Id, current)
		if cost and state.Cash >= cost then
			styleAction(skills.Unlock, "Unlock " .. Util.FormatCash(cost), C.Ochre, C.Cream, true)
		else
			styleAction(skills.Unlock, "Need " .. Util.FormatCash(cost or 0), Color3.fromRGB(226, 206, 176), C.InkSoft, true)
		end
	else
		styleAction(skills.Unlock, "🔒 Unlock " .. (ROMAN[current + 1] or "") .. " first", C.Locked, C.Ink, false)
	end
end

--------------------------------------------------------------------------
-- FINDS JOURNAL PAGE
--------------------------------------------------------------------------
local function depthLabel(find)
	local avg = (find.DepthMin + find.DepthMax) / 2
	if avg < 6.5 then
		return "Shallow"
	elseif avg < 10 then
		return "Mid-depth"
	end
	return "Deep"
end

local function buildJournal()
	local page = menu.Pages.Journal
	local top = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = page })
	journal.Count = text({ Size = UDim2.fromOffset(240, 30), Text = "Discovered 0 / 14", Font = TITLE, TextSize = 20, Parent = top })
	local _, fill = progressBar(top, { Size = UDim2.new(1, -260, 0, 14), Position = UDim2.new(0, 250, 0.5, -7), Fill = C.Gold })
	journal.Fill = fill

	local grid = new("ScrollingFrame", {
		Name = "Grid",
		Size = UDim2.new(1, 0, 1, -148),
		Position = UDim2.fromOffset(0, 42),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Ochre,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = page,
	}, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(98, 136), CellPadding = UDim2.fromOffset(8, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 2) }),
	})

	for index, find in ipairs(GameConfig.Finds) do
		local rarityColor = GameConfig.Rarities[find.Rarity]
		local cardButton = new("TextButton", { Name = find.Id, BackgroundColor3 = C.Paper, AutoButtonColor = false, Text = "", BorderSizePixel = 0, LayoutOrder = index, Parent = grid }, {
			corner(12),
			stroke(rarityColor, 2),
		})
		pressFeedback(cardButton)
		new("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = rarityColor, BorderSizePixel = 0, Parent = cardButton }, { corner(3) })
		local viewport = makeViewport(cardButton, FindModels.Build(find.Id, true), { Size = UDim2.fromOffset(86, 78), Position = UDim2.fromOffset(6, 10), Zoom = 0.95 })
		local name = text({ Size = UDim2.new(1, -8, 0, 30), Position = UDim2.fromOffset(4, 88), Text = "???", Font = BOLD, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Parent = cardButton })
		local rarity = text({ Size = UDim2.new(1, -8, 0, 14), Position = UDim2.fromOffset(4, 118), Text = find.Rarity, Font = BOLD, TextSize = 11, TextColor3 = rarityColor, TextXAlignment = Enum.TextXAlignment.Center, Parent = cardButton })
		cardButton.MouseButton1Click:Connect(function()
			journal.Selected = find.Id
			Effects.Play("Click", 0.6, 1.2)
			Interface.RefreshJournal()
		end)
		journal.Cards[find.Id] = { Button = cardButton, Viewport = viewport, Name = name, Rarity = rarity }
	end

	local details = card({ Name = "Details", Size = UDim2.new(1, 0, 0, 96), Position = UDim2.new(0, 0, 1, -96), BackgroundColor3 = C.Paper, Parent = page }, { stroke(C.Ochre, 2) })
	journal.DetailTitle = text({ Size = UDim2.new(1, -32, 0, 26), Position = UDim2.fromOffset(16, 10), Text = "", Font = TITLE, TextSize = 21, Parent = details })
	journal.DetailMeta = text({ Size = UDim2.new(1, -32, 0, 18), Position = UDim2.fromOffset(16, 38), Text = "", Font = BOLD, TextSize = 13, TextColor3 = C.Terracotta, Parent = details })
	journal.DetailBody = text({ Size = UDim2.new(1, -32, 0, 30), Position = UDim2.fromOffset(16, 58), Text = "", TextWrapped = true, TextSize = 13, TextColor3 = C.InkSoft, TextYAlignment = Enum.TextYAlignment.Top, Parent = details })
end

function Interface.RefreshJournal()
	if not journal.Count then
		return
	end
	local state = ClientState.State
	local found = state.Finds or {}
	local count = Util.CountKeys(found)
	journal.Count.Text = string.format("Discovered %d / %d", count, #GameConfig.Finds)
	TweenService:Create(journal.Fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(count / #GameConfig.Finds, 1) }):Play()
	for _, find in ipairs(GameConfig.Finds) do
		local entry = journal.Cards[find.Id]
		local discovered = found[find.Id] == true
		entry.Viewport.ImageColor3 = discovered and Color3.new(1, 1, 1) or Color3.fromRGB(40, 30, 24)
		entry.Viewport.ImageTransparency = discovered and 0 or 0.35
		entry.Name.Text = discovered and find.Name or "???"
		entry.Button.BackgroundColor3 = (journal.Selected == find.Id) and C.Cream or C.Paper
	end
	local selectedId = journal.Selected
	if not selectedId then
		journal.DetailTitle.Text = "Finds Journal"
		journal.DetailMeta.Text = string.format("%d relics are buried in every lot", #GameConfig.Finds)
		journal.DetailBody.Text = "Dig down until a relic glints, walk up to it and press E to collect. Deeper finds pay more."
		return
	end
	local find = GameConfig.GetFind(selectedId)
	local discovered = found[selectedId] == true
	journal.DetailTitle.Text = discovered and find.Name or "Undiscovered relic"
	journal.DetailMeta.Text = string.format("%s  ·  %s  ·  First find %s  ·  Repeat %s", find.Rarity, depthLabel(find), Util.FormatCash(find.Bonus), Util.FormatCash(math.floor(find.Bonus * GameConfig.Economy.DuplicateFindMultiplier)))
	journal.DetailBody.Text = discovered and find.Description or string.format("Buried roughly %.0f-%.0f studs below the lot's edge. Keep digging!", find.DepthMin, find.DepthMax)
end

--------------------------------------------------------------------------
-- OPEN / CLOSE
--------------------------------------------------------------------------
local SUBTITLES = {
	Shop = "Better tools, bigger bags",
	Skills = "Passive upgrades that stack forever",
	Journal = "Every relic you've pulled from the sand",
}
local TITLES = { Shop = "Upgrade Shop", Skills = "Skill Tree", Journal = "Finds Journal" }

function Interface.Open(tab)
	if not menu.Pages or not menu.Pages[tab] then
		return
	end
	local wasOpen = currentTab ~= nil
	currentTab = tab
	ClientState.UIOpen = true
	ClientState.DigHeld = false
	menu.Backdrop.Visible = true
	menu.Window.Visible = true
	UserInputService.MouseIconEnabled = true
	for name, page in pairs(menu.Pages) do
		page.Visible = name == tab
	end
	for name, button in pairs(menu.TabButtons) do
		button.BackgroundColor3 = name == tab and C.Ochre or C.Paper
		button.TextColor3 = name == tab and C.Cream or C.Ink
	end
	menu.Title.Text = TITLES[tab]
	menu.Subtitle.Text = SUBTITLES[tab]
	menu.CashLabel.Text = Util.FormatCash(ClientState.State.Cash)
	Interface.RefreshShop()
	Interface.RefreshSkills()
	Interface.RefreshJournal()
	Effects.Play("Click", 0.8, wasOpen and 1.2 or 1)
	if not wasOpen then
		local scale = menu.Window:FindFirstChildOfClass("UIScale")
		local target = scale:GetAttribute("Target") or 1
		scale.Scale = target * 0.85
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
	end
end

function Interface.Close()
	if not currentTab then
		return
	end
	currentTab = nil
	ClientState.UIOpen = false
	menu.Backdrop.Visible = false
	menu.Window.Visible = false
	UserInputService.MouseIconEnabled = false
	Effects.Play("Click", 0.6, 0.85)
end

function Interface.Toggle(tab)
	if currentTab == tab then
		Interface.Close()
	else
		Interface.Open(tab)
	end
end

--------------------------------------------------------------------------
-- NOTIFICATIONS
--------------------------------------------------------------------------
local lastBagFullToast = 0
local function celebrateFind(payload)
	local find = GameConfig.GetFind(payload.FindId)
	if not find then
		return
	end
	local rarityColor = GameConfig.Rarities[find.Rarity]
	hud.CelebrationHeader.Text = payload.IsNew and "NEW FIND!" or "FOUND AGAIN"
	hud.CelebrationName.Text = find.Name
	hud.CelebrationRarity.Text = string.upper(find.Rarity)
	hud.CelebrationRarity.TextColor3 = rarityColor
	hud.CelebrationBonus.Text = "+" .. Util.FormatCash(payload.Bonus)
	hud.CelebrationCount.Text = string.format("Journal  %d / %d", payload.Count or 0, payload.Total or #GameConfig.Finds)
	local celebrationStroke = hud.Celebration:FindFirstChildOfClass("UIStroke")
	if celebrationStroke then
		celebrationStroke.Color = rarityColor
	end
	hud.CelebrationView:ClearAllChildren()
	corner(100).Parent = hud.CelebrationView
	local viewport, camera, center = makeViewport(hud.CelebrationView, FindModels.Build(find.Id, true), { Size = UDim2.fromScale(1, 1), Zoom = 0.85 })
	viewport.ZIndex = 12
	local distance = viewport:GetAttribute("Distance")
	local spinConnection
	local angle = 0
	spinConnection = RunService.RenderStepped:Connect(function(dt)
		if not viewport.Parent then
			spinConnection:Disconnect()
			return
		end
		angle += dt * 1.4
		camera.CFrame = CFrame.lookAt(center + Vector3.new(math.cos(angle), 0.7, math.sin(angle)).Unit * distance, center)
	end)

	hud.Celebration.Visible = true
	hud.CelebrationScale.Scale = 0.2
	TweenService:Create(hud.CelebrationScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Effects.Fanfare()
	confetti(payload.IsNew and 70 or 30)
	task.delay(3.6, function()
		local tween = TweenService:Create(hud.CelebrationScale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
		tween:Play()
		tween.Completed:Wait()
		hud.Celebration.Visible = false
		if spinConnection then
			spinConnection:Disconnect()
		end
	end)
end

local function onNotify(payload)
	local kind = payload.Kind
	if kind == "Sell" then
		Effects.CashRegister()
		popText("+" .. Util.FormatCash(payload.Cash), C.Gold, 52)
		Interface.Toast(string.format("Melted %s kg of sand into glass for %s", Util.FormatKg(payload.Kg), Util.FormatCash(payload.Cash)), "Sage", "🔥")
	elseif kind == "BagFull" then
		local now = os.clock()
		if now - lastBagFullToast > 4 then
			lastBagFullToast = now
			Interface.Toast("Your bag is full! Melt it at the Glass Furnace in base camp.", "Terracotta", "🎒")
		end
		local bagStroke = hud.BagStroke
		if bagStroke then
			bagStroke.Color = C.Terracotta
			bagStroke.Thickness = 4
			TweenService:Create(bagStroke, TweenInfo.new(0.6), { Thickness = 2 }):Play()
		end
	elseif kind == "Find" then
		celebrateFind(payload)
	elseif kind == "FindUncovered" then
		local find = GameConfig.GetFind(payload.FindId)
		if find then
			local discovered = ClientState.State.Finds and ClientState.State.Finds[find.Id]
			Interface.Toast(discovered and string.format("A %s glints in the sand!", find.Name) or string.format("Something %s glints in the sand...", string.lower(find.Rarity)), find.Rarity, "✨")
			Effects.Play("Chime", 0.6, 1.5)
		end
	elseif kind == "LotCleared" then
		Effects.Fanfare()
		confetti(90)
		local body = payload.Bonus and payload.Bonus > 0 and string.format("You moved %s kg. Clearing bonus: %s!", Util.FormatKg(payload.Contributed or 0), Util.FormatCash(payload.Bonus))
			or "Fresh sand is on its way."
		showBanner("DESERT CLEARED! Not a grain left.", body .. string.format(" New sand in %ds.", payload.Delay or 10), "Sage", 6)
	elseif kind == "LotReady" then
		showBanner("Fresh sand delivered!", "A brand new desert with 14 new relics buried inside.", "Ochre", 4)
		Effects.Play("Splash", 1, 0.7)
	elseif kind == "Toast" then
		Interface.Toast(payload.Text or "", payload.Color or "Ochre", payload.Icon)
	end
end

--------------------------------------------------------------------------
-- PER-FRAME UPDATES
--------------------------------------------------------------------------
local function updateScales()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local hudScale = math.clamp(math.min(viewport.X / 1100, viewport.Y / 700), 0.62, 1)
	hud.Scale.Scale = hudScale
	local windowScale = math.clamp(math.min((viewport.X - 24) / 780, (viewport.Y - 24) / 540), 0.45, 1.15)
	if menu.Scale then
		menu.Scale:SetAttribute("Target", windowScale)
		if not currentTab then
			menu.Scale.Scale = windowScale
		end
	end
end

local function frame(dt)
	local state = ClientState.State
	-- cash count-up
	local target = state.Cash or 0
	if math.abs(target - displayedCash) < 0.5 then
		displayedCash = target
	else
		displayedCash += (target - displayedCash) * math.min(1, dt * 8)
	end
	hud.CashLabel.Text = Util.FormatCash(displayedCash)

	-- bag fill
	local stats = ClientState.GetStats()
	local capacity = math.max(stats.Capacity, 0.001)
	local bagKg = state.BagKg or 0
	displayedBag += (bagKg - displayedBag) * math.min(1, dt * 12)
	if math.abs(bagKg - displayedBag) < 0.01 then
		displayedBag = bagKg
	end
	local fraction = math.clamp(displayedBag / capacity, 0, 1)
	hud.BagFill.Size = UDim2.fromScale(fraction, 1)
	hud.BagWeight.Text = string.format("%s / %s kg", Util.FormatKg(displayedBag), Util.FormatKg(capacity))
	local full = bagKg >= capacity - 0.01
	hud.BagFill.BackgroundColor3 = full and C.Terracotta or (fraction > 0.8 and C.Ochre:Lerp(C.Terracotta, (fraction - 0.8) / 0.2) or C.Ochre)
	hud.FullPill.Visible = full
	if full then
		hud.FullPill.BackgroundTransparency = 0.1 + math.abs(math.sin(os.clock() * 4)) * 0.25
	end
	if hud.BagStroke and not full then
		hud.BagStroke.Color = hud.BagStroke.Color:Lerp(C.Ochre, math.min(1, dt * 3))
	end

	-- crosshair
	local crosshair = ClientState.Crosshair
	local show = not ClientState.UIOpen
	hud.Cross.Visible = show
	hud.Ring.Visible = show and crosshair ~= "idle"
	hud.CrossHint.Visible = show
	if crosshair == "valid" then
		hud.Cross.BackgroundColor3 = C.Cream
		hud.RingStroke.Color = C.Cream
		hud.CrossHint.Text = ""
	elseif crosshair == "full" then
		hud.Cross.BackgroundColor3 = C.Terracotta
		hud.RingStroke.Color = C.Terracotta
		hud.CrossHint.Text = "Bag full"
	elseif crosshair == "outside" then
		hud.Cross.BackgroundColor3 = C.Locked
		hud.RingStroke.Color = C.Locked
		hud.CrossHint.Text = "Outside the dig zone (past the flags)"
	elseif crosshair == "far" then
		hud.Cross.BackgroundColor3 = C.Locked
		hud.RingStroke.Color = C.Locked
		hud.CrossHint.Text = "Too far - get closer"
	else
		hud.Cross.BackgroundColor3 = C.Cream
		hud.CrossHint.Text = ""
	end
	if show and not ClientState.UIOpen then
		UserInputService.MouseIconEnabled = false
	end
end

--------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------
function Interface.Init(options)
	options = options or {}
	onDigPress = options.OnDigPress
	local playerGui = player:WaitForChild("PlayerGui")
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	buildHUD(playerGui)
	buildMenu(playerGui)
	buildShop()
	buildSkills()
	buildJournal()
	updateScales()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScales)
	end

	ClientState.Changed:Connect(function(state)
		refreshHUD(state)
		if currentTab then
			Interface.RefreshShop()
			Interface.RefreshSkills()
			Interface.RefreshJournal()
		end
	end)
	ClientState.LotChanged:Connect(refreshLot)
	ClientState.Notified:Connect(onNotify)
	ClientState.MenuRequested:Connect(function(name)
		Interface.Open(name or "Shop")
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.ButtonSelect then
			Interface.Toggle("Shop")
		elseif input.KeyCode == Enum.KeyCode.K then
			Interface.Toggle("Skills")
		elseif input.KeyCode == Enum.KeyCode.J then
			Interface.Toggle("Journal")
		end
	end)

	refreshHUD(ClientState.State)
	refreshLot(ClientState.Lot)
	RunService.RenderStepped:Connect(frame)

	task.delay(2, function()
		Interface.Toast("Welcome to the " .. GameConfig.Lot.Name .. "! Dig sand with your hands, melt it into glass at the furnace, find all 14 relics.", "Ochre", "🌵", 7)
	end)
end

return Interface
]======]

-- Studio-only settings (Lighting.Technology can only be set from Studio)
pcall(function() Lighting.Technology = Enum.Technology.Future end)
StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
StarterPlayer.CharacterWalkSpeed = 16

-- Remove the default template Baseplate/SpawnLocation (the game builds its own world)
for _, name in ipairs({ "Baseplate", "SpawnLocation" }) do
	local part = workspace:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		part:Destroy()
		print("[Sandsweep] Removed default " .. name)
	end
end

pcall(function() ChangeHistoryService:SetWaypoint("Sandsweep installed") end)
print("[Sandsweep] Installed! Press Play (F5). Tip: enable Game Settings > Security > Studio Access to API Services to test DataStore saving.")
