--!strict
--[[
	CinematicGrade
	Client-side owner of the post-processing stack created by the server's
	LightingService. Every frame it writes:

		value = lerp(menuGrade, gameplayGrade, blend) + transient offsets

	• blend 0 = menu (heavy DOF focused on the current shot subject, darker,
	  punchier), blend 1 = gameplay grade from Config.Lighting.
	• Menu focus distance/radius glide on a spring when the shot changes.
	• flash() adds a decaying exposure spike (lightning).
	• Quality presets toggle DOF / SunRays and scale Bloom.

	Client writes to replicated Lighting objects stay local to this player.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Spring = require(Shared.Spring)
local Types = require(Shared.Types)

local CinematicGrade = {}

local NAMES = {
	ColorCorrection = "Grade_ColorCorrection",
	Bloom = "Grade_Bloom",
	DepthOfField = "Grade_DepthOfField",
	SunRays = "Grade_SunRays",
}

local cc: ColorCorrectionEffect? = nil
local bloom: BloomEffect? = nil
local dof: DepthOfFieldEffect? = nil
local rays: SunRaysEffect? = nil

local blend = 0
local flashOffset = 0
local preset: Types.QualityPreset = Config.Quality.High
local focusSpring = Spring.new(Vector3.new(20, 9, 0), 0.9, 1)

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function find(name: string, className: string): Instance?
	local inst = Lighting:WaitForChild(name, 10)
	if inst and inst.ClassName == className then
		return inst
	end
	warn("[CinematicGrade] missing Lighting effect:", name)
	return nil
end

local function step(dt: number)
	local G = Config.Lighting
	local M = Config.MenuGrade
	local focus = focusSpring:update(dt)
	local t = blend

	local depth = dof
	if depth then
		depth.Enabled = preset.DepthOfField
		depth.FocusDistance = lerp(focus.X, G.DepthOfField.FocusDistance, t)
		depth.InFocusRadius = lerp(focus.Y, G.DepthOfField.InFocusRadius, t)
		depth.FarIntensity = lerp(M.FarIntensity, G.DepthOfField.FarIntensity, t)
		depth.NearIntensity = lerp(M.NearIntensity, G.DepthOfField.NearIntensity, t)
	end

	local grade = cc
	if grade then
		grade.Contrast = lerp(M.Contrast, G.ColorCorrection.Contrast, t)
		grade.Saturation = lerp(M.Saturation, G.ColorCorrection.Saturation, t)
	end

	local glow = bloom
	if glow then
		glow.Intensity = G.Bloom.Intensity * preset.BloomScale * (1 + flashOffset * 0.25)
	end

	local sun = rays
	if sun then
		sun.Enabled = preset.SunRays
	end

	Lighting.ExposureCompensation = lerp(M.ExposureCompensation, G.ExposureCompensation, t) + flashOffset
	flashOffset *= math.exp(-dt * 9)
	if flashOffset < 0.002 then
		flashOffset = 0
	end
end

function CinematicGrade.init()
	cc = find(NAMES.ColorCorrection, "ColorCorrectionEffect") :: any
	bloom = find(NAMES.Bloom, "BloomEffect") :: any
	dof = find(NAMES.DepthOfField, "DepthOfFieldEffect") :: any
	rays = find(NAMES.SunRays, "SunRaysEffect") :: any
	RunService:BindToRenderStep("CinematicGrade", Enum.RenderPriority.Last.Value, step)
end

-- 0 = menu grade, 1 = gameplay grade.
function CinematicGrade.setBlend(alpha: number)
	blend = math.clamp(alpha, 0, 1)
end

function CinematicGrade.getBlend(): number
	return blend
end

function CinematicGrade.setMenuFocus(distance: number, radius: number, instant: boolean?)
	local target = Vector3.new(distance, radius, 0)
	if instant then
		focusSpring:reset(target)
	else
		focusSpring.Target = target
	end
end

function CinematicGrade.flash(amount: number)
	flashOffset = math.max(flashOffset, amount)
end

function CinematicGrade.applyQuality(quality: Types.QualityLevel)
	preset = Config.Quality[quality] or Config.Quality.High
end

return CinematicGrade
