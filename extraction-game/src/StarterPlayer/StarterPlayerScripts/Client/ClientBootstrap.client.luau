--!strict
--[[
	ClientBootstrap (LocalScript)
	Client entry point. Initialises controllers in dependency order and wires
	the menu ↔ gameplay lifecycle:

	  MenuController.Deployed  → movement, weapons and HUD attach to the character
	  MenuController.Entered   → they detach (death / return to safehouse)
]]

local Players = game:GetService("Players")

local Controllers = script.Parent.Controllers
local SettingsController = require(Controllers.SettingsController)
local AudioController = require(Controllers.AudioController)
local CinematicGrade = require(Controllers.CinematicGrade)
local AtmosphereController = require(Controllers.AtmosphereController)
local MenuCamera = require(Controllers.MenuCamera)
local MenuController = require(Controllers.MenuController)
local CharacterPoser = require(Controllers.CharacterPoser)
local MovementController = require(Controllers.MovementController)
local WeaponController = require(Controllers.WeaponController)
local LoadoutDisplay = require(Controllers.LoadoutDisplay)
local VehicleCamera = require(Controllers.VehicleCamera)
local VehicleController = require(Controllers.VehicleController)
local VehicleFx = require(Controllers.VehicleFx)
local HUD = require(script.Parent.UI.HUD)
local PromptUI = require(script.Parent.UI.PromptUI)

local player = Players.LocalPlayer

SettingsController.init()
AudioController.init()
CinematicGrade.init()
AtmosphereController.init({
	Flash = CinematicGrade.flash,
	Thunder = AudioController.thunder,
	EngineSound = function(): Sound?
		return AudioController.get("EngineIdle")
	end,
})

local function applyQuality(settings: any)
	AtmosphereController.applyQuality(settings.Quality)
	CinematicGrade.applyQuality(settings.Quality)
end
applyQuality(SettingsController.get())
SettingsController.Changed:Connect(applyQuality)

HUD.init()
PromptUI.init()
CharacterPoser.init()
WeaponController.init()
LoadoutDisplay.init()
VehicleCamera.init()
VehicleFx.init()
MenuCamera.init()
MenuController.init()

local carryConnection: RBXScriptConnection? = nil
MenuController.Deployed:Connect(function(character: any)
	MovementController.attach(character)
	WeaponController.attach(character, SettingsController.getLoadout())
	VehicleController.attach(character)
	HUD.setMode("OnFoot")
	HUD.setCarry(nil)
	if carryConnection then
		carryConnection:Disconnect()
	end
	carryConnection = character:GetAttributeChangedSignal("CarryValue"):Connect(function()
		local value = character:GetAttribute("CarryValue")
		HUD.setCarry(if typeof(value) == "number" and value > 0 then value else nil)
	end)
end)
MenuController.Entered:Connect(function()
	VehicleController.detach()
	WeaponController.detach()
	MovementController.detach()
	HUD.setCarry(nil)
	if carryConnection then
		carryConnection:Disconnect()
		carryConnection = nil
	end
end)

MenuController.enter(false)

player:GetAttributeChangedSignal("State"):Connect(function()
	if player:GetAttribute("State") == "Menu" and MenuController.isDeployed() then
		task.spawn(MenuController.returnFromRaid)
	end
end)
