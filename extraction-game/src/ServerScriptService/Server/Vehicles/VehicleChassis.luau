--!strict
--[[
	VehicleChassis
	Turns a GetawayCarBody built with Physics = true into a real constraint car.

	Per wheel:
	  Root ──CylindricalConstraint──▶ Knuckle ──HingeConstraint(Motor)──▶ Tire
	         (vertical slide = suspension travel,
	          rotation about vertical = steering servo on the fronts,
	          rotation locked on the rears)
	  Root ──SpringConstraint──▶ Knuckle   (stiffness/damping solved from the
	                                         real sprung mass so the car sits at
	                                         its designed ride height)

	Mass: every body part is massless; one low invisible Ballast part carries
	the weight, which puts the centre of mass near axle height (stable, still
	rolls into corners). Tires use high-weight custom friction so the tire
	material, not the road, decides grip — the driver lowers rear friction for
	handbrake drifts.

	Collision groups keep spinning/steering wheels from fighting the body.
]]

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local GetawayCarBody = require(Shared.Builders.GetawayCarBody)

export type WheelRig = {
	Name: string,
	Front: boolean,
	Tire: BasePart,
	Knuckle: BasePart,
	Slide: CylindricalConstraint,
	Spring: SpringConstraint,
	Hinge: HingeConstraint,
}

export type Rig = {
	Handles: GetawayCarBody.CarHandles,
	Wheels: { WheelRig },
	Ballast: BasePart,
	Downforce: VectorForce,
}

local VehicleChassis = {}

local V = Config.Vehicle
local SPRING_TOP = 1.6 -- spring anchor height above the wheel centre (studs)

local groupsReady = false
local function ensureGroups()
	if groupsReady then
		return
	end
	groupsReady = true
	for _, name in { "VehicleBody", "VehicleWheels" } do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(name)
		end)
	end
	PhysicsService:CollisionGroupSetCollidable("VehicleBody", "VehicleWheels", false)
	PhysicsService:CollisionGroupSetCollidable("VehicleWheels", "VehicleWheels", false)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable("VehicleWheels", "Debris", false)
	end)
end

local function attachment(parent: BasePart, name: string, cf: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = cf
	a.Parent = parent
	return a
end

-- Attachment frame whose primary axis (X) points up in the car's frame.
local UP_AXIS = CFrame.Angles(0, 0, math.rad(90))

function VehicleChassis.rig(handles: GetawayCarBody.CarHandles): Rig
	ensureGroups()
	local model = handles.Model
	local root = handles.Root

	-- Body: massless, body collision group.
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Massless = true
			d.CollisionGroup = "VehicleBody"
		end
	end

	-- Low ballast carries the mass.
	local ballast = Instance.new("Part")
	ballast.Name = "Ballast"
	ballast.Size = Vector3.new(4.2, 0.5, 12)
	ballast.CFrame = root.CFrame * CFrame.new(0, -0.9, 0)
	ballast.Transparency = 1
	ballast.CanCollide = false
	ballast.CanQuery = false
	ballast.CanTouch = false
	ballast.Massless = false
	ballast.CustomPhysicalProperties = PhysicalProperties.new(V.BallastDensity, 0.3, 0)
	ballast.CollisionGroup = "VehicleBody"
	ballast.Parent = model
	local ballastWeld = Instance.new("WeldConstraint")
	ballastWeld.Part0 = root
	ballastWeld.Part1 = ballast
	ballastWeld.Parent = ballast

	local wheels: { WheelRig } = {}
	for name, wheelModel in handles.Wheels do
		local tire = wheelModel.PrimaryPart
		assert(tire, "[VehicleChassis] wheel without Tire")
		local front = string.sub(name, 1, 1) == "F"

		for _, d in wheelModel:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = "VehicleWheels"
				d.Massless = d ~= tire
				d.CanCollide = d == tire
			end
		end
		tire.Massless = false
		tire.CustomPhysicalProperties = PhysicalProperties.new(0.7, V.TireFriction, 0, 100, 100)

		-- Wheel centre in the root's frame (car frame, root sits at y 1.8).
		local centre = root.CFrame:ToObjectSpace(tire.CFrame).Position

		local knuckle = Instance.new("Part")
		knuckle.Name = "Knuckle_" .. name
		knuckle.Size = Vector3.new(0.4, 0.4, 0.4)
		knuckle.CFrame = root.CFrame * CFrame.new(centre)
		knuckle.Transparency = 1
		knuckle.CanCollide = false
		knuckle.CanQuery = false
		knuckle.CanTouch = false
		knuckle.CustomPhysicalProperties = PhysicalProperties.new(2, 0.3, 0)
		knuckle.CollisionGroup = "VehicleWheels"
		knuckle.Parent = wheelModel

		-- Suspension slide + steering
		local mount = attachment(root, "Mount_" .. name, CFrame.new(centre) * UP_AXIS)
		local knuckleAxis = attachment(knuckle, "SlideAxis", UP_AXIS)
		local slide = Instance.new("CylindricalConstraint")
		slide.Name = "Suspension"
		slide.Attachment0 = mount
		slide.Attachment1 = knuckleAxis
		slide.LimitsEnabled = true
		slide.LowerLimit = -V.SuspensionTravel
		slide.UpperLimit = V.SuspensionTravel
		slide.Restitution = 0
		if front then
			slide.AngularActuatorType = Enum.ActuatorType.Servo
			slide.ServoMaxTorque = 1e6
			slide.AngularSpeed = 8
			slide.AngularResponsiveness = 45
			slide.TargetAngle = 0
		else
			slide.AngularLimitsEnabled = true
			slide.LowerAngle = 0
			slide.UpperAngle = 0
		end
		slide.Parent = knuckle

		-- Spring (anchored above the wheel)
		local springTop = attachment(root, "SpringTop_" .. name, CFrame.new(centre + Vector3.new(0, SPRING_TOP, 0)))
		local springBottom = attachment(knuckle, "SpringBottom", CFrame.identity)
		local spring = Instance.new("SpringConstraint")
		spring.Name = "Spring"
		spring.Attachment0 = springTop
		spring.Attachment1 = springBottom
		spring.Visible = false
		spring.Parent = knuckle

		-- Axle motor
		local axleKnuckle = attachment(knuckle, "Axle", CFrame.identity)
		local axleTire = attachment(tire, "Axle", CFrame.identity)
		local hinge = Instance.new("HingeConstraint")
		hinge.Name = "Axle"
		hinge.Attachment0 = axleKnuckle
		hinge.Attachment1 = axleTire
		hinge.ActuatorType = Enum.ActuatorType.Motor
		hinge.MotorMaxAcceleration = math.huge
		hinge.MotorMaxTorque = 0
		hinge.AngularVelocity = 0
		hinge.Parent = knuckle

		table.insert(wheels, {
			Name = name,
			Front = front,
			Tire = tire,
			Knuckle = knuckle,
			Slide = slide,
			Spring = spring,
			Hinge = hinge,
		})
	end

	-- Solve spring rates from the real sprung mass so the car rests at its design height.
	-- Everything on the body is massless except the ballast, so its mass IS the
	-- sprung mass (GetMass works before the model is parented to Workspace).
	local sprungMass = ballast:GetMass()
	local cornerMass = sprungMass / 4
	local omega = 2 * math.pi * V.SuspensionFrequency
	local stiffness = cornerMass * omega * omega
	local damping = 2 * V.SuspensionDamping * math.sqrt(stiffness * cornerMass)
	local cornerWeight = cornerMass * Workspace.Gravity
	for _, wheel in wheels do
		wheel.Spring.Stiffness = stiffness
		wheel.Spring.Damping = damping
		wheel.Spring.FreeLength = SPRING_TOP + cornerWeight / stiffness
		wheel.Spring.LimitsEnabled = false
	end

	-- Speed-squared downforce, updated by the driver.
	local forceAttachment = attachment(root, "DownforcePoint", CFrame.new(0, -0.9, 0))
	local downforce = Instance.new("VectorForce")
	downforce.Name = "Downforce"
	downforce.Attachment0 = forceAttachment
	downforce.RelativeTo = Enum.ActuatorRelativeTo.World
	downforce.ApplyAtCenterOfMass = true
	downforce.Force = Vector3.zero
	downforce.Parent = root

	model:SetAttribute("SprungMass", sprungMass)
	return {
		Handles = handles,
		Wheels = wheels,
		Ballast = ballast,
		Downforce = downforce,
	}
end

-- Parking brake / no driver: hold every wheel still.
function VehicleChassis.park(rig: Rig)
	for _, wheel in rig.Wheels do
		wheel.Hinge.AngularVelocity = 0
		wheel.Hinge.MotorMaxTorque = Config.Vehicle.HandbrakeTorque
		if wheel.Front then
			wheel.Slide.TargetAngle = 0
		end
	end
	rig.Downforce.Force = Vector3.zero
end

return VehicleChassis
