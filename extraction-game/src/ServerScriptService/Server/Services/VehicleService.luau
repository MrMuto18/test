--!strict
--[[
	VehicleService
	Drivable "Zabour" getaway cars.

	  • Spawns a physics car on each Config.Vehicle.SpawnPads entry
	  • Prompts: Drive (driver door), Ride (passenger), Trunk, Flip (only when
	    upside down)
	  • Seating hands network ownership to the driver so the driver's client
	    simulates the car with zero input lag; leaving parks the car and the
	    server takes ownership back
	  • Driver streams throttle/brake/steer/rpm (unreliable, validated) →
	    replicated as attributes; the server renders brake, reverse, hazard,
	    head and underglow lights from them so every client sees the same car
	  • Trunk: load the bag you carry / take a bag out; cargo shows as small
	    bags behind the seats; the lid swings open on use
	  • Weapons are holstered while seated and drawn again on exit
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Schema = require(Shared.Schema)
local GetawayCarBody = require(Shared.Builders.GetawayCarBody)
local LootBagBuilder = require(Shared.Builders.LootBagBuilder)

local VehicleChassis = require(script.Parent.Parent.Vehicles.VehicleChassis)

local VehicleService = {}

local V = Config.Vehicle

type Car = {
	Model: Model,
	Rig: VehicleChassis.Rig,
	Seat: VehicleSeat,
	Passenger: Seat,
	Driver: Player?,
	Cargo: { number },
	CargoModels: { Model },
	TrunkValue: NumberValue,
	FlipPrompt: ProximityPrompt,
	TrunkPrompt: ProximityPrompt,
	LastState: number,
	HazardPhase: number,
}

type Hooks = {
	SetHolstered: (player: Player, holstered: boolean) -> (),
	ConsumeCarried: (player: Player) -> number?,
	GiveCarried: (player: Player, value: number) -> boolean,
	IsCarrying: (player: Player) -> boolean,
}

local cars: { [Model]: Car } = {}
local hooks: Hooks
local folder: Folder

-- Cargo slots behind the front seats (root-local; root sits at car y 1.8).
local CARGO_SLOTS = {
	CFrame.new(-1.2, 1.35, 2.6),
	CFrame.new(1.2, 1.35, 2.6),
	CFrame.new(-1.2, 1.35, 3.9),
	CFrame.new(1.2, 1.35, 3.9),
}

local function formatValue(value: number): string
	local s = tostring(math.floor(value))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return "$" .. out
end

local function prompt(parent: Instance, name: string, action: string, object: string, hold: number, key: Enum.KeyCode): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p.KeyboardKeyCode = key
	p.Parent = parent
	return p
end

local function playerFromSeat(seat: Seat | VehicleSeat): Player?
	local humanoid = seat.Occupant
	if not humanoid then
		return nil
	end
	return Players:GetPlayerFromCharacter(humanoid.Parent)
end

local function sitIn(player: Player, seat: Seat | VehicleSeat)
	if seat.Occupant or player:GetAttribute("State") ~= "Deployed" then
		return
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 or humanoid.Sit then
		return
	end
	seat:Sit(humanoid)
end

local function exitSeat(player: Player, car: Car)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not character or not humanoid then
		return
	end
	local seat = humanoid.SeatPart
	if seat ~= car.Seat and seat ~= car.Passenger then
		return
	end
	local door = if seat == car.Seat then car.Rig.Handles.DriverDoor else car.Rig.Handles.PassengerDoor
	local weld = (seat :: BasePart):FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	humanoid.Sit = false
	-- Step out beside the door, upright and facing the car's heading.
	local look = car.Rig.Handles.Root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
	local position = door.WorldPosition + Vector3.new(0, 2.6, 0)
	character:PivotTo(CFrame.lookAt(position, position + flat))
end

--------------------------------------------------------------------------------
-- Trunk
--------------------------------------------------------------------------------
local function animateTrunk(car: Car)
	local hinge = car.Rig.Handles.TrunkHinge
	local value = Instance.new("NumberValue")
	value.Value = 0
	local connection = value.Changed:Connect(function(v: number)
		hinge.C0 = GetawayCarBody.trunkFrame(v)
	end)
	local open = TweenService:Create(value, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Value = 1 })
	open:Play()
	open.Completed:Once(function()
		task.wait(1.2)
		local close = TweenService:Create(value, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Value = 0 })
		close:Play()
		close.Completed:Once(function()
			connection:Disconnect()
			value:Destroy()
		end)
	end)
end

local function refreshCargo(car: Car)
	for _, m in car.CargoModels do
		m:Destroy()
	end
	table.clear(car.CargoModels)
	local root = car.Rig.Handles.Root
	local total = 0
	for i, value in car.Cargo do
		total += value
		local slot = CARGO_SLOTS[i]
		if slot then
			local bag = LootBagBuilder.build(root.CFrame * slot * CFrame.Angles(0, math.rad(90), 0), 0.55, false)
			for _, d in bag.Model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Massless = true
					d.CanCollide = false
					d.CanQuery = false
					d.CollisionGroup = "VehicleBody"
				end
			end
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = bag.Body
			weld.Parent = bag.Body
			bag.Model.Name = "Cargo"
			bag.Model.Parent = car.Model
			table.insert(car.CargoModels, bag.Model)
		end
	end
	car.TrunkValue.Value = total
	car.Model:SetAttribute("TrunkValue", total)
	car.Model:SetAttribute("TrunkCount", #car.Cargo)
	car.TrunkPrompt.ObjectText = string.format("TRUNK  %d/%d  ·  %s", #car.Cargo, V.TrunkCapacity, formatValue(total))
end

local function useTrunk(player: Player, car: Car)
	if player:GetAttribute("State") ~= "Deployed" then
		return
	end
	if hooks.IsCarrying(player) then
		if #car.Cargo >= V.TrunkCapacity then
			return
		end
		local value = hooks.ConsumeCarried(player)
		if value then
			table.insert(car.Cargo, value)
			animateTrunk(car)
			refreshCargo(car)
		end
	elseif #car.Cargo > 0 then
		local value = car.Cargo[#car.Cargo]
		if hooks.GiveCarried(player, value) then
			table.remove(car.Cargo)
			animateTrunk(car)
			refreshCargo(car)
		end
	end
end

--------------------------------------------------------------------------------
-- Lights
--------------------------------------------------------------------------------
local function renderLights(car: Car, dt: number)
	local model = car.Model
	local handles = car.Rig.Handles
	local brake = model:GetAttribute("Brake")
	GetawayCarBody.setBrakeIntensity(handles, if typeof(brake) == "number" then brake else 0)
	GetawayCarBody.setReverse(handles, model:GetAttribute("Reversing") == true)
	if model:GetAttribute("Hazards") == true then
		car.HazardPhase = (car.HazardPhase + dt) % 0.9
		GetawayCarBody.setIndicators(handles, car.HazardPhase < 0.45)
	elseif car.HazardPhase ~= -1 then
		car.HazardPhase = -1
		GetawayCarBody.setIndicators(handles, false)
	end
end

local function toggle(player: Player, carModel: any, name: any)
	if typeof(carModel) ~= "Instance" or not carModel:IsA("Model") then
		return
	end
	local car = cars[carModel]
	if not car or car.Driver ~= player then
		return
	end
	local handles = car.Rig.Handles
	if name == "Lights" then
		local on = not (car.Model:GetAttribute("Lights") == true)
		car.Model:SetAttribute("Lights", on)
		GetawayCarBody.setHeadlights(handles, on)
	elseif name == "Hazards" then
		car.Model:SetAttribute("Hazards", not (car.Model:GetAttribute("Hazards") == true))
		car.HazardPhase = 0
	elseif name == "Underglow" then
		GetawayCarBody.setUnderglow(handles, not (car.Model:GetAttribute("Underglow") == true))
	end
end

local function onState(player: Player, carModel: any, throttle: any, brake: any, steer: any, handbrake: any, rpm: any, gear: any, backfires: any)
	if typeof(carModel) ~= "Instance" or not carModel:IsA("Model") then
		return
	end
	local car = cars[carModel]
	if not car or car.Driver ~= player then
		return
	end
	local now = os.clock()
	if now - car.LastState < 1 / 40 then
		return
	end
	car.LastState = now
	local function num(v: any, lo: number, hi: number): number
		return if Schema.isFiniteNumber(v) then math.clamp(v, lo, hi) else 0
	end
	local m = car.Model
	m:SetAttribute("Throttle", math.round(num(throttle, -1, 1) * 100) / 100)
	m:SetAttribute("Brake", math.round(num(brake, 0, 1) * 100) / 100)
	m:SetAttribute("Steer", math.round(num(steer, -1, 1) * 100) / 100)
	m:SetAttribute("Handbrake", handbrake == true)
	m:SetAttribute("RPM", math.round(num(rpm, 0, 1) * 100) / 100)
	m:SetAttribute("Gear", math.floor(num(gear, -1, 6)))
	m:SetAttribute("Reversing", num(throttle, -1, 1) < -0.1 and car.Rig.Handles.Root.AssemblyLinearVelocity:Dot(car.Rig.Handles.Root.CFrame.LookVector) < 1)
	local count = math.floor(num(backfires, 0, 1e6))
	if count ~= m:GetAttribute("Backfires") then
		m:SetAttribute("Backfires", count)
	end
end

--------------------------------------------------------------------------------
-- Spawning
--------------------------------------------------------------------------------
local function onDriverChanged(car: Car)
	local driver = playerFromSeat(car.Seat)
	local previous = car.Driver
	if driver == previous then
		return
	end
	if previous and previous.Parent then
		hooks.SetHolstered(previous, false)
	end
	car.Driver = driver
	local root = car.Rig.Handles.Root
	-- Wheels/knuckles are separate assemblies joined by constraints: hand all
	-- of them to the same owner or the suspension fights across the network.
	local function setOwner(owner: Player?)
		pcall(function()
			root:SetNetworkOwner(owner)
			for _, wheel in car.Rig.Wheels do
				wheel.Tire:SetNetworkOwner(owner)
				wheel.Knuckle:SetNetworkOwner(owner)
			end
		end)
	end
	if driver then
		setOwner(driver)
		car.Model:SetAttribute("Driver", driver.UserId)
		car.Model:SetAttribute("Lights", true)
		GetawayCarBody.setHeadlights(car.Rig.Handles, true)
		hooks.SetHolstered(driver, true)
	else
		car.Model:SetAttribute("Driver", 0)
		car.Model:SetAttribute("Throttle", 0)
		car.Model:SetAttribute("RPM", 0)
		car.Model:SetAttribute("Brake", 0)
		car.Model:SetAttribute("Handbrake", false)
		car.Model:SetAttribute("Reversing", false)
		VehicleChassis.park(car.Rig)
		setOwner(nil)
	end
end

local function spawnCar(index: number, pad: CFrame): Car
	local origin = Config.World.Origin * pad
	local handles = GetawayCarBody.build(origin, {
		Name = "Zabour_" .. index,
		Anchored = false,
		Physics = true,
		PlateText = string.format("ZBR %03d", 100 + index),
	})
	local rig = VehicleChassis.rig(handles)
	local model = handles.Model
	local root = handles.Root

	-- Seats (inside the solid body; same assembly, so no self-collision)
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(1.2, 0.2, 1.2)
	seat.CFrame = root.CFrame * CFrame.new(-1.3, -0.5, 1.0)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanQuery = false
	seat.Massless = true
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.CanTouch = false -- no touch-to-sit: only the prompt seats you
	seat.Parent = model
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = root
	seatWeld.Part1 = seat
	seatWeld.Parent = seat

	local passenger = Instance.new("Seat")
	passenger.Name = "PassengerSeat"
	passenger.Size = Vector3.new(1.2, 0.2, 1.2)
	passenger.CFrame = root.CFrame * CFrame.new(1.3, -0.5, 1.0)
	passenger.Transparency = 1
	passenger.CanCollide = false
	passenger.CanQuery = false
	passenger.Massless = true
	passenger.CanTouch = false
	passenger.Parent = model
	local passengerWeld = Instance.new("WeldConstraint")
	passengerWeld.Part0 = root
	passengerWeld.Part1 = passenger
	passengerWeld.Parent = passenger

	local trunkValue = Instance.new("NumberValue")
	trunkValue.Name = "TrunkValue"
	trunkValue.Parent = model

	local trunkAttachment = handles.TrunkLid:FindFirstChild("TrunkPrompt")
	local car: Car = {
		Model = model,
		Rig = rig,
		Seat = seat,
		Passenger = passenger,
		Driver = nil,
		Cargo = {},
		CargoModels = {},
		TrunkValue = trunkValue,
		FlipPrompt = prompt(root, "FlipPrompt", "Flip", "ZABOUR", 1.2, Enum.KeyCode.E),
		TrunkPrompt = prompt(if trunkAttachment then trunkAttachment else handles.TrunkLid, "TrunkPrompt", "Trunk", "", 0.35, Enum.KeyCode.E),
		LastState = 0,
		HazardPhase = -1,
	}
	car.FlipPrompt.Enabled = false

	local drivePrompt = prompt(handles.DriverDoor, "DrivePrompt", "Drive", "ZABOUR", 0.25, Enum.KeyCode.E)
	local ridePrompt = prompt(handles.PassengerDoor, "RidePrompt", "Ride", "ZABOUR", 0.25, Enum.KeyCode.E)
	drivePrompt.Triggered:Connect(function(player: Player)
		sitIn(player, seat)
	end)
	ridePrompt.Triggered:Connect(function(player: Player)
		sitIn(player, passenger)
	end)
	car.TrunkPrompt.Triggered:Connect(function(player: Player)
		useTrunk(player, car)
	end)
	car.FlipPrompt.Triggered:Connect(function()
		local cf = root.CFrame
		local flat = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
		flat = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
		local upright = cf.Position + Vector3.new(0, 4, 0)
		-- PrimaryPart is Root, so pivoting the model rights the whole car + wheels.
		model:PivotTo(CFrame.lookAt(upright, upright + flat))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		drivePrompt.Enabled = seat.Occupant == nil
		onDriverChanged(car)
	end)
	passenger:GetPropertyChangedSignal("Occupant"):Connect(function()
		ridePrompt.Enabled = passenger.Occupant == nil
		local rider = playerFromSeat(passenger)
		if rider then
			hooks.SetHolstered(rider, true)
		end
	end)

	model:SetAttribute("Lights", false)
	model:SetAttribute("Hazards", false)
	model:SetAttribute("Backfires", 0)
	GetawayCarBody.setHeadlights(handles, false)
	CollectionService:AddTag(model, "DrivableCar")
	model.Parent = folder
	VehicleChassis.park(rig)
	refreshCargo(car)
	cars[model] = car
	return car
end

function VehicleService.init(injected: Hooks)
	hooks = injected
	local f = Instance.new("Folder")
	f.Name = "Vehicles"
	f.Parent = workspace
	folder = f

	for index, pad in V.SpawnPads do
		spawnCar(index, pad)
	end

	Net.unreliable(Net.Unreliable.VehicleState).OnServerEvent:Connect(onState)
	Net.event(Net.Events.VehicleToggle).OnServerEvent:Connect(toggle)
	Net.event(Net.Events.VehicleExit).OnServerEvent:Connect(function(player: Player)
		for _, car in cars do
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid and (humanoid.SeatPart == car.Seat or humanoid.SeatPart == car.Passenger) then
				exitSeat(player, car)
				return
			end
		end
	end)

	-- Passenger leaving re-draws their weapon.
	local function watchSeat(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Seated:Connect(function(active: boolean)
					if not active then
						hooks.SetHolstered(player, false)
					end
				end)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		watchSeat(player)
	end
	Players.PlayerAdded:Connect(watchSeat)

	local flipTimer = 0
	RunService.Heartbeat:Connect(function(dt: number)
		flipTimer += dt
		local checkFlip = flipTimer >= V.FlipCheckInterval
		if checkFlip then
			flipTimer = 0
		end
		for _, car in cars do
			renderLights(car, dt)
			if checkFlip then
				car.FlipPrompt.Enabled = car.Rig.Handles.Root.CFrame.UpVector.Y < 0.35 and car.Driver == nil
			end
		end
	end)
end

-- Phase 4 extraction reads trunk contents through this.
function VehicleService.getCars(): { [Model]: any }
	return cars
end

function VehicleService.emptyTrunk(carModel: Model): number
	local car = cars[carModel]
	if not car then
		return 0
	end
	local total = 0
	for _, value in car.Cargo do
		total += value
	end
	table.clear(car.Cargo)
	refreshCargo(car)
	return total
end

return VehicleService
