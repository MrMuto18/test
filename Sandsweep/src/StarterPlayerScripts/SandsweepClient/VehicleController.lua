-- VehicleController (ModuleScript) - StarterPlayerScripts/SandsweepClient/VehicleController
-- Drives the local player's machine. The server gives the driver network
-- ownership; this script turns VehicleSeat throttle/steer into a planar
-- LinearVelocity + a ground-hugging AlignOrientation (so machines never
-- flip in craters). Also: [R] unstuck, excavator scoop input, wheel/roller
-- spin for every machine, and the engine rumble.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Sandsweep")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = Shared:WaitForChild("Remotes")

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local VehicleController = {}

local player = Players.LocalPlayer
local current = nil
local scoopHeld = false
local lastScoop = 0
local lastFlip = 0
local wheelBases = setmetatable({}, { __mode = "k" })
local wheelAngles = setmetatable({}, { __mode = "k" })
local wheelLists = setmetatable({}, { __mode = "k" })

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function vehicleFromSeat(seatPart)
	if not seatPart or not seatPart:IsA("VehicleSeat") then
		return nil
	end
	local model = seatPart:FindFirstAncestorOfClass("Model")
	while model and not model:GetAttribute("VehicleId") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return model
end

local function moveToward(value, target, step)
	if value < target then
		return math.min(value + step, target)
	end
	return math.max(value - step, target)
end

local function begin(model, seat)
	local chassis = model.PrimaryPart
	local config = GameConfig.GetVehicle(model:GetAttribute("VehicleId"))
	if not chassis or not config then
		return nil
	end
	local look = chassis.CFrame.LookVector
	return {
		Model = model,
		Seat = seat,
		Chassis = chassis,
		Config = config,
		Yaw = math.atan2(-look.X, -look.Z),
		Speed = chassis.AssemblyLinearVelocity:Dot(look),
		Up = Vector3.yAxis,
		Owned = model:GetAttribute("OwnerUserId") == player.UserId,
	}
end

local function drive(dt)
	local chassis = current.Chassis
	local driveConstraint = chassis:FindFirstChild("Drive")
	local align = chassis:FindFirstChild("Align")
	if not driveConstraint or not align then
		return
	end
	local config = current.Config
	local throttle = current.Seat.ThrottleFloat
	local steer = current.Seat.SteerFloat
	local target = throttle * config.MaxSpeed
	if throttle < 0 then
		target *= 0.6
	end
	local braking = math.abs(target) < math.abs(current.Speed) or (target ~= 0 and math.sign(target) ~= math.sign(current.Speed))
	current.Speed = moveToward(current.Speed, target, config.Acceleration * (braking and 2.2 or 1) * dt)

	local turnFactor = config.TurnInPlace and 1 or math.clamp(math.abs(current.Speed) / 6, 0, 1)
	local direction = current.Speed < -0.5 and -1 or 1
	current.Yaw -= steer * config.TurnRate * dt * turnFactor * direction
	local forward = Vector3.new(-math.sin(current.Yaw), 0, -math.cos(current.Yaw))

	groundParams.FilterDescendantsInstances = { current.Model, player.Character }
	local hit = Workspace:Raycast(chassis.Position, Vector3.new(0, -9, 0), groundParams)
	local up = hit and hit.Normal or Vector3.yAxis
	if up.Y < 0.55 then
		up = Vector3.yAxis
	end
	current.Up = current.Up:Lerp(up, math.min(1, dt * 6)).Unit
	local flatForward = (forward - current.Up * forward:Dot(current.Up)).Unit
	local right = flatForward:Cross(current.Up)
	align.CFrame = CFrame.fromMatrix(Vector3.zero, right, current.Up)

	local velocity = forward * current.Speed
	driveConstraint.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
end

local function animateWheels(dt)
	local world = Workspace:FindFirstChild("SandsweepWorld")
	local vehicles = world and world:FindFirstChild("Vehicles")
	if not vehicles then
		return
	end
	for _, model in ipairs(vehicles:GetChildren()) do
		local chassis = model.PrimaryPart
		if chassis then
			local list = wheelLists[model]
			if not list then
				list = {}
				for _, descendant in ipairs(model:GetDescendants()) do
					if descendant:IsA("Weld") and descendant.Name == "WheelWeld" then
						table.insert(list, descendant)
					end
				end
				wheelLists[model] = list
			end
			local speed = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
			if math.abs(speed) > 0.05 then
				for _, weld in ipairs(list) do
					if not wheelBases[weld] then
						wheelBases[weld] = weld.C0
					end
					local radius = (weld.Part1 and weld.Part1:GetAttribute("Radius")) or 1
					wheelAngles[weld] = ((wheelAngles[weld] or 0) - speed / radius * dt) % (math.pi * 2)
					weld.C0 = wheelBases[weld] * CFrame.Angles(wheelAngles[weld], 0, 0)
				end
			end
		end
	end
end

function VehicleController.Flip()
	if current and current.Owned and os.clock() - lastFlip > 2 then
		lastFlip = os.clock()
		Remotes:WaitForChild("VehicleAction"):FireServer("Flip")
		Effects.Play("Swing", 0.8, 0.6)
	end
end

function VehicleController.IsDriving()
	return current ~= nil
end

local function step(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local model = vehicleFromSeat(seat)
	if model then
		if not current or current.Model ~= model then
			current = begin(model, seat)
		end
	elseif current then
		current = nil
	end
	ClientState.InVehicle = current

	local speedFraction = 0
	if current then
		if current.Owned then
			drive(dt)
		end
		speedFraction = math.clamp(math.abs(current.Speed) / current.Config.MaxSpeed, 0, 1)
		if current.Config.Id == "Excavator" and current.Owned and (scoopHeld or ClientState.DigHeld) and not ClientState.UIOpen then
			local now = os.clock()
			if now - lastScoop >= current.Config.ScoopCooldown then
				lastScoop = now
				Remotes:WaitForChild("VehicleAction"):FireServer("Scoop")
				Effects.Play("Swing", 1, 0.35)
				task.delay(0.6, function()
					Effects.Play("Dig", 1, 0.45)
					Effects.Shake(0.25)
				end)
			end
		end
	end
	Effects.UpdateEngine(current ~= nil, speedFraction, dt)
	animateWheels(dt)
end

function VehicleController.Init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			scoopHeld = true
		elseif input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonY then
			VehicleController.Flip()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			scoopHeld = false
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return VehicleController
