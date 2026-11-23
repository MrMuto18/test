--!strict
--[[
	Widgets
	Minimal, boxless UI primitives with motion baked in. Every interactive
	widget returns a Row so MenuUI can drive mouse, keyboard and gamepad
	focus through one navigation model.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

export type Row = {
	Root: GuiObject,
	SetFocused: (focused: boolean) -> (),
	Activate: (() -> ())?,
	Adjust: ((direction: number) -> ())?,
}

export type OptionRow = {
	Root: GuiObject,
	Content: Frame,
	SetFocused: (focused: boolean) -> (),
	Activate: (() -> ())?,
	Adjust: ((direction: number) -> ())?,
	SetActive: (active: boolean) -> (),
}

export type SliderRow = {
	Root: GuiObject,
	SetFocused: (focused: boolean) -> (),
	Activate: (() -> ())?,
	Adjust: ((direction: number) -> ())?,
	Set: (value: number, silent: boolean?) -> (),
}

export type CycleRow = {
	Root: GuiObject,
	SetFocused: (focused: boolean) -> (),
	Activate: (() -> ())?,
	Adjust: ((direction: number) -> ())?,
	Set: (index: number, silent: boolean?) -> (),
}

export type WeaponRow = {
	Root: GuiObject,
	SetFocused: (focused: boolean) -> (),
	Activate: (() -> ())?,
	Adjust: ((direction: number) -> ())?,
	SetSelected: (selected: boolean) -> (),
}

export type StatBar = {
	Root: Frame,
	Set: (alpha: number) -> (),
}

export type LabelProps = {
	Name: string,
	Text: string,
	Font: Font,
	TextSize: number,
	Color: Color3?,
	Transparency: number?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	XAlign: Enum.TextXAlignment?,
	YAlign: Enum.TextYAlignment?,
	AutomaticSize: Enum.AutomaticSize?,
	Wrapped: boolean?,
	LayoutOrder: number?,
	ZIndex: number?,
}

export type FrameProps = {
	Name: string,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Transparency: number?,
	LayoutOrder: number?,
	ZIndex: number?,
	ClipsDescendants: boolean?,
}

local Widgets = {}

function Widgets.tween(instance: Instance, info: TweenInfo, goals: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, goals)
	tween:Play()
	return tween
end

function Widgets.label(parent: Instance, p: LabelProps): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = p.Name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = p.Text
	label.FontFace = p.Font
	label.TextSize = p.TextSize
	label.TextColor3 = p.Color or Theme.Colors.Text
	label.TextTransparency = p.Transparency or 0
	label.Size = p.Size or UDim2.new(1, 0, 0, p.TextSize + 6)
	label.Position = p.Position or UDim2.new()
	label.AnchorPoint = p.AnchorPoint or Vector2.zero
	label.TextXAlignment = p.XAlign or Enum.TextXAlignment.Left
	label.TextYAlignment = p.YAlign or Enum.TextYAlignment.Center
	label.AutomaticSize = p.AutomaticSize or Enum.AutomaticSize.None
	label.TextWrapped = p.Wrapped == true
	label.LayoutOrder = p.LayoutOrder or 0
	label.ZIndex = p.ZIndex or 1
	label.Parent = parent
	return label
end

function Widgets.frame(parent: Instance, p: FrameProps): Frame
	local frame = Instance.new("Frame")
	frame.Name = p.Name
	frame.Size = p.Size
	frame.Position = p.Position or UDim2.new()
	frame.AnchorPoint = p.AnchorPoint or Vector2.zero
	frame.BackgroundColor3 = p.Color or Theme.Colors.Black
	frame.BackgroundTransparency = if p.Transparency == nil then 1 else p.Transparency
	frame.BorderSizePixel = 0
	frame.LayoutOrder = p.LayoutOrder or 0
	frame.ZIndex = p.ZIndex or 1
	frame.ClipsDescendants = p.ClipsDescendants == true
	frame.Parent = parent
	return frame
end

function Widgets.hitbox(parent: Instance, name: string, size: UDim2?, position: UDim2?): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Selectable = false
	button.Size = size or UDim2.fromScale(1, 1)
	button.Position = position or UDim2.new()
	button.ZIndex = 5
	button.Parent = parent
	return button
end

function Widgets.list(parent: Instance, padding: number, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding)
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.Parent = parent
	return layout
end

function Widgets.section(parent: Instance, text: string, order: number): TextLabel
	return Widgets.label(parent, {
		Name = "Section_" .. text,
		Text = Theme.track(text),
		Font = Theme.Fonts.MonoBold,
		TextSize = 11,
		Color = Theme.Colors.Accent,
		Transparency = 0.1,
		Size = UDim2.new(1, 0, 0, 26),
		YAlign = Enum.TextYAlignment.Bottom,
		LayoutOrder = order,
	})
end

--------------------------------------------------------------------------------
-- Main menu option: "01 — DEPLOY"
--------------------------------------------------------------------------------
export type OptionOpts = {
	Name: string,
	Index: number,
	Text: string,
	TextSize: number,
	LayoutOrder: number,
	OnActivate: () -> (),
	OnHover: () -> (),
}

function Widgets.menuOption(parent: Instance, opts: OptionOpts): OptionRow
	local height = opts.TextSize + 22
	local root = Widgets.frame(parent, { Name = opts.Name, Size = UDim2.new(1, 0, 0, height), LayoutOrder = opts.LayoutOrder })
	local content = Widgets.frame(root, { Name = "Content", Size = UDim2.fromScale(1, 1) })

	local index = Widgets.label(content, {
		Name = "Index",
		Text = string.format("%02d", opts.Index),
		Font = Theme.Fonts.Mono,
		TextSize = 12,
		Color = Theme.Colors.Dim,
		Transparency = 0.6,
		Size = UDim2.new(0, 28, 1, 0),
	})
	local bar = Widgets.frame(content, {
		Name = "Bar",
		Size = UDim2.fromOffset(0, 2),
		Position = UDim2.new(0, 34, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = Theme.Colors.Accent,
		Transparency = 0,
	})
	local label = Widgets.label(content, {
		Name = "Label",
		Text = Theme.track(opts.Text),
		Font = if opts.TextSize >= 30 then Theme.Fonts.Heading else Theme.Fonts.Option,
		TextSize = opts.TextSize,
		Transparency = Theme.Text.IdleTransparency,
		Size = UDim2.new(1, -40, 1, 0),
		Position = UDim2.new(0, 34, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
	})
	local hit = Widgets.hitbox(root, "Hit")

	local focused = false
	local active = false
	local function render()
		local lit = focused or active
		Widgets.tween(label, Theme.Tween.Medium, {
			Position = UDim2.new(0, if lit then 64 else 34, 0.5, 0),
			TextTransparency = if lit then 0 else Theme.Text.IdleTransparency,
			TextColor3 = if active then Theme.Colors.Accent else Theme.Colors.Text,
		})
		Widgets.tween(bar, Theme.Tween.Medium, { Size = UDim2.fromOffset(if lit then 22 else 0, 2) })
		Widgets.tween(index, Theme.Tween.Fast, {
			TextTransparency = if lit then 0.15 else 0.6,
			TextColor3 = if active then Theme.Colors.Accent else Theme.Colors.Dim,
		})
	end

	hit.MouseEnter:Connect(opts.OnHover)
	hit.Activated:Connect(opts.OnActivate)

	return {
		Root = root,
		Content = content,
		SetFocused = function(value: boolean)
			if focused ~= value then
				focused = value
				render()
			end
		end,
		Activate = opts.OnActivate,
		Adjust = nil,
		SetActive = function(value: boolean)
			if active ~= value then
				active = value
				render()
			end
		end,
	}
end

--------------------------------------------------------------------------------
-- Slider
--------------------------------------------------------------------------------
export type SliderOpts = {
	Name: string,
	Label: string,
	Min: number,
	Max: number,
	Step: number,
	KeyStep: number,
	Value: number,
	Format: (value: number) -> string,
	LayoutOrder: number,
	OnChanged: (value: number) -> (),
	OnHover: () -> (),
	OnTick: () -> (),
}

function Widgets.slider(parent: Instance, opts: SliderOpts): SliderRow
	local root = Widgets.frame(parent, { Name = opts.Name, Size = UDim2.new(1, 0, 0, 64), LayoutOrder = opts.LayoutOrder })
	local caption = Widgets.label(root, {
		Name = "Caption",
		Text = Theme.track(opts.Label),
		Font = Theme.Fonts.Mono,
		TextSize = 12,
		Color = Theme.Colors.Text,
		Transparency = Theme.Text.DimTransparency,
		Size = UDim2.new(0.7, 0, 0, 22),
	})
	local valueLabel = Widgets.label(root, {
		Name = "Value",
		Text = opts.Format(opts.Value),
		Font = Theme.Fonts.Heading,
		TextSize = 18,
		Size = UDim2.new(0.3, 0, 0, 22),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		XAlign = Enum.TextXAlignment.Right,
	})
	local track = Widgets.frame(root, {
		Name = "Track",
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 0, 44),
		Color = Theme.Colors.White,
		Transparency = 0.85,
	})
	local fill = Widgets.frame(track, {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		Color = Theme.Colors.Accent,
		Transparency = 0,
	})
	local knob = Widgets.frame(track, {
		Name = "Knob",
		Size = UDim2.fromOffset(10, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Color = Theme.Colors.White,
		Transparency = 0,
		ZIndex = 2,
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = knob
	local hit = Widgets.hitbox(root, "Hit")

	local value = opts.Value
	local dragging = false
	local focused = false

	local function alphaOf(v: number): number
		return math.clamp((v - opts.Min) / (opts.Max - opts.Min), 0, 1)
	end

	local function render(animate: boolean)
		local a = alphaOf(value)
		local info = if animate then Theme.Tween.Fast else TweenInfo.new(0)
		Widgets.tween(fill, info, { Size = UDim2.fromScale(a, 1) })
		Widgets.tween(knob, info, { Position = UDim2.fromScale(a, 0.5) })
		valueLabel.Text = opts.Format(value)
	end

	local function set(v: number, silent: boolean?)
		local stepped = math.round(v / opts.Step) * opts.Step
		stepped = math.clamp(stepped, opts.Min, opts.Max)
		-- Kill float noise (0.30000000004)
		stepped = math.round(stepped * 1000) / 1000
		if stepped == value then
			return
		end
		value = stepped
		render(true)
		if not silent then
			opts.OnTick()
			opts.OnChanged(value)
		end
	end

	local function setFromScreenX(x: number)
		local absPos = track.AbsolutePosition.X
		local absSize = track.AbsoluteSize.X
		if absSize <= 0 then
			return
		end
		local a = math.clamp((x - absPos) / absSize, 0, 1)
		set(opts.Min + a * (opts.Max - opts.Min))
	end

	local function renderFocus()
		local lit = focused or dragging
		Widgets.tween(caption, Theme.Tween.Fast, { TextTransparency = if lit then 0.05 else Theme.Text.DimTransparency })
		Widgets.tween(knob, Theme.Tween.Fast, { Size = UDim2.fromOffset(if lit then 14 else 10, if lit then 14 else 10) })
		Widgets.tween(track, Theme.Tween.Fast, { BackgroundTransparency = if lit then 0.7 else 0.85 })
	end

	hit.MouseEnter:Connect(opts.OnHover)
	hit.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			renderFocus()
			setFromScreenX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromScreenX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			renderFocus()
		end
	end)

	render(false)

	return {
		Root = root,
		SetFocused = function(v: boolean)
			if focused ~= v then
				focused = v
				renderFocus()
			end
		end,
		Activate = nil,
		Adjust = function(direction: number)
			set(value + direction * opts.KeyStep)
		end,
		Set = function(v: number, silent: boolean?)
			set(v, if silent == nil then true else silent)
		end,
	}
end

--------------------------------------------------------------------------------
-- Cycle selector: LABEL ........ ‹ HIGH ›
--------------------------------------------------------------------------------
export type CycleOpts = {
	Name: string,
	Label: string,
	Options: { string },
	Index: number,
	LayoutOrder: number,
	OnChanged: (index: number) -> (),
	OnHover: () -> (),
	OnTick: () -> (),
}

function Widgets.cycle(parent: Instance, opts: CycleOpts): CycleRow
	local root = Widgets.frame(parent, { Name = opts.Name, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = opts.LayoutOrder })
	local caption = Widgets.label(root, {
		Name = "Caption",
		Text = Theme.track(opts.Label),
		Font = Theme.Fonts.Mono,
		TextSize = 12,
		Transparency = Theme.Text.DimTransparency,
		Size = UDim2.new(0.5, 0, 1, 0),
	})
	local valueLabel = Widgets.label(root, {
		Name = "Value",
		Text = string.upper(opts.Options[opts.Index] or ""),
		Font = Theme.Fonts.Heading,
		TextSize = 18,
		Size = UDim2.new(0, 120, 1, 0),
		Position = UDim2.new(1, -26, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		XAlign = Enum.TextXAlignment.Center,
	})
	local left = Widgets.label(root, {
		Name = "Left",
		Text = "‹",
		Font = Theme.Fonts.Heading,
		TextSize = 22,
		Color = Theme.Colors.Accent,
		Transparency = 0.5,
		Size = UDim2.new(0, 24, 1, 0),
		Position = UDim2.new(1, -146, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		XAlign = Enum.TextXAlignment.Center,
	})
	local right = Widgets.label(root, {
		Name = "Right",
		Text = "›",
		Font = Theme.Fonts.Heading,
		TextSize = 22,
		Color = Theme.Colors.Accent,
		Transparency = 0.5,
		Size = UDim2.new(0, 24, 1, 0),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		XAlign = Enum.TextXAlignment.Center,
	})
	local rowHit = Widgets.hitbox(root, "Hit")
	local leftHit = Widgets.hitbox(root, "LeftHit", UDim2.new(0, 40, 1, 0), UDim2.new(1, -170, 0, 0))
	local rightHit = Widgets.hitbox(root, "RightHit", UDim2.new(0, 40, 1, 0), UDim2.new(1, -40, 0, 0))
	leftHit.ZIndex = 6
	rightHit.ZIndex = 6

	local index = opts.Index
	local focused = false

	local function set(i: number, silent: boolean?)
		local count = #opts.Options
		local wrapped = ((i - 1) % count) + 1
		if wrapped == index then
			return
		end
		local direction = if i > index then 1 else -1
		index = wrapped
		valueLabel.Text = string.upper(opts.Options[index])
		-- Slide-in micro motion
		valueLabel.Position = UDim2.new(1, -26 + direction * 10, 0, 0)
		valueLabel.TextTransparency = 0.6
		Widgets.tween(valueLabel, Theme.Tween.Medium, { Position = UDim2.new(1, -26, 0, 0), TextTransparency = 0 })
		if not silent then
			opts.OnTick()
			opts.OnChanged(index)
		end
	end

	local function renderFocus()
		Widgets.tween(caption, Theme.Tween.Fast, { TextTransparency = if focused then 0.05 else Theme.Text.DimTransparency })
		Widgets.tween(left, Theme.Tween.Fast, { TextTransparency = if focused then 0 else 0.5 })
		Widgets.tween(right, Theme.Tween.Fast, { TextTransparency = if focused then 0 else 0.5 })
	end

	for _, hit in { rowHit, leftHit, rightHit } do
		hit.MouseEnter:Connect(opts.OnHover)
	end
	rowHit.Activated:Connect(function()
		set(index + 1)
	end)
	leftHit.Activated:Connect(function()
		set(index - 1)
	end)
	rightHit.Activated:Connect(function()
		set(index + 1)
	end)

	return {
		Root = root,
		SetFocused = function(v: boolean)
			if focused ~= v then
				focused = v
				renderFocus()
			end
		end,
		Activate = function()
			set(index + 1)
		end,
		Adjust = function(direction: number)
			set(index + direction)
		end,
		Set = function(i: number, silent: boolean?)
			set(i, if silent == nil then true else silent)
		end,
	}
end

--------------------------------------------------------------------------------
-- Weapon row (loadout list)
--------------------------------------------------------------------------------
export type WeaponRowOpts = {
	Name: string,
	Title: string,
	Tag: string,
	LayoutOrder: number,
	OnActivate: () -> (),
	OnHover: () -> (),
}

function Widgets.weaponRow(parent: Instance, opts: WeaponRowOpts): WeaponRow
	local root = Widgets.frame(parent, {
		Name = opts.Name,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = opts.LayoutOrder,
		Color = Theme.Colors.White,
		Transparency = 1,
	})
	local marker = Widgets.frame(root, {
		Name = "Marker",
		Size = UDim2.new(0, 3, 0, 0),
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = Theme.Colors.Accent,
		Transparency = 0,
	})
	local title = Widgets.label(root, {
		Name = "Title",
		Text = opts.Title,
		Font = Theme.Fonts.Option,
		TextSize = 19,
		Transparency = Theme.Text.IdleTransparency,
		Size = UDim2.new(1, -110, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
	})
	local tag = Widgets.label(root, {
		Name = "Tag",
		Text = Theme.track(opts.Tag),
		Font = Theme.Fonts.Mono,
		TextSize = 11,
		Color = Theme.Colors.Dim,
		Transparency = 0.3,
		Size = UDim2.new(0, 100, 1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		XAlign = Enum.TextXAlignment.Right,
	})
	local hit = Widgets.hitbox(root, "Hit")

	local focused = false
	local selected = false
	local function render()
		Widgets.tween(root, Theme.Tween.Fast, { BackgroundTransparency = if focused then 0.94 else 1 })
		Widgets.tween(marker, Theme.Tween.Medium, { Size = UDim2.new(0, 3, if selected then 0.62 else 0, 0) })
		Widgets.tween(title, Theme.Tween.Fast, {
			TextTransparency = if selected or focused then 0 else Theme.Text.IdleTransparency,
			TextColor3 = if selected then Theme.Colors.Accent else Theme.Colors.Text,
		})
		Widgets.tween(tag, Theme.Tween.Fast, { TextTransparency = if selected or focused then 0.1 else 0.3 })
	end

	hit.MouseEnter:Connect(opts.OnHover)
	hit.Activated:Connect(opts.OnActivate)

	return {
		Root = root,
		SetFocused = function(v: boolean)
			if focused ~= v then
				focused = v
				render()
			end
		end,
		Activate = opts.OnActivate,
		Adjust = nil,
		SetSelected = function(v: boolean)
			if selected ~= v then
				selected = v
				render()
			end
		end,
	}
end

--------------------------------------------------------------------------------
-- Stat bar
--------------------------------------------------------------------------------
function Widgets.statBar(parent: Instance, name: string, order: number): StatBar
	local root = Widgets.frame(parent, { Name = "Stat_" .. name, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = order })
	Widgets.label(root, {
		Name = "Caption",
		Text = Theme.track(name),
		Font = Theme.Fonts.Mono,
		TextSize = 10,
		Color = Theme.Colors.Dim,
		Size = UDim2.new(0, 110, 1, 0),
	})
	local track = Widgets.frame(root, {
		Name = "Track",
		Size = UDim2.new(1, -120, 0, 2),
		Position = UDim2.new(0, 120, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = Theme.Colors.White,
		Transparency = 0.86,
	})
	local fill = Widgets.frame(track, {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		Color = Theme.Colors.Text,
		Transparency = 0,
	})
	return {
		Root = root,
		Set = function(alpha: number)
			Widgets.tween(fill, Theme.Tween.Slow, { Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1) })
		end,
	}
end

return Widgets
