--!strict
--[[
	VehicleController
	Local player in a car. The server gives the driver network ownership, so
	all physics control happens here with zero input lag:

	  • W/S (or triggers) from the VehicleSeat: throttle, brake, reverse
	  • RWD motor torque with a falling torque curve and engine braking
	  • speed-sensitive steering on the front servos (smoothed input)
	  • Space / X handbrake: rear wheels lock + rear grip drops → drift
	  • speed² downforce for stability
	  • simulated 5-speed gearbox → RPM for audio/HUD, shift torque cut,
	    backfires on hard upshifts and throttle lift-off
	  • L lights · H hazards · U underglow · F / Y exit
	  • state streamed to the server (unreliable) so everyone sees brake
	    lights, hears the engine and sees backfires

	Passengers get the chase camera and the exit key only.
]]

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Trove = require(Shared.Trove)

local Controllers = script.Parent
local AudioController = require(Controllers.AudioController)
local MovementController = require(Controllers.MovementController)
local TacticalCamera = require(Controllers.TacticalCamera)
local VehicleCamera = require(Controllers.VehicleCamera)
local WeaponController = require(Controllers.WeaponController)
local HUD = require(Controllers.Parent.UI.HUD)

local V = Config.Vehicle
local KEYS = Config.VehicleKeys

local VehicleController = {}

type Wheel = {
	Front: boolean,
	Tire: BasePart,
	Hinge: HingeConstraint,
	Slide: CylindricalConstraint,
}

local character: Model? = nil
local humanoid: Humanoid? = nil
local characterTrove: Trove.Trove? = nil
local rideTrove: Trove.Trove? = nil

local car: Model? = nil
local root: BasePart? = nil
local seat: VehicleSeat? = nil
local isDriver = false
local wheels: { Wheel } = {}
local downforce: VectorForce? = nil

local handbrake = false
local appliedHandbrake: boolean? = nil
local steer = 0
local gear = 1
local shiftUntil = 0
local backfires = 0
local lastThrottle = 0
local rpm = 0.12
local sendTimer = 0
local rng = Random.new()

local ACTIONS = { "CarHandbrake", "CarExit", "CarLights", "CarHazards", "CarUnderglow" }

local function collectWheels(model: Model): { Wheel }
	local list: { Wheel } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 8) == "Knuckle_" then
			local hinge = d:FindFirstChild("Axle")
			local slide = d:FindFirstChild("Suspension")
			local wheelModel = d.Parent
			local tire = if wheelModel and wheelModel:IsA("Model") then wheelModel.PrimaryPart else nil
			if hinge and hinge:IsA("HingeConstraint") and slide and slide:IsA("CylindricalConstraint") and tire then
				table.insert(list, {
					Front = string.sub(d.Name, 9, 9) == "F",
					Tire = tire,
					Hinge = hinge,
					Slide = slide,
				})
			end
		end
	end
	return list
end

local function setRearGrip(locked: boolean)
	if appliedHandbrake == locked then
		return
	end
	appliedHandbrake = locked
	local friction = if locked then V.TireFrictionHandbrake else V.TireFriction
	for _, wheel in wheels do
		if not wheel.Front then
			wheel.Tire.CustomPhysicalProperties = PhysicalProperties.new(0.7, friction, 0, 100, 100)
		end
	end
end

local function gearFor(speed: number): number
	local gears = V.Gears
	for g = #gears - 1, 1, -1 do
		if speed >= gears[g] then
			return g
		end
	end
	return 1
end

local function drive(dt: number)
	local r = root
	local s = seat
	local force = downforce
	if not r or not s or not force then
		return
	end
	local now = os.clock()
	local throttleIn = s.ThrottleFloat
	local steerIn = s.SteerFloat

	local forward = r.CFrame.LookVector
	local velocity = r.AssemblyLinearVelocity
	local speed = velocity:Dot(forward)
	local absSpeed = math.abs(speed)
	local speed01 = math.clamp(absSpeed / V.MaxSpeed, 0, 1)

	-- Steering
	steer += (steerIn - steer) * (1 - math.exp(-dt * V.SteerSpeed * (if math.abs(steerIn) < 0.05 then 1.6 else 1)))
	local maxAngle = V.SteerAngleLow + (V.SteerAngleHigh - V.SteerAngleLow) * speed01
	-- Counter-steer room while drifting.
	if handbrake then
		maxAngle = math.max(maxAngle, V.SteerAngleLow * 0.8)
	end

	-- Gearbox (drives RPM, shift cut and backfires)
	local targetGear = if speed < -1 then -1 else gearFor(absSpeed)
	if targetGear > gear and gear >= 1 then
		shiftUntil = now + V.ShiftTime
		if throttleIn > 0.6 and rpm > 0.75 then
			backfires += 1
		end
	end
	gear = targetGear
	local gears = V.Gears
	local g = math.max(gear, 1)
	local low, high = gears[g], gears[math.min(g + 1, #gears)]
	local gearRpm = if high > low then (absSpeed - low) / (high - low) else 1
	local targetRpm = 0.12 + math.clamp(gearRpm, 0, 1) * 0.86
	if absSpeed < 3 and math.abs(throttleIn) > 0.05 then
		targetRpm = math.max(targetRpm, 0.2 + math.abs(throttleIn) * 0.3)
	end
	if now < shiftUntil then
		targetRpm *= 0.72
	end
	rpm += (targetRpm - rpm) * (1 - math.exp(-dt * 10))

	-- Throttle lift-off pop
	if lastThrottle > 0.8 and throttleIn < 0.1 and rpm > 0.65 and rng:NextNumber() < 0.6 then
		backfires += 1
	end
	lastThrottle = throttleIn

	-- Longitudinal
	local driveVelocity = 0
	local driveTorque = 0
	local brake = 0
	if throttleIn > 0.05 then
		if speed < -2 then
			brake = throttleIn
		else
			local curve = math.clamp(1.15 - speed01 * speed01 * 0.6, 0.3, 1)
			driveVelocity = V.MaxSpeed
			driveTorque = V.DriveTorque * throttleIn * curve * (if now < shiftUntil then 0.2 else 1)
		end
	elseif throttleIn < -0.05 then
		if speed > 2 then
			brake = -throttleIn
		else
			driveVelocity = -V.ReverseSpeed
			driveTorque = V.DriveTorque * 0.7 * -throttleIn
		end
	end

	for _, wheel in wheels do
		local hinge = wheel.Hinge
		if wheel.Front then
			wheel.Slide.TargetAngle = -steer * maxAngle
		end
		if handbrake and not wheel.Front then
			hinge.AngularVelocity = 0
			hinge.MotorMaxTorque = V.HandbrakeTorque
		elseif brake > 0 then
			hinge.AngularVelocity = 0
			hinge.MotorMaxTorque = V.BrakeTorque * brake
		elseif driveTorque > 0 and not wheel.Front then
			hinge.AngularVelocity = -driveVelocity / V.WheelRadius
			hinge.MotorMaxTorque = driveTorque
		elseif not wheel.Front then
			hinge.AngularVelocity = 0
			hinge.MotorMaxTorque = V.CoastTorque
		else
			hinge.MotorMaxTorque = 0
		end
	end
	setRearGrip(handbrake)
	force.Force = Vector3.new(0, -V.Downforce * absSpeed * absSpeed, 0)

	HUD.setVehicle(absSpeed, gear, rpm)

	sendTimer -= dt
	if sendTimer <= 0 and car then
		sendTimer = 1 / V.StateSendRate
		Net.unreliable(Net.Unreliable.VehicleState):FireServer(car, throttleIn, brake, steer, handbrake, rpm, gear, backfires)
	end
end

local function bindRide()
	local function exitAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			Net.event(Net.Events.VehicleExit):FireServer()
		end
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindActionAtPriority("CarExit", exitAction, false, Enum.ContextActionPriority.High.Value, table.unpack(KEYS.Exit))
	if not isDriver then
		return
	end
	ContextActionService:BindActionAtPriority("CarHandbrake", function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			handbrake = true
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			handbrake = false
		end
		-- Sink so Space doesn't make the humanoid jump out of the seat.
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, table.unpack(KEYS.Handbrake))
	local function toggle(name: string): (string, Enum.UserInputState) -> Enum.ContextActionResult
		return function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin and car then
				Net.event(Net.Events.VehicleToggle):FireServer(car, name)
				AudioController.play("UITick")
			end
			return Enum.ContextActionResult.Sink
		end
	end
	ContextActionService:BindAction("CarLights", toggle("Lights"), false, table.unpack(KEYS.Lights))
	ContextActionService:BindAction("CarHazards", toggle("Hazards"), false, table.unpack(KEYS.Hazards))
	ContextActionService:BindAction("CarUnderglow", toggle("Underglow"), false, table.unpack(KEYS.Underglow))
end

local function leave()
	if not car then
		return
	end
	for _, name in ACTIONS do
		ContextActionService:UnbindAction(name)
	end
	if rideTrove then
		local t = rideTrove
		rideTrove = nil
		t:Clean()
	end
	handbrake = false
	appliedHandbrake = nil
	car = nil
	root = nil
	seat = nil
	wheels = {}
	downforce = nil
	HUD.setMode("OnFoot")

	local fromCF, fromFov, yaw = VehicleCamera.stop()
	if TacticalCamera.isAttached() then
		TacticalCamera.setBodyControl(true)
		TacticalCamera.setYaw(yaw)
		TacticalCamera.startBlended(fromCF, fromFov, 0.45)
	end
	MovementController.setEnabled(true)
	WeaponController.setEnabled(true)
end

local function enter(seatPart: BasePart)
	local model = seatPart.Parent
	if not model or not model:IsA("Model") or not CollectionService:HasTag(model, "DrivableCar") then
		return
	end
	local r = model.PrimaryPart
	if not r then
		return
	end
	car = model
	root = r
	isDriver = seatPart:IsA("VehicleSeat")
	seat = if seatPart:IsA("VehicleSeat") then seatPart else nil
	wheels = collectWheels(model)
	local force = r:FindFirstChild("Downforce")
	downforce = if force and force:IsA("VectorForce") then force else nil
	steer, gear, rpm, backfires, lastThrottle = 0, 1, 0.12, 0, 0
	appliedHandbrake = nil

	WeaponController.setEnabled(false)
	MovementController.setEnabled(false)
	TacticalCamera.setBodyControl(false)
	TacticalCamera.stop()
	local camera = Workspace.CurrentCamera
	VehicleCamera.start(model, if camera then camera.CFrame else r.CFrame, if camera then camera.FieldOfView else 70, character)
	AudioController.play("DoorOpen")
	HUD.setMode(if isDriver then "Vehicle" else "Passenger")

	local t = Trove.new()
	rideTrove = t
	if isDriver then
		t:Connect(RunService.Heartbeat, drive)
	end
	bindRide()
end

function VehicleController.attach(model: Model)
	VehicleController.detach()
	local h = model:FindFirstChildOfClass("Humanoid")
	if not h then
		return
	end
	character = model
	humanoid = h
	local t = Trove.new()
	characterTrove = t
	t:Connect(h.Seated, function(active: boolean, seatPart: BasePart?)
		if active and seatPart then
			enter(seatPart)
		else
			leave()
		end
	end)
	t:Connect(h.Died, leave)
end

function VehicleController.detach()
	leave()
	if characterTrove then
		local t = characterTrove
		characterTrove = nil
		t:Clean()
	end
	character = nil
	humanoid = nil
end

return VehicleController
