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
	local vehicles, storage = {}, {}
	for vehicleId, value in pairs(data.OwnedVehicles) do
		if value and GameConfig.GetVehicle(vehicleId) then
			vehicles[vehicleId] = true
		end
	end
	for vehicleId, kg in pairs(data.VehicleStorage) do
		local vehicle = GameConfig.GetVehicle(vehicleId)
		if vehicle and tonumber(kg) then
			storage[vehicleId] = math.clamp(tonumber(kg), 0, vehicle.Capacity)
		end
	end
	data.OwnedVehicles = vehicles
	data.VehicleStorage = storage
	local factory = {}
	for machineId, value in pairs(data.Factory) do
		if value and GameConfig.GetMachine(machineId) then
			factory[machineId] = true
		end
	end
	data.Factory = factory
	data.FactoryBufferKg = math.max(0, tonumber(data.FactoryBufferKg) or 0)
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
		OwnedVehicles = Util.DeepCopy(data.OwnedVehicles),
		VehicleStorage = Util.DeepCopy(data.VehicleStorage),
		Factory = Util.DeepCopy(data.Factory),
		FactoryBufferKg = math.floor((data.FactoryBufferKg or 0) * 1000) / 1000,
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
