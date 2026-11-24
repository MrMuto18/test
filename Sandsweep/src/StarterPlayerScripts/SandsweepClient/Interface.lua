-- Interface (ModuleScript) - StarterPlayerScripts/SandsweepClient/Interface
-- Minimalist warm UI: HUD (cash, bag, lot %, tool), toasts, sell pops, find
-- celebrations, and one tabbed window: Upgrade Shop, Skill Tree, Finds Journal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Sandsweep")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ToolModels = require(Shared:WaitForChild("ToolModels"))
local FindModels = require(Shared:WaitForChild("FindModels"))
local VehicleModels = require(Shared:WaitForChild("VehicleModels"))
local Remotes = Shared:WaitForChild("Remotes")
local Util = require(Shared:WaitForChild("Util"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local Interface = {}

local player = Players.LocalPlayer
local C = GameConfig.Palette
local TITLE = Enum.Font.FredokaOne
local BODY = Enum.Font.GothamMedium
local BOLD = Enum.Font.GothamBold

local hud = {}
local menu = {}
local shop = { Tab = "Tools", ToolCards = {}, BagCards = {}, VehicleCards = {}, MachineCards = {} }
local onFlip = nil
local wasInVehicle = false
local skills = { Nodes = {}, Lines = {}, Selected = nil }
local journal = { Cards = {}, Selected = nil }
local currentTab = nil
local displayedCash = 0
local displayedBag = 0
local onDigPress = nil

--------------------------------------------------------------------------
-- GUI HELPERS
--------------------------------------------------------------------------
local function new(className, props, children)
	local instance = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

local function stroke(color, thickness, transparency)
	return new("UIStroke", {
		Color = color or C.Ochre,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function padding(all)
	local px = UDim.new(0, all)
	return new("UIPadding", { PaddingTop = px, PaddingBottom = px, PaddingLeft = px, PaddingRight = px })
end

local function text(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or BODY
	props.TextColor3 = props.TextColor3 or C.Ink
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
	if props.TextScaled == nil and props.TextSize == nil then
		props.TextSize = 16
	end
	return new("TextLabel", props)
end

local function card(props, children)
	local radius = props.Radius or 14
	props.Radius = nil
	props.BackgroundColor3 = props.BackgroundColor3 or C.Paper
	props.BorderSizePixel = 0
	local frame = new("Frame", props, children)
	corner(radius).Parent = frame
	return frame
end

local function colorByName(name)
	if typeof(name) == "Color3" then
		return name
	end
	return C[name] or GameConfig.Rarities[name] or C.Ochre
end

local function pressFeedback(button)
	local scale = button:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.95 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.04 }):Play()
	end)
end

local function makeButton(props)
	local button = new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.Color or C.Ochre,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Font = props.Font or BOLD,
		Text = props.Text or "",
		TextColor3 = props.TextColor or C.Cream,
		TextSize = props.TextSize or 16,
		TextScaled = props.TextScaled or false,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	corner(props.Radius or 10).Parent = button
	pressFeedback(button)
	return button
end

local function progressBar(parent, props)
	local track = card({
		Name = props.Name or "Bar",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.Track or Color3.fromRGB(236, 222, 198),
		Radius = props.Radius or 8,
		Parent = parent,
	})
	local fill = card({
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = props.Fill or C.Ochre,
		Radius = props.Radius or 8,
		Parent = track,
	})
	new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(225, 225, 225)),
		Rotation = 90,
		Parent = fill,
	})
	return track, fill
end

-- ViewportFrame showing a model, auto-framed
local function makeViewport(parent, model, props)
	local viewport = new("ViewportFrame", {
		Name = props.Name or "Viewport",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 184, 160),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-1, -1.4, -0.8),
		LayoutOrder = props.LayoutOrder or 0,
		Parent = parent,
	})
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	model.Parent = viewport
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * (props.Zoom or 1.05)
	local direction = (props.Direction or Vector3.new(1, 0.9, 1.2)).Unit
	camera.CFrame = CFrame.lookAt(cf.Position + direction * distance, cf.Position)
	viewport:SetAttribute("Distance", distance)
	return viewport, camera, cf.Position
end

--------------------------------------------------------------------------
-- TOASTS & POPS
--------------------------------------------------------------------------
function Interface.Toast(message, color, icon, duration)
	if not hud.Toasts then
		return
	end
	local accent = colorByName(color)
	local toast = card({
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Paper,
		BackgroundTransparency = 0.02,
		Parent = hud.Toasts,
	}, { stroke(accent, 2), padding(10) })
	toast.LayoutOrder = -math.floor(os.clock() * 100)
	new("Frame", {
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = toast,
	}, { corner(2) })
	text({
		Size = UDim2.new(1, -14, 0, 0),
		Position = UDim2.fromOffset(14, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = (icon and (icon .. "  ") or "") .. tostring(message),
		TextWrapped = true,
		Font = BOLD,
		TextSize = 15,
		Parent = toast,
	})
	local scale = new("UIScale", { Scale = 0.6, Parent = toast })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(duration or 3.2, function()
		if toast.Parent then
			TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
			task.wait(0.22)
			toast:Destroy()
		end
	end)
end

local function popText(message, color, size)
	local label = text({
		Size = UDim2.fromOffset(420, size or 56),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -70),
		Text = message,
		Font = TITLE,
		TextSize = size or 46,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = color or C.Gold,
		TextStrokeColor3 = C.Ink,
		TextStrokeTransparency = 0.3,
		ZIndex = 20,
		Parent = hud.Gui,
	})
	local scale = new("UIScale", { Scale = 0.3, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(label, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.5, -150) }):Play()
	task.delay(0.8, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(1.4, function()
		label:Destroy()
	end)
end

local function confetti(count)
	local colors = { C.Ochre, C.Terracotta, C.Sky, C.Sage, C.Gold, C.Cream }
	local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	for _ = 1, count do
		local piece = new("Frame", {
			Size = UDim2.fromOffset(math.random(6, 12), math.random(10, 18)),
			Position = UDim2.fromOffset(math.random(0, math.floor(viewport.X)), -20),
			BackgroundColor3 = colors[math.random(1, #colors)],
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 30,
			Parent = hud.Gui,
		})
		local duration = 1.6 + math.random() * 1.4
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(piece.Position.X.Offset + math.random(-160, 160), math.floor(viewport.Y) + 30),
			Rotation = piece.Rotation + math.random(-540, 540),
		}):Play()
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

--------------------------------------------------------------------------
-- HUD
--------------------------------------------------------------------------
local function buildHUD(playerGui)
	local gui = new("ScreenGui", {
		Name = "SandsweepHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		Parent = playerGui,
	})
	hud.Gui = gui
	hud.Scale = new("UIScale", { Parent = gui })

	-- CASH
	local cashCard = card({ Name = "Cash", Size = UDim2.fromOffset(236, 66), Position = UDim2.fromOffset(16, 66), Parent = gui }, { stroke(C.Ochre, 2) })
	new("Frame", { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(12, 11), BackgroundColor3 = C.Gold, BorderSizePixel = 0, Parent = cashCard }, {
		corner(22),
		stroke(C.Ochre, 3),
		text({ Size = UDim2.fromScale(1, 1), Text = "$", Font = TITLE, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Ink }),
	})
	text({ Size = UDim2.fromOffset(160, 16), Position = UDim2.fromOffset(66, 10), Text = "CASH", Font = BOLD, TextSize = 12, TextColor3 = C.InkSoft, Parent = cashCard })
	hud.CashLabel = text({ Size = UDim2.fromOffset(164, 34), Position = UDim2.fromOffset(66, 24), Text = "$0", Font = TITLE, TextSize = 30, Parent = cashCard })

	-- FINDS CHIP (opens journal)
	local findsChip = makeButton({ Name = "FindsChip", Size = UDim2.fromOffset(160, 32), Position = UDim2.fromOffset(16, 140), Color = C.Paper, TextColor = C.Ink, Text = "📜  Finds 0/14", TextSize = 14, Parent = gui })
	stroke(C.Ochre, 2).Parent = findsChip
	findsChip.MouseButton1Click:Connect(function()
		Interface.Open("Journal")
	end)
	hud.FindsChip = findsChip

	-- LOT PROGRESS
	local lotCard = card({ Name = "Lot", Size = UDim2.fromOffset(340, 58), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Parent = gui }, { stroke(C.Ochre, 2) })
	hud.LotTitle = text({ Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 6), Text = string.upper(GameConfig.Lot.Name), Font = BOLD, TextSize = 13, TextColor3 = C.InkSoft, Parent = lotCard })
	hud.LotPercent = text({ Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 6), Text = "0.0% cleared", Font = TITLE, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Right, Parent = lotCard })
	local _, lotFill = progressBar(lotCard, { Size = UDim2.new(1, -24, 0, 12), Position = UDim2.fromOffset(12, 34), Fill = C.Sage })
	hud.LotFill = lotFill

	-- BAG
	local bagCard = card({ Name = "Bag", Size = UDim2.fromOffset(460, 72), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Parent = gui }, { stroke(C.Ochre, 2) })
	hud.BagName = text({ Size = UDim2.new(0.6, 0, 0, 22), Position = UDim2.fromOffset(14, 8), Text = "👝  Pocket Pouch", Font = BOLD, TextSize = 16, Parent = bagCard })
	hud.BagWeight = text({ Size = UDim2.new(0.5, 0, 0, 22), Position = UDim2.new(0.5, -14, 0, 8), Text = "0.0 / 15.0 kg", Font = TITLE, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, Parent = bagCard })
	local bagTrack, bagFill = progressBar(bagCard, { Size = UDim2.new(1, -28, 0, 20), Position = UDim2.fromOffset(14, 40), Fill = C.Ochre, Radius = 10 })
	hud.BagTrack = bagTrack
	hud.BagFill = bagFill
	hud.BagCard = bagCard
	hud.BagStroke = bagCard:FindFirstChildOfClass("UIStroke")
	local fullPill = card({ Name = "FullPill", Size = UDim2.fromOffset(330, 32), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8), BackgroundColor3 = C.Terracotta, Radius = 16, Visible = false, Parent = bagCard })
	hud.FullPillLabel = text({ Size = UDim2.fromScale(1, 1), Text = "BAG FULL - melt it at the Glass Furnace 🔥", Font = BOLD, TextSize = 14, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Center, Parent = fullPill })
	hud.FullPill = fullPill

	-- TOOL
	local toolCard = card({ Name = "Tool", Size = UDim2.fromOffset(260, 72), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -20), Parent = gui }, { stroke(C.Ochre, 2) })
	hud.ToolName = text({ Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 7), Text = "Bare Hands", Font = TITLE, TextSize = 19, Parent = toolCard })
	hud.ToolHint = text({ Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 30), Text = "Click sand to dig", Font = BOLD, TextSize = 12, TextColor3 = C.InkSoft, Parent = toolCard })
	hud.ToolStats = text({ Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 48), Text = "", Font = BODY, TextSize = 12, TextColor3 = C.InkSoft, Parent = toolCard })
	local hotbar = new("Frame", { Name = "Hotbar", Size = UDim2.fromOffset(350, 34), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -100), BackgroundTransparency = 1, Parent = gui }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	hud.Hotbar = {}
	for index, tool in ipairs(GameConfig.Tools) do
		local slot = makeButton({ Name = tool.Id, Size = UDim2.fromOffset(66, 34), Color = C.Paper, TextColor = C.InkSoft, Text = tostring(index), TextSize = 12, LayoutOrder = index, Parent = hotbar })
		stroke(C.Locked, 2).Parent = slot
		slot.MouseButton1Click:Connect(function()
			if ClientState.State.OwnedTools[tool.Id] then
				local ok, message = ClientState.Purchase("Equip", tool.Id)
				if not ok then
					Interface.Toast(message, "Terracotta")
				end
			else
				Interface.Open("Shop")
			end
		end)
		hud.Hotbar[tool.Id] = slot
	end

	-- MENU BUTTONS (right edge on PC; a top-right row on touch so they never cover DIG/Jump)
	local touch = UserInputService.TouchEnabled
	local side = new("Frame", {
		Name = "SideButtons",
		Size = touch and UDim2.fromOffset(230, 70) or UDim2.fromOffset(70, 236),
		AnchorPoint = touch and Vector2.new(1, 0) or Vector2.new(1, 0.5),
		Position = touch and UDim2.new(1, -16, 0, 12) or UDim2.new(1, -16, 0.5, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = touch and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		}),
	})
	for index, spec in ipairs({ { "Shop", "🛠", "B" }, { "Skills", "✦", "K" }, { "Journal", "📖", "J" } }) do
		local button = makeButton({ Name = spec[1], Size = UDim2.fromOffset(70, 70), Color = C.Paper, TextColor = C.Ink, Text = "", LayoutOrder = index, Parent = side })
		stroke(C.Ochre, 2).Parent = button
		text({ Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 6), Text = spec[2], Font = TITLE, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Parent = button })
		text({ Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 44), Text = spec[1] .. "  [" .. spec[3] .. "]", Font = BOLD, TextSize = 11, TextColor3 = C.InkSoft, TextXAlignment = Enum.TextXAlignment.Center, Parent = button })
		button.MouseButton1Click:Connect(function()
			Interface.Toggle(spec[1])
		end)
	end

	-- CROSSHAIR
	local cross = new("Frame", { Name = "Crosshair", Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.Cream, BorderSizePixel = 0, Parent = gui }, {
		corner(5),
		stroke(C.Ink, 1.5, 0.3),
	})
	local ring = new("Frame", { Name = "Ring", Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = gui }, {
		corner(15),
		stroke(C.Cream, 2, 0.2),
	})
	hud.Cross = cross
	hud.Ring = ring
	hud.RingStroke = ring:FindFirstChildOfClass("UIStroke")
	hud.CrossHint = text({ Size = UDim2.fromOffset(240, 18), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 24), Text = "", Font = BOLD, TextSize = 13, TextColor3 = C.Cream, TextStrokeTransparency = 0.4, TextStrokeColor3 = C.Ink, TextXAlignment = Enum.TextXAlignment.Center, Parent = gui })

	-- TOASTS
	hud.Toasts = new("Frame", { Name = "Toasts", Size = UDim2.fromOffset(300, 400), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, touch and 96 or 66), BackgroundTransparency = 1, Parent = gui }, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})

	-- BANNER (lot cleared / fresh sand)
	local banner = card({ Name = "Banner", Size = UDim2.fromOffset(520, 92), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -120), BackgroundColor3 = C.Paper, Parent = gui }, { stroke(C.Gold, 3) })
	hud.BannerTitle = text({ Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 10), Text = "", Font = TITLE, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, Parent = banner })
	hud.BannerBody = text({ Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 52), Text = "", Font = BOLD, TextSize = 15, TextColor3 = C.InkSoft, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Parent = banner })
	hud.Banner = banner

	-- FIND CELEBRATION
	local celebration = card({ Name = "FindCelebration", Size = UDim2.fromOffset(360, 330), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Visible = false, ZIndex = 10, Parent = gui }, { stroke(C.Gold, 4) })
	hud.CelebrationScale = new("UIScale", { Parent = celebration })
	hud.CelebrationHeader = text({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 12), Text = "NEW FIND!", Font = TITLE, TextSize = 28, TextColor3 = C.Terracotta, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = celebration })
	hud.CelebrationView = new("Frame", { Name = "ViewHolder", Size = UDim2.fromOffset(200, 160), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), BackgroundColor3 = C.Cream, BorderSizePixel = 0, ZIndex = 11, Parent = celebration }, { corner(100) })
	hud.CelebrationName = text({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 210), Text = "", Font = TITLE, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = celebration })
	hud.CelebrationRarity = text({ Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 240), Text = "", Font = BOLD, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = celebration })
	hud.CelebrationBonus = text({ Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 262), Text = "", Font = TITLE, TextSize = 26, TextColor3 = C.Sage, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = celebration })
	hud.CelebrationCount = text({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 296), Text = "", Font = BOLD, TextSize = 13, TextColor3 = C.InkSoft, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = celebration })
	hud.Celebration = celebration

	-- MOBILE DIG BUTTON
	if UserInputService.TouchEnabled then
		-- sits above Roblox's Jump button (which occupies roughly the bottom-right 180x150 px)
		local digButton = makeButton({ Name = "DigButton", Size = UDim2.fromOffset(100, 100), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -56, 1, -190), Color = C.Ochre, TextColor = C.Cream, Text = "DIG", Font = TITLE, TextSize = 28, Radius = 48, Parent = gui })
		stroke(C.Cream, 3).Parent = digButton
		digButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				ClientState.DigHeld = true
				if onDigPress then
					onDigPress()
				end
			end
		end)
		digButton.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				ClientState.DigHeld = false
			end
		end)
		hud.DigButton = digButton
		local flipButton = makeButton({ Name = "FlipButton", Size = UDim2.fromOffset(72, 72), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -172, 1, -200), Color = C.Sky, TextColor = C.Ink, Text = "FLIP", Font = TITLE, TextSize = 20, Radius = 36, Parent = gui })
		flipButton.Visible = false
		stroke(C.Cream, 3).Parent = flipButton
		flipButton.MouseButton1Click:Connect(function()
			if onFlip then
				onFlip()
			end
		end)
		hud.FlipButton = flipButton
	end
end

local function refreshHUD(state)
	local stats = state.Derived or ClientState.GetStats()
	local tool = GameConfig.GetTool(state.EquippedTool) or GameConfig.Tools[1]
	local bag = GameConfig.GetBag(state.BagTier) or GameConfig.Bags[1]
	hud.ToolName.Text = string.format("%s  ·  Tier %d", tool.Name, tool.Tier)
	if tool.Mode == "Click" then
		hud.ToolHint.Text = "Click sand to dig  ·  1-5 swap tools"
	elseif tool.Mode == "Hold" then
		hud.ToolHint.Text = "Click or hold to dig  ·  1-5 swap tools"
	else
		hud.ToolHint.Text = "Hold to vacuum  ·  1-5 swap tools"
	end
	hud.ToolStats.Text = string.format("Radius %.1f  ·  %.2fs  ·  x%.1f value", stats.Radius, stats.Cooldown, stats.ValueMultiplier)
	hud.BagName.Text = string.format("%s  %s", bag.Icon, bag.Name)
	hud.FindsChip.Text = string.format("📜  Finds %d/%d", Util.CountKeys(state.Finds or {}), #GameConfig.Finds)
	for _, item in ipairs(GameConfig.Tools) do
		local slot = hud.Hotbar[item.Id]
		local owned = state.OwnedTools and state.OwnedTools[item.Id]
		local equipped = state.EquippedTool == item.Id
		slot.Text = owned and string.format("%d %s", item.Index, item.Short or item.Id) or string.format("%d 🔒", item.Index)
		slot.TextColor3 = equipped and C.Cream or (owned and C.Ink or C.InkSoft)
		slot.BackgroundColor3 = equipped and C.Ochre or C.Paper
		local slotStroke = slot:FindFirstChildOfClass("UIStroke")
		if slotStroke then
			slotStroke.Color = equipped and C.Ink or (owned and C.Ochre or C.Locked)
		end
	end
	if menu.CashLabel then
		menu.CashLabel.Text = Util.FormatCash(state.Cash)
	end
end

local function refreshLot(lot)
	if lot.Generating then
		hud.LotPercent.Text = "fresh sand incoming..."
		TweenService:Create(hud.LotFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(0, 1) }):Play()
		return
	end
	hud.LotPercent.Text = string.format("%s cleared", Util.FormatPercent(lot.Percent >= GameConfig.Lot.ClearedThreshold and 1 or lot.Percent))
	TweenService:Create(hud.LotFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(lot.Percent, 0, 1), 1) }):Play()
end

local function showBanner(title, body, color, duration)
	hud.BannerTitle.Text = title
	hud.BannerTitle.TextColor3 = colorByName(color or "Ink")
	hud.BannerBody.Text = body
	TweenService:Create(hud.Banner, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 84) }):Play()
	task.delay(duration or 4, function()
		TweenService:Create(hud.Banner, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -120) }):Play()
	end)
end

--------------------------------------------------------------------------
-- MENU WINDOW (tabs: Shop, Skills, Journal)
--------------------------------------------------------------------------
local function buildMenu(playerGui)
	local gui = new("ScreenGui", {
		Name = "SandsweepMenus",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Enabled = true,
		Parent = playerGui,
	})
	menu.Gui = gui
	-- Modal backdrop frees the mouse from first-person lock while a menu is open
	local backdrop = new("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.55,
		AutoButtonColor = false,
		Text = "",
		Modal = true,
		Visible = false,
		Parent = gui,
	})
	backdrop.MouseButton1Click:Connect(function()
		Interface.Close()
	end)
	menu.Backdrop = backdrop

	local window = card({ Name = "Window", Size = UDim2.fromOffset(780, 540), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.Cream, Radius = 20, Visible = false, Parent = gui }, { stroke(C.Ochre, 3) })
	menu.Window = window
	menu.Scale = new("UIScale", { Parent = window })
	-- swallow clicks so they don't reach the backdrop
	new("TextButton", { Name = "Blocker", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = window })

	local header = new("Frame", { Name = "Header", Size = UDim2.new(1, -32, 0, 56), Position = UDim2.fromOffset(16, 12), BackgroundTransparency = 1, Parent = window })
	menu.Title = text({ Size = UDim2.fromOffset(260, 30), Position = UDim2.fromOffset(0, 0), Text = "Upgrade Shop", Font = TITLE, TextSize = 28, Parent = header })
	menu.Subtitle = text({ Size = UDim2.fromOffset(300, 18), Position = UDim2.fromOffset(0, 32), Text = "", Font = BOLD, TextSize = 13, TextColor3 = C.InkSoft, Parent = header })

	local tabs = new("Frame", { Name = "Tabs", Size = UDim2.fromOffset(330, 40), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 30, 0, 6), BackgroundTransparency = 1, Parent = header }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	menu.TabButtons = {}
	for index, spec in ipairs({ { "Shop", "🛠 Shop" }, { "Skills", "✦ Skills" }, { "Journal", "📖 Journal" } }) do
		local tabButton = makeButton({ Name = spec[1], Size = UDim2.fromOffset(104, 38), Color = C.Paper, TextColor = C.Ink, Text = spec[2], TextSize = 15, LayoutOrder = index, Parent = tabs })
		stroke(C.Ochre, 2).Parent = tabButton
		tabButton.MouseButton1Click:Connect(function()
			Interface.Open(spec[1])
		end)
		menu.TabButtons[spec[1]] = tabButton
	end

	local cashPill = card({ Name = "CashPill", Size = UDim2.fromOffset(130, 36), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -50, 0, 8), BackgroundColor3 = C.Gold, Radius = 18, Parent = header }, { stroke(C.Ochre, 2) })
	menu.CashLabel = text({ Size = UDim2.fromScale(1, 1), Text = "$0", Font = TITLE, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Parent = cashPill })
	local close = makeButton({ Name = "Close", Size = UDim2.fromOffset(38, 38), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 7), Color = C.Terracotta, Text = "✕", TextSize = 18, Radius = 19, Parent = header })
	close.MouseButton1Click:Connect(function()
		Interface.Close()
	end)

	local content = new("Frame", { Name = "Content", Size = UDim2.new(1, -32, 1, -88), Position = UDim2.fromOffset(16, 76), BackgroundTransparency = 1, Parent = window })
	menu.Content = content
	menu.Pages = {}
	for _, name in ipairs({ "Shop", "Skills", "Journal" }) do
		menu.Pages[name] = new("Frame", { Name = name .. "Page", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = content })
	end
end

--------------------------------------------------------------------------
-- SHOP PAGE
--------------------------------------------------------------------------
local function buildShop()
	local page = menu.Pages.Shop
	local subTabs = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = page }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	shop.SubButtons = {}
	for index, spec in ipairs({ { "Tools", "🛠 Tools" }, { "Bags", "🎒 Bags" }, { "Vehicles", "🚚 Vehicles" }, { "Factory", "🏭 Factory" } }) do
		local button = makeButton({ Name = spec[1], Size = UDim2.fromOffset(124, 32), Color = C.Paper, TextColor = C.Ink, Text = spec[2], TextSize = 14, LayoutOrder = index, Parent = subTabs })
		button.MouseButton1Click:Connect(function()
			shop.Tab = spec[1]
			Effects.Play("Click", 0.8, 1.1)
			Interface.RefreshShop()
		end)
		shop.SubButtons[spec[1]] = button
	end

	local function makeList(name)
		return new("ScrollingFrame", {
			Name = name,
			Size = UDim2.new(1, 0, 1, -44),
			Position = UDim2.fromOffset(0, 44),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = C.Ochre,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = page,
		}, {
			new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
			new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6) }),
		})
	end
	shop.ToolList = makeList("ToolList")
	shop.BagList = makeList("BagList")

	for index, tool in ipairs(GameConfig.Tools) do
		local row = card({ Name = tool.Id, Size = UDim2.new(1, 0, 0, 108), LayoutOrder = index, BackgroundColor3 = C.Paper, Parent = shop.ToolList }, { stroke(C.Ochre, 2) })
		local holder = new("Frame", { Size = UDim2.fromOffset(92, 92), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C.Cream, BorderSizePixel = 0, Parent = row }, { corner(46) })
		if tool.Id == "Hands" then
			text({ Size = UDim2.fromScale(1, 1), Text = "✋", Font = TITLE, TextSize = 46, TextXAlignment = Enum.TextXAlignment.Center, Parent = holder })
		else
			makeViewport(holder, ToolModels.Build(tool.Id, true), { Size = UDim2.fromScale(1, 1), Direction = Vector3.new(1.4, 0.8, 0.3), Zoom = 0.9 })
		end
		text({ Size = UDim2.new(1, -280, 0, 26), Position = UDim2.fromOffset(112, 8), Text = tool.Name, Font = TITLE, TextSize = 22, Parent = row })
		local modeText = tool.Mode == "Click" and "Click to dig" or (tool.Mode == "Hold" and "Click / hold" or "Hold to vacuum")
		text({ Size = UDim2.new(1, -280, 0, 18), Position = UDim2.fromOffset(112, 36), Text = string.format("Tier %d  ·  Radius %.1f  ·  every %.2fs  ·  %s", tool.Tier, tool.Radius, tool.Cooldown, modeText), Font = BOLD, TextSize = 13, TextColor3 = C.Terracotta, Parent = row })
		text({ Size = UDim2.new(1, -280, 0, 36), Position = UDim2.fromOffset(112, 58), Text = tool.Description, TextWrapped = true, TextSize = 13, TextColor3 = C.InkSoft, TextYAlignment = Enum.TextYAlignment.Top, Parent = row })
		local action = makeButton({ Name = "Action", Size = UDim2.fromOffset(150, 46), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Text = "", TextSize = 16, Parent = row })
		action.MouseButton1Click:Connect(function()
			local state = ClientState.State
			local kind = state.OwnedTools[tool.Id] and "Equip" or "Tool"
			local ok, message = ClientState.Purchase(kind, tool.Id)
			if ok then
				Effects.Play(kind == "Tool" and "Sell" or "Click", 0.9, kind == "Tool" and 1.3 or 1)
				if kind == "Tool" then
					confetti(30)
				end
				Interface.Toast(message, "Sage", "✓")
			else
				Effects.Play("Error", 0.6, 1)
				Interface.Toast(message, "Terracotta")
			end
		end)
		shop.ToolCards[tool.Id] = { Row = row, Action = action }
	end

	for index, bag in ipairs(GameConfig.Bags) do
		local row = card({ Name = bag.Name, Size = UDim2.new(1, 0, 0, 84), LayoutOrder = index, BackgroundColor3 = C.Paper, Parent = shop.BagList }, { stroke(C.Ochre, 2) })
		new("Frame", { Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = C.Cream, BorderSizePixel = 0, Parent = row }, {
			corner(32),
			text({ Size = UDim2.fromScale(1, 1), Text = bag.Icon, Font = TITLE, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center }),
		})
		text({ Size = UDim2.new(1, -260, 0, 24), Position = UDim2.fromOffset(88, 10), Text = bag.Name, Font = TITLE, TextSize = 20, Parent = row })
		text({ Size = UDim2.new(1, -260, 0, 18), Position = UDim2.fromOffset(88, 36), Text = string.format("Tier %d  ·  Holds %s kg", bag.Tier, Util.Commas(bag.Capacity)), Font = BOLD, TextSize = 13, TextColor3 = C.Terracotta, Parent = row })
		text({ Size = UDim2.new(1, -260, 0, 18), Position = UDim2.fromOffset(88, 56), Text = bag.Description, TextSize = 13, TextColor3 = C.InkSoft, Parent = row })
		local action = makeButton({ Name = "Action", Size = UDim2.fromOffset(150, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Text = "", TextSize = 16, Parent = row })
		action.MouseButton1Click:Connect(function()
			local ok, message = ClientState.Purchase("Bag", bag.Tier)
			if ok then
				Effects.Play("Sell", 0.9, 1.3)
				confetti(24)
				Interface.Toast(message, "Sage", "✓")
			else
				Effects.Play("Error", 0.6, 1)
				Interface.Toast(message, "Terracotta")
			end
		end)
		shop.BagCards[bag.Tier] = { Row = row, Action = action }
	end

	-- VEHICLES
	shop.VehicleList = makeList("VehicleList")
	for index, vehicle in ipairs(GameConfig.Vehicles) do
		local row = card({ Name = vehicle.Id, Size = UDim2.new(1, 0, 0, 112), LayoutOrder = index, BackgroundColor3 = C.Paper, Parent = shop.VehicleList }, { stroke(C.Ochre, 2) })
		local holder = new("Frame", { Size = UDim2.fromOffset(120, 96), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C.Cream, BorderSizePixel = 0, Parent = row }, { corner(14) })
		makeViewport(holder, VehicleModels.Build(vehicle.Id, true), { Size = UDim2.fromScale(1, 1), Direction = Vector3.new(-1.2, 0.7, -1), Zoom = 0.95 })
		text({ Size = UDim2.new(1, -310, 0, 26), Position = UDim2.fromOffset(140, 8), Text = vehicle.Icon .. "  " .. vehicle.Name, Font = TITLE, TextSize = 22, Parent = row })
		local extra = vehicle.Id == "Bulldozer" and "  ·  auto-blade" or (vehicle.Id == "Excavator" and "  ·  12-stud scoops" or "  ·  fastest")
		text({ Size = UDim2.new(1, -310, 0, 18), Position = UDim2.fromOffset(140, 36), Text = string.format("Tier %d  ·  holds %s kg  ·  %d speed%s", vehicle.Tier, Util.Commas(vehicle.Capacity), vehicle.MaxSpeed, extra), Font = BOLD, TextSize = 13, TextColor3 = C.Terracotta, Parent = row })
		text({ Size = UDim2.new(1, -310, 0, 48), Position = UDim2.fromOffset(140, 58), Text = vehicle.Description, TextWrapped = true, TextSize = 13, TextColor3 = C.InkSoft, TextYAlignment = Enum.TextYAlignment.Top, Parent = row })
		local action = makeButton({ Name = "Action", Size = UDim2.fromOffset(150, 46), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Text = "", TextSize = 16, Parent = row })
		action.MouseButton1Click:Connect(function()
			local state = ClientState.State
			local kind
			if state.ActiveVehicle == vehicle.Id then
				kind = "DespawnVehicle"
			elseif state.OwnedVehicles and state.OwnedVehicles[vehicle.Id] then
				kind = "SpawnVehicle"
			else
				kind = "Vehicle"
			end
			local ok, message = ClientState.Purchase(kind, vehicle.Id)
			if ok then
				Effects.Play(kind == "Vehicle" and "Sell" or "Click", 0.9, kind == "Vehicle" and 1.3 or 1)
				if kind == "Vehicle" then
					confetti(40)
				end
				Interface.Toast(message, "Sage", vehicle.Icon)
				if kind ~= "DespawnVehicle" then
					Interface.Close()
				end
			else
				Effects.Play("Error", 0.6, 1)
				Interface.Toast(message, "Terracotta")
			end
		end)
		shop.VehicleCards[vehicle.Id] = { Row = row, Action = action }
	end

	-- FACTORY
	shop.FactoryList = makeList("FactoryList")
	shop.FactoryInfo = card({ Name = "Info", Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 0, BackgroundColor3 = C.Cream, Parent = shop.FactoryList }, { stroke(C.Ochre, 2) })
	shop.FactoryInfoLabel = text({ Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0), Text = "", Font = BOLD, TextSize = 14, TextWrapped = true, Parent = shop.FactoryInfo })
	for index, machine in ipairs(GameConfig.Factory) do
		local row = card({ Name = machine.Id, Size = UDim2.new(1, 0, 0, 92), LayoutOrder = index, BackgroundColor3 = C.Paper, Parent = shop.FactoryList }, { stroke(C.Ochre, 2) })
		new("Frame", { Size = UDim2.fromOffset(72, 72), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = C.Cream, BorderSizePixel = 0, Parent = row }, {
			corner(36),
			text({ Size = UDim2.fromScale(1, 1), Text = machine.Icon, Font = TITLE, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center }),
		})
		text({ Size = UDim2.new(1, -270, 0, 24), Position = UDim2.fromOffset(96, 8), Text = machine.Name, Font = TITLE, TextSize = 20, Parent = row })
		text({ Size = UDim2.new(1, -270, 0, 18), Position = UDim2.fromOffset(96, 34), Text = string.format("Output: %s  ·  %dx value", machine.Product, machine.Multiplier), Font = BOLD, TextSize = 13, TextColor3 = C.Terracotta, Parent = row })
		text({ Size = UDim2.new(1, -270, 0, 34), Position = UDim2.fromOffset(96, 54), Text = machine.Description, TextWrapped = true, TextSize = 13, TextColor3 = C.InkSoft, TextYAlignment = Enum.TextYAlignment.Top, Parent = row })
		local action = makeButton({ Name = "Action", Size = UDim2.fromOffset(150, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Text = "", TextSize = 16, Parent = row })
		action.MouseButton1Click:Connect(function()
			local ok, message = ClientState.Purchase("Factory", machine.Id)
			if ok then
				Effects.Fanfare()
				confetti(40)
				Interface.Toast(message, "Sage", machine.Icon)
			else
				Effects.Play("Error", 0.6, 1)
				Interface.Toast(message, "Terracotta")
			end
		end)
		shop.MachineCards[machine.Id] = { Row = row, Action = action }
	end
end

local function styleAction(button, label, color, textColor, enabled)
	button.Text = label
	button.BackgroundColor3 = color
	button.TextColor3 = textColor or C.Cream
	button.Active = enabled
	button.AutoButtonColor = false
end

local function refreshMachines(state)
	local owned = state.OwnedVehicles or {}
	for _, vehicle in ipairs(GameConfig.Vehicles) do
		local entry = shop.VehicleCards[vehicle.Id]
		local previous = GameConfig.Vehicles[vehicle.Index - 1]
		local unlocked = not previous or owned[previous.Id]
		if state.ActiveVehicle == vehicle.Id then
			styleAction(entry.Action, "Park (despawn)", C.Sky, C.Ink, true)
		elseif owned[vehicle.Id] then
			styleAction(entry.Action, "Spawn at Garage", C.Sage, C.Cream, true)
		elseif not unlocked then
			styleAction(entry.Action, "🔒 " .. Util.FormatCash(vehicle.Price), C.Locked, C.Ink, false)
		elseif (state.Cash or 0) >= vehicle.Price then
			styleAction(entry.Action, "Buy " .. Util.FormatCash(vehicle.Price), C.Ochre, C.Cream, true)
		else
			styleAction(entry.Action, Util.FormatCash(vehicle.Price), Color3.fromRGB(226, 206, 176), C.InkSoft, true)
		end
	end
	local factory = state.Factory or {}
	for _, machine in ipairs(GameConfig.Factory) do
		local entry = shop.MachineCards[machine.Id]
		local previous = GameConfig.Factory[machine.Index - 1]
		local unlocked = not previous or factory[previous.Id]
		if factory[machine.Id] then
			styleAction(entry.Action, "Online ✓", C.Sage, C.Cream, false)
		elseif not unlocked then
			styleAction(entry.Action, "🔒 " .. Util.FormatCash(machine.Price), C.Locked, C.Ink, false)
		elseif (state.Cash or 0) >= machine.Price then
			styleAction(entry.Action, "Build " .. Util.FormatCash(machine.Price), C.Ochre, C.Cream, true)
		else
			styleAction(entry.Action, Util.FormatCash(machine.Price), Color3.fromRGB(226, 206, 176), C.InkSoft, true)
		end
	end
	local stage = GameConfig.FactoryStage(state)
	if stage < 0 then
		shop.FactoryInfoLabel.Text = "🏭 Build the Input Hopper to start processing. Dump sand at the hopper (bag: E prompt · machines: drive onto the dump bay)."
	else
		shop.FactoryInfoLabel.Text = string.format("🏭 Hopper buffer: %s kg  ·  Your line outputs %sx value products", Util.FormatKg(state.FactoryBufferKg or 0), tostring(GameConfig.StageMultiplier(stage)))
	end
end


function Interface.RefreshShop()
	if not shop.ToolList then
		return
	end
	local state = ClientState.State
	shop.ToolList.Visible = shop.Tab == "Tools"
	shop.BagList.Visible = shop.Tab == "Bags"
	shop.VehicleList.Visible = shop.Tab == "Vehicles"
	shop.FactoryList.Visible = shop.Tab == "Factory"
	refreshMachines(state)
	for name, button in pairs(shop.SubButtons) do
		local active = name == shop.Tab
		button.BackgroundColor3 = active and C.Ochre or C.Paper
		button.TextColor3 = active and C.Cream or C.Ink
	end
	for _, tool in ipairs(GameConfig.Tools) do
		local entry = shop.ToolCards[tool.Id]
		local owned = state.OwnedTools[tool.Id]
		local previous = GameConfig.Tools[tool.Tier - 1]
		local unlocked = not previous or state.OwnedTools[previous.Id]
		if owned and state.EquippedTool == tool.Id then
			styleAction(entry.Action, "Equipped ✓", C.Sage, C.Cream, false)
		elseif owned then
			styleAction(entry.Action, "Equip", C.Sky, C.Ink, true)
		elseif not unlocked then
			styleAction(entry.Action, "🔒 " .. Util.FormatCash(tool.Price), C.Locked, C.Ink, false)
		elseif state.Cash >= tool.Price then
			styleAction(entry.Action, "Buy " .. Util.FormatCash(tool.Price), C.Ochre, C.Cream, true)
		else
			styleAction(entry.Action, Util.FormatCash(tool.Price), Color3.fromRGB(226, 206, 176), C.InkSoft, true)
		end
	end
	for _, bag in ipairs(GameConfig.Bags) do
		local entry = shop.BagCards[bag.Tier]
		if bag.Tier < state.BagTier then
			styleAction(entry.Action, "Owned ✓", C.Locked, C.Ink, false)
		elseif bag.Tier == state.BagTier then
			styleAction(entry.Action, "Current ✓", C.Sage, C.Cream, false)
		elseif bag.Tier == state.BagTier + 1 then
			if state.Cash >= bag.Price then
				styleAction(entry.Action, "Upgrade " .. Util.FormatCash(bag.Price), C.Ochre, C.Cream, true)
			else
				styleAction(entry.Action, Util.FormatCash(bag.Price), Color3.fromRGB(226, 206, 176), C.InkSoft, true)
			end
		else
			styleAction(entry.Action, "🔒 " .. Util.FormatCash(bag.Price), C.Locked, C.Ink, false)
		end
	end
end

--------------------------------------------------------------------------
-- SKILL TREE PAGE
--------------------------------------------------------------------------
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

local function drawLine(parent, a, b, thickness, color)
	local delta = b - a
	local line = new("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		Size = UDim2.fromOffset(delta.Magnitude, thickness),
		Rotation = math.deg(math.atan2(delta.Y, delta.X)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = parent,
	}, { corner(thickness / 2) })
	return line
end

local function buildSkills()
	local page = menu.Pages.Skills
	local canvas = card({ Name = "Canvas", Size = UDim2.new(1, 0, 1, -122), BackgroundColor3 = C.Paper, Parent = page }, { stroke(C.Ochre, 2) })
	skills.Canvas = canvas
	-- subtle dotted backdrop
	for gx = 0, 14 do
		for gy = 0, 6 do
			new("Frame", { Size = UDim2.fromOffset(3, 3), Position = UDim2.fromOffset(18 + gx * 50, 16 + gy * 46), BackgroundColor3 = Color3.fromRGB(236, 222, 198), BorderSizePixel = 0, Parent = canvas }, { corner(2) })
		end
	end

	local rootPos = Vector2.new(64, 160)
	local rowYs = { 44, 122, 200, 278 }
	local startX, spacing = 170, 56
	local NODE = 44

	-- lines first (under nodes)
	for index, skill in ipairs(GameConfig.Skills) do
		local y = rowYs[index]
		skills.Lines[skill.Id] = {}
		local firstPos = Vector2.new(startX, y)
		skills.Lines[skill.Id][1] = drawLine(canvas, rootPos, firstPos, 5, C.Locked)
		for level = 2, skill.MaxLevel do
			local a = Vector2.new(startX + (level - 2) * spacing, y)
			local b = Vector2.new(startX + (level - 1) * spacing, y)
			skills.Lines[skill.Id][level] = drawLine(canvas, a, b, 5, C.Locked)
		end
	end

	-- root node
	local root = makeButton({ Name = "Root", Size = UDim2.fromOffset(72, 72), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(rootPos.X, rootPos.Y), Color = C.Gold, TextColor = C.Ink, Text = "🌵", Font = TITLE, TextSize = 32, Radius = 36, Parent = canvas })
	root.ZIndex = 3
	stroke(C.Ochre, 3).Parent = root
	root.MouseButton1Click:Connect(function()
		skills.Selected = nil
		Effects.Play("Click", 0.7, 1.2)
		Interface.RefreshSkills()
	end)

	for index, skill in ipairs(GameConfig.Skills) do
		local y = rowYs[index]
		skills.Nodes[skill.Id] = {}
		for level = 1, skill.MaxLevel do
			local x = startX + (level - 1) * spacing
			local node = makeButton({
				Name = skill.Id .. level,
				Size = UDim2.fromOffset(NODE, NODE),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(x, y),
				Color = C.Cream,
				TextColor = C.InkSoft,
				Text = ROMAN[level] or tostring(level),
				Font = TITLE,
				TextSize = 16,
				Radius = NODE / 2,
				Parent = canvas,
			})
			node.ZIndex = 3
			stroke(C.Locked, 3).Parent = node
			node.MouseButton1Click:Connect(function()
				skills.Selected = { Id = skill.Id, Level = level }
				Effects.Play("Click", 0.7, 1 + level * 0.05)
				Interface.RefreshSkills()
			end)
			skills.Nodes[skill.Id][level] = node
		end
		local labelX = startX + (skill.MaxLevel - 1) * spacing + 32
		skills.Nodes[skill.Id].Label = text({
			Size = UDim2.fromOffset(150, 40),
			Position = UDim2.fromOffset(labelX, y - 20),
			Text = "",
			Font = BOLD,
			TextSize = 13,
			RichText = true,
			Parent = canvas,
		})
	end

	-- details panel
	local details = card({ Name = "Details", Size = UDim2.new(1, 0, 0, 110), Position = UDim2.new(0, 0, 1, -110), BackgroundColor3 = C.Paper, Parent = page }, { stroke(C.Ochre, 2) })
	skills.DetailTitle = text({ Size = UDim2.new(1, -220, 0, 28), Position = UDim2.fromOffset(16, 10), Text = "", Font = TITLE, TextSize = 22, Parent = details })
	skills.DetailBody = text({ Size = UDim2.new(1, -220, 0, 40), Position = UDim2.fromOffset(16, 40), Text = "", TextWrapped = true, TextSize = 14, TextColor3 = C.InkSoft, TextYAlignment = Enum.TextYAlignment.Top, Parent = details })
	skills.DetailEffect = text({ Size = UDim2.new(1, -220, 0, 20), Position = UDim2.fromOffset(16, 80), Text = "", Font = BOLD, TextSize = 14, TextColor3 = C.Terracotta, RichText = true, Parent = details })
	local unlock = makeButton({ Name = "Unlock", Size = UDim2.fromOffset(180, 52), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Text = "", TextSize = 16, Parent = details })
	unlock.MouseButton1Click:Connect(function()
		local selected = skills.Selected
		if not selected then
			return
		end
		local current = ClientState.State.Skills[selected.Id] or 0
		if selected.Level ~= current + 1 then
			return
		end
		local ok, message = ClientState.Purchase("Skill", selected.Id)
		if ok then
			Effects.Fanfare()
			confetti(20)
			Interface.Toast(message, "Sage", "✦")
			local skill = GameConfig.GetSkill(selected.Id)
			if skill and selected.Level < skill.MaxLevel then
				skills.Selected = { Id = selected.Id, Level = selected.Level + 1 }
			end
		else
			Effects.Play("Error", 0.6, 1)
			Interface.Toast(message, "Terracotta")
		end
		Interface.RefreshSkills()
	end)
	skills.Unlock = unlock
end

function Interface.RefreshSkills()
	if not skills.Canvas then
		return
	end
	local state = ClientState.State
	for _, skill in ipairs(GameConfig.Skills) do
		local current = state.Skills[skill.Id] or 0
		for level = 1, skill.MaxLevel do
			local node = skills.Nodes[skill.Id][level]
			local nodeStroke = node:FindFirstChildOfClass("UIStroke")
			local line = skills.Lines[skill.Id][level]
			local selected = skills.Selected and skills.Selected.Id == skill.Id and skills.Selected.Level == level
			if level <= current then
				node.BackgroundColor3 = skill.Color
				node.TextColor3 = C.Cream
				nodeStroke.Color = selected and C.Ink or C.Ochre
				line.BackgroundColor3 = skill.Color
			elseif level == current + 1 then
				local cost = GameConfig.GetSkillCost(skill.Id, current)
				node.BackgroundColor3 = C.Cream
				node.TextColor3 = C.Ink
				nodeStroke.Color = selected and C.Ink or skill.Color
				line.BackgroundColor3 = (cost and state.Cash >= cost) and skill.Color:Lerp(C.Cream, 0.4) or C.Locked
			else
				node.BackgroundColor3 = Color3.fromRGB(236, 228, 216)
				node.TextColor3 = C.Locked
				nodeStroke.Color = selected and C.Ink or C.Locked
				line.BackgroundColor3 = C.Locked
			end
			nodeStroke.Thickness = selected and 4 or 3
		end
		skills.Nodes[skill.Id].Label.Text = string.format("%s %s\n<font color=\"#8A6C56\">%s</font>", skill.Icon, skill.Name, current > 0 and GameConfig.DescribeSkillEffect(skill.Id, current) or "not learned")
	end

	local selected = skills.Selected
	if not selected then
		local total, maxTotal = 0, 0
		for _, skill in ipairs(GameConfig.Skills) do
			total += state.Skills[skill.Id] or 0
			maxTotal += skill.MaxLevel
		end
		skills.DetailTitle.Text = GameConfig.SkillRoot.Name
		skills.DetailBody.Text = GameConfig.SkillRoot.Description .. " Pick a node to see its upgrade."
		skills.DetailEffect.Text = string.format("%d / %d nodes unlocked", total, maxTotal)
		styleAction(skills.Unlock, "Select a node", C.Locked, C.Ink, false)
		return
	end
	local skill = GameConfig.GetSkill(selected.Id)
	local current = state.Skills[skill.Id] or 0
	skills.DetailTitle.Text = string.format("%s %s %s", skill.Icon, skill.Name, ROMAN[selected.Level] or tostring(selected.Level))
	skills.DetailBody.Text = skill.Description
	skills.DetailEffect.Text = string.format("Now: %s   →   At %s: <b>%s</b>", current > 0 and GameConfig.DescribeSkillEffect(skill.Id, current) or "none", ROMAN[selected.Level] or tostring(selected.Level), GameConfig.DescribeSkillEffect(skill.Id, selected.Level))
	if selected.Level <= current then
		styleAction(skills.Unlock, "Learned ✓", C.Sage, C.Cream, false)
	elseif selected.Level == current + 1 then
		local cost = GameConfig.GetSkillCost(skill.Id, current)
		if cost and state.Cash >= cost then
			styleAction(skills.Unlock, "Unlock " .. Util.FormatCash(cost), C.Ochre, C.Cream, true)
		else
			styleAction(skills.Unlock, "Need " .. Util.FormatCash(cost or 0), Color3.fromRGB(226, 206, 176), C.InkSoft, true)
		end
	else
		styleAction(skills.Unlock, "🔒 Unlock " .. (ROMAN[current + 1] or "") .. " first", C.Locked, C.Ink, false)
	end
end

--------------------------------------------------------------------------
-- FINDS JOURNAL PAGE
--------------------------------------------------------------------------
local function depthLabel(find)
	local avg = (find.DepthMin + find.DepthMax) / 2
	if avg < 6.5 then
		return "Shallow"
	elseif avg < 10 then
		return "Mid-depth"
	end
	return "Deep"
end

local function buildJournal()
	local page = menu.Pages.Journal
	local top = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = page })
	journal.Count = text({ Size = UDim2.fromOffset(240, 30), Text = "Discovered 0 / 14", Font = TITLE, TextSize = 20, Parent = top })
	local _, fill = progressBar(top, { Size = UDim2.new(1, -260, 0, 14), Position = UDim2.new(0, 250, 0.5, -7), Fill = C.Gold })
	journal.Fill = fill

	local grid = new("ScrollingFrame", {
		Name = "Grid",
		Size = UDim2.new(1, 0, 1, -148),
		Position = UDim2.fromOffset(0, 42),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Ochre,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = page,
	}, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(98, 136), CellPadding = UDim2.fromOffset(8, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 2) }),
	})

	for index, find in ipairs(GameConfig.Finds) do
		local rarityColor = GameConfig.Rarities[find.Rarity]
		local cardButton = new("TextButton", { Name = find.Id, BackgroundColor3 = C.Paper, AutoButtonColor = false, Text = "", BorderSizePixel = 0, LayoutOrder = index, Parent = grid }, {
			corner(12),
			stroke(rarityColor, 2),
		})
		pressFeedback(cardButton)
		new("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = rarityColor, BorderSizePixel = 0, Parent = cardButton }, { corner(3) })
		local viewport = makeViewport(cardButton, FindModels.Build(find.Id, true), { Size = UDim2.fromOffset(86, 78), Position = UDim2.fromOffset(6, 10), Zoom = 0.95 })
		local name = text({ Size = UDim2.new(1, -8, 0, 30), Position = UDim2.fromOffset(4, 88), Text = "???", Font = BOLD, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Parent = cardButton })
		local rarity = text({ Size = UDim2.new(1, -8, 0, 14), Position = UDim2.fromOffset(4, 118), Text = find.Rarity, Font = BOLD, TextSize = 11, TextColor3 = rarityColor, TextXAlignment = Enum.TextXAlignment.Center, Parent = cardButton })
		cardButton.MouseButton1Click:Connect(function()
			journal.Selected = find.Id
			Effects.Play("Click", 0.6, 1.2)
			Interface.RefreshJournal()
		end)
		journal.Cards[find.Id] = { Button = cardButton, Viewport = viewport, Name = name, Rarity = rarity }
	end

	local details = card({ Name = "Details", Size = UDim2.new(1, 0, 0, 96), Position = UDim2.new(0, 0, 1, -96), BackgroundColor3 = C.Paper, Parent = page }, { stroke(C.Ochre, 2) })
	journal.DetailTitle = text({ Size = UDim2.new(1, -32, 0, 26), Position = UDim2.fromOffset(16, 10), Text = "", Font = TITLE, TextSize = 21, Parent = details })
	journal.DetailMeta = text({ Size = UDim2.new(1, -32, 0, 18), Position = UDim2.fromOffset(16, 38), Text = "", Font = BOLD, TextSize = 13, TextColor3 = C.Terracotta, Parent = details })
	journal.DetailBody = text({ Size = UDim2.new(1, -32, 0, 30), Position = UDim2.fromOffset(16, 58), Text = "", TextWrapped = true, TextSize = 13, TextColor3 = C.InkSoft, TextYAlignment = Enum.TextYAlignment.Top, Parent = details })
end

function Interface.RefreshJournal()
	if not journal.Count then
		return
	end
	local state = ClientState.State
	local found = state.Finds or {}
	local count = Util.CountKeys(found)
	journal.Count.Text = string.format("Discovered %d / %d", count, #GameConfig.Finds)
	TweenService:Create(journal.Fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(count / #GameConfig.Finds, 1) }):Play()
	for _, find in ipairs(GameConfig.Finds) do
		local entry = journal.Cards[find.Id]
		local discovered = found[find.Id] == true
		entry.Viewport.ImageColor3 = discovered and Color3.new(1, 1, 1) or Color3.fromRGB(40, 30, 24)
		entry.Viewport.ImageTransparency = discovered and 0 or 0.35
		entry.Name.Text = discovered and find.Name or "???"
		entry.Button.BackgroundColor3 = (journal.Selected == find.Id) and C.Cream or C.Paper
	end
	local selectedId = journal.Selected
	if not selectedId then
		journal.DetailTitle.Text = "Finds Journal"
		journal.DetailMeta.Text = string.format("%d relics are buried in every lot", #GameConfig.Finds)
		journal.DetailBody.Text = "Dig down until a relic glints, walk up to it and press E to collect. Deeper finds pay more."
		return
	end
	local find = GameConfig.GetFind(selectedId)
	local discovered = found[selectedId] == true
	journal.DetailTitle.Text = discovered and find.Name or "Undiscovered relic"
	journal.DetailMeta.Text = string.format("%s  ·  %s  ·  First find %s  ·  Repeat %s", find.Rarity, depthLabel(find), Util.FormatCash(find.Bonus), Util.FormatCash(math.floor(find.Bonus * GameConfig.Economy.DuplicateFindMultiplier)))
	journal.DetailBody.Text = discovered and find.Description or string.format("Buried roughly %.0f-%.0f studs below the lot's edge. Keep digging!", find.DepthMin, find.DepthMax)
end

--------------------------------------------------------------------------
-- OPEN / CLOSE
--------------------------------------------------------------------------
local SUBTITLES = {
	Shop = "Better tools, bigger bags",
	Skills = "Passive upgrades that stack forever",
	Journal = "Every relic you've pulled from the sand",
}
local TITLES = { Shop = "Upgrade Shop", Skills = "Skill Tree", Journal = "Finds Journal" }

function Interface.Open(tab)
	if not menu.Pages or not menu.Pages[tab] then
		return
	end
	local wasOpen = currentTab ~= nil
	currentTab = tab
	ClientState.UIOpen = true
	ClientState.DigHeld = false
	menu.Backdrop.Visible = true
	menu.Window.Visible = true
	UserInputService.MouseIconEnabled = true
	for name, page in pairs(menu.Pages) do
		page.Visible = name == tab
	end
	for name, button in pairs(menu.TabButtons) do
		button.BackgroundColor3 = name == tab and C.Ochre or C.Paper
		button.TextColor3 = name == tab and C.Cream or C.Ink
	end
	menu.Title.Text = TITLES[tab]
	menu.Subtitle.Text = SUBTITLES[tab]
	menu.CashLabel.Text = Util.FormatCash(ClientState.State.Cash)
	Interface.RefreshShop()
	Interface.RefreshSkills()
	Interface.RefreshJournal()
	Effects.Play("Click", 0.8, wasOpen and 1.2 or 1)
	if not wasOpen then
		local scale = menu.Window:FindFirstChildOfClass("UIScale")
		local target = scale:GetAttribute("Target") or 1
		scale.Scale = target * 0.85
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
	end
end

function Interface.Close()
	if not currentTab then
		return
	end
	currentTab = nil
	ClientState.UIOpen = false
	menu.Backdrop.Visible = false
	menu.Window.Visible = false
	UserInputService.MouseIconEnabled = false
	Effects.Play("Click", 0.6, 0.85)
end

function Interface.Toggle(tab)
	if currentTab == tab then
		Interface.Close()
	else
		Interface.Open(tab)
	end
end

--------------------------------------------------------------------------
-- NOTIFICATIONS
--------------------------------------------------------------------------
local lastBagFullToast = 0
local function celebrateFind(payload)
	local find = GameConfig.GetFind(payload.FindId)
	if not find then
		return
	end
	local rarityColor = GameConfig.Rarities[find.Rarity]
	hud.CelebrationHeader.Text = payload.IsNew and "NEW FIND!" or "FOUND AGAIN"
	hud.CelebrationName.Text = find.Name
	hud.CelebrationRarity.Text = string.upper(find.Rarity)
	hud.CelebrationRarity.TextColor3 = rarityColor
	hud.CelebrationBonus.Text = "+" .. Util.FormatCash(payload.Bonus)
	hud.CelebrationCount.Text = string.format("Journal  %d / %d", payload.Count or 0, payload.Total or #GameConfig.Finds)
	local celebrationStroke = hud.Celebration:FindFirstChildOfClass("UIStroke")
	if celebrationStroke then
		celebrationStroke.Color = rarityColor
	end
	hud.CelebrationView:ClearAllChildren()
	corner(100).Parent = hud.CelebrationView
	local viewport, camera, center = makeViewport(hud.CelebrationView, FindModels.Build(find.Id, true), { Size = UDim2.fromScale(1, 1), Zoom = 0.85 })
	viewport.ZIndex = 12
	local distance = viewport:GetAttribute("Distance")
	local spinConnection
	local angle = 0
	spinConnection = RunService.RenderStepped:Connect(function(dt)
		if not viewport.Parent then
			spinConnection:Disconnect()
			return
		end
		angle += dt * 1.4
		camera.CFrame = CFrame.lookAt(center + Vector3.new(math.cos(angle), 0.7, math.sin(angle)).Unit * distance, center)
	end)

	hud.Celebration.Visible = true
	hud.CelebrationScale.Scale = 0.2
	TweenService:Create(hud.CelebrationScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Effects.Fanfare()
	confetti(payload.IsNew and 70 or 30)
	task.delay(3.6, function()
		local tween = TweenService:Create(hud.CelebrationScale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
		tween:Play()
		tween.Completed:Wait()
		hud.Celebration.Visible = false
		if spinConnection then
			spinConnection:Disconnect()
		end
	end)
end

local function onNotify(payload)
	local kind = payload.Kind
	if kind == "Sell" then
		Effects.CashRegister()
		popText("+" .. Util.FormatCash(payload.Cash), C.Gold, 52)
		Interface.Toast(string.format("Melted %s kg of sand into glass for %s", Util.FormatKg(payload.Kg), Util.FormatCash(payload.Cash)), "Sage", "🔥")
	elseif kind == "BagFull" then
		local now = os.clock()
		if now - lastBagFullToast > 4 then
			lastBagFullToast = now
			Interface.Toast("Your bag is full! Melt it at the Glass Furnace in base camp.", "Terracotta", "🎒")
		end
		local bagStroke = hud.BagStroke
		if bagStroke then
			bagStroke.Color = C.Terracotta
			bagStroke.Thickness = 4
			TweenService:Create(bagStroke, TweenInfo.new(0.6), { Thickness = 2 }):Play()
		end
	elseif kind == "Find" then
		celebrateFind(payload)
	elseif kind == "FindUncovered" then
		local find = GameConfig.GetFind(payload.FindId)
		if find then
			local discovered = ClientState.State.Finds and ClientState.State.Finds[find.Id]
			Interface.Toast(discovered and string.format("A %s glints in the sand!", find.Name) or string.format("Something %s glints in the sand...", string.lower(find.Rarity)), find.Rarity, "✨")
			Effects.Play("Chime", 0.6, 1.5)
		end
	elseif kind == "LotCleared" then
		Effects.Fanfare()
		confetti(90)
		local body = payload.Bonus and payload.Bonus > 0 and string.format("You moved %s kg. Clearing bonus: %s!", Util.FormatKg(payload.Contributed or 0), Util.FormatCash(payload.Bonus))
			or "Fresh sand is on its way."
		showBanner("DESERT CLEARED! Not a grain left.", body .. string.format(" New sand in %ds.", payload.Delay or 10), "Sage", 6)
	elseif kind == "LotReady" then
		showBanner("Fresh sand delivered!", "A brand new desert with 14 new relics buried inside.", "Ochre", 4)
		Effects.Play("Splash", 1, 0.7)
	elseif kind == "Toast" then
		Interface.Toast(payload.Text or "", payload.Color or "Ochre", payload.Icon)
	end
end

--------------------------------------------------------------------------
-- PER-FRAME UPDATES
--------------------------------------------------------------------------
local function updateScales()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local hudScale = math.clamp(math.min(viewport.X / 1100, viewport.Y / 700), 0.62, 1)
	hud.Scale.Scale = hudScale
	local windowScale = math.clamp(math.min((viewport.X - 24) / 780, (viewport.Y - 24) / 540), 0.45, 1.15)
	if menu.Scale then
		menu.Scale:SetAttribute("Target", windowScale)
		if not currentTab then
			menu.Scale.Scale = windowScale
		end
	end
end

local function frame(dt)
	local state = ClientState.State
	-- cash count-up
	local target = state.Cash or 0
	if math.abs(target - displayedCash) < 0.5 then
		displayedCash = target
	else
		displayedCash += (target - displayedCash) * math.min(1, dt * 8)
	end
	hud.CashLabel.Text = Util.FormatCash(displayedCash)

	-- bag fill (switches to the machine's storage while driving)
	local stats = ClientState.GetStats()
	local capacity = math.max(stats.Capacity, 0.001)
	local bagKg = state.BagKg or 0
	local vehicle = ClientState.InVehicle
	if vehicle and vehicle.Model.Parent then
		capacity = math.max(vehicle.Model:GetAttribute("Capacity") or vehicle.Config.Capacity, 0.001)
		bagKg = vehicle.Model:GetAttribute("StorageKg") or 0
		hud.BagName.Text = string.format("%s  %s storage", vehicle.Config.Icon, vehicle.Config.Name)
		hud.ToolName.Text = vehicle.Config.Name
		hud.ToolHint.Text = vehicle.Config.Id == "Excavator" and "WASD drive · hold click: scoop · R flip" or "WASD drive · R flip · Space exit"
		hud.ToolStats.Text = vehicle.Config.Id == "Bulldozer" and "Drive forward to carve sand with the blade" or "Dump bays: kiln (sell) · hopper (factory)"
		if hud.FullPillLabel then
			hud.FullPillLabel.Text = "MACHINE FULL - drive onto a dump bay 🚚"
		end
	elseif wasInVehicle then
		refreshHUD(state)
		if hud.FullPillLabel then
			hud.FullPillLabel.Text = "BAG FULL - melt it at the Glass Furnace 🔥"
		end
	end
	if hud.FlipButton then
		hud.FlipButton.Visible = vehicle ~= nil
	end
	if hud.DigButton then
		hud.DigButton.Text = (vehicle and vehicle.Config.Id == "Excavator") and "SCOOP" or "DIG"
		hud.DigButton.Visible = vehicle == nil or vehicle.Config.Id == "Excavator"
	end
	wasInVehicle = vehicle ~= nil
	displayedBag += (bagKg - displayedBag) * math.min(1, dt * 12)
	if math.abs(bagKg - displayedBag) < 0.01 then
		displayedBag = bagKg
	end
	local fraction = math.clamp(displayedBag / capacity, 0, 1)
	hud.BagFill.Size = UDim2.fromScale(fraction, 1)
	hud.BagWeight.Text = string.format("%s / %s kg", Util.FormatKg(displayedBag), Util.FormatKg(capacity))
	local full = bagKg >= capacity - 0.01
	hud.BagFill.BackgroundColor3 = full and C.Terracotta or (fraction > 0.8 and C.Ochre:Lerp(C.Terracotta, (fraction - 0.8) / 0.2) or C.Ochre)
	hud.FullPill.Visible = full
	if full then
		hud.FullPill.BackgroundTransparency = 0.1 + math.abs(math.sin(os.clock() * 4)) * 0.25
	end
	if hud.BagStroke and not full then
		hud.BagStroke.Color = hud.BagStroke.Color:Lerp(C.Ochre, math.min(1, dt * 3))
	end

	-- crosshair
	local crosshair = ClientState.Crosshair
	local show = not ClientState.UIOpen
	hud.Cross.Visible = show
	hud.Ring.Visible = show and crosshair ~= "idle"
	hud.CrossHint.Visible = show
	if crosshair == "valid" then
		hud.Cross.BackgroundColor3 = C.Cream
		hud.RingStroke.Color = C.Cream
		hud.CrossHint.Text = ""
	elseif crosshair == "full" then
		hud.Cross.BackgroundColor3 = C.Terracotta
		hud.RingStroke.Color = C.Terracotta
		hud.CrossHint.Text = "Bag full"
	elseif crosshair == "outside" then
		hud.Cross.BackgroundColor3 = C.Locked
		hud.RingStroke.Color = C.Locked
		hud.CrossHint.Text = "Outside the dig zone (past the flags)"
	elseif crosshair == "far" then
		hud.Cross.BackgroundColor3 = C.Locked
		hud.RingStroke.Color = C.Locked
		hud.CrossHint.Text = "Too far - get closer"
	else
		hud.Cross.BackgroundColor3 = C.Cream
		hud.CrossHint.Text = ""
	end
	if show and not ClientState.UIOpen then
		UserInputService.MouseIconEnabled = false
	end
end

--------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------
function Interface.Init(options)
	options = options or {}
	onDigPress = options.OnDigPress
	onFlip = options.OnFlip
	local playerGui = player:WaitForChild("PlayerGui")
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	buildHUD(playerGui)
	buildMenu(playerGui)
	buildShop()
	buildSkills()
	buildJournal()
	updateScales()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScales)
	end

	ClientState.Changed:Connect(function(state)
		refreshHUD(state)
		if currentTab then
			Interface.RefreshShop()
			Interface.RefreshSkills()
			Interface.RefreshJournal()
		end
	end)
	ClientState.LotChanged:Connect(refreshLot)
	ClientState.Notified:Connect(onNotify)
	local lastPayoutSound = 0
	Remotes:WaitForChild("FactoryFx").OnClientEvent:Connect(function(ownerUserId, position, value, stage)
		if typeof(position) ~= "Vector3" or type(value) ~= "number" then
			return
		end
		Effects.FloatingText(position + Vector3.new(0, 2.5, 0), "+" .. Util.FormatCash(value), Color3.fromRGB(110, 230, 130))
		if ownerUserId == player.UserId and os.clock() - lastPayoutSound > 0.15 then
			lastPayoutSound = os.clock()
			Effects.Play("Sell", 0.45, 1.3 + (tonumber(stage) or 0) * 0.12)
		end
	end)
	ClientState.MenuRequested:Connect(function(name)
		if name == "Vehicles" or name == "Factory" or name == "Tools" or name == "Bags" then
			shop.Tab = name
			name = "Shop"
		end
		Interface.Open(name or "Shop")
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.ButtonSelect then
			Interface.Toggle("Shop")
		elseif input.KeyCode == Enum.KeyCode.K then
			Interface.Toggle("Skills")
		elseif input.KeyCode == Enum.KeyCode.J then
			Interface.Toggle("Journal")
		end
	end)

	refreshHUD(ClientState.State)
	refreshLot(ClientState.Lot)
	RunService.RenderStepped:Connect(frame)

	task.delay(2, function()
		Interface.Toast("Welcome to the " .. GameConfig.Lot.Name .. "! Dig sand with your hands, melt it into glass at the furnace, find all 14 relics.", "Ochre", "🌵", 7)
	end)
end

return Interface
