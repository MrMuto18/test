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
