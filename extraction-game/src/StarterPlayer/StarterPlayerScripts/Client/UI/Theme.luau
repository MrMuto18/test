--!strict
--[[
	Theme
	Typography, colour and motion tokens for every client UI.
]]

local Theme = {}

local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"
local GOTHAM = "rbxasset://fonts/families/GothamSSm.json"
local MONO = "rbxasset://fonts/families/RobotoMono.json"

Theme.Fonts = {
	Display = Font.new(MONTSERRAT, Enum.FontWeight.ExtraBold),
	Heading = Font.new(MONTSERRAT, Enum.FontWeight.Bold),
	Option = Font.new(MONTSERRAT, Enum.FontWeight.SemiBold),
	Body = Font.new(GOTHAM, Enum.FontWeight.Medium),
	Mono = Font.new(MONO, Enum.FontWeight.Regular),
	MonoBold = Font.new(MONO, Enum.FontWeight.Bold),
}

Theme.Colors = {
	Text = Color3.fromRGB(236, 234, 228),
	Dim = Color3.fromRGB(150, 150, 146),
	Accent = Color3.fromRGB(255, 168, 86),
	AccentCool = Color3.fromRGB(90, 210, 255),
	Danger = Color3.fromRGB(255, 72, 72),
	Black = Color3.new(0, 0, 0),
	White = Color3.new(1, 1, 1),
}

Theme.Tween = {
	Fast = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Medium = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
	Fade = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
}

Theme.Text = {
	IdleTransparency = 0.42,
	DimTransparency = 0.55,
}

-- Wide tracking for small caps labels (thin spaces between glyphs).
local THIN = utf8.char(0x2009)
function Theme.track(text: string): string
	local out = {}
	for _, code in utf8.codes(text) do
		local char = utf8.char(code)
		if char == " " then
			table.insert(out, THIN .. THIN .. THIN)
		else
			table.insert(out, char)
		end
	end
	return table.concat(out, THIN)
end

return Theme
