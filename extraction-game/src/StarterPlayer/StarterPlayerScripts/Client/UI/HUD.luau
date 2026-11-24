--!strict
--[[
	HUD
	Minimal combat HUD, same typography as the menu:

	  centre        dynamic crosshair (gap = real cone of fire in pixels),
	                shrinks to a dot when aiming, hides while sprinting
	  centre        hitmarker: white body, red head, gold kill (+ grey when the
	                target is protected, e.g. players in the safe zone)
	  bottom-right  weapon name, fire mode, big magazine count / reserve,
	                reload progress line, low-ammo tint
	  bottom-centre stamina line (fades out when full)
	  bottom-left   health line + number, red edge flash on damage
	  top-centre    short toasts (weapon switch, "SAFE ZONE")
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local HUD = {}

local gui: ScreenGui
local root: CanvasGroup
local crosshair: Frame
local lines: { Frame } = {}
local dot: Frame
local hitmarker: Frame
local hitScale: UIScale
local hitLines: { Frame } = {}
local ammoMag: TextLabel
local ammoReserve: TextLabel
local weaponLabel: TextLabel
local modeLabel: TextLabel
local reloadTrack: Frame
local reloadFill: Frame
local staminaTrack: Frame
local staminaFill: Frame
local healthFill: Frame
local healthLabel: TextLabel
local damageEdges: Frame
local toastLabel: TextLabel
local scales: { UIScale } = {}
local ammoFrame: Frame
local vehicleFrame: Frame
local speedLabel: TextLabel
local gearLabel: TextLabel
local rpmFill: Frame
local carryLabel: TextLabel
local mode: "OnFoot" | "Vehicle" | "Passenger" = "OnFoot"
local shownSpeed = 0

local gapTarget = 12
local gap = 12
local pulse = 0
local crosshairAlphaTarget = 1
local crosshairAlpha = 1
local dotOnly = 0
local staminaShown = 0
local staminaTarget = 0
local lastHealth = 100
local hitToken = 0
local toastToken = 0
local magSize = 30

local HIT_COLORS: { [string]: Color3 } = {
	Body = Color3.fromRGB(255, 255, 255),
	Head = Color3.fromRGB(255, 70, 70),
	Kill = Color3.fromRGB(255, 200, 80),
	Blocked = Color3.fromRGB(140, 140, 140),
}

local function line(parent: Instance, name: string, size: UDim2): Frame
	local frame = Widgets.frame(parent, {
		Name = name,
		Size = size,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Color = Theme.Colors.White,
		Transparency = 0,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Black
	stroke.Transparency = 0.6
	stroke.Thickness = 1
	stroke.Parent = frame
	return frame
end

local function scaled(frame: Instance)
	local s = Instance.new("UIScale")
	s.Parent = frame
	table.insert(scales, s)
end

local function build()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Enabled = false
	gui.Parent = playerGui

	local group = Instance.new("CanvasGroup")
	group.Name = "Root"
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Parent = gui
	root = group

	-- Damage edges (outside the scaled panels, full screen)
	damageEdges = Widgets.frame(root, { Name = "DamageEdges", Size = UDim2.fromScale(1, 1) })
	for _, spec in {
		{ UDim2.fromScale(0.25, 1), UDim2.new(), Vector2.zero, 0 },
		{ UDim2.fromScale(0.25, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0), 180 },
		{ UDim2.fromScale(1, 0.25), UDim2.new(), Vector2.zero, 90 },
		{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 1), Vector2.new(0, 1), -90 },
	} do
		local edge = Widgets.frame(damageEdges, {
			Name = "Edge",
			Size = spec[1],
			Position = spec[2],
			AnchorPoint = spec[3],
			Color = Color3.fromRGB(160, 0, 0),
			Transparency = 0,
		})
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = spec[4]
		gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		gradient.Parent = edge
	end
	damageEdges.Visible = false

	-- Crosshair
	crosshair = Widgets.frame(root, {
		Name = "Crosshair",
		Size = UDim2.fromOffset(200, 200),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	for i = 1, 4 do
		local horizontal = i <= 2
		lines[i] = line(crosshair, "Line" .. i, if horizontal then UDim2.fromOffset(10, 2) else UDim2.fromOffset(2, 10))
	end
	dot = line(crosshair, "Dot", UDim2.fromOffset(3, 3))
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot

	-- Hitmarker
	hitmarker = Widgets.frame(root, {
		Name = "Hitmarker",
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	hitScale = Instance.new("UIScale")
	hitScale.Parent = hitmarker
	for i, angle in { 45, 135, 225, 315 } do
		local rad = math.rad(angle)
		local hm = line(hitmarker, "Tick" .. i, UDim2.fromOffset(10, 2))
		hm.Position = UDim2.new(0.5, math.cos(rad) * 11, 0.5, -math.sin(rad) * 11)
		hm.Rotation = -angle
		hm.BackgroundTransparency = 1
		local stroke = hm:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 1
		end
		hitLines[i] = hm
	end

	-- Ammo (bottom-right)
	local ammo = Widgets.frame(root, {
		Name = "Ammo",
		Size = UDim2.fromOffset(300, 110),
		Position = UDim2.fromScale(0.955, 0.925),
		AnchorPoint = Vector2.new(1, 1),
	})
	scaled(ammo)
	weaponLabel = Widgets.label(ammo, {
		Name = "Weapon",
		Text = "",
		Font = Theme.Fonts.MonoBold,
		TextSize = 11,
		Color = Theme.Colors.Text,
		Transparency = 0.25,
		Size = UDim2.new(1, 0, 0, 16),
		XAlign = Enum.TextXAlignment.Right,
	})
	modeLabel = Widgets.label(ammo, {
		Name = "Mode",
		Text = "",
		Font = Theme.Fonts.Mono,
		TextSize = 10,
		Color = Theme.Colors.Accent,
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 16),
		XAlign = Enum.TextXAlignment.Right,
	})
	ammoReserve = Widgets.label(ammo, {
		Name = "Reserve",
		Text = "",
		Font = Theme.Fonts.Mono,
		TextSize = 16,
		Color = Theme.Colors.Dim,
		Size = UDim2.fromOffset(80, 48),
		Position = UDim2.new(1, 0, 0, 34),
		AnchorPoint = Vector2.new(1, 0),
		XAlign = Enum.TextXAlignment.Right,
		YAlign = Enum.TextYAlignment.Bottom,
	})
	ammoMag = Widgets.label(ammo, {
		Name = "Mag",
		Text = "",
		Font = Theme.Fonts.Display,
		TextSize = 46,
		Size = UDim2.fromOffset(140, 52),
		Position = UDim2.new(1, -86, 0, 30),
		AnchorPoint = Vector2.new(1, 0),
		XAlign = Enum.TextXAlignment.Right,
		YAlign = Enum.TextYAlignment.Bottom,
	})
	reloadTrack = Widgets.frame(ammo, {
		Name = "ReloadTrack",
		Size = UDim2.fromOffset(160, 2),
		Position = UDim2.new(1, 0, 0, 92),
		AnchorPoint = Vector2.new(1, 0),
		Color = Theme.Colors.White,
		Transparency = 0.85,
	})
	reloadFill = Widgets.frame(reloadTrack, { Name = "Fill", Size = UDim2.fromScale(0, 1), Color = Theme.Colors.Accent, Transparency = 0 })
	reloadTrack.Visible = false
	ammoFrame = ammo

	-- Vehicle cluster (bottom-right, replaces ammo while driving)
	local vehicle = Widgets.frame(root, {
		Name = "Vehicle",
		Size = UDim2.fromOffset(300, 110),
		Position = UDim2.fromScale(0.955, 0.925),
		AnchorPoint = Vector2.new(1, 1),
	})
	scaled(vehicle)
	vehicle.Visible = false
	vehicleFrame = vehicle
	Widgets.label(vehicle, {
		Name = "Caption",
		Text = Theme.track("ZABOUR  ·  KM/H"),
		Font = Theme.Fonts.MonoBold,
		TextSize = 11,
		Transparency = 0.25,
		Size = UDim2.new(1, 0, 0, 16),
		XAlign = Enum.TextXAlignment.Right,
	})
	gearLabel = Widgets.label(vehicle, {
		Name = "Gear",
		Text = "N",
		Font = Theme.Fonts.Heading,
		TextSize = 26,
		Color = Theme.Colors.Accent,
		Size = UDim2.fromOffset(40, 52),
		Position = UDim2.new(1, 0, 0, 30),
		AnchorPoint = Vector2.new(1, 0),
		XAlign = Enum.TextXAlignment.Right,
		YAlign = Enum.TextYAlignment.Bottom,
	})
	speedLabel = Widgets.label(vehicle, {
		Name = "Speed",
		Text = "0",
		Font = Theme.Fonts.Display,
		TextSize = 46,
		Size = UDim2.fromOffset(160, 52),
		Position = UDim2.new(1, -52, 0, 30),
		AnchorPoint = Vector2.new(1, 0),
		XAlign = Enum.TextXAlignment.Right,
		YAlign = Enum.TextYAlignment.Bottom,
	})
	local rpmTrack = Widgets.frame(vehicle, {
		Name = "RpmTrack",
		Size = UDim2.fromOffset(200, 2),
		Position = UDim2.new(1, 0, 0, 92),
		AnchorPoint = Vector2.new(1, 0),
		Color = Theme.Colors.White,
		Transparency = 0.85,
	})
	rpmFill = Widgets.frame(rpmTrack, { Name = "Fill", Size = UDim2.fromScale(0, 1), Color = Theme.Colors.Text, Transparency = 0 })

	carryLabel = Widgets.label(root, {
		Name = "Carry",
		Text = "",
		Font = Theme.Fonts.MonoBold,
		TextSize = 12,
		Color = Theme.Colors.Accent,
		Transparency = 1,
		Size = UDim2.fromOffset(500, 18),
		Position = UDim2.fromScale(0.5, 0.86),
		AnchorPoint = Vector2.new(0.5, 0.5),
		XAlign = Enum.TextXAlignment.Center,
	})
	scaled(carryLabel)

	-- Stamina (bottom-centre)
	staminaTrack = Widgets.frame(root, {
		Name = "Stamina",
		Size = UDim2.fromOffset(200, 2),
		Position = UDim2.fromScale(0.5, 0.9),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Theme.Colors.White,
		Transparency = 1,
	})
	scaled(staminaTrack)
	staminaFill = Widgets.frame(staminaTrack, { Name = "Fill", Size = UDim2.fromScale(1, 1), Color = Theme.Colors.Text, Transparency = 1 })

	-- Health (bottom-left)
	local health = Widgets.frame(root, {
		Name = "Health",
		Size = UDim2.fromOffset(240, 50),
		Position = UDim2.fromScale(0.045, 0.925),
		AnchorPoint = Vector2.new(0, 1),
	})
	scaled(health)
	Widgets.label(health, {
		Name = "Caption",
		Text = Theme.track("VITALS"),
		Font = Theme.Fonts.MonoBold,
		TextSize = 10,
		Color = Theme.Colors.Dim,
		Size = UDim2.new(1, 0, 0, 14),
	})
	healthLabel = Widgets.label(health, {
		Name = "Value",
		Text = "100",
		Font = Theme.Fonts.Heading,
		TextSize = 22,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 14),
	})
	local healthTrack = Widgets.frame(health, {
		Name = "Track",
		Size = UDim2.fromOffset(180, 2),
		Position = UDim2.fromOffset(0, 44),
		Color = Theme.Colors.White,
		Transparency = 0.85,
	})
	healthFill = Widgets.frame(healthTrack, { Name = "Fill", Size = UDim2.fromScale(1, 1), Color = Theme.Colors.Text, Transparency = 0 })

	toastLabel = Widgets.label(root, {
		Name = "Toast",
		Text = "",
		Font = Theme.Fonts.MonoBold,
		TextSize = 12,
		Color = Theme.Colors.Text,
		Transparency = 1,
		Size = UDim2.fromOffset(500, 20),
		Position = UDim2.fromScale(0.5, 0.14),
		AnchorPoint = Vector2.new(0.5, 0.5),
		XAlign = Enum.TextXAlignment.Center,
	})

	local function rescale()
		local camera = Workspace.CurrentCamera
		local s = math.clamp((if camera then camera.ViewportSize.Y else 1080) / 1080, 0.62, 1.35)
		for _, scale in scales do
			scale.Scale = s
		end
	end
	rescale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
end

local function render(dt: number)
	if not gui.Enabled then
		return
	end
	local k = 1 - math.exp(-dt * 18)
	pulse *= math.exp(-dt * 14)
	gap += (gapTarget + pulse - gap) * k
	crosshairAlpha += (crosshairAlphaTarget - crosshairAlpha) * (1 - math.exp(-dt * 12))
	local g = gap * (1 - dotOnly) + 2

	lines[1].Position = UDim2.new(0.5, -g - 5, 0.5, 0)
	lines[2].Position = UDim2.new(0.5, g + 5, 0.5, 0)
	lines[3].Position = UDim2.new(0.5, 0, 0.5, -g - 5)
	lines[4].Position = UDim2.new(0.5, 0, 0.5, g + 5)
	local lineAlpha = 1 - crosshairAlpha * (1 - dotOnly)
	for _, l in lines do
		l.BackgroundTransparency = lineAlpha
		local stroke = l:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 0.6 + 0.4 * lineAlpha
		end
	end
	dot.BackgroundTransparency = 1 - crosshairAlpha * 0.9

	staminaShown += (staminaTarget - staminaShown) * (1 - math.exp(-dt * 10))
	staminaFill.Size = UDim2.fromScale(staminaShown, 1)
	local staminaVisible = if staminaTarget < 0.995 then 1 else 0
	local staminaAlpha = staminaTrack:GetAttribute("Alpha")
	local current = if typeof(staminaAlpha) == "number" then staminaAlpha else 0
	current += (staminaVisible - current) * (1 - math.exp(-dt * (if staminaVisible > 0 then 10 else 2)))
	staminaTrack:SetAttribute("Alpha", current)
	staminaTrack.BackgroundTransparency = 1 - current * 0.15
	staminaFill.BackgroundTransparency = 1 - current * 0.9
end

function HUD.init()
	build()
	RunService.RenderStepped:Connect(render)
end

function HUD.show()
	gui.Enabled = true
	Widgets.tween(root, Theme.Tween.Fade, { GroupTransparency = 0 })
end

function HUD.hide(instant: boolean?)
	if instant then
		root.GroupTransparency = 1
		gui.Enabled = false
		return
	end
	local tween = Widgets.tween(root, Theme.Tween.Medium, { GroupTransparency = 1 })
	tween.Completed:Once(function()
		if root.GroupTransparency >= 0.99 then
			gui.Enabled = false
		end
	end)
end

function HUD.setWeapon(name: string, fireMode: string, size: number)
	magSize = size
	weaponLabel.Text = Theme.track(name)
	modeLabel.Text = Theme.track(string.upper(fireMode))
	HUD.toast(name)
end

function HUD.setAmmo(mag: number, reserve: number)
	ammoMag.Text = tostring(mag)
	ammoReserve.Text = "/ " .. tostring(reserve)
	local low = mag <= math.max(1, math.floor(magSize * 0.25))
	ammoMag.TextColor3 = if mag == 0 then Theme.Colors.Danger elseif low then Theme.Colors.Accent else Theme.Colors.Text
end

function HUD.setReload(progress: number?)
	if progress == nil then
		reloadTrack.Visible = false
	ammoFrame = ammo

	-- Vehicle cluster (bottom-right, replaces ammo while driving)
	local vehicle = Widgets.frame(root, {
		Name = "Vehicle",
		Size = UDim2.fromOffset(300, 110),
		Position = UDim2.fromScale(0.955, 0.925),
		AnchorPoint = Vector2.new(1, 1),
	})
	scaled(vehicle)
	vehicle.Visible = false
	vehicleFrame = vehicle
	Widgets.label(vehicle, {
		Name = "Caption",
		Text = Theme.track("ZABOUR  ·  KM/H"),
		Font = Theme.Fonts.MonoBold,
		TextSize = 11,
		Transparency = 0.25,
		Size = UDim2.new(1, 0, 0, 16),
		XAlign = Enum.TextXAlignment.Right,
	})
	gearLabel = Widgets.label(vehicle, {
		Name = "Gear",
		Text = "N",
		Font = Theme.Fonts.Heading,
		TextSize = 26,
		Color = Theme.Colors.Accent,
		Size = UDim2.fromOffset(40, 52),
		Position = UDim2.new(1, 0, 0, 30),
		AnchorPoint = Vector2.new(1, 0),
		XAlign = Enum.TextXAlignment.Right,
		YAlign = Enum.TextYAlignment.Bottom,
	})
	speedLabel = Widgets.label(vehicle, {
		Name = "Speed",
		Text = "0",
		Font = Theme.Fonts.Display,
		TextSize = 46,
		Size = UDim2.fromOffset(160, 52),
		Position = UDim2.new(1, -52, 0, 30),
		AnchorPoint = Vector2.new(1, 0),
		XAlign = Enum.TextXAlignment.Right,
		YAlign = Enum.TextYAlignment.Bottom,
	})
	local rpmTrack = Widgets.frame(vehicle, {
		Name = "RpmTrack",
		Size = UDim2.fromOffset(200, 2),
		Position = UDim2.new(1, 0, 0, 92),
		AnchorPoint = Vector2.new(1, 0),
		Color = Theme.Colors.White,
		Transparency = 0.85,
	})
	rpmFill = Widgets.frame(rpmTrack, { Name = "Fill", Size = UDim2.fromScale(0, 1), Color = Theme.Colors.Text, Transparency = 0 })

	carryLabel = Widgets.label(root, {
		Name = "Carry",
		Text = "",
		Font = Theme.Fonts.MonoBold,
		TextSize = 12,
		Color = Theme.Colors.Accent,
		Transparency = 1,
		Size = UDim2.fromOffset(500, 18),
		Position = UDim2.fromScale(0.5, 0.86),
		AnchorPoint = Vector2.new(0.5, 0.5),
		XAlign = Enum.TextXAlignment.Center,
	})
	scaled(carryLabel)
		return
	end
	reloadTrack.Visible = true
	reloadFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
end

function HUD.setStamina(alpha: number)
	staminaTarget = math.clamp(alpha, 0, 1)
end

-- spreadDeg = current cone half-angle; converted to pixels from the real FOV.
function HUD.setSpread(spreadDeg: number, fieldOfView: number, aim: number, visible: boolean)
	local camera = Workspace.CurrentCamera
	local halfHeight = if camera then camera.ViewportSize.Y / 2 else 540
	local px = math.tan(math.rad(spreadDeg)) / math.tan(math.rad(fieldOfView / 2)) * halfHeight
	gapTarget = math.clamp(px, 3, 140)
	dotOnly = math.clamp(aim, 0, 1)
	crosshairAlphaTarget = if visible then 1 else 0
end

function HUD.pulse(amount: number)
	pulse = math.min(pulse + amount, 30)
end

function HUD.hitmarker(kind: string)
	hitToken += 1
	local token = hitToken
	local color = HIT_COLORS[kind] or HIT_COLORS.Body
	local big = kind == "Kill" or kind == "Head"
	for _, l in hitLines do
		l.BackgroundColor3 = color
		l.BackgroundTransparency = 0
		l.Size = UDim2.fromOffset(if big then 14 else 10, 2)
		local stroke = l:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 0.5
		end
	end
	hitScale.Scale = if kind == "Kill" then 1.8 else 1.4
	Widgets.tween(hitScale, Theme.Tween.Medium, { Scale = 1 })
	task.delay(if kind == "Kill" then 0.45 else 0.18, function()
		if token ~= hitToken then
			return
		end
		for _, l in hitLines do
			Widgets.tween(l, Theme.Tween.Medium, { BackgroundTransparency = 1 })
			local stroke = l:FindFirstChildOfClass("UIStroke")
			if stroke then
				Widgets.tween(stroke, Theme.Tween.Medium, { Transparency = 1 })
			end
		end
	end)
end

function HUD.setHealth(health: number, maxHealth: number)
	local alpha = math.clamp(health / math.max(maxHealth, 1), 0, 1)
	Widgets.tween(healthFill, Theme.Tween.Medium, {
		Size = UDim2.fromScale(alpha, 1),
		BackgroundColor3 = if alpha < 0.3 then Theme.Colors.Danger else Theme.Colors.Text,
	})
	healthLabel.Text = tostring(math.ceil(health))
	if health < lastHealth - 0.5 then
		damageEdges.Visible = true
		damageEdges:SetAttribute("Flash", os.clock())
		for _, edge in damageEdges:GetChildren() do
			if edge:IsA("Frame") then
				edge.BackgroundTransparency = 0
				Widgets.tween(edge, TweenInfo.new(0.9, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
			end
		end
	end
	lastHealth = health
end

function HUD.resetHealth(maxHealth: number)
	lastHealth = maxHealth
	HUD.setHealth(maxHealth, maxHealth)
end

function HUD.setMode(newMode: "OnFoot" | "Vehicle" | "Passenger")
	mode = newMode
	ammoFrame.Visible = newMode == "OnFoot"
	vehicleFrame.Visible = newMode == "Vehicle"
	crosshair.Visible = newMode == "OnFoot"
	staminaTrack.Visible = newMode == "OnFoot"
end

function HUD.setVehicle(speed: number, gear: number, rpm: number)
	if mode ~= "Vehicle" then
		return
	end
	shownSpeed += (speed - shownSpeed) * 0.25
	speedLabel.Text = tostring(math.floor(shownSpeed + 0.5))
	gearLabel.Text = if gear < 0 then "R" elseif speed < 0.5 then "N" else tostring(gear)
	rpmFill.Size = UDim2.fromScale(math.clamp(rpm, 0, 1), 1)
	rpmFill.BackgroundColor3 = if rpm > 0.88 then Theme.Colors.Danger else Theme.Colors.Text
end

local function money(value: number): string
	local s = tostring(math.floor(value))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return "$" .. out
end

function HUD.setCarry(value: number?)
	if value and value > 0 then
		carryLabel.Text = Theme.track("CARRYING  " .. money(value) .. "   ·   G  DROP")
		Widgets.tween(carryLabel, Theme.Tween.Medium, { TextTransparency = 0.05 })
	else
		Widgets.tween(carryLabel, Theme.Tween.Medium, { TextTransparency = 1 })
	end
end

function HUD.toast(text: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = Theme.track(text)
	toastLabel.TextTransparency = 1
	Widgets.tween(toastLabel, Theme.Tween.Medium, { TextTransparency = 0.1 })
	task.delay(1.6, function()
		if token == toastToken then
			Widgets.tween(toastLabel, Theme.Tween.Slow, { TextTransparency = 1 })
		end
	end)
end

return HUD
