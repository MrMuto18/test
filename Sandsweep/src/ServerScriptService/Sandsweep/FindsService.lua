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
local MIN_SPACING = 9
local EDGE_MARGIN = 5

local function getFolder()
	local root = Workspace:WaitForChild("SandsweepWorld")
	return root:WaitForChild("Finds")
end

local function nearLadder(x, z)
	local cx, cz = Lot.CenterX, Lot.CenterZ
	local spots = {
		Vector2.new(cx, cz - Lot.SizeZ / 2),
		Vector2.new(cx, cz + Lot.SizeZ / 2),
		Vector2.new(cx - Lot.SizeX / 2, cz),
		Vector2.new(cx + Lot.SizeX / 2, cz),
	}
	for _, spot in ipairs(spots) do
		if (Vector2.new(x, z) - spot).Magnitude < 6 then
			return true
		end
	end
	return false
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
		for _ = 1, 80 do
			local x = Lot.CenterX + rng:NextNumber(-halfX, halfX)
			local z = Lot.CenterZ + rng:NextNumber(-halfZ, halfZ)
			local depth = rng:NextNumber(config.DepthMin, config.DepthMax)
			local y = math.max(Lot.BottomY + 1.4, LotService.Top - depth)
			local candidate = Vector3.new(x, y, z)
			local ok = not nearLadder(x, z)
			for _, other in ipairs(placed) do
				if (Vector2.new(other.X, other.Z) - Vector2.new(x, z)).Magnitude < MIN_SPACING then
					ok = false
					break
				end
			end
			if ok then
				position = candidate
				break
			end
		end
		if not position then
			position = Vector3.new(
				Lot.CenterX + rng:NextNumber(-halfX, halfX),
				LotService.Top - config.DepthMax,
				Lot.CenterZ + rng:NextNumber(-halfZ, halfZ)
			)
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
