--!strict
--[[
	ClientBootstrap (LocalScript)
	Client entry point. Initialises controllers in dependency order and wires
	the server-driven player state to the menu / gameplay flow.
]]

local Players = game:GetService("Players")

local Controllers = script.Parent.Controllers
local SettingsController = require(Controllers.SettingsController)
local AudioController = require(Controllers.AudioController)
local CinematicGrade = require(Controllers.CinematicGrade)
local AtmosphereController = require(Controllers.AtmosphereController)
local MenuCamera = require(Controllers.MenuCamera)
local MenuController = require(Controllers.MenuController)

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

MenuCamera.init()
MenuController.init()
MenuController.enter(false)

player:GetAttributeChangedSignal("State"):Connect(function()
	if player:GetAttribute("State") == "Menu" and MenuController.isDeployed() then
		task.spawn(MenuController.returnFromRaid)
	end
end)
