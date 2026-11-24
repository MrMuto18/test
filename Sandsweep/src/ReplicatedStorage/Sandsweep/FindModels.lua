-- FindModels (ModuleScript) - ReplicatedStorage/Sandsweep/FindModels
-- Procedural models for the 14 buried relics. Used by the server (world) and
-- the client (journal / celebration ViewportFrames). PrimaryPart is "Core".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PartKit = require(ReplicatedStorage:WaitForChild("Sandsweep"):WaitForChild("PartKit"))

local FindModels = {}

local P = PartKit.Part
local Cyl = PartKit.Cylinder
local Ell = PartKit.Ellipsoid
local Ball = PartKit.Ball

local METAL = Enum.Material.Metal
local SMOOTH = Enum.Material.SmoothPlastic
local GLASS = Enum.Material.Glass
local NEON = Enum.Material.Neon
local FOIL = Enum.Material.Foil

local GOLD = Color3.fromRGB(236, 186, 64)
local DARK = Color3.fromRGB(56, 44, 36)

local builders = {}

builders.PocketWatch = function(m)
	local rust = Color3.fromRGB(184, 128, 62)
	local core = Cyl(m, 0.3, 1.5, CFrame.new(0, 0, 0), "Y", { Name = "Core", Material = Enum.Material.CorrodedMetal, Color = rust })
	Cyl(m, 0.32, 1.22, CFrame.new(0, 0.01, 0), "Y", { Material = SMOOTH, Color = Color3.fromRGB(246, 236, 212) })
	Cyl(m, 0.34, 1.08, CFrame.new(0, 0.02, 0), "Y", { Material = GLASS, Transparency = 0.6, Color = Color3.fromRGB(220, 235, 240) })
	P(m, { Size = Vector3.new(0.06, 0.04, 0.42), CFrame = CFrame.new(0, 0.18, -0.16), Color = DARK })
	P(m, { Size = Vector3.new(0.3, 0.04, 0.06), CFrame = CFrame.new(0.12, 0.18, 0) * CFrame.Angles(0, math.rad(30), 0), Color = DARK })
	for i = 0, 11 do
		local a = math.rad(i * 30)
		P(m, { Size = Vector3.new(0.04, 0.03, 0.1), CFrame = CFrame.new(math.sin(a) * 0.48, 0.17, math.cos(a) * 0.48) * CFrame.Angles(0, a, 0), Color = DARK })
	end
	Cyl(m, 0.22, 0.24, CFrame.new(0, 0, -0.84), "Z", { Material = METAL, Color = rust })
	for i = 0, 7 do
		local a = math.rad(i * 45)
		P(m, { Size = Vector3.new(0.08, 0.08, 0.12), CFrame = CFrame.new(math.sin(a) * 0.2, math.cos(a) * 0.2, -1.12) * CFrame.Angles(0, 0, -a), Material = METAL, Color = GOLD })
	end
	return core
end

builders.AncientCoin = function(m)
	local bronze = Color3.fromRGB(200, 146, 70)
	local core = Cyl(m, 0.2, 1.7, CFrame.new(0, 0, 0), "Y", { Name = "Core", Material = FOIL, Color = bronze })
	Cyl(m, 0.24, 1.25, CFrame.new(0, 0, 0), "Y", { Material = METAL, Color = Color3.fromRGB(170, 120, 56) })
	P(m, { Size = Vector3.new(0.36, 0.3, 0.36), CFrame = CFrame.new(0, 0, 0), Color = DARK })
	for i = 0, 3 do
		local a = math.rad(i * 90 + 45)
		P(m, { Size = Vector3.new(0.18, 0.27, 0.08), CFrame = CFrame.new(math.sin(a) * 0.42, 0, math.cos(a) * 0.42) * CFrame.Angles(0, a, 0), Material = FOIL, Color = GOLD })
	end
	return core
end

builders.GlassBottle = function(m)
	local blue = Color3.fromRGB(90, 160, 205)
	local core = Cyl(m, 1.8, 0.85, CFrame.new(0, 0, 0), "X", { Name = "Core", Material = GLASS, Transparency = 0.35, Color = blue })
	Cyl(m, 0.3, 0.55, CFrame.new(1.02, 0, 0), "X", { Material = GLASS, Transparency = 0.35, Color = blue })
	Cyl(m, 0.55, 0.36, CFrame.new(1.4, 0, 0), "X", { Material = GLASS, Transparency = 0.3, Color = blue })
	Cyl(m, 0.25, 0.3, CFrame.new(1.74, 0, 0), "X", { Material = Enum.Material.Wood, Color = Color3.fromRGB(150, 104, 62) })
	Cyl(m, 1.1, 0.32, CFrame.new(-0.1, -0.12, 0), "X", { Color = Color3.fromRGB(246, 232, 200) })
	Cyl(m, 0.12, 0.34, CFrame.new(-0.1, -0.12, 0), "X", { Color = Color3.fromRGB(196, 96, 62) })
	return core
end

builders.Sunglasses = function(m)
	local frame = Color3.fromRGB(120, 72, 40)
	local core = P(m, { Name = "Core", Size = Vector3.new(0.4, 0.1, 0.1), CFrame = CFrame.new(0, 0.12, 0), Color = frame })
	for _, side in ipairs({ -1, 1 }) do
		Cyl(m, 0.08, 0.7, CFrame.new(side * 0.5, 0, 0), "Z", { Color = frame })
		Cyl(m, 0.1, 0.6, CFrame.new(side * 0.5, 0, -0.01), "Z", { Material = GLASS, Transparency = 0.15, Color = Color3.fromRGB(30, 26, 30), Reflectance = 0.3 })
		P(m, { Size = Vector3.new(0.06, 0.08, 1.3), CFrame = CFrame.new(side * 0.85, 0.1, 0.62) * CFrame.Angles(0, side * math.rad(-6), 0), Color = frame })
		P(m, { Size = Vector3.new(0.06, 0.08, 0.3), CFrame = CFrame.new(side * 0.88, -0.02, 1.32) * CFrame.Angles(math.rad(-40), 0, 0), Color = frame })
	end
	return core
end

builders.ToyRobot = function(m)
	local blue = Color3.fromRGB(110, 170, 210)
	local tin = Color3.fromRGB(190, 194, 200)
	local core = P(m, { Name = "Core", Size = Vector3.new(0.95, 1.0, 0.65), CFrame = CFrame.new(0, 0, 0), Material = METAL, Color = blue })
	P(m, { Size = Vector3.new(0.72, 0.58, 0.58), CFrame = CFrame.new(0, 0.82, 0), Material = METAL, Color = tin })
	for _, side in ipairs({ -1, 1 }) do
		Ball(m, 0.16, CFrame.new(side * 0.17, 0.88, -0.29), { Material = NEON, Color = Color3.fromRGB(255, 200, 90), CastShadow = false })
		P(m, { Size = Vector3.new(0.22, 0.75, 0.24), CFrame = CFrame.new(side * 0.6, 0.02, 0) * CFrame.Angles(0, 0, side * math.rad(12)), Material = METAL, Color = tin })
		P(m, { Size = Vector3.new(0.28, 0.5, 0.32), CFrame = CFrame.new(side * 0.24, -0.74, 0), Material = METAL, Color = tin })
	end
	Cyl(m, 0.35, 0.06, CFrame.new(0, 1.28, 0), "Y", { Material = METAL, Color = tin })
	Ball(m, 0.16, CFrame.new(0, 1.48, 0), { Material = NEON, Color = Color3.fromRGB(230, 90, 70), CastShadow = false })
	P(m, { Size = Vector3.new(0.5, 0.3, 0.05), CFrame = CFrame.new(0, 0.05, -0.34), Material = SMOOTH, Color = Color3.fromRGB(240, 190, 60) })
	return core
end

builders.Amphora = function(m)
	local clay = Color3.fromRGB(196, 104, 66)
	local core = Ell(m, Vector3.new(1.4, 1.9, 1.4), CFrame.new(0, 0, 0), { Name = "Core", Color = clay })
	Cyl(m, 0.7, 0.5, CFrame.new(0, 1.15, 0), "Y", { Color = clay })
	Cyl(m, 0.14, 0.7, CFrame.new(0, 1.5, 0), "Y", { Color = clay })
	Cyl(m, 0.34, 0.36, CFrame.new(0, -1.0, 0), "Y", { Color = clay })
	for _, side in ipairs({ -1, 1 }) do
		P(m, { Size = Vector3.new(0.14, 0.62, 0.14), CFrame = CFrame.new(side * 0.5, 1.12, 0) * CFrame.Angles(0, 0, side * math.rad(-28)), Color = clay })
	end
	Cyl(m, 0.06, 1.44, CFrame.new(0, 0.25, 0), "Y", { Color = Color3.fromRGB(60, 40, 30) })
	Cyl(m, 0.06, 1.38, CFrame.new(0, -0.15, 0), "Y", { Color = Color3.fromRGB(240, 200, 140) })
	P(m, { Size = Vector3.new(0.05, 0.5, 0.05), CFrame = CFrame.new(0.4, 0.35, -0.55) * CFrame.Angles(0, 0, math.rad(20)), Color = DARK })
	m:SetAttribute("LieAngle", 70)
	return core
end

builders.DesertRose = function(m)
	local rose = Color3.fromRGB(222, 170, 140)
	local core = Cyl(m, 0.12, 1.3, CFrame.new(0, 0, 0), "Y", { Name = "Core", Material = Enum.Material.Sandstone, Color = rose })
	local petals = {
		{ 0, 0.25, 0, 20, 0 },
		{ 0.3, 0.2, 0.1, 50, 60 },
		{ -0.3, 0.25, -0.1, 55, 160 },
		{ 0.05, 0.45, -0.3, 40, 250 },
		{ -0.15, 0.4, 0.3, 65, 320 },
		{ 0.2, 0.55, 0.15, 35, 110 },
	}
	for _, petal in ipairs(petals) do
		Cyl(m, 0.1, 1.0, CFrame.new(petal[1], petal[2], petal[3]) * CFrame.Angles(0, math.rad(petal[5]), math.rad(petal[4])), "Y", {
			Material = Enum.Material.Sandstone,
			Color = rose,
		})
	end
	Ball(m, 0.22, CFrame.new(0.1, 0.62, 0), { Material = GLASS, Transparency = 0.3, Color = Color3.fromRGB(255, 220, 230) })
	return core
end

builders.GoldRing = function(m)
	local core = P(m, { Name = "Core", Size = Vector3.new(0.3, 0.12, 0.3), CFrame = CFrame.new(0, 0.42, 0), Material = FOIL, Color = GOLD })
	for i = 0, 13 do
		local a = math.rad(i * (360 / 14))
		P(m, {
			Size = Vector3.new(0.24, 0.18, 0.12),
			CFrame = CFrame.new(math.sin(a) * 0.48, math.cos(a) * 0.48, 0) * CFrame.Angles(0, 0, -a),
			Material = FOIL,
			Color = GOLD,
		})
	end
	Ball(m, 0.34, CFrame.new(0, 0.66, 0), { Material = GLASS, Color = Color3.fromRGB(220, 40, 70), Reflectance = 0.2 })
	for _, side in ipairs({ -1, 1 }) do
		P(m, { Size = Vector3.new(0.05, 0.22, 0.05), CFrame = CFrame.new(side * 0.13, 0.58, 0), Material = FOIL, Color = GOLD })
	end
	m:SetAttribute("LieAngle", 80)
	return core
end

builders.BrassCompass = function(m)
	local brass = Color3.fromRGB(196, 150, 72)
	local core = Cyl(m, 0.28, 1.3, CFrame.new(0, 0, 0), "Y", { Name = "Core", Material = METAL, Color = brass })
	Cyl(m, 0.3, 1.08, CFrame.new(0, 0.01, 0), "Y", { Color = Color3.fromRGB(246, 236, 212) })
	Cyl(m, 0.32, 1.06, CFrame.new(0, 0.02, 0), "Y", { Material = GLASS, Transparency = 0.65, Color = Color3.fromRGB(220, 235, 240) })
	P(m, { ClassName = "WedgePart", Size = Vector3.new(0.08, 0.04, 0.4), CFrame = CFrame.new(0, 0.17, -0.2) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.Angles(0, 0, 0), Color = Color3.fromRGB(210, 50, 50) })
	P(m, { Size = Vector3.new(0.08, 0.04, 0.4), CFrame = CFrame.new(0, 0.17, 0.2), Color = Color3.fromRGB(240, 240, 240) })
	Cyl(m, 0.08, 1.3, CFrame.new(0, 0.62, 0.72) * CFrame.Angles(math.rad(-75), 0, 0), "Y", { Material = METAL, Color = brass })
	Cyl(m, 0.2, 0.22, CFrame.new(0, 0, -0.74), "Z", { Material = METAL, Color = brass })
	return core
end

builders.Ammonite = function(m)
	local stone = Color3.fromRGB(206, 186, 150)
	local core = Ball(m, 0.5, CFrame.new(0, 0, 0), { Name = "Core", Material = Enum.Material.Limestone, Color = stone })
	local angle, radius, size = 0, 0.2, 0.38
	for i = 1, 22 do
		angle += math.rad(30)
		radius *= 1.075
		size *= 1.06
		Ball(m, size, CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), {
			Material = Enum.Material.Limestone,
			Color = (i % 2 == 0) and stone or Color3.fromRGB(184, 160, 124),
		})
	end
	m:SetAttribute("LieAngle", 75)
	return core
end

builders.Harmonica = function(m)
	local silver = Color3.fromRGB(200, 204, 212)
	local core = P(m, { Name = "Core", Size = Vector3.new(1.6, 0.14, 0.42), CFrame = CFrame.new(0, 0.16, 0), Material = METAL, Color = silver })
	P(m, { Size = Vector3.new(1.6, 0.14, 0.42), CFrame = CFrame.new(0, -0.16, 0), Material = METAL, Color = silver })
	P(m, { Size = Vector3.new(1.5, 0.2, 0.4), CFrame = CFrame.new(0, 0, 0.01), Material = Enum.Material.Wood, Color = Color3.fromRGB(150, 96, 56) })
	for i = 0, 9 do
		P(m, { Size = Vector3.new(0.08, 0.1, 0.05), CFrame = CFrame.new(-0.63 + i * 0.14, 0, -0.2), Color = DARK })
	end
	P(m, { Size = Vector3.new(0.7, 0.02, 0.2), CFrame = CFrame.new(0, 0.24, 0), Material = FOIL, Color = GOLD })
	return core
end

builders.Scarab = function(m)
	local turquoise = Color3.fromRGB(60, 176, 170)
	local core = Ell(m, Vector3.new(0.9, 0.4, 1.2), CFrame.new(0, 0, 0), { Name = "Core", Material = GLASS, Color = turquoise, Reflectance = 0.1 })
	Ell(m, Vector3.new(0.5, 0.3, 0.38), CFrame.new(0, 0, -0.68), { Material = GLASS, Color = Color3.fromRGB(40, 140, 140) })
	P(m, { Size = Vector3.new(0.05, 0.42, 1.05), CFrame = CFrame.new(0, 0.02, 0.05), Material = FOIL, Color = GOLD })
	Cyl(m, 0.08, 1.05, CFrame.new(0, -0.05, 0.05), "Y", { Material = FOIL, Color = GOLD })
	for _, side in ipairs({ -1, 1 }) do
		for leg = -1, 1 do
			P(m, { Size = Vector3.new(0.4, 0.06, 0.06), CFrame = CFrame.new(side * 0.55, -0.1, leg * 0.32) * CFrame.Angles(0, side * leg * math.rad(20), 0), Material = FOIL, Color = GOLD })
		end
		Ell(m, Vector3.new(0.5, 0.14, 0.9), CFrame.new(side * 0.62, 0.02, 0.15) * CFrame.Angles(0, side * math.rad(15), 0), { Material = FOIL, Color = GOLD })
	end
	for i = 0, 7 do
		local a = math.rad(i * 45)
		Ball(m, 0.1, CFrame.new(math.sin(a) * 0.18, 0.08, -1.05 - math.cos(a) * 0.18), { Material = FOIL, Color = GOLD })
	end
	return core
end

builders.DinoSkull = function(m)
	local bone = Color3.fromRGB(230, 214, 182)
	local boneDark = Color3.fromRGB(196, 176, 140)
	local core = Ell(m, Vector3.new(1.7, 1.4, 2.0), CFrame.new(0, 0.2, 0.6), { Name = "Core", Color = bone })
	Ell(m, Vector3.new(1.1, 0.8, 2.2), CFrame.new(0, 0.05, -0.9), { Color = bone })
	P(m, { ClassName = "WedgePart", Size = Vector3.new(0.9, 0.35, 1.8), CFrame = CFrame.new(0, -0.55, -0.5) * CFrame.Angles(0, math.rad(180), math.rad(180)), Color = boneDark })
	for _, side in ipairs({ -1, 1 }) do
		Ball(m, 0.5, CFrame.new(side * 0.55, 0.45, 0.35), { Color = DARK })
		Ball(m, 0.25, CFrame.new(side * 0.35, 0.25, -1.75), { Color = DARK })
		for t = 0, 5 do
			P(m, {
				ClassName = "WedgePart",
				Size = Vector3.new(0.08, 0.28, 0.12),
				CFrame = CFrame.new(side * 0.42, -0.4, -1.75 + t * 0.32) * CFrame.Angles(math.rad(180), 0, 0),
				Color = Color3.fromRGB(250, 244, 226),
			})
		end
		P(m, { ClassName = "WedgePart", Size = Vector3.new(0.18, 0.5, 0.5), CFrame = CFrame.new(side * 0.6, 0.95, 1.1) * CFrame.Angles(math.rad(-30), 0, 0), Color = boneDark })
	end
	Ell(m, Vector3.new(1.2, 0.5, 0.5), CFrame.new(0, -0.15, 1.45), { Color = boneDark })
	return core
end

builders.GoldenIdol = function(m)
	local core = P(m, { Name = "Core", Size = Vector3.new(1.1, 0.35, 1.1), CFrame = CFrame.new(0, -1.05, 0), Material = FOIL, Color = GOLD })
	Cyl(m, 1.2, 0.8, CFrame.new(0, -0.3, 0), "Y", { Material = FOIL, Color = GOLD })
	Ball(m, 0.8, CFrame.new(0, 0.62, 0), { Material = FOIL, Color = GOLD })
	for _, side in ipairs({ -1, 1 }) do
		P(m, { Size = Vector3.new(0.2, 0.75, 0.2), CFrame = CFrame.new(side * 0.42, -0.2, -0.15) * CFrame.Angles(math.rad(-50), 0, side * math.rad(-15)), Material = FOIL, Color = GOLD })
		Ball(m, 0.16, CFrame.new(side * 0.16, 0.7, -0.36), { Material = NEON, Color = Color3.fromRGB(90, 230, 140), CastShadow = false })
		P(m, { ClassName = "WedgePart", Size = Vector3.new(0.1, 0.35, 0.25), CFrame = CFrame.new(side * 0.28, 1.1, 0) * CFrame.Angles(0, math.rad(90), 0), Material = FOIL, Color = GOLD })
	end
	P(m, { ClassName = "WedgePart", Size = Vector3.new(0.1, 0.45, 0.25), CFrame = CFrame.new(0, 1.15, 0) * CFrame.Angles(0, math.rad(90), 0), Material = FOIL, Color = GOLD })
	Cyl(m, 0.1, 0.86, CFrame.new(0, 0.95, 0), "Y", { Material = FOIL, Color = Color3.fromRGB(250, 214, 110) })
	P(m, { Size = Vector3.new(1.3, 0.1, 1.3), CFrame = CFrame.new(0, -1.22, 0), Material = Enum.Material.Sandstone, Color = Color3.fromRGB(180, 130, 90) })
	return core
end

function FindModels.Build(findId, anchored)
	local builder = builders[findId]
	assert(builder, "Unknown find: " .. tostring(findId))
	local model = Instance.new("Model")
	model.Name = findId
	local core = builder(model)
	PartKit.Finalize(model, core, anchored ~= false)
	model:SetAttribute("FindId", findId)
	return model
end

return FindModels
