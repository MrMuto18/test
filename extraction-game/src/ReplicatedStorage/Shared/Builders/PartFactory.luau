--!strict
--[[
	PartFactory
	Every procedural part in the game goes through here so surfaces, shadow
	casting and collision defaults stay consistent across builders.
]]

export type Style = {
	Color: Color3,
	Material: Enum.Material,
	Reflectance: number?,
	Transparency: number?,
	CastShadow: boolean?,
}

export type Spec = {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Style: Style,
	Class: ("Part" | "WedgePart" | "CornerWedgePart")?,
	Shape: Enum.PartType?,
	CanCollide: boolean?,
	Anchored: boolean?,
	Parent: Instance?,
}

local PartFactory = {}

-- Rotations that turn a Cylinder (axis = local X) onto other axes.
PartFactory.AxisY = CFrame.Angles(0, 0, math.rad(90))
PartFactory.AxisZ = CFrame.Angles(0, math.rad(90), 0)

-- Resolves newer materials by name and falls back on older engines.
function PartFactory.material(name: string, fallback: Enum.Material): Enum.Material
	local ok, result = pcall(function(): any
		return (Enum.Material :: any)[name]
	end)
	if ok and typeof(result) == "EnumItem" then
		return result :: Enum.Material
	end
	return fallback
end

function PartFactory.style(
	color: Color3,
	material: Enum.Material,
	reflectance: number?,
	transparency: number?,
	castShadow: boolean?
): Style
	return {
		Color = color,
		Material = material,
		Reflectance = reflectance,
		Transparency = transparency,
		CastShadow = castShadow,
	}
end

function PartFactory.make(spec: Spec): BasePart
	local part: BasePart
	if spec.Class == "WedgePart" then
		part = Instance.new("WedgePart")
	elseif spec.Class == "CornerWedgePart" then
		part = Instance.new("CornerWedgePart")
	else
		local basic = Instance.new("Part")
		if spec.Shape then
			basic.Shape = spec.Shape
		end
		part = basic
	end

	local style = spec.Style
	part.Name = spec.Name
	part.Size = spec.Size
	part.CFrame = spec.CFrame
	part.Color = style.Color
	part.Material = style.Material
	part.Reflectance = style.Reflectance or 0
	part.Transparency = style.Transparency or 0
	part.CastShadow = if style.CastShadow == nil then true else style.CastShadow
	part.Anchored = if spec.Anchored == nil then true else spec.Anchored
	part.CanCollide = spec.CanCollide == true
	-- Invisible helpers (light emitters, rigs, roots) never block raycasts.
	part.CanQuery = part.CanCollide or (style.Transparency or 0) < 1
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = spec.Parent
	return part
end

function PartFactory.weld(part0: BasePart, part1: BasePart): WeldConstraint
	local weld = Instance.new("WeldConstraint")
	weld.Name = "Weld_" .. part1.Name
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part1
	return weld
end

-- Thin straight segment between two world points (cables, rails, braces).
function PartFactory.segment(
	name: string,
	from: Vector3,
	to: Vector3,
	thickness: number,
	style: Style,
	parent: Instance
): BasePart
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	return PartFactory.make({
		Name = name,
		Size = Vector3.new(thickness, thickness, math.max(length, 0.05)),
		CFrame = CFrame.lookAt(mid, to),
		Style = style,
		Parent = parent,
	})
end

function PartFactory.folder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

return PartFactory
