--!strict
--[[
	Bootstrap (Script)
	Server entry point. Order matters:
	  1. Remotes exist before any client asks for them.
	  2. Look-dev + safehouse + training range exist before the first camera needs them.
	  3. Data, deploy and combat services start listening for players.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local LightingService = require(script.Parent.Services.LightingService)
local PlayerDataService = require(script.Parent.Services.PlayerDataService)
local DeployService = require(script.Parent.Services.DeployService)
local CombatService = require(script.Parent.Services.CombatService)
local SafehouseBuilder = require(script.Parent.World.SafehouseBuilder)
local TrainingRange = require(script.Parent.World.TrainingRange)

Net.init()
LightingService.apply()
local safehouse = SafehouseBuilder.ensure(false)
TrainingRange.build(safehouse)
PlayerDataService.init()
DeployService.init(safehouse)
CombatService.init(DeployService.Deployed, function(player: Player)
	local data = PlayerDataService.getData(player)
	return if data then data.Loadout else Config.DefaultLoadout
end)

print("[Bootstrap] Phase 2 server ready.")
