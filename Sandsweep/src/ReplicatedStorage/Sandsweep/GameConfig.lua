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
		Id = "Spoon",
		Name = "Rusty Spoon",
		Tier = 1,
		Price = 0,
		Radius = 1.8,
		Cooldown = 0.45,
		Range = 14,
		Mode = "Click",
		Shake = 0.05,
		Accent = Color3.fromRGB(190, 196, 204),
		Description = "Everyone starts somewhere. One heroic spoonful at a time.",
	},
	{
		Id = "Shovel",
		Name = "Trusty Shovel",
		Tier = 2,
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
		Tier = 3,
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
		Tier = 4,
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
		Description = "Haggle better at the Weigh Station. Sand sells for more.",
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
	OwnedTools = { Spoon = true },
	EquippedTool = "Spoon",
	BagTier = 1,
	Skills = { DigSpeed = 0, DigRadius = 0, SandValue = 0, WalkSpeed = 0 },
	Finds = {},
	Stats = { TotalKg = 0, TotalEarned = 0, LotsCleared = 0, FindsCollected = 0 },
}

return GameConfig
