-- VehicleModels (ModuleScript) - ReplicatedStorage/Sandsweep/VehicleModels
-- Procedural low-poly heavy machinery: Mini Dump Truck, Bulldozer, Mega Excavator.
-- Vehicles face -Z. The invisible "Chassis" is the heavy root; four invisible
-- low-friction ball "Skids" are the only parts touching the ground, so the
-- vehicles glide over craters instead of snagging. Moving joints are Welds:
--   BedHinge (truck), BoomJoint / StickJoint / BucketJoint (excavator), WheelWeld (all wheels & rollers).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PartKit = require(ReplicatedStorage:WaitForChild("Sandsweep"):WaitForChild("PartKit"))

local VehicleModels = {}

local YELLOW = Color3.fromRGB(242, 186, 48)
local DARK = Color3.fromRGB(58, 58, 62)
local STEEL = Color3.fromRGB(150, 154, 160)
local TIRE = Color3.fromRGB(28, 28, 30)
local GLASS = Color3.fromRGB(170, 210, 230)
local SAND = Color3.fromRGB(232, 196, 128)

local GROUND_Y = -2.0 -- skid bottoms in model space

local function P(parent, props)
	return PartKit.Part(parent, props)
end

local function group(model, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = model
	return folder
end

local function wheel(parent, position, diameter, width, hubColor)
	local tire = PartKit.Cylinder(parent, width, diameter, CFrame.new(position), "X", { Name = "Wheel", Color = TIRE, Material = Enum.Material.SmoothPlastic })
	local hub = PartKit.Cylinder(parent, width + 0.06, diameter * 0.45, CFrame.new(position), "X", { Name = "Hub", Color = hubColor or YELLOW })
	tire:SetAttribute("Spin", true)
	tire:SetAttribute("Radius", diameter / 2)
	hub:SetAttribute("Spin", true)
	hub:SetAttribute("Radius", diameter / 2)
	return tire, hub
end

local function skids(model, halfX, halfZ)
	for _, x in ipairs({ -halfX, halfX }) do
		for _, z in ipairs({ -halfZ, halfZ }) do
			PartKit.Ball(model, 2.4, CFrame.new(x, GROUND_Y + 1.2, z), {
				Name = "Skid",
				Transparency = 1,
				CanCollide = true,
				CastShadow = false,
				CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 1),
			})
		end
	end
end

local function cab(parent, center, width, depth, floorY, roofY, color)
	-- open cab: floor, 4 pillars, roof, back wall, windshield, so the driver is visible
	local halfW, halfD = width / 2, depth / 2
	P(parent, { Name = "CabFloor", Size = Vector3.new(width, 0.4, depth), CFrame = CFrame.new(center.X, floorY, center.Z), Color = DARK })
	for _, x in ipairs({ -halfW + 0.2, halfW - 0.2 }) do
		for _, z in ipairs({ -halfD + 0.2, halfD - 0.2 }) do
			P(parent, { Name = "Pillar", Size = Vector3.new(0.35, roofY - floorY, 0.35), CFrame = CFrame.new(center.X + x, (floorY + roofY) / 2, center.Z + z), Color = color })
		end
	end
	P(parent, { Name = "Roof", Size = Vector3.new(width + 0.3, 0.35, depth + 0.3), CFrame = CFrame.new(center.X, roofY, center.Z), Color = color })
	P(parent, { Name = "CabBack", Size = Vector3.new(width, (roofY - floorY) * 0.55, 0.25), CFrame = CFrame.new(center.X, floorY + (roofY - floorY) * 0.3, center.Z + halfD - 0.15), Color = color })
	P(parent, {
		Name = "Windshield",
		Size = Vector3.new(width - 0.4, (roofY - floorY) * 0.55, 0.12),
		CFrame = CFrame.new(center.X, floorY + (roofY - floorY) * 0.62, center.Z - halfD + 0.2),
		Material = Enum.Material.Glass,
		Transparency = 0.55,
		Color = GLASS,
		CastShadow = false,
	})
	P(parent, { Name = "RoofLight", Size = Vector3.new(0.6, 0.3, 0.6), CFrame = CFrame.new(center.X, roofY + 0.3, center.Z), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 150, 40), CastShadow = false })
end

local function seat(parent, position)
	local driverSeat = Instance.new("VehicleSeat")
	driverSeat.Name = "DriverSeat"
	driverSeat.Size = Vector3.new(2, 0.5, 2)
	driverSeat.CFrame = CFrame.new(position)
	driverSeat.Color = DARK
	driverSeat.Material = Enum.Material.Fabric
	driverSeat.TopSurface = Enum.SurfaceType.Smooth
	driverSeat.BottomSurface = Enum.SurfaceType.Smooth
	driverSeat.MaxSpeed = 0
	driverSeat.Torque = 0
	driverSeat.TurnSpeed = 0
	driverSeat.HeadsUpDisplay = false
	driverSeat.CanCollide = false
	driverSeat.CastShadow = false
	driverSeat.Parent = parent
	return driverSeat
end

local function emitter(parent, name, position, direction, rate)
	local holder = P(parent, { Name = name .. "Part", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(-math.pi / 2, 0, 0), Transparency = 1, CastShadow = false })
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	local particles = Instance.new("ParticleEmitter")
	particles.Name = name
	particles.Texture = "rbxasset://textures/particles/smoke_main.dds"
	particles.Color = ColorSequence.new(Color3.fromRGB(244, 218, 164), SAND)
	particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
	particles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	particles.Lifetime = NumberRange.new(0.6, 1.1)
	particles.Speed = NumberRange.new(6, 10)
	particles.SpreadAngle = Vector2.new(20, 20)
	particles.Acceleration = Vector3.new(0, -40, 0)
	particles.Rate = rate
	particles.EmissionDirection = Enum.NormalId.Top
	particles.LightInfluence = 1
	particles.Enabled = false
	particles.Parent = attachment
	return particles
end

local function exhaust(parent, position)
	PartKit.Cylinder(parent, 2.4, 0.4, CFrame.new(position), "Y", { Name = "Exhaust", Material = Enum.Material.Metal, Color = DARK })
	local cap = P(parent, { Name = "ExhaustTip", Size = Vector3.new(0.3, 0.3, 0.3), CFrame = CFrame.new(position + Vector3.new(0, 1.3, 0)), Transparency = 1, CastShadow = false })
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(90, 86, 84)
	smoke.Opacity = 0.08
	smoke.RiseVelocity = 3
	smoke.Size = 1
	smoke.Parent = cap
end

local function tracks(parent, halfX, length, height)
	for _, side in ipairs({ -1, 1 }) do
		P(parent, { Name = "Track", Size = Vector3.new(1.9, height, length), CFrame = CFrame.new(side * halfX, GROUND_Y + height / 2 + 0.05, 0), Color = DARK, Material = Enum.Material.Slate })
		for i = 0, 3 do
			local z = -length / 2 + 1.2 + i * (length - 2.4) / 3
			wheel(parent, Vector3.new(side * (halfX + 0.05), GROUND_Y + height / 2 + 0.05, z), height * 0.62, 2.0, STEEL)
		end
	end
end

--------------------------------------------------------------------------
-- BUILDERS (return chassis; fill `joints` with hinge specs)
--------------------------------------------------------------------------
local builders = {}

builders.DumpTruck = function(model, joints)
	local chassis = P(model, { Name = "Chassis", Size = Vector3.new(6, 0.8, 13), CFrame = CFrame.new(0, 0, 0), Transparency = 1, CastShadow = false })
	local body = group(model, "Body")
	P(body, { Name = "Hull", Size = Vector3.new(5.4, 1, 12.6), CFrame = CFrame.new(0, 0.1, 0), Color = DARK, CanCollide = true, CanQuery = true })
	P(body, { Name = "Hood", Size = Vector3.new(5.8, 1.6, 2.6), CFrame = CFrame.new(0, 1.3, -5.2), Color = YELLOW, CanCollide = true, CanQuery = true })
	P(body, { Name = "Grille", Size = Vector3.new(4, 1.0, 0.2), CFrame = CFrame.new(0, 1.2, -6.55), Color = DARK })
	for _, x in ipairs({ -2.2, 2.2 }) do
		P(body, { Name = "Headlight", Size = Vector3.new(0.8, 0.5, 0.15), CFrame = CFrame.new(x, 1.5, -6.55), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 244, 210), CastShadow = false })
	end
	P(body, { Name = "Bumper", Size = Vector3.new(6.2, 0.5, 0.5), CFrame = CFrame.new(0, 0.4, -6.6), Material = Enum.Material.Metal, Color = STEEL })
	cab(body, Vector3.new(0, 0, -2.6), 5.8, 2.8, 1.1, 6.0, YELLOW)
	seat(body, Vector3.new(0, 1.55, -2.5))
	exhaust(body, Vector3.new(2.7, 3.6, -1.1))
	for _, z in ipairs({ -4.3, 3.6 }) do
		for _, x in ipairs({ -2.95, 2.95 }) do
			wheel(body, Vector3.new(x, -0.4, z), 3.2, 1.2)
		end
	end

	-- tilting bed (hinged at its rear-bottom edge)
	local bed = group(model, "Bed")
	local bedBase = P(bed, { Name = "BedBase", Size = Vector3.new(6, 0.4, 7.6), CFrame = CFrame.new(0, 1.0, 2.6), Color = YELLOW })
	P(bed, { Name = "BedSide", Size = Vector3.new(0.3, 2.4, 7.6), CFrame = CFrame.new(-2.95, 2.3, 2.6), Color = YELLOW })
	P(bed, { Name = "BedSide", Size = Vector3.new(0.3, 2.4, 7.6), CFrame = CFrame.new(2.95, 2.3, 2.6), Color = YELLOW })
	P(bed, { Name = "BedFront", Size = Vector3.new(6, 3.0, 0.3), CFrame = CFrame.new(0, 2.5, -1.15), Color = YELLOW })
	P(bed, { Name = "BedGate", Size = Vector3.new(6, 2.2, 0.3), CFrame = CFrame.new(0, 2.2, 6.25), Color = Color3.fromRGB(222, 168, 40) })
	P(bed, { Name = "SandFill", Size = Vector3.new(5.5, 2.0, 7.0), CFrame = CFrame.new(0, 2.2, 2.6), Material = Enum.Material.Sand, Color = SAND, Transparency = 1 })
	emitter(bed, "Pour", Vector3.new(0, 1.4, 6.6), Vector3.new(0, -0.6, 1), 60)
	joints.Bed = { Folder = bed, Root = bedBase, Hinge = CFrame.new(0, 0.8, 6.4), Name = "BedHinge" }

	skids(model, 2.2, 4.6)
	return chassis
end

builders.Bulldozer = function(model, _joints)
	local chassis = P(model, { Name = "Chassis", Size = Vector3.new(7, 0.8, 9), CFrame = CFrame.new(0, 0, 0), Transparency = 1, CastShadow = false })
	local body = group(model, "Body")
	tracks(body, 3.4, 9.6, 2.4)
	P(body, { Name = "Hull", Size = Vector3.new(4.8, 2.4, 6.4), CFrame = CFrame.new(0, 1.4, 1.2), Color = YELLOW, CanCollide = true, CanQuery = true })
	P(body, { Name = "Grill", Size = Vector3.new(3.4, 1.4, 0.2), CFrame = CFrame.new(0, 1.6, -2.05), Color = DARK })
	P(body, { Name = "Hopper", Size = Vector3.new(4.6, 1.2, 3.4), CFrame = CFrame.new(0, 3.2, 2.8), Color = DARK })
	P(body, { Name = "SandFill", Size = Vector3.new(4.2, 1.0, 3.0), CFrame = CFrame.new(0, 3.35, 2.8), Material = Enum.Material.Sand, Color = SAND, Transparency = 1 })
	cab(body, Vector3.new(0, 0, -0.6), 4.4, 3.6, 2.8, 7.4, YELLOW)
	seat(body, Vector3.new(0, 3.25, -0.4))
	exhaust(body, Vector3.new(1.8, 4.2, 2.6))
	emitter(body, "Pour", Vector3.new(0, 3.4, 4.6), Vector3.new(0, -0.4, 1), 50)

	-- blade (static) with push arms
	P(body, { Name = "Blade", Size = Vector3.new(10, 3.0, 0.5), CFrame = CFrame.new(0, GROUND_Y + 1.5, -6.4) * CFrame.Angles(math.rad(-8), 0, 0), Material = Enum.Material.Metal, Color = STEEL })
	P(body, { Name = "BladeLip", Size = Vector3.new(10.2, 0.3, 0.8), CFrame = CFrame.new(0, GROUND_Y + 3.1, -6.2), Material = Enum.Material.Metal, Color = YELLOW })
	P(body, { Name = "BladeEdge", Size = Vector3.new(10, 0.25, 0.7), CFrame = CFrame.new(0, GROUND_Y + 0.15, -6.7), Material = Enum.Material.Metal, Color = DARK })
	for _, x in ipairs({ -3.4, 3.4 }) do
		P(body, { Name = "PushArm", Size = Vector3.new(0.5, 0.6, 4.2), CFrame = CFrame.new(x, GROUND_Y + 1.6, -4.4) * CFrame.Angles(math.rad(-10), 0, 0), Color = YELLOW })
	end
	emitter(body, "BladeSpray", Vector3.new(0, GROUND_Y + 2.6, -7), Vector3.new(0, 1, -0.4), 70)
	local bladeMarker = Instance.new("Attachment")
	bladeMarker.Name = "BladeCut"
	bladeMarker.Position = Vector3.new(0, GROUND_Y + 0.4, -6.9)
	bladeMarker.Parent = chassis

	skids(model, 3.0, 3.8)
	return chassis
end

builders.Excavator = function(model, joints)
	local chassis = P(model, { Name = "Chassis", Size = Vector3.new(8, 0.8, 9), CFrame = CFrame.new(0, 0, 0), Transparency = 1, CastShadow = false })
	local body = group(model, "Body")
	tracks(body, 4.0, 10.4, 2.6)
	PartKit.Cylinder(body, 1.0, 6, CFrame.new(0, 0.9, 0.6), "Y", { Name = "TurretRing", Color = DARK })
	P(body, { Name = "Hull", Size = Vector3.new(7, 3, 7), CFrame = CFrame.new(0, 2.8, 1.0), Color = YELLOW, CanCollide = true, CanQuery = true })
	P(body, { Name = "Counterweight", Size = Vector3.new(7.2, 2.2, 1.8), CFrame = CFrame.new(0, 2.4, 5.2), Color = DARK })
	P(body, { Name = "Hopper", Size = Vector3.new(5, 1.2, 3.2), CFrame = CFrame.new(0.6, 4.9, 2.4), Color = DARK })
	P(body, { Name = "SandFill", Size = Vector3.new(4.6, 1.0, 2.8), CFrame = CFrame.new(0.6, 5.05, 2.4), Material = Enum.Material.Sand, Color = SAND, Transparency = 1 })
	cab(body, Vector3.new(-2.0, 0, -1.4), 2.8, 3.2, 4.4, 8.6, YELLOW)
	seat(body, Vector3.new(-2.0, 4.85, -1.2))
	exhaust(body, Vector3.new(2.6, 5.2, 3.6))
	emitter(body, "Pour", Vector3.new(0.6, 5.2, 4.4), Vector3.new(0, -0.4, 1), 60)

	-- articulated arm (boom -> stick -> bucket), each hinged with an animated Weld
	local p0 = Vector3.new(1.4, 4.0, -2.4)
	local p1 = Vector3.new(1.4, 9.0, -10.5)
	local p2 = Vector3.new(1.4, 3.0, -14.5)

	local boom = group(model, "Boom")
	local boomRoot = P(boom, { Name = "BoomBeam", Size = Vector3.new(1.3, 1.3, (p1 - p0).Magnitude), CFrame = CFrame.lookAt((p0 + p1) / 2, p1), Color = YELLOW })
	PartKit.Cylinder(boom, 1.6, 1.1, CFrame.new(p0), "X", { Name = "BoomPin", Material = Enum.Material.Metal, Color = DARK })
	PartKit.Cylinder(boom, 6, 0.4, CFrame.lookAt((p0 + p1) / 2 + Vector3.new(0, -0.9, 0), p1 + Vector3.new(0, -0.9, 0)), "Z", { Name = "Piston", Material = Enum.Material.Metal, Color = STEEL })
	joints.Boom = { Folder = boom, Root = boomRoot, Hinge = CFrame.new(p0), Name = "BoomJoint", Parent = "Chassis" }

	local stick = group(model, "Stick")
	local stickRoot = P(stick, { Name = "StickBeam", Size = Vector3.new(1.0, 1.0, (p2 - p1).Magnitude), CFrame = CFrame.lookAt((p1 + p2) / 2, p2), Color = YELLOW })
	PartKit.Cylinder(stick, 1.4, 0.9, CFrame.new(p1), "X", { Name = "StickPin", Material = Enum.Material.Metal, Color = DARK })
	joints.Stick = { Folder = stick, Root = stickRoot, Hinge = CFrame.new(p1), Name = "StickJoint", Parent = "Boom" }

	local bucket = group(model, "Bucket")
	local bucketRoot = P(bucket, { Name = "BucketBack", Size = Vector3.new(3.2, 2.2, 0.4), CFrame = CFrame.new(p2 + Vector3.new(0, -0.9, -0.4)), Material = Enum.Material.Metal, Color = DARK })
	P(bucket, { Name = "BucketFloor", Size = Vector3.new(3.2, 0.4, 2.2), CFrame = CFrame.new(p2 + Vector3.new(0, -2.0, -1.4)), Material = Enum.Material.Metal, Color = DARK })
	P(bucket, { Name = "BucketSide", Size = Vector3.new(0.3, 2.0, 2.2), CFrame = CFrame.new(p2 + Vector3.new(-1.55, -1.1, -1.4)), Material = Enum.Material.Metal, Color = DARK })
	P(bucket, { Name = "BucketSide", Size = Vector3.new(0.3, 2.0, 2.2), CFrame = CFrame.new(p2 + Vector3.new(1.55, -1.1, -1.4)), Material = Enum.Material.Metal, Color = DARK })
	P(bucket, { Name = "BucketSand", Size = Vector3.new(2.8, 1.2, 1.8), CFrame = CFrame.new(p2 + Vector3.new(0, -1.3, -1.4)), Material = Enum.Material.Sand, Color = SAND, Transparency = 1 })
	for i = 0, 4 do
		P(bucket, {
			ClassName = "WedgePart",
			Name = "Tooth",
			Size = Vector3.new(0.35, 0.3, 0.7),
			CFrame = CFrame.new(p2 + Vector3.new(-1.3 + i * 0.65, -2.05, -2.8)) * CFrame.Angles(0, math.rad(180), 0),
			Material = Enum.Material.Metal,
			Color = STEEL,
		})
	end
	joints.Bucket = { Folder = bucket, Root = bucketRoot, Hinge = CFrame.new(p2), Name = "BucketJoint", Parent = "Stick" }

	skids(model, 3.6, 4.0)
	return chassis
end

--------------------------------------------------------------------------
-- ASSEMBLY
--------------------------------------------------------------------------
local function weldTo(part, root)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local function hingeWeld(name, part0, part1, hinge)
	local weld = Instance.new("Weld")
	weld.Name = name
	weld.Part0 = part0
	weld.Part1 = part1
	weld.C0 = part0.CFrame:ToObjectSpace(hinge)
	weld.C1 = part1.CFrame:ToObjectSpace(hinge)
	weld.Parent = part1
	return weld
end

-- Build a vehicle. display=true returns an anchored, inert copy for UI viewports.
function VehicleModels.Build(vehicleId, display)
	local builder = builders[vehicleId]
	assert(builder, "Unknown vehicle: " .. tostring(vehicleId))
	local model = Instance.new("Model")
	model.Name = vehicleId
	local joints = {}
	local chassis = builder(model, joints)
	model.PrimaryPart = chassis
	chassis.PivotOffset = CFrame.identity

	local jointed = {}
	for _, spec in pairs(joints) do
		jointed[spec.Folder] = spec
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = display == true
			if descendant ~= chassis then
				descendant.Massless = true
			end
		end
	end
	chassis.CustomPhysicalProperties = PhysicalProperties.new(30, 0.3, 0, 1, 1)

	if not display then
		local roots = { Chassis = chassis }
		-- order: boom before stick before bucket
		local ordered = {}
		for _, key in ipairs({ "Bed", "Boom", "Stick", "Bucket" }) do
			if joints[key] then
				table.insert(ordered, { Key = key, Spec = joints[key] })
			end
		end
		for _, entry in ipairs(ordered) do
			local spec = entry.Spec
			for _, part in ipairs(spec.Folder:GetDescendants()) do
				if part:IsA("BasePart") and part ~= spec.Root then
					weldTo(part, spec.Root)
				end
			end
			local parentPart = roots[spec.Parent or "Chassis"] or chassis
			hingeWeld(spec.Name, parentPart, spec.Root, spec.Hinge)
			roots[entry.Key] = spec.Root
		end
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part ~= chassis then
				local inJointGroup = false
				for folder in pairs(jointed) do
					if part:IsDescendantOf(folder) then
						inJointGroup = true
						break
					end
				end
				if not inJointGroup then
					if part:GetAttribute("Spin") then
						hingeWeld("WheelWeld", chassis, part, part.CFrame)
					else
						weldTo(part, chassis)
					end
				end
			end
		end
	end
	model:SetAttribute("VehicleId", vehicleId)
	return model
end

return VehicleModels
