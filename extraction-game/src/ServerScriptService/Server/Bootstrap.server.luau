--!strict
--[[
	Bootstrap (Script)
	Server entry point. Order matters:
	  1. Remotes exist before any client asks for them.
	  2. Look-dev + safehouse exist before the first player's camera needs them.
	  3. Data + deploy services start listening for players.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local LightingService = require(script.Parent.Services.LightingService)
local PlayerDataService = require(script.Parent.Services.PlayerDataService)
local DeployService = require(script.Parent.Services.DeployService)
local SafehouseBuilder = require(script.Parent.World.SafehouseBuilder)

Net.init()
LightingService.apply()
local safehouse = SafehouseBuilder.ensure(false)
PlayerDataService.init()
DeployService.init(safehouse)

print("[Bootstrap] Phase 1 server ready.")
