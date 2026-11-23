--!strict
--[[
	LightingService
	Applies the gritty dusk/overcast look-dev to Lighting, MaterialService,
	Terrain clouds and the post-processing stack.

	Works from the server at runtime AND from the Studio Command Bar:
		require(game.ServerScriptService.Server.Services.LightingService).apply()

	Some engine properties are not writable from scripts on every Studio
	build (Lighting.Technology is the usual one). Those writes are attempted
	safely, and anything that failed is printed so you can set it once in
	the Properties panel.
]]

local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local LightingService = {}

-- Stable names so the client can find and blend the effects.
LightingService.EffectNames = {
	ColorCorrection = "Grade_ColorCorrection",
	Bloom = "Grade_Bloom",
	DepthOfField = "Grade_DepthOfField",
	SunRays = "Grade_SunRays",
	ColorGrading = "Grade_Tonemap",
}

local function trySet(instance: Instance, property: string, value: any, failures: { string })
	local ok = pcall(function()
		(instance :: any)[property] = value
	end)
	if not ok then
		table.insert(failures, string.format("%s.%s = %s", instance.ClassName, property, tostring(value)))
	end
end

local function trySetEnum(instance: Instance, property: string, enumName: string, itemName: string, failures: { string })
	local ok, item = pcall(function(): any
		return ((Enum :: any)[enumName] :: any)[itemName]
	end)
	if ok and item ~= nil then
		trySet(instance, property, item, failures)
	else
		table.insert(failures, string.format("%s.%s = %s (enum unavailable)", instance.ClassName, property, itemName))
	end
end

-- Reuses an existing child of the class (e.g. the template's Bloom) and
-- disables duplicates so effects never stack unpredictably.
local function ensureSingle(parent: Instance, className: string, name: string): Instance
	local chosen: Instance? = parent:FindFirstChild(name)
	if chosen and chosen.ClassName ~= className then
		chosen = nil
	end
	for _, child in parent:GetChildren() do
		if child.ClassName == className then
			if chosen == nil then
				chosen = child
			elseif child ~= chosen then
				pcall(function()
					(child :: any).Enabled = false
				end)
			end
		end
	end
	if chosen == nil then
		local created = Instance.new(className :: any)
		created.Parent = parent
		chosen = created
	end
	local result = chosen :: Instance
	result.Name = name
	return result
end

function LightingService.apply(): { string }
	local failures: { string } = {}
	local L = Config.Lighting

	-- Renderer
	trySetEnum(Lighting, "Technology", "Technology", "Future", failures)
	trySetEnum(Lighting, "LightingStyle", "LightingStyle", "Realistic", failures)
	trySet(Lighting, "PrioritizeLightingQuality", true, failures)
	trySet(MaterialService, "Use2022Materials", true, failures)

	-- Sun, sky and ambient response
	Lighting.GlobalShadows = true
	Lighting.ClockTime = L.ClockTime
	Lighting.GeographicLatitude = L.GeographicLatitude
	Lighting.Brightness = L.Brightness
	Lighting.ExposureCompensation = L.ExposureCompensation
	Lighting.EnvironmentDiffuseScale = L.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = L.EnvironmentSpecularScale
	Lighting.ShadowSoftness = L.ShadowSoftness
	Lighting.Ambient = L.Ambient
	Lighting.OutdoorAmbient = L.OutdoorAmbient
	Lighting.ColorShift_Top = L.ColorShiftTop
	Lighting.ColorShift_Bottom = L.ColorShiftBottom
	Lighting.FogEnd = 100000 -- Atmosphere owns distance fog.

	local atmosphere = ensureSingle(Lighting, "Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = L.Atmosphere.Density
	atmosphere.Offset = L.Atmosphere.Offset
	atmosphere.Color = L.Atmosphere.Color
	atmosphere.Decay = L.Atmosphere.Decay
	atmosphere.Glare = L.Atmosphere.Glare
	atmosphere.Haze = L.Atmosphere.Haze

	local sky = ensureSingle(Lighting, "Sky", "Sky") :: Sky
	sky.StarCount = 0
	sky.SunAngularSize = 11
	sky.MoonAngularSize = 9
	sky.CelestialBodiesShown = true

	local clouds = ensureSingle(Workspace.Terrain, "Clouds", "Clouds") :: Clouds
	clouds.Enabled = true
	clouds.Cover = L.Clouds.Cover
	clouds.Density = L.Clouds.Density
	clouds.Color = L.Clouds.Color

	-- Post-processing stack
	local cc = ensureSingle(Lighting, "ColorCorrectionEffect", LightingService.EffectNames.ColorCorrection) :: ColorCorrectionEffect
	cc.Enabled = true
	cc.Brightness = L.ColorCorrection.Brightness
	cc.Contrast = L.ColorCorrection.Contrast
	cc.Saturation = L.ColorCorrection.Saturation
	cc.TintColor = L.ColorCorrection.TintColor

	local bloom = ensureSingle(Lighting, "BloomEffect", LightingService.EffectNames.Bloom) :: BloomEffect
	bloom.Enabled = true
	bloom.Intensity = L.Bloom.Intensity
	bloom.Size = L.Bloom.Size
	bloom.Threshold = L.Bloom.Threshold

	local dof = ensureSingle(Lighting, "DepthOfFieldEffect", LightingService.EffectNames.DepthOfField) :: DepthOfFieldEffect
	dof.Enabled = true
	dof.FarIntensity = L.DepthOfField.FarIntensity
	dof.FocusDistance = L.DepthOfField.FocusDistance
	dof.InFocusRadius = L.DepthOfField.InFocusRadius
	dof.NearIntensity = L.DepthOfField.NearIntensity

	local rays = ensureSingle(Lighting, "SunRaysEffect", LightingService.EffectNames.SunRays) :: SunRaysEffect
	rays.Enabled = true
	rays.Intensity = L.SunRays.Intensity
	rays.Spread = L.SunRays.Spread

	-- Filmic tonemapper (newer engines only).
	local gradingOk = pcall(function()
		local grading: any = ensureSingle(Lighting, "ColorGradingEffect", LightingService.EffectNames.ColorGrading)
		grading.Enabled = true
		grading.TonemapperPreset = (Enum :: any).TonemapperPreset.Default
	end)
	if not gradingOk then
		table.insert(failures, "ColorGradingEffect (not available on this engine build — optional)")
	end

	-- Old blur effects from templates would wreck the grade.
	for _, child in Lighting:GetChildren() do
		if child:IsA("BlurEffect") then
			child.Enabled = false
		end
	end

	if #failures > 0 then
		warn(
			"[LightingService] Set these once in the Properties panel (not writable from this context):\n  • "
				.. table.concat(failures, "\n  • ")
		)
	else
		print("[LightingService] Look-dev applied (Future lighting, 2022 materials, full post stack).")
	end
	return failures
end

return LightingService
