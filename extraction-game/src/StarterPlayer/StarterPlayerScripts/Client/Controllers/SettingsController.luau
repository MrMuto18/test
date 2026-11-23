--!strict
--[[
	SettingsController
	Client copy of the player's settings + loadout. Pulls the profile from the
	server once, applies changes instantly (optimistic), debounces saves, and
	re-syncs loadout from the server-confirmed player attributes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Schema = require(Shared.Schema)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)

local player = Players.LocalPlayer

local SettingsController = {}
SettingsController.Changed = Signal.new() -- (settings: PlayerSettings)
SettingsController.LoadoutChanged = Signal.new() -- (loadout: Loadout)

local current: Types.PlayerSettings = Schema.sanitizeSettings(nil, Config.Settings.Defaults)
local loadout: Types.Loadout = Schema.sanitizeLoadout(nil, Config.DefaultLoadout)
local saveToken = 0

local function scheduleSave()
	saveToken += 1
	local token = saveToken
	task.delay(Config.Settings.SaveDebounce, function()
		if token == saveToken then
			Net.event(Net.Events.SaveSettings):FireServer(current)
		end
	end)
end

local function syncLoadoutFromAttributes()
	local confirmed = Schema.sanitizeLoadout({
		Primary = player:GetAttribute("Loadout_Primary"),
		Secondary = player:GetAttribute("Loadout_Secondary"),
	}, loadout)
	if confirmed.Primary ~= loadout.Primary or confirmed.Secondary ~= loadout.Secondary then
		loadout = confirmed
		SettingsController.LoadoutChanged:Fire(table.clone(loadout))
	end
end

function SettingsController.init()
	local ok, profile = pcall(function(): any
		return Net.func(Net.Functions.GetProfile):InvokeServer()
	end)
	if ok and typeof(profile) == "table" then
		current = Schema.sanitizeSettings(profile.Settings, current)
		loadout = Schema.sanitizeLoadout(profile.Loadout, loadout)
	else
		warn("[Settings] profile fetch failed, using defaults:", profile)
	end

	player:GetAttributeChangedSignal("Loadout_Primary"):Connect(syncLoadoutFromAttributes)
	player:GetAttributeChangedSignal("Loadout_Secondary"):Connect(syncLoadoutFromAttributes)
end

function SettingsController.get(): Types.PlayerSettings
	return table.clone(current)
end

function SettingsController.set(key: "Quality" | "FieldOfView" | "Sensitivity", value: any)
	local candidate: any = table.clone(current)
	candidate[key] = value
	local sanitized = Schema.sanitizeSettings(candidate, current)
	if
		sanitized.Quality == current.Quality
		and sanitized.FieldOfView == current.FieldOfView
		and sanitized.Sensitivity == current.Sensitivity
	then
		return
	end
	current = sanitized
	SettingsController.Changed:Fire(table.clone(current))
	scheduleSave()
end

function SettingsController.getLoadout(): Types.Loadout
	return table.clone(loadout)
end

function SettingsController.setLoadout(slot: Types.WeaponSlot, weaponId: string)
	if not Schema.isWeaponForSlot(slot, weaponId) then
		return
	end
	if slot == "Primary" then
		if loadout.Primary == weaponId then
			return
		end
		loadout.Primary = weaponId
	else
		if loadout.Secondary == weaponId then
			return
		end
		loadout.Secondary = weaponId
	end
	SettingsController.LoadoutChanged:Fire(table.clone(loadout))
	Net.event(Net.Events.SetLoadout):FireServer(slot, weaponId)
end

return SettingsController
