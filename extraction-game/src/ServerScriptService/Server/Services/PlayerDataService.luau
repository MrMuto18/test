--!strict
--[[
	PlayerDataService
	Owns each player's persistent profile (settings, loadout, stash).

	• Real DataStore in live servers; automatic in-memory mock in Studio when
	  "Enable Studio Access to API Services" is off or the place is unpublished.
	• Every inbound value is sanitised through Shared.Schema.
	• Retries with exponential backoff, dirty-flag autosave, save on leave,
	  BindToClose flush.

	Phase 4 extends this with stash banking on extraction; the data shape is
	already in place (Stash / StashValue).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Schema = require(Shared.Schema)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)

type Backend = {
	Name: string,
	Load: (key: string) -> (boolean, any),
	Save: (key: string, data: Types.ProfileData) -> boolean,
}

type Profile = {
	Data: Types.ProfileData,
	Dirty: boolean,
	Saving: boolean,
}

local PlayerDataService = {}
PlayerDataService.ProfileLoaded = Signal.new() -- (player, data)

local profiles: { [Player]: Profile } = {}
local lastSettingsSave: { [Player]: number } = {}
local backend: Backend

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[deepCopy(k)] = deepCopy(v)
	end
	return copy
end

local function defaultData(): Types.ProfileData
	return {
		Version = Config.Data.SchemaVersion,
		Settings = Schema.sanitizeSettings(nil, Config.Settings.Defaults),
		Loadout = Schema.sanitizeLoadout(nil, Config.DefaultLoadout),
		Stash = {},
		StashValue = 0,
	}
end

local function reconcile(raw: any): Types.ProfileData
	local data = defaultData()
	if typeof(raw) ~= "table" then
		return data
	end
	data.Settings = Schema.sanitizeSettings(raw.Settings, data.Settings)
	data.Loadout = Schema.sanitizeLoadout(raw.Loadout, data.Loadout)
	if typeof(raw.Stash) == "table" then
		for itemId, count in raw.Stash do
			if typeof(itemId) == "string" and Schema.isFiniteNumber(count) and count > 0 then
				data.Stash[itemId] = math.floor(count)
			end
		end
	end
	if Schema.isFiniteNumber(raw.StashValue) then
		data.StashValue = math.max(0, math.floor(raw.StashValue))
	end
	return data
end

--------------------------------------------------------------------------------
-- Backends
--------------------------------------------------------------------------------
local function makeMockBackend(): Backend
	local memory: { [string]: any } = {}
	return {
		Name = "Mock",
		Load = function(key: string): (boolean, any)
			return true, deepCopy(memory[key])
		end,
		Save = function(key: string, data: Types.ProfileData): boolean
			memory[key] = deepCopy(data)
			return true
		end,
	}
end

local function makeDataStoreBackend(store: DataStore): Backend
	local retries = Config.Data.Retries
	return {
		Name = "DataStore",
		Load = function(key: string): (boolean, any)
			for attempt = 1, retries do
				local ok, result = pcall(function(): any
					return store:GetAsync(key)
				end)
				if ok then
					return true, result
				end
				warn(string.format("[PlayerData] load %s failed (attempt %d/%d): %s", key, attempt, retries, tostring(result)))
				task.wait(0.5 * 2 ^ attempt)
			end
			return false, nil
		end,
		Save = function(key: string, data: Types.ProfileData): boolean
			for attempt = 1, retries do
				local ok, err = pcall(function()
					store:UpdateAsync(key, function(_previous: any): any
						return data
					end)
				end)
				if ok then
					return true
				end
				warn(string.format("[PlayerData] save %s failed (attempt %d/%d): %s", key, attempt, retries, tostring(err)))
				task.wait(0.5 * 2 ^ attempt)
			end
			return false
		end,
	}
end

local function resolveBackend(): Backend
	local ok, store = pcall(function(): DataStore
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if not ok then
		warn("[PlayerData] DataStoreService unavailable — using in-memory mock (data resets each session).")
		return makeMockBackend()
	end
	if RunService:IsStudio() then
		local probeOk = pcall(function()
			(store :: DataStore):GetAsync("__studio_probe")
		end)
		if not probeOk then
			warn(
				"[PlayerData] Studio has no DataStore access (publish the place + enable 'Studio Access to API Services' to test real saves). Using in-memory mock."
			)
			return makeMockBackend()
		end
	end
	return makeDataStoreBackend(store :: DataStore)
end

--------------------------------------------------------------------------------
-- Profiles
--------------------------------------------------------------------------------
local function keyFor(player: Player): string
	return Config.Data.KeyPrefix .. tostring(player.UserId)
end

local function publishAttributes(player: Player, data: Types.ProfileData)
	player:SetAttribute("Loadout_Primary", data.Loadout.Primary)
	player:SetAttribute("Loadout_Secondary", data.Loadout.Secondary)
	player:SetAttribute("StashValue", data.StashValue)
end

local function saveProfile(player: Player): boolean
	local profile = profiles[player]
	if not profile or profile.Saving then
		return false
	end
	profile.Saving = true
	profile.Dirty = false
	local ok = backend.Save(keyFor(player), profile.Data)
	if not ok then
		profile.Dirty = true
	end
	profile.Saving = false
	return ok
end

local function loadProfile(player: Player)
	local ok, raw = backend.Load(keyFor(player))
	if not player.Parent then
		return
	end
	local data = reconcile(if ok then raw else nil)
	if not ok then
		warn(string.format("[PlayerData] %s: load failed, using defaults this session (saves disabled to protect data).", player.Name))
	end
	profiles[player] = { Data = data, Dirty = false, Saving = not ok }
	publishAttributes(player, data)
	player:SetAttribute("ProfileLoaded", true)
	PlayerDataService.ProfileLoaded:Fire(player, data)
end

local function waitForProfile(player: Player, timeout: number): Profile?
	local deadline = os.clock() + timeout
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

--------------------------------------------------------------------------------
-- Public API (used by later phases)
--------------------------------------------------------------------------------
function PlayerDataService.getData(player: Player): Types.ProfileData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function PlayerDataService.markDirty(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Dirty = true
		publishAttributes(player, profile.Data)
	end
end

function PlayerDataService.save(player: Player): boolean
	return saveProfile(player)
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------
function PlayerDataService.init()
	backend = resolveBackend()
	print("[PlayerData] backend:", backend.Name)

	Net.func(Net.Functions.GetProfile).OnServerInvoke = function(player: Player): any
		local profile = waitForProfile(player, Config.Data.ProfileWaitTimeout)
		if not profile then
			return nil
		end
		local payload: Types.ClientProfile = {
			Settings = table.clone(profile.Data.Settings),
			Loadout = table.clone(profile.Data.Loadout),
			StashValue = profile.Data.StashValue,
		}
		return payload
	end

	Net.event(Net.Events.SaveSettings).OnServerEvent:Connect(function(player: Player, raw: any)
		local profile = profiles[player]
		if not profile then
			return
		end
		local now = os.clock()
		if (lastSettingsSave[player] or 0) + Config.Settings.ServerSaveCooldown > now then
			return
		end
		lastSettingsSave[player] = now
		profile.Data.Settings = Schema.sanitizeSettings(raw, profile.Data.Settings)
		profile.Dirty = true
	end)

	Net.event(Net.Events.SetLoadout).OnServerEvent:Connect(function(player: Player, slot: any, weaponId: any)
		local profile = profiles[player]
		if not profile or not Schema.isWeaponForSlot(slot, weaponId) then
			return
		end
		-- Loadout is locked once deployed; it only changes in the safehouse.
		if player:GetAttribute("State") ~= "Menu" then
			publishAttributes(player, profile.Data)
			return
		end
		if slot == "Primary" then
			profile.Data.Loadout.Primary = weaponId
		elseif slot == "Secondary" then
			profile.Data.Loadout.Secondary = weaponId
		end
		profile.Dirty = true
		publishAttributes(player, profile.Data)
	end)

	Players.PlayerAdded:Connect(loadProfile)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		local profile = profiles[player]
		if profile and profile.Dirty then
			saveProfile(player)
		end
		profiles[player] = nil
		lastSettingsSave[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			for player, profile in profiles do
				if profile.Dirty then
					task.spawn(saveProfile, player)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			if profile.Dirty then
				pending += 1
				task.spawn(function()
					saveProfile(player)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
