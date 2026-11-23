--!strict
--[[
	Schema
	Validation + sanitising for anything that crosses the network or comes
	out of a DataStore. Server and client run the exact same rules.
]]

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Schema = {}

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
Schema.isFiniteNumber = isFiniteNumber

function Schema.isQuality(value: any): boolean
	if typeof(value) ~= "string" then
		return false
	end
	return table.find(Config.Settings.QualityLevels, value :: any) ~= nil
end

function Schema.sanitizeSettings(raw: any, fallback: Types.PlayerSettings): Types.PlayerSettings
	local result: Types.PlayerSettings = {
		Quality = fallback.Quality,
		FieldOfView = fallback.FieldOfView,
		Sensitivity = fallback.Sensitivity,
	}
	if typeof(raw) ~= "table" then
		return result
	end

	if Schema.isQuality(raw.Quality) then
		result.Quality = raw.Quality
	end
	if isFiniteNumber(raw.FieldOfView) then
		result.FieldOfView = math.clamp(math.round(raw.FieldOfView), Config.Settings.FovMin, Config.Settings.FovMax)
	end
	if isFiniteNumber(raw.Sensitivity) then
		local rounded = math.round(raw.Sensitivity * 100) / 100
		result.Sensitivity = math.clamp(rounded, Config.Settings.SensitivityMin, Config.Settings.SensitivityMax)
	end
	return result
end

function Schema.isWeaponForSlot(slot: any, weaponId: any): boolean
	if typeof(slot) ~= "string" or typeof(weaponId) ~= "string" then
		return false
	end
	local def = Config.Weapons[weaponId]
	return def ~= nil and def.Slot == slot
end

function Schema.sanitizeLoadout(raw: any, fallback: Types.Loadout): Types.Loadout
	local result: Types.Loadout = {
		Primary = fallback.Primary,
		Secondary = fallback.Secondary,
	}
	if typeof(raw) ~= "table" then
		return result
	end
	if Schema.isWeaponForSlot("Primary", raw.Primary) then
		result.Primary = raw.Primary
	end
	if Schema.isWeaponForSlot("Secondary", raw.Secondary) then
		result.Secondary = raw.Secondary
	end
	return result
end

function Schema.weaponsForSlot(slot: Types.WeaponSlot): { string }
	local ids: { string } = {}
	for id, def in Config.Weapons do
		if def.Slot == slot then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a: string, b: string): boolean
		return Config.Weapons[a].Order < Config.Weapons[b].Order
	end)
	return ids
end

return Schema
