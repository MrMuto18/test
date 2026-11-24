-- ToolModels (ModuleScript) - ReplicatedStorage/Sandsweep/ToolModels
-- Procedural models for the 4 digging tools. Tools point along -Z.
-- Every model has PrimaryPart "Handle", an Attachment "Tip" at the business end,
-- optional "SandFill" part (fill gauge) and optional "Fan" folder (spinning blades).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PartKit = require(ReplicatedStorage:WaitForChild("Sandsweep"):WaitForChild("PartKit"))

local ToolModels = {}

local METAL = Enum.Material.Metal
local WOOD = Enum.Material.Wood
local GLASS = Enum.Material.Glass
local NEON = Enum.Material.Neon

local SAND = Color3.fromRGB(232, 196, 128)

-- First-person placement relative to the camera
ToolModels.ViewOffsets = {
	Spoon = CFrame.new(0.85, -0.8, -1.7) * CFrame.Angles(math.rad(10), math.rad(-10), math.rad(-4)),
	Shovel = CFrame.new(1.05, -1.15, -1.6) * CFrame.Angles(math.rad(14), math.rad(-10), math.rad(-8)),
	HandVac = CFrame.new(0.95, -0.95, -1.7) * CFrame.Angles(math.rad(6), math.rad(-7), 0),
	TurbineVac = CFrame.new(1.15, -1.35, -2.5) * CFrame.Angles(math.rad(5), math.rad(-6), 0),
}

-- Grip point (tool space) that sits in the character's hand
ToolModels.Grips = {
	Spoon = Vector3.new(0, 0, 0.45),
	Shovel = Vector3.new(0, 0, 1.15),
	HandVac = Vector3.new(0, 0.55, 0.4),
	TurbineVac = Vector3.new(0.8, 0, 0.2),
}

local function addTip(handle, position)
	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = position
	tip.Parent = handle
	return tip
end

local builders = {}

builders.Spoon = function(model)
	local silver = Color3.fromRGB(196, 200, 208)
	local handle = PartKit.Part(model, {
		Name = "Handle",
		Size = Vector3.new(0.2, 0.07, 1.25),
		CFrame = CFrame.new(0, 0, 0.1),
		Material = METAL,
		Color = silver,
	})
	PartKit.Part(model, {
		Name = "Rust",
		Size = Vector3.new(0.22, 0.08, 0.3),
		CFrame = CFrame.new(0, 0, 0.62),
		Material = Enum.Material.CorrodedMetal,
		Color = Color3.fromRGB(176, 104, 64),
	})
	PartKit.Part(model, {
		Name = "Neck",
		Size = Vector3.new(0.12, 0.06, 0.45),
		CFrame = CFrame.new(0, 0.03, -0.72) * CFrame.Angles(math.rad(-8), 0, 0),
		Material = METAL,
		Color = silver,
	})
	PartKit.Ellipsoid(model, Vector3.new(0.55, 0.16, 0.75), CFrame.new(0, 0.06, -1.25), {
		Name = "Bowl",
		Material = METAL,
		Color = silver,
	})
	PartKit.Ellipsoid(model, Vector3.new(0.42, 0.1, 0.55), CFrame.new(0, 0.12, -1.25), {
		Name = "SandScoop",
		Color = SAND,
		Material = Enum.Material.Sand,
	})
	addTip(handle, Vector3.new(0, 0.05, -1.55))
	return handle
end

builders.Shovel = function(model)
	local woodColor = Color3.fromRGB(156, 106, 64)
	local steel = Color3.fromRGB(150, 156, 164)
	local handle = PartKit.Cylinder(model, 2.7, 0.2, CFrame.new(0, 0, 0), "Z", {
		Name = "Handle",
		Material = WOOD,
		Color = woodColor,
	})
	-- D-grip
	PartKit.Cylinder(model, 0.55, 0.14, CFrame.new(0, 0, 1.6), "X", { Name = "GripBar", Material = WOOD, Color = woodColor })
	PartKit.Part(model, {
		Name = "GripL",
		Size = Vector3.new(0.08, 0.08, 0.4),
		CFrame = CFrame.new(-0.22, 0, 1.42) * CFrame.Angles(0, math.rad(-25), 0),
		Material = METAL,
		Color = steel,
	})
	PartKit.Part(model, {
		Name = "GripR",
		Size = Vector3.new(0.08, 0.08, 0.4),
		CFrame = CFrame.new(0.22, 0, 1.42) * CFrame.Angles(0, math.rad(25), 0),
		Material = METAL,
		Color = steel,
	})
	PartKit.Cylinder(model, 0.45, 0.27, CFrame.new(0, 0, -1.45), "Z", { Name = "Collar", Material = METAL, Color = steel })
	PartKit.Part(model, {
		Name = "Blade",
		Size = Vector3.new(0.95, 0.07, 1.05),
		CFrame = CFrame.new(0, -0.02, -2.15),
		Material = METAL,
		Color = steel,
	})
	PartKit.Part(model, {
		Name = "BladeTip",
		Size = Vector3.new(0.67, 0.07, 0.67),
		CFrame = CFrame.new(0, -0.02, -2.62) * CFrame.Angles(0, math.rad(45), 0),
		Material = METAL,
		Color = steel,
	})
	PartKit.Part(model, {
		Name = "LipL",
		Size = Vector3.new(0.06, 0.16, 1.0),
		CFrame = CFrame.new(-0.46, 0.05, -2.12),
		Material = METAL,
		Color = steel,
	})
	PartKit.Part(model, {
		Name = "LipR",
		Size = Vector3.new(0.06, 0.16, 1.0),
		CFrame = CFrame.new(0.46, 0.05, -2.12),
		Material = METAL,
		Color = steel,
	})
	PartKit.Ellipsoid(model, Vector3.new(0.7, 0.18, 0.8), CFrame.new(0, 0.06, -2.2), {
		Name = "SandScoop",
		Color = SAND,
		Material = Enum.Material.Sand,
	})
	addTip(handle, Vector3.new(0, 0, -2.9))
	return handle
end

builders.HandVac = function(model)
	local body = Color3.fromRGB(214, 110, 70)
	local dark = Color3.fromRGB(62, 52, 46)
	local steel = Color3.fromRGB(170, 174, 180)
	local handle = PartKit.Part(model, {
		Name = "Handle",
		Size = Vector3.new(0.7, 0.66, 1.1),
		CFrame = CFrame.new(0, 0, 0.35),
		Color = body,
	})
	PartKit.Part(model, { Name = "Grip", Size = Vector3.new(0.24, 0.26, 0.95), CFrame = CFrame.new(0, 0.58, 0.45), Color = dark })
	PartKit.Part(model, { Name = "GripPostF", Size = Vector3.new(0.2, 0.32, 0.18), CFrame = CFrame.new(0, 0.38, 0.05), Color = dark })
	PartKit.Part(model, { Name = "GripPostB", Size = Vector3.new(0.2, 0.32, 0.18), CFrame = CFrame.new(0, 0.38, 0.85), Color = dark })
	PartKit.Cylinder(model, 0.95, 0.8, CFrame.new(0, 0, -0.55), "Z", {
		Name = "Canister",
		Material = GLASS,
		Transparency = 0.55,
		Color = Color3.fromRGB(240, 232, 214),
		CastShadow = false,
	})
	PartKit.Cylinder(model, 0.9, 0.62, CFrame.new(0, -0.06, -0.55), "Z", {
		Name = "SandFill",
		Material = Enum.Material.Sand,
		Color = SAND,
	}):SetAttribute("FillAxis", "X")
	PartKit.Cylinder(model, 0.1, 0.86, CFrame.new(0, 0, -1.04), "Z", { Name = "CapRing", Color = dark })
	PartKit.Cylinder(model, 1.25, 0.34, CFrame.new(0, -0.06, -1.7), "Z", { Name = "Nozzle", Material = METAL, Color = steel })
	PartKit.Cylinder(model, 0.14, 0.48, CFrame.new(0, -0.06, -2.3), "Z", { Name = "Mouth", Color = dark })
	PartKit.Part(model, {
		Name = "Glow",
		Size = Vector3.new(0.04, 0.1, 0.6),
		CFrame = CFrame.new(0.36, 0.12, 0.35),
		Material = NEON,
		Color = Color3.fromRGB(132, 200, 230),
		CastShadow = false,
	})
	PartKit.Part(model, { Name = "Vent", Size = Vector3.new(0.5, 0.06, 0.3), CFrame = CFrame.new(0, 0.34, 0.75), Color = dark })
	addTip(handle, Vector3.new(0, -0.06, -2.75))
	return handle
end

builders.TurbineVac = function(model)
	local yellow = Color3.fromRGB(240, 190, 60)
	local dark = Color3.fromRGB(64, 62, 66)
	local steel = Color3.fromRGB(160, 164, 170)
	local handle = PartKit.Cylinder(model, 1.25, 1.3, CFrame.new(0, 0, 0.2), "Z", {
		Name = "Handle",
		Color = yellow,
	})
	PartKit.Cylinder(model, 0.12, 1.38, CFrame.new(0, 0, -0.32), "Z", { Name = "BandF", Color = dark })
	PartKit.Cylinder(model, 0.12, 1.38, CFrame.new(0, 0, 0.62), "Z", { Name = "BandB", Color = dark })
	PartKit.Cylinder(model, 0.07, 1.36, CFrame.new(0, 0, -0.44), "Z", {
		Name = "NeonRing",
		Material = NEON,
		Color = Color3.fromRGB(120, 200, 240),
		CastShadow = false,
	})
	-- hazard stripes on top
	for index = 0, 3 do
		PartKit.Part(model, {
			Name = "Stripe",
			Size = Vector3.new(0.5, 0.05, 0.12),
			CFrame = CFrame.new(0, 0.66, -0.15 + index * 0.25) * CFrame.Angles(0, math.rad(35), 0),
			Color = dark,
		})
	end
	-- turbine housing at the back (faces the camera) with spinning fan
	PartKit.Cylinder(model, 0.4, 1.5, CFrame.new(0, 0, 1.0), "Z", { Name = "Housing", Material = METAL, Color = dark })
	local fan = Instance.new("Folder")
	fan.Name = "Fan"
	fan.Parent = model
	local hub = PartKit.Cylinder(fan, 0.12, 0.34, CFrame.new(0, 0, 1.23), "Z", { Name = "FanHub", Material = METAL, Color = steel })
	hub:SetAttribute("FanHub", true)
	for index = 0, 5 do
		PartKit.Part(fan, {
			Name = "Blade",
			Size = Vector3.new(0.14, 0.62, 0.04),
			CFrame = CFrame.new(0, 0, 1.22) * CFrame.Angles(0, 0, math.rad(index * 60)) * CFrame.new(0, 0.34, 0) * CFrame.Angles(0, math.rad(25), 0),
			Material = METAL,
			Color = steel,
		})
	end
	-- sand window on top
	PartKit.Part(model, {
		Name = "Window",
		Size = Vector3.new(0.4, 0.14, 1.0),
		CFrame = CFrame.new(-0.42, 0.55, 0.15) * CFrame.Angles(0, 0, math.rad(40)),
		Material = GLASS,
		Transparency = 0.5,
		Color = Color3.fromRGB(240, 232, 214),
		CastShadow = false,
	})
	PartKit.Part(model, {
		Name = "SandFill",
		Size = Vector3.new(0.32, 0.1, 0.94),
		CFrame = CFrame.new(-0.4, 0.53, 0.15) * CFrame.Angles(0, 0, math.rad(40)),
		Material = Enum.Material.Sand,
		Color = SAND,
	}):SetAttribute("FillAxis", "Z")
	-- nozzle
	PartKit.Cylinder(model, 1.5, 0.62, CFrame.new(0, -0.12, -1.15), "Z", { Name = "Nozzle", Material = METAL, Color = steel })
	PartKit.Cylinder(model, 0.28, 0.95, CFrame.new(0, -0.12, -2.0), "Z", { Name = "Mouth", Color = Color3.fromRGB(214, 110, 70) })
	PartKit.Cylinder(model, 0.06, 1.0, CFrame.new(0, -0.12, -2.16), "Z", { Name = "MouthLip", Color = dark })
	-- side grips
	PartKit.Part(model, { Name = "SideGrip", Size = Vector3.new(0.22, 0.22, 0.9), CFrame = CFrame.new(0.8, 0, 0.2), Color = dark })
	PartKit.Part(model, { Name = "SideGripTop", Size = Vector3.new(0.9, 0.18, 0.22), CFrame = CFrame.new(0, 0.78, 0.6), Color = dark })
	addTip(handle, Vector3.new(0, -0.12, -2.25))
	return handle
end

-- Build a tool model. anchored=true for viewmodels/displays, false for welding to a character.
function ToolModels.Build(toolId, anchored)
	local builder = builders[toolId] or builders.Spoon
	local model = Instance.new("Model")
	model.Name = toolId
	local handle = builder(model)
	PartKit.Finalize(model, handle, anchored)
	model:SetAttribute("ToolId", toolId)
	return model
end

return ToolModels
