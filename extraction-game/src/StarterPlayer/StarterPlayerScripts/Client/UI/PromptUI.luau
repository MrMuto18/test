--!strict
--[[
	PromptUI
	Minimal custom renderer for every ProximityPrompt with Style = Custom:

	   [E]  GRAB
	        LOOT · $6,800
	        ───────────  ← hold progress

	Key cap adapts to keyboard / gamepad / touch, the hold line fills over
	HoldDuration, triggers flash, and the card slides in/out. Tapping the card
	works on touch screens. Object/action text updates live (trunk counts).
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local PromptUI = {}

local active: { [ProximityPrompt]: BillboardGui } = {}

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		return (string.gsub(prompt.GamepadKeyCode.Name, "^Button", ""))
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	end
	return prompt.KeyboardKeyCode.Name
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom or active[prompt] then
		return
	end
	local adornee = prompt.Parent
	if not adornee or not (adornee:IsA("BasePart") or adornee:IsA("Attachment") or adornee:IsA("Model")) then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Prompt"
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(240, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
	gui.Active = true
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local card = Instance.new("CanvasGroup")
	card.Name = "Card"
	card.BackgroundTransparency = 1
	card.Size = UDim2.fromScale(1, 1)
	card.Position = UDim2.fromOffset(-14, 0)
	card.GroupTransparency = 1
	card.Parent = gui

	local cap = Widgets.frame(card, {
		Name = "KeyCap",
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromOffset(0, 6),
		Color = Theme.Colors.Black,
		Transparency = 0.45,
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = cap
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Text
	stroke.Thickness = 1.5
	stroke.Transparency = 0.1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = cap
	local key = Widgets.label(cap, {
		Name = "Key",
		Text = keyText(prompt, inputType),
		Font = Theme.Fonts.MonoBold,
		TextSize = 13,
		Size = UDim2.fromScale(1, 1),
		XAlign = Enum.TextXAlignment.Center,
	})

	local action = Widgets.label(card, {
		Name = "Action",
		Text = Theme.track(string.upper(prompt.ActionText)),
		Font = Theme.Fonts.Heading,
		TextSize = 16,
		Size = UDim2.new(1, -42, 0, 20),
		Position = UDim2.fromOffset(42, 4),
	})
	local object = Widgets.label(card, {
		Name = "Object",
		Text = Theme.track(prompt.ObjectText),
		Font = Theme.Fonts.Mono,
		TextSize = 10,
		Color = Theme.Colors.Accent,
		Size = UDim2.new(1, -42, 0, 14),
		Position = UDim2.fromOffset(42, 24),
	})
	local track = Widgets.frame(card, {
		Name = "HoldTrack",
		Size = UDim2.new(1, -42, 0, 2),
		Position = UDim2.fromOffset(42, 44),
		Color = Theme.Colors.White,
		Transparency = if prompt.HoldDuration > 0 then 0.8 else 1,
	})
	local fill = Widgets.frame(track, { Name = "Fill", Size = UDim2.fromScale(0, 1), Color = Theme.Colors.Accent, Transparency = 0 })

	local hit = Widgets.hitbox(card, "Tap")
	hit.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
		end
	end)
	hit.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end)

	local connections: { RBXScriptConnection } = {}
	local holdTween: Tween? = nil
	table.insert(connections, prompt.PromptButtonHoldBegan:Connect(function()
		fill.Size = UDim2.fromScale(0, 1)
		holdTween = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
		local tween = holdTween :: Tween
		tween:Play()
		Widgets.tween(cap, Theme.Tween.Fast, { BackgroundTransparency = 0.1 })
	end))
	table.insert(connections, prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then
			holdTween:Cancel()
		end
		Widgets.tween(fill, Theme.Tween.Fast, { Size = UDim2.fromScale(0, 1) })
		Widgets.tween(cap, Theme.Tween.Fast, { BackgroundTransparency = 0.45 })
	end))
	table.insert(connections, prompt.Triggered:Connect(function()
		stroke.Color = Theme.Colors.Accent
		key.TextColor3 = Theme.Colors.Accent
		task.delay(0.2, function()
			stroke.Color = Theme.Colors.Text
			key.TextColor3 = Theme.Colors.Text
		end)
	end))
	table.insert(connections, prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
		object.Text = Theme.track(prompt.ObjectText)
	end))
	table.insert(connections, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		action.Text = Theme.track(string.upper(prompt.ActionText))
	end))

	active[prompt] = gui
	Widgets.tween(card, Theme.Tween.Medium, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })

	local hidden: RBXScriptConnection
	hidden = prompt.PromptHidden:Connect(function()
		hidden:Disconnect()
		for _, c in connections do
			c:Disconnect()
		end
		active[prompt] = nil
		local out = Widgets.tween(card, Theme.Tween.Fast, { GroupTransparency = 1, Position = UDim2.fromOffset(-10, 0) })
		out.Completed:Once(function()
			gui:Destroy()
		end)
	end)
end

function PromptUI.init()
	ProximityPromptService.PromptShown:Connect(show)
end

return PromptUI
