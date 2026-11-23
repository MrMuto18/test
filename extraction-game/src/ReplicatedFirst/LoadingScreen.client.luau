--!strict
--[[
	LoadingScreen (LocalScript in ReplicatedFirst)
	Replaces the default Roblox loader with a black title card and a thin
	indeterminate progress line. Holds until the menu camera is live
	("ClientMenuReady"), then dissolves straight into the 3D scene.
	Uses only engine built-ins: ReplicatedFirst runs before anything else
	has replicated.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local READY_TIMEOUT = 25
local ACCENT = Color3.fromRGB(255, 168, 86)
local TEXT = Color3.fromRGB(236, 234, 228)

ReplicatedFirst:RemoveDefaultLoadingScreen()
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)

local THIN = utf8.char(0x2009)
local function track(text: string): string
	local out = {}
	for _, code in utf8.codes(text) do
		local char = utf8.char(code)
		table.insert(out, if char == " " then THIN .. THIN .. THIN else char)
	end
	return table.concat(out, THIN)
end

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BorderSizePixel = 0
backdrop.Parent = gui

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.47)
title.Size = UDim2.fromOffset(600, 70)
title.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
title.TextSize = 52
title.TextColor3 = TEXT
title.TextTransparency = 1
title.Text = track("ZABOUR")
title.Parent = backdrop

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(0.5, 0.5)
status.Position = UDim2.fromScale(0.5, 0.535)
status.Size = UDim2.fromOffset(600, 18)
status.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular)
status.TextSize = 11
status.TextColor3 = Color3.fromRGB(150, 150, 146)
status.TextTransparency = 1
status.Text = track("ESTABLISHING SECURE LINK")
status.Parent = backdrop

local trackBar = Instance.new("Frame")
trackBar.Name = "Track"
trackBar.AnchorPoint = Vector2.new(0.5, 0.5)
trackBar.Position = UDim2.fromScale(0.5, 0.57)
trackBar.Size = UDim2.fromOffset(220, 1)
trackBar.BackgroundColor3 = Color3.new(1, 1, 1)
trackBar.BackgroundTransparency = 0.88
trackBar.BorderSizePixel = 0
trackBar.ClipsDescendants = true
trackBar.Parent = backdrop

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0.3, 1)
fill.Position = UDim2.fromScale(-0.3, 0)
fill.BackgroundColor3 = ACCENT
fill.BorderSizePixel = 0
fill.Parent = trackBar

gui.Parent = player:WaitForChild("PlayerGui")

local fadeIn = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
TweenService:Create(title, fadeIn, { TextTransparency = 0 }):Play()
TweenService:Create(status, fadeIn, { TextTransparency = 0.2 }):Play()
local sweep = TweenService:Create(
	fill,
	TweenInfo.new(1.1, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut, -1, false),
	{ Position = UDim2.fromScale(1, 0) }
)
sweep:Play()

if not game:IsLoaded() then
	game.Loaded:Wait()
end
status.Text = track("SYNCING SAFEHOUSE")

local deadline = os.clock() + READY_TIMEOUT
while player:GetAttribute("ClientMenuReady") ~= true and os.clock() < deadline do
	task.wait(0.1)
end
-- One beat for the menu camera and grade to settle under the card.
task.wait(0.4)

sweep:Cancel()
fill.Position = UDim2.fromScale(0, 0)
local complete = TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
	Size = UDim2.fromScale(1, 1),
})
complete:Play()
complete.Completed:Wait()

local out = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
TweenService:Create(title, out, { TextTransparency = 1 }):Play()
TweenService:Create(status, out, { TextTransparency = 1 }):Play()
TweenService:Create(trackBar, out, { BackgroundTransparency = 1 }):Play()
TweenService:Create(fill, out, { BackgroundTransparency = 1 }):Play()
task.wait(0.35)
local dissolve = TweenService:Create(backdrop, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
	BackgroundTransparency = 1,
})
dissolve:Play()
dissolve.Completed:Wait()
gui:Destroy()
