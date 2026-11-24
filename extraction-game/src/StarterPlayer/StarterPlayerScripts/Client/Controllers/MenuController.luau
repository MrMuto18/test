--!strict
--[[
	MenuController
	Orchestrates the safehouse menu experience:

	  enter()          CoreGui hidden, menu camera on MenuShot, UI in, input bound
	  LOADOUT/SETTINGS camera glides to the workbench / headlight shot + panel
	  DEPLOY           UI out → server spawns character → camera blends from the
	                   live menu frame into the live tactical camera (no cut),
	                   grade blends menu → gameplay, letterbox retracts
	  returnFromRaid() fade to black → back into the menu (death / extraction)
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local Controllers = script.Parent
local AudioController = require(Controllers.AudioController)
local CinematicGrade = require(Controllers.CinematicGrade)
local MenuCamera = require(Controllers.MenuCamera)
local SettingsController = require(Controllers.SettingsController)
local TacticalCamera = require(Controllers.TacticalCamera)
local MenuUI = require(Controllers.Parent.UI.MenuUI)

local player = Players.LocalPlayer

local MenuController = {}
MenuController.Deployed = Signal.new() -- (character) after the camera hand-off
MenuController.Entered = Signal.new() -- menu became active (initial load or back from a raid)

local INPUT_ACTION = "ZabourMenuNavigation"
local TRANSITION_STEP = "ZabourDeployTransition"

local ui: MenuUI.MenuUI
local active = false
local busy = false
local deployed = false

local function hasKey(list: { Enum.KeyCode }, key: Enum.KeyCode): boolean
	return table.find(list, key) ~= nil
end

local function setCoreGui(inMenu: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		if not inMenu then
			for _, coreType in Config.CoreGui.Gameplay do
				StarterGui:SetCoreGuiEnabled(coreType, true)
			end
		end
	end)
end

local function smootherstep(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * x * (x * (x * 6 - 15) + 10)
end

--------------------------------------------------------------------------------
-- Panels / camera shots
--------------------------------------------------------------------------------
local function closePanel()
	if ui:getPanel() == nil then
		return
	end
	ui:openPanel(nil)
	MenuCamera.goTo("MenuShot")
end

local function togglePanel(name: "Loadout" | "Settings")
	if ui:getPanel() == name then
		closePanel()
		return
	end
	ui:openPanel(name)
	MenuCamera.goTo(name .. "Shot")
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------
local function onMenuInput(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin or not active or busy then
		return Enum.ContextActionResult.Pass
	end
	local key = input.KeyCode
	local binds = Config.Keybinds
	if hasKey(binds.MenuUp, key) then
		ui:navigate(-1)
	elseif hasKey(binds.MenuDown, key) then
		ui:navigate(1)
	elseif hasKey(binds.MenuLeft, key) then
		ui:adjust(-1)
	elseif hasKey(binds.MenuRight, key) then
		ui:adjust(1)
	elseif hasKey(binds.MenuSelect, key) then
		ui:activate()
	elseif hasKey(binds.MenuBack, key) then
		if ui:getPanel() then
			AudioController.play("UIBack")
			closePanel()
		end
	else
		return Enum.ContextActionResult.Pass
	end
	return Enum.ContextActionResult.Sink
end

local function bindInput()
	local keys: { Enum.KeyCode } = {}
	local binds = Config.Keybinds
	for _, list in { binds.MenuUp, binds.MenuDown, binds.MenuLeft, binds.MenuRight, binds.MenuSelect, binds.MenuBack } do
		for _, key in list do
			if not table.find(keys, key) then
				table.insert(keys, key)
			end
		end
	end
	ContextActionService:BindActionAtPriority(INPUT_ACTION, onMenuInput, false, Enum.ContextActionPriority.High.Value, table.unpack(keys))
end

local function unbindInput()
	ContextActionService:UnbindAction(INPUT_ACTION)
end

--------------------------------------------------------------------------------
-- Deploy
--------------------------------------------------------------------------------
local function waitForDeployedCharacter(timeout: number): Model?
	local started = os.clock()
	local seenDeploying = false
	while os.clock() - started < timeout do
		local state = player:GetAttribute("State")
		local character = player.Character
		if state == "Deploying" then
			seenDeploying = true
		elseif state == "Deployed" and character and character:FindFirstChild("HumanoidRootPart") then
			return character
		elseif state == "Menu" and (seenDeploying or os.clock() - started > 3) then
			return nil -- rejected or failed server-side
		end
		task.wait()
	end
	return nil
end

local function blendIntoTactical()
	local camera = Workspace.CurrentCamera
	local fromCF = MenuCamera.getCFrame()
	local fromFov = MenuCamera.getFieldOfView()
	MenuCamera.stop()

	local duration = Config.Camera.DeployTransitionTime
	local elapsed = 0
	local finished = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	RunService:BindToRenderStep(TRANSITION_STEP, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		elapsed += dt
		local alpha = smootherstep(elapsed / duration)
		local targetCF, targetFov = TacticalCamera.evaluate(dt)
		if camera then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = fromCF:Lerp(targetCF, alpha)
			camera.FieldOfView = fromFov + (targetFov - fromFov) * alpha
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		CinematicGrade.setBlend(alpha)
		if elapsed >= duration then
			finished = true
		end
	end)
	while not finished do
		RunService.RenderStepped:Wait()
	end
	RunService:UnbindFromRenderStep(TRANSITION_STEP)
	CinematicGrade.setBlend(1)
	TacticalCamera.start()
end

local function deploy()
	if busy or not active then
		return
	end
	busy = true
	ui:hide(0.7)
	MenuCamera.goTo("MenuShot")
	MenuCamera.pushIn(Config.Camera.Menu.DeployPushIn)
	AudioController.setMenuMix(false, 2.5)
	Net.event(Net.Events.RequestDeploy):FireServer()

	local character = waitForDeployedCharacter(Config.Deploy.SpawnTimeout)
	if character then
		TacticalCamera.attach(character)
	end
	if not character or not TacticalCamera.isAttached() then
		MenuCamera.pushIn(0)
		AudioController.setMenuMix(true)
		ui:show(false)
		ui:toast("DEPLOY FAILED — TRY AGAIN")
		busy = false
		return
	end

	active = false
	unbindInput()
	blendIntoTactical()
	setCoreGui(false)
	deployed = true
	busy = false
	MenuController.Deployed:Fire(character)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------
function MenuController.init()
	ui = MenuUI.new({
		DisplayName = player.DisplayName,
		Settings = SettingsController.get(),
		Loadout = SettingsController.getLoadout(),
		PlaySound = function(name: string)
			AudioController.play(name)
		end,
	})

	ui.OptionActivated:Connect(function(id: string)
		if id == "Deploy" then
			deploy()
		elseif id == "Loadout" then
			togglePanel("Loadout")
		elseif id == "Settings" then
			togglePanel("Settings")
		end
	end)
	ui.LoadoutSelected:Connect(function(slot: any, weaponId: any)
		SettingsController.setLoadout(slot, weaponId)
	end)
	ui.SettingChanged:Connect(function(key: any, value: any)
		SettingsController.set(key, value)
	end)
	SettingsController.LoadoutChanged:Connect(function(loadout: any)
		ui:setLoadout(loadout)
	end)
	SettingsController.Changed:Connect(function(settings: any)
		ui:setSettings(settings)
	end)
end

function MenuController.enter(instant: boolean)
	active = true
	busy = false
	deployed = false
	setCoreGui(true)
	TacticalCamera.detach()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	CinematicGrade.setBlend(0)
	MenuCamera.start("MenuShot")
	AudioController.setMenuMix(true, if instant then 0.01 else 1.5)
	ui:openPanel(nil)
	ui:setLoadout(SettingsController.getLoadout())
	ui:show(instant)
	bindInput()
	player:SetAttribute("ClientMenuReady", true)
	MenuController.Entered:Fire()
end

function MenuController.returnFromRaid()
	if active or busy then
		return
	end
	busy = true
	ui:fade(true, 0.6)
	MenuController.enter(true)
	ui:fade(false, 1.4)
end

function MenuController.isDeployed(): boolean
	return deployed
end

return MenuController
