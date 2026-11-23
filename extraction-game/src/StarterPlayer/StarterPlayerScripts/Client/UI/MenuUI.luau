--!strict
--[[
	MenuUI
	Ultra-minimal main menu: boxless left-aligned typography over the live 3D
	scene, cinematic letterbox + edge vignette, and two slide-in panels
	(LOADOUT, SETTINGS). Mouse, keyboard and gamepad share one focus model.

	MenuUI only renders and reports intent through signals; MenuController
	decides what intent means (camera moves, deploy, saving).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Schema = require(Shared.Schema)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

export type PanelName = "Loadout" | "Settings"

export type Context = {
	DisplayName: string,
	Settings: Types.PlayerSettings,
	Loadout: Types.Loadout,
	PlaySound: (name: string) -> (),
}

export type MenuUI = {
	OptionActivated: Signal.Signal, -- (id: "Deploy" | "Loadout" | "Settings")
	BackRequested: Signal.Signal,
	LoadoutSelected: Signal.Signal, -- (slot: WeaponSlot, weaponId: string)
	SettingChanged: Signal.Signal, -- (key: string, value: any)

	show: (self: MenuUI, instant: boolean?) -> (),
	hide: (self: MenuUI, duration: number?) -> (),
	openPanel: (self: MenuUI, name: PanelName?) -> (),
	getPanel: (self: MenuUI) -> PanelName?,
	setLoadout: (self: MenuUI, loadout: Types.Loadout) -> (),
	setSettings: (self: MenuUI, settings: Types.PlayerSettings) -> (),
	navigate: (self: MenuUI, delta: number) -> (),
	adjust: (self: MenuUI, delta: number) -> (),
	activate: (self: MenuUI) -> (),
	fade: (self: MenuUI, toBlack: boolean, duration: number) -> (),
	toast: (self: MenuUI, text: string) -> (),
	isInteractive: (self: MenuUI) -> boolean,
}

type FocusList = "Main" | "Panel"

type MainOption = {
	Id: string,
	Text: string,
	Hint: string,
	Size: number,
}

local MAIN_OPTIONS: { MainOption } = {
	{ Id = "Deploy", Text = "DEPLOY", Hint = "Drop into the zone. Whatever you carry out is yours.", Size = 36 },
	{ Id = "Loadout", Text = "LOADOUT", Hint = "Pick your kit at the workbench.", Size = 26 },
	{ Id = "Settings", Text = "SETTINGS", Hint = "Effects quality, field of view, sensitivity.", Size = 26 },
}

local SLOTS: { Types.WeaponSlot } = { "Primary", "Secondary" }
local STAT_KEYS = { "Damage", "FireRate", "Handling", "Range" }
local STAT_LABELS = { Damage = "DAMAGE", FireRate = "FIRE RATE", Handling = "HANDLING", Range = "RANGE" }

local LETTERBOX_HEIGHT = 0.065

local function formatThousands(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

local function gradientEdge(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2, rotation: number, startAlpha: number)
	local frame = Widgets.frame(parent, {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		Color = Theme.Colors.Black,
		Transparency = 0,
	})
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, startAlpha),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = frame
end

local function addScale(target: Instance): UIScale
	local scale = Instance.new("UIScale")
	scale.Parent = target
	return scale
end

local MenuUI = {}

function MenuUI.new(ctx: Context): MenuUI
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local ui = {} :: MenuUI
	ui.OptionActivated = Signal.new()
	ui.BackRequested = Signal.new()
	ui.LoadoutSelected = Signal.new()
	ui.SettingChanged = Signal.new()

	local interactive = false
	local openPanelName: PanelName? = nil
	local focusList: FocusList = "Main"
	local focusIndex: { [FocusList]: number } = { Main = 1, Panel = 1 }
	local currentLoadout: Types.Loadout = table.clone(ctx.Loadout)
	local scales: { UIScale } = {}

	----------------------------------------------------------------------------
	-- Roots
	----------------------------------------------------------------------------
	local gui = Instance.new("ScreenGui")
	gui.Name = "MainMenu"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	gui.Parent = playerGui

	local root = Instance.new("CanvasGroup")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.GroupTransparency = 1
	root.Parent = gui

	local faderGui = Instance.new("ScreenGui")
	faderGui.Name = "Fader"
	faderGui.IgnoreGuiInset = true
	faderGui.ResetOnSpawn = false
	faderGui.DisplayOrder = 100
	faderGui.Parent = playerGui
	local fader = Widgets.frame(faderGui, { Name = "Black", Size = UDim2.fromScale(1, 1), Color = Theme.Colors.Black, Transparency = 1 })

	-- Cinematic letterbox (outside the CanvasGroup so it retracts on its own)
	local barTop = Widgets.frame(gui, { Name = "LetterboxTop", Size = UDim2.fromScale(1, 0), Color = Theme.Colors.Black, Transparency = 0, ZIndex = 20 })
	local barBottom = Widgets.frame(gui, {
		Name = "LetterboxBottom",
		Size = UDim2.fromScale(1, 0),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		Color = Theme.Colors.Black,
		Transparency = 0,
		ZIndex = 20,
	})

	-- Edge vignette: heavier on the left where the type sits.
	local vignette = Widgets.frame(root, { Name = "Vignette", Size = UDim2.fromScale(1, 1) })
	gradientEdge(vignette, "Left", UDim2.fromScale(0.5, 1), UDim2.new(), Vector2.zero, 0, 0.2)
	gradientEdge(vignette, "Right", UDim2.fromScale(0.3, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0), 180, 0.45)
	gradientEdge(vignette, "Top", UDim2.fromScale(1, 0.25), UDim2.new(), Vector2.zero, 90, 0.5)
	gradientEdge(vignette, "Bottom", UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 1), Vector2.new(0, 1), -90, 0.35)

	----------------------------------------------------------------------------
	-- Left column: title + options + hint
	----------------------------------------------------------------------------
	local column = Widgets.frame(root, {
		Name = "LeftColumn",
		Size = UDim2.fromOffset(480, 560),
		Position = UDim2.new(0.065, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
	})
	table.insert(scales, addScale(column))

	local titleGroup = Widgets.frame(column, { Name = "TitleGroup", Size = UDim2.new(1, 0, 0, 130) })
	Widgets.label(titleGroup, {
		Name = "Title",
		Text = Theme.track(Config.Branding.Title),
		Font = Theme.Fonts.Display,
		TextSize = 76,
		Size = UDim2.new(1, 0, 0, 84),
	})
	Widgets.label(titleGroup, {
		Name = "Subtitle",
		Text = Theme.track(Config.Branding.Subtitle),
		Font = Theme.Fonts.MonoBold,
		TextSize = 12,
		Color = Theme.Colors.Accent,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(4, 86),
	})
	Widgets.frame(titleGroup, {
		Name = "Rule",
		Size = UDim2.fromOffset(44, 2),
		Position = UDim2.fromOffset(4, 118),
		Color = Theme.Colors.Accent,
		Transparency = 0.2,
	})

	local optionsFrame = Widgets.frame(column, { Name = "Options", Size = UDim2.new(1, 0, 0, 220), Position = UDim2.fromOffset(0, 158) })
	Widgets.list(optionsFrame, 2)

	local hint = Widgets.label(column, {
		Name = "Hint",
		Text = MAIN_OPTIONS[1].Hint,
		Font = Theme.Fonts.Body,
		TextSize = 14,
		Color = Theme.Colors.Dim,
		Transparency = 0.1,
		Size = UDim2.fromOffset(380, 40),
		Position = UDim2.fromOffset(4, 392),
		Wrapped = true,
		YAlign = Enum.TextYAlignment.Top,
	})

	local mainRows: { Widgets.Row } = {}
	local optionRows: { [string]: Widgets.OptionRow } = {}
	local panelRows: { [PanelName]: { Widgets.Row } } = { Loadout = {}, Settings = {} }
	-- Extra behaviour when a row gains focus (e.g. weapon detail preview).
	local focusHooks: { [any]: () -> () } = {}

	local function rowsFor(list: FocusList): { Widgets.Row }
		if list == "Panel" then
			local name = openPanelName
			if name then
				return panelRows[name]
			end
			return {}
		end
		return mainRows
	end

	local updateDetail: (weaponId: string?) -> () = function(_: string?) end

	local function setHint(text: string)
		if hint.Text == text then
			return
		end
		hint.TextTransparency = 1
		hint.Text = text
		Widgets.tween(hint, Theme.Tween.Medium, { TextTransparency = 0.1 })
	end

	local function setFocus(list: FocusList, index: number, silent: boolean?)
		local previousRows = rowsFor(focusList)
		local previous = previousRows[focusIndex[focusList]]
		local nextRows = rowsFor(list)
		if #nextRows == 0 then
			return
		end
		local clamped = ((index - 1) % #nextRows) + 1
		local nextRow = nextRows[clamped]
		if previous == nextRow then
			return
		end
		if previous then
			previous.SetFocused(false)
		end
		focusList = list
		focusIndex[list] = clamped
		nextRow.SetFocused(true)
		if list == "Main" then
			setHint(MAIN_OPTIONS[clamped].Hint)
		end
		local hook = focusHooks[nextRow]
		if hook then
			hook()
		end
		if not silent then
			ctx.PlaySound("UIHover")
		end
	end

	local function focusRow(list: FocusList, row: Widgets.Row)
		if not interactive then
			return
		end
		local index = table.find(rowsFor(list), row)
		if index then
			setFocus(list, index)
		end
	end

	for i, def in MAIN_OPTIONS do
		local row: Widgets.OptionRow
		row = Widgets.menuOption(optionsFrame, {
			Name = def.Id,
			Index = i,
			Text = def.Text,
			TextSize = def.Size,
			LayoutOrder = i,
			OnHover = function()
				focusRow("Main", row)
			end,
			OnActivate = function()
				if not interactive then
					return
				end
				ctx.PlaySound(if def.Id == "Deploy" then "UIDeploy" else "UIClick")
				ui.OptionActivated:Fire(def.Id)
			end,
		})
		table.insert(mainRows, row)
		optionRows[def.Id] = row
	end

	----------------------------------------------------------------------------
	-- Corners: operator, footer, key hints, toast
	----------------------------------------------------------------------------
	local topRight = Widgets.frame(root, {
		Name = "Operator",
		Size = UDim2.fromOffset(320, 70),
		Position = UDim2.fromScale(0.935, 0.095),
		AnchorPoint = Vector2.new(1, 0),
	})
	table.insert(scales, addScale(topRight))
	Widgets.label(topRight, {
		Name = "Role",
		Text = Theme.track("OPERATOR"),
		Font = Theme.Fonts.Mono,
		TextSize = 10,
		Color = Theme.Colors.Dim,
		Size = UDim2.new(1, 0, 0, 16),
		XAlign = Enum.TextXAlignment.Right,
	})
	Widgets.label(topRight, {
		Name = "Name",
		Text = Theme.track(string.upper(ctx.DisplayName)),
		Font = Theme.Fonts.Heading,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 16),
		XAlign = Enum.TextXAlignment.Right,
	})
	local stashLabel = Widgets.label(topRight, {
		Name = "Stash",
		Text = "",
		Font = Theme.Fonts.Mono,
		TextSize = 11,
		Color = Theme.Colors.Accent,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 42),
		XAlign = Enum.TextXAlignment.Right,
	})
	local function refreshStash()
		local value = player:GetAttribute("StashValue")
		stashLabel.Text = if typeof(value) == "number" then Theme.track("STASH  $" .. formatThousands(value)) else ""
	end
	refreshStash()
	player:GetAttributeChangedSignal("StashValue"):Connect(refreshStash)

	local footer = Widgets.frame(root, {
		Name = "Footer",
		Size = UDim2.fromOffset(520, 40),
		Position = UDim2.fromScale(0.065, 0.905),
		AnchorPoint = Vector2.new(0, 1),
	})
	table.insert(scales, addScale(footer))
	local locationLabel = Widgets.label(footer, {
		Name = "Location",
		Text = "",
		Font = Theme.Fonts.Mono,
		TextSize = 11,
		Color = Theme.Colors.Text,
		Transparency = 0.35,
		Size = UDim2.new(1, 0, 0, 18),
	})
	Widgets.label(footer, {
		Name = "Build",
		Text = Theme.track(Config.Branding.Build),
		Font = Theme.Fonts.Mono,
		TextSize = 10,
		Color = Theme.Colors.Dim,
		Transparency = 0.4,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 20),
	})
	task.spawn(function()
		while gui.Parent do
			locationLabel.Text = Theme.track(Config.Branding.Location .. "   ·   " .. tostring(os.date("%H:%M")))
			task.wait(1)
		end
	end)

	local keyHints = Widgets.label(root, {
		Name = "KeyHints",
		Text = "",
		Font = Theme.Fonts.Mono,
		TextSize = 11,
		Color = Theme.Colors.Dim,
		Transparency = 0.25,
		Size = UDim2.fromOffset(520, 18),
		Position = UDim2.fromScale(0.935, 0.905),
		AnchorPoint = Vector2.new(1, 1),
		XAlign = Enum.TextXAlignment.Right,
	})
	table.insert(scales, addScale(keyHints))
	local function refreshHints()
		local last = UserInputService:GetLastInputType()
		local gamepad = last.Name:sub(1, 7) == "Gamepad"
		keyHints.Text = Theme.track(if gamepad then "DPAD  NAVIGATE    A  SELECT    B  BACK" else "↑↓  NAVIGATE    ENTER  SELECT    BKSP  BACK")
	end
	refreshHints()
	UserInputService.LastInputTypeChanged:Connect(refreshHints)

	local toastLabel = Widgets.label(root, {
		Name = "Toast",
		Text = "",
		Font = Theme.Fonts.MonoBold,
		TextSize = 12,
		Color = Theme.Colors.Danger,
		Transparency = 1,
		Size = UDim2.fromOffset(600, 20),
		Position = UDim2.fromScale(0.5, 0.84),
		AnchorPoint = Vector2.new(0.5, 0.5),
		XAlign = Enum.TextXAlignment.Center,
	})

	----------------------------------------------------------------------------
	-- Panels
	----------------------------------------------------------------------------
	local panels: { [PanelName]: CanvasGroup } = {}

	local function makePanel(name: PanelName, title: string, subtitle: string): Frame
		local group = Instance.new("CanvasGroup")
		group.Name = name .. "Panel"
		group.Size = UDim2.fromOffset(440, 600)
		group.AnchorPoint = Vector2.new(1, 0.5)
		group.Position = UDim2.new(0.935, 40, 0.5, 0)
		group.BackgroundTransparency = 1
		group.GroupTransparency = 1
		group.Visible = false
		group.Parent = root
		table.insert(scales, addScale(group))
		panels[name] = group

		Widgets.label(group, {
			Name = "Header",
			Text = Theme.track(title),
			Font = Theme.Fonts.Heading,
			TextSize = 30,
			Size = UDim2.new(1, 0, 0, 36),
		})
		Widgets.label(group, {
			Name = "Sub",
			Text = Theme.track(subtitle),
			Font = Theme.Fonts.Mono,
			TextSize = 10,
			Color = Theme.Colors.Dim,
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.fromOffset(2, 38),
		})
		Widgets.frame(group, {
			Name = "Rule",
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromOffset(0, 64),
			Color = Theme.Colors.White,
			Transparency = 0.88,
		})
		local body = Widgets.frame(group, { Name = "Body", Size = UDim2.new(1, 0, 1, -76), Position = UDim2.fromOffset(0, 76) })
		Widgets.list(body, 4)
		return body
	end

	-- LOADOUT -----------------------------------------------------------------
	local loadoutBody = makePanel("Loadout", "LOADOUT", "SELECT YOUR KIT  ·  LOCKED ON DEPLOY")
	local weaponRows: { [string]: Widgets.WeaponRow } = {}
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	for _, slot in SLOTS do
		Widgets.section(loadoutBody, string.upper(slot), nextOrder())
		for _, weaponId in Schema.weaponsForSlot(slot) do
			local def = Config.Weapons[weaponId]
			local row: Widgets.WeaponRow
			row = Widgets.weaponRow(loadoutBody, {
				Name = weaponId,
				Title = def.DisplayName,
				Tag = def.Class,
				LayoutOrder = nextOrder(),
				OnHover = function()
					focusRow("Panel", row)
				end,
				OnActivate = function()
					if not interactive then
						return
					end
					ctx.PlaySound("UIClick")
					ui.LoadoutSelected:Fire(slot, weaponId)
				end,
			})
			weaponRows[weaponId] = row
			focusHooks[row] = function()
				updateDetail(weaponId)
			end
			table.insert(panelRows.Loadout, row)
		end
	end

	Widgets.frame(loadoutBody, { Name = "Spacer", Size = UDim2.new(1, 0, 0, 14), LayoutOrder = nextOrder() })
	local detail = Widgets.frame(loadoutBody, { Name = "Detail", Size = UDim2.new(1, 0, 0, 190), LayoutOrder = nextOrder() })
	local detailName = Widgets.label(detail, {
		Name = "Name",
		Text = "",
		Font = Theme.Fonts.Heading,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 22),
	})
	local detailDesc = Widgets.label(detail, {
		Name = "Description",
		Text = "",
		Font = Theme.Fonts.Body,
		TextSize = 13,
		Color = Theme.Colors.Dim,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 26),
		Wrapped = true,
		YAlign = Enum.TextYAlignment.Top,
	})
	local statsFrame = Widgets.frame(detail, { Name = "Stats", Size = UDim2.new(1, 0, 0, 100), Position = UDim2.fromOffset(0, 80) })
	Widgets.list(statsFrame, 2)
	local statBars: { [string]: Widgets.StatBar } = {}
	for i, key in STAT_KEYS do
		statBars[key] = Widgets.statBar(statsFrame, STAT_LABELS[key], i)
	end

	updateDetail = function(weaponId: string?)
		local id = weaponId or currentLoadout.Primary
		local def = Config.Weapons[id]
		if not def then
			return
		end
		if detailName.Text ~= def.DisplayName then
			detailName.TextTransparency = 1
			detailDesc.TextTransparency = 1
			Widgets.tween(detailName, Theme.Tween.Medium, { TextTransparency = 0 })
			Widgets.tween(detailDesc, Theme.Tween.Medium, { TextTransparency = 0 })
		end
		detailName.Text = def.DisplayName
		detailDesc.Text = def.Description
		for _, key in STAT_KEYS do
			statBars[key].Set((def.Stats :: any)[key])
		end
	end

	-- SETTINGS ----------------------------------------------------------------
	local settingsBody = makePanel("Settings", "SETTINGS", "SAVED AUTOMATICALLY")
	order = 0
	local qualityLevels = Config.Settings.QualityLevels

	Widgets.section(settingsBody, "DISPLAY", nextOrder())
	local qualityRow: Widgets.CycleRow
	qualityRow = Widgets.cycle(settingsBody, {
		Name = "Quality",
		Label = "EFFECTS QUALITY",
		Options = qualityLevels :: any,
		Index = table.find(qualityLevels, ctx.Settings.Quality) or 3,
		LayoutOrder = nextOrder(),
		OnHover = function()
			focusRow("Panel", qualityRow)
		end,
		OnTick = function()
			ctx.PlaySound("UITick")
		end,
		OnChanged = function(index: number)
			ui.SettingChanged:Fire("Quality", qualityLevels[index])
		end,
	})
	table.insert(panelRows.Settings, qualityRow)

	local fovRow: Widgets.SliderRow
	fovRow = Widgets.slider(settingsBody, {
		Name = "FieldOfView",
		Label = "FIELD OF VIEW",
		Min = Config.Settings.FovMin,
		Max = Config.Settings.FovMax,
		Step = 1,
		KeyStep = 2,
		Value = ctx.Settings.FieldOfView,
		Format = function(v: number): string
			return string.format("%d°", v)
		end,
		LayoutOrder = nextOrder(),
		OnHover = function()
			focusRow("Panel", fovRow)
		end,
		OnTick = function()
			ctx.PlaySound("UITick")
		end,
		OnChanged = function(v: number)
			ui.SettingChanged:Fire("FieldOfView", v)
		end,
	})
	table.insert(panelRows.Settings, fovRow)

	Widgets.section(settingsBody, "CONTROLS", nextOrder())
	local sensRow: Widgets.SliderRow
	sensRow = Widgets.slider(settingsBody, {
		Name = "Sensitivity",
		Label = "LOOK SENSITIVITY",
		Min = Config.Settings.SensitivityMin,
		Max = Config.Settings.SensitivityMax,
		Step = 0.05,
		KeyStep = 0.05,
		Value = ctx.Settings.Sensitivity,
		Format = function(v: number): string
			return string.format("%.2f", v)
		end,
		LayoutOrder = nextOrder(),
		OnHover = function()
			focusRow("Panel", sensRow)
		end,
		OnTick = function()
			ctx.PlaySound("UITick")
		end,
		OnChanged = function(v: number)
			ui.SettingChanged:Fire("Sensitivity", v)
		end,
	})
	table.insert(panelRows.Settings, sensRow)

	Widgets.frame(settingsBody, { Name = "Spacer", Size = UDim2.new(1, 0, 0, 10), LayoutOrder = nextOrder() })
	Widgets.label(settingsBody, {
		Name = "Note",
		Text = "Effects quality scales rain, mist, light shafts, shadows and post FX. Engine graphics level stays in the Roblox menu.",
		Font = Theme.Fonts.Body,
		TextSize = 12,
		Color = Theme.Colors.Dim,
		Transparency = 0.2,
		Size = UDim2.new(1, 0, 0, 34),
		Wrapped = true,
		YAlign = Enum.TextYAlignment.Top,
		LayoutOrder = nextOrder(),
	})

	----------------------------------------------------------------------------
	-- Responsive scale
	----------------------------------------------------------------------------
	local function rescale()
		local camera = Workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 1080
		local s = math.clamp(height / 1080, 0.62, 1.35)
		for _, scale in scales do
			scale.Scale = s
		end
	end
	rescale()
	local function bindViewport()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		end
	end
	bindViewport()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		bindViewport()
		rescale()
	end)

	----------------------------------------------------------------------------
	-- Methods
	----------------------------------------------------------------------------
	local function refreshActiveOptions()
		for id, row in optionRows do
			row.SetActive(openPanelName ~= nil and id == openPanelName)
		end
	end

	function ui.getPanel(_self: MenuUI): PanelName?
		return openPanelName
	end

	function ui.openPanel(_self: MenuUI, name: PanelName?)
		if name == openPanelName then
			return
		end
		local previous = openPanelName
		if previous then
			local group = panels[previous]
			for _, row in panelRows[previous] do
				row.SetFocused(false)
			end
			Widgets.tween(group, Theme.Tween.Medium, { GroupTransparency = 1, Position = UDim2.new(0.935, 40, 0.5, 0) })
			task.delay(Theme.Tween.Medium.Time, function()
				if openPanelName ~= previous then
					group.Visible = false
				end
			end)
		end
		openPanelName = name
		if focusList == "Panel" then
			focusList = "Main"
		end
		if name then
			local group = panels[name]
			group.Visible = true
			group.Position = UDim2.new(0.935, 40, 0.5, 0)
			Widgets.tween(group, Theme.Tween.Slow, { GroupTransparency = 0, Position = UDim2.new(0.935, 0, 0.5, 0) })
			focusIndex.Panel = 1
			if name == "Loadout" then
				updateDetail(nil)
			end
		end
		refreshActiveOptions()
	end

	function ui.setLoadout(_self: MenuUI, loadout: Types.Loadout)
		currentLoadout = table.clone(loadout)
		for weaponId, row in weaponRows do
			row.SetSelected(weaponId == loadout.Primary or weaponId == loadout.Secondary)
		end
		if openPanelName == "Loadout" then
			updateDetail(nil)
		end
	end

	function ui.setSettings(_self: MenuUI, settings: Types.PlayerSettings)
		qualityRow.Set(table.find(qualityLevels, settings.Quality) or 3, true)
		fovRow.Set(settings.FieldOfView, true)
		sensRow.Set(settings.Sensitivity, true)
	end

	function ui.navigate(_self: MenuUI, delta: number)
		if not interactive then
			return
		end
		setFocus(focusList, focusIndex[focusList] + delta)
	end

	function ui.adjust(_self: MenuUI, delta: number)
		if not interactive then
			return
		end
		local row = rowsFor(focusList)[focusIndex[focusList]]
		if focusList == "Panel" and row and row.Adjust then
			row.Adjust(delta)
		elseif focusList == "Main" and delta > 0 and openPanelName then
			setFocus("Panel", focusIndex.Panel)
		elseif focusList == "Panel" and delta < 0 then
			local name = openPanelName
			local mainIndex = if name then table.find({ "Deploy", "Loadout", "Settings" }, name) else nil
			setFocus("Main", mainIndex or 1)
		end
	end

	function ui.activate(_self: MenuUI)
		if not interactive then
			return
		end
		local row = rowsFor(focusList)[focusIndex[focusList]]
		if row and row.Activate then
			row.Activate()
		end
	end

	function ui.isInteractive(_self: MenuUI): boolean
		return interactive
	end

	function ui.show(_self: MenuUI, instant: boolean?)
		gui.Enabled = true
		root.Visible = true
		interactive = true
		focusList = "Main"
		for _, row in mainRows do
			row.SetFocused(false)
		end
		focusIndex.Main = 0
		setFocus("Main", 1, true)

		if instant then
			root.GroupTransparency = 0
			barTop.Size = UDim2.fromScale(1, LETTERBOX_HEIGHT)
			barBottom.Size = UDim2.fromScale(1, LETTERBOX_HEIGHT)
		else
			Widgets.tween(root, Theme.Tween.Fade, { GroupTransparency = 0 })
			Widgets.tween(barTop, Theme.Tween.Slow, { Size = UDim2.fromScale(1, LETTERBOX_HEIGHT) })
			Widgets.tween(barBottom, Theme.Tween.Slow, { Size = UDim2.fromScale(1, LETTERBOX_HEIGHT) })
		end

		-- Staggered slide-in for the title and options.
		titleGroup.Position = UDim2.fromOffset(-30, 0)
		Widgets.tween(titleGroup, Theme.Tween.Slow, { Position = UDim2.fromOffset(0, 0) })
		for i, def in MAIN_OPTIONS do
			local content = optionRows[def.Id].Content
			content.Position = UDim2.fromOffset(-40, 0)
			task.delay(0.12 + i * 0.07, function()
				Widgets.tween(content, Theme.Tween.Slow, { Position = UDim2.fromOffset(0, 0) })
			end)
		end
	end

	function ui.hide(_self: MenuUI, duration: number?)
		local d = duration or 0.8
		interactive = false
		ui:openPanel(nil)
		local info = TweenInfo.new(d, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
		Widgets.tween(root, info, { GroupTransparency = 1 })
		Widgets.tween(barTop, TweenInfo.new(d * 1.4, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), { Size = UDim2.fromScale(1, 0) })
		Widgets.tween(barBottom, TweenInfo.new(d * 1.4, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), { Size = UDim2.fromScale(1, 0) })
		for i, def in MAIN_OPTIONS do
			local content = optionRows[def.Id].Content
			task.delay((i - 1) * 0.04, function()
				Widgets.tween(content, info, { Position = UDim2.fromOffset(-60, 0) })
			end)
		end
		task.delay(d * 1.4, function()
			if not interactive then
				root.Visible = false
			end
		end)
	end

	function ui.fade(_self: MenuUI, toBlack: boolean, duration: number)
		local tween = Widgets.tween(fader, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			BackgroundTransparency = if toBlack then 0 else 1,
		})
		tween.Completed:Wait()
	end

	local toastToken = 0
	function ui.toast(_self: MenuUI, text: string)
		toastToken += 1
		local token = toastToken
		toastLabel.Text = Theme.track(text)
		Widgets.tween(toastLabel, Theme.Tween.Medium, { TextTransparency = 0 })
		task.delay(3, function()
			if token == toastToken then
				Widgets.tween(toastLabel, Theme.Tween.Slow, { TextTransparency = 1 })
			end
		end)
	end

	ui:setLoadout(currentLoadout)
	ui:setSettings(ctx.Settings)
	return ui
end

return MenuUI
