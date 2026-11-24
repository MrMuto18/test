--!strict
--[[
	LootBagBuilder
	Heavy duffel loot bag (~20 parts): padded body, rounded end caps, zipper
	track with pull, carry handles, shoulder strap, side pocket, value tag.

	Local space: centre of the bag, long axis = Z, up = +Y.
	"Body" is the PrimaryPart; everything else is welded to it.
	scale < 1 builds the miniature used for trunk cargo.
]]

local PartFactory = require(script.Parent.PartFactory)

export type BagHandles = {
	Model: Model,
	Body: BasePart,
}

local LootBagBuilder = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local CANVAS = PartFactory.style(rgb(30, 32, 30), Enum.Material.Fabric)
local CANVAS_DARK = PartFactory.style(rgb(20, 21, 20), Enum.Material.Fabric)
local WEBBING = PartFactory.style(rgb(14, 14, 14), Enum.Material.Fabric)
local METAL = PartFactory.style(rgb(150, 150, 150), Enum.Material.Metal, 0.2)
local TAG = PartFactory.style(rgb(220, 170, 60), Enum.Material.SmoothPlastic)

function LootBagBuilder.build(origin: CFrame, scale: number?, anchored: boolean?): BagHandles
	local k = scale or 1
	local model = Instance.new("Model")
	model.Name = "LootBag"

	local body: BasePart
	local function add(name: string, size: Vector3, offset: CFrame, style: PartFactory.Style, shape: Enum.PartType?, collide: boolean?): BasePart
		local cf = origin * (offset - offset.Position + offset.Position * k)
		local part = PartFactory.make({
			Name = name,
			Size = size * k,
			CFrame = cf,
			Style = style,
			Shape = shape,
			CanCollide = collide == true,
			Anchored = false,
			Parent = model,
		})
		if body then
			part.Massless = true
			PartFactory.weld(body, part)
		end
		return part
	end

	body = add("Body", Vector3.new(1.5, 1.0, 2.3), CFrame.new(), CANVAS, nil, true)
	body.Anchored = anchored == true
	model.PrimaryPart = body

	local axisZ = PartFactory.AxisZ
	add("EndCapFront", Vector3.new(0.16, 1.08, 1.08), CFrame.new(0, 0, -1.15) * axisZ, CANVAS_DARK, Enum.PartType.Cylinder)
	add("EndCapBack", Vector3.new(0.16, 1.08, 1.08), CFrame.new(0, 0, 1.15) * axisZ, CANVAS_DARK, Enum.PartType.Cylinder)
	add("TopPanel", Vector3.new(1.3, 0.1, 2.2), CFrame.new(0, 0.5, 0), CANVAS_DARK)
	add("ZipperTrack", Vector3.new(0.06, 0.04, 2.15), CFrame.new(0, 0.56, 0), WEBBING)
	add("ZipperPull", Vector3.new(0.08, 0.05, 0.16), CFrame.new(0.05, 0.59, -0.6), METAL)
	for _, z in { -0.55, 0.55 } do
		add("StrapWrap", Vector3.new(1.56, 1.06, 0.12), CFrame.new(0, 0, z), WEBBING)
		add("HandleL", Vector3.new(0.08, 0.32, 0.08), CFrame.new(-0.18, 0.68, z), WEBBING)
		add("HandleR", Vector3.new(0.08, 0.32, 0.08), CFrame.new(0.18, 0.68, z), WEBBING)
	end
	add("HandleGrip", Vector3.new(0.44, 0.1, 1.2), CFrame.new(0, 0.86, 0), WEBBING)
	add("ShoulderStrap", Vector3.new(0.06, 0.12, 2.0), CFrame.new(0.78, 0.15, 0) * CFrame.Angles(0, 0, math.rad(-10)), WEBBING)
	add("SidePocket", Vector3.new(0.14, 0.55, 0.9), CFrame.new(-0.78, -0.05, 0.2), CANVAS_DARK)
	add("PocketZip", Vector3.new(0.16, 0.03, 0.85), CFrame.new(-0.79, 0.2, 0.2), WEBBING)
	add("BaseSkid", Vector3.new(1.4, 0.06, 2.1), CFrame.new(0, -0.5, 0), WEBBING)
	add("ValueTag", Vector3.new(0.02, 0.22, 0.16), CFrame.new(0.8, 0.25, -0.75), TAG)
	add("TagRing", Vector3.new(0.05, 0.05, 0.05), CFrame.new(0.79, 0.4, -0.75), METAL)

	model:SetAttribute("LootBag", true)
	return { Model = model, Body = body }
end

return LootBagBuilder
