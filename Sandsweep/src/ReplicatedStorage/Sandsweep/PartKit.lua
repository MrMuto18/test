-- PartKit (ModuleScript) - ReplicatedStorage/Sandsweep/PartKit
-- Tiny procedural-geometry toolkit used by the tool, relic and world builders.

local PartKit = {}

local DEFAULTS = {
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	CastShadow = true,
	Material = Enum.Material.SmoothPlastic,
	Color = Color3.fromRGB(200, 200, 200),
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
}

local SPECIAL = {
	ClassName = true,
	Mesh = true,
	MeshScale = true,
	Parent = true,
}

-- PartKit.Part(parent, { Size=, CFrame=, Color=, Material=, Shape=, Mesh=, ... })
function PartKit.Part(parent, props)
	local part = Instance.new(props.ClassName or "Part")
	for key, value in pairs(DEFAULTS) do
		part[key] = value
	end
	for key, value in pairs(props) do
		if not SPECIAL[key] then
			part[key] = value
		end
	end
	if props.Mesh then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = props.Mesh
		mesh.Scale = props.MeshScale or Vector3.one
		mesh.Parent = part
	end
	part.Parent = parent
	return part
end

-- Cylinder whose length runs along the given local axis ("X", "Y" or "Z").
function PartKit.Cylinder(parent, length, diameter, cframe, axis, props)
	props = props or {}
	local rotation = CFrame.identity
	if axis == "Y" then
		rotation = CFrame.Angles(0, 0, math.rad(90))
	elseif axis == "Z" then
		rotation = CFrame.Angles(0, math.rad(90), 0)
	end
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(length, diameter, diameter)
	props.CFrame = cframe * rotation
	return PartKit.Part(parent, props)
end

-- Ellipsoid (sphere mesh stretched to `size`).
function PartKit.Ellipsoid(parent, size, cframe, props)
	props = props or {}
	props.Size = size
	props.CFrame = cframe
	props.Mesh = Enum.MeshType.Sphere
	return PartKit.Part(parent, props)
end

function PartKit.Ball(parent, diameter, cframe, props)
	props = props or {}
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(diameter, diameter, diameter)
	props.CFrame = cframe
	return PartKit.Part(parent, props)
end

-- Make a model ready for use. anchored=false welds all parts to the primary part.
-- The model's pivot is the origin it was designed around (not the primary part's own frame).
function PartKit.Finalize(model, primaryPart, anchored)
	model.PrimaryPart = primaryPart
	primaryPart.PivotOffset = primaryPart.CFrame:Inverse()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
			descendant.Massless = true
			if not anchored and descendant ~= primaryPart then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primaryPart
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
	return model
end

function PartKit.SetCollision(model, canCollide, canQuery, canTouch)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = canCollide
			descendant.CanQuery = canQuery
			descendant.CanTouch = canTouch
		end
	end
end

function PartKit.SetCastShadow(model, castShadow)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CastShadow = castShadow
		end
	end
end

return PartKit
