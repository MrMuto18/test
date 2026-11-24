-- VehicleService (ModuleScript) - ServerScriptService/Sandsweep/VehicleService
-- Heavy machinery: spawning (1 per player), driver-only seats, network
-- ownership, flip/unstuck, server-side storage, bulldozer blade carving,
-- excavator scoops and the hydraulic dump bays (kiln = sell, hopper = factory).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Sandsweep")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local VehicleModels = require(Shared:WaitForChild("VehicleModels"))

local LotService = require(script.Parent:WaitForChild("LotService"))
local FindsService = require(script.Parent:WaitForChild("FindsService"))

local VehicleService = {}
VehicleService.Hooks = {
	GetData = nil, -- function(player) -> data
	Notify = nil, -- function(player, payload)
	PushState = nil, -- function(player)
	SellKg = nil, -- function(player, kg, position)
	DepositHopper = nil, -- function(player, kg) -> ok, message
	LoadBag = nil, -- function(player, entry)
	DigFx = nil, -- function(player, position, kind, kg)
}

local Economy = GameConfig.Economy
local active = {} -- [player] = entry
local refs = {}
local folder

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { Workspace.Terrain }

local function yawOnly(cframe)
	local look = cframe.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(Vector3.zero, flat.Unit)
end

local function notify(player, payload)
	if VehicleService.Hooks.Notify then
		VehicleService.Hooks.Notify(player, payload)
	end
end

local function setFill(entry)
	local fraction = math.clamp(entry.Storage / entry.Config.Capacity, 0, 1)
	entry.Model:SetAttribute("StorageKg", math.floor(entry.Storage * 10) / 10)
	local fill = entry.Model:FindFirstChild("SandFill", true)
	if fill then
		fill.Transparency = fraction > 0.01 and 0 or 1
	end
end

function VehicleService.AddStorage(entry, kg)
	local room = entry.Config.Capacity - entry.Storage
	local added = math.clamp(kg, 0, room)
	entry.Storage += added
	setFill(entry)
	return added
end

function VehicleService.Room(entry)
	return entry.Config.Capacity - entry.Storage
end

function VehicleService.GetActive(player)
	return active[player]
end

local function saveStorage(entry)
	local data = VehicleService.Hooks.GetData and VehicleService.Hooks.GetData(entry.Owner)
	if data then
		data.VehicleStorage[entry.Config.Id] = math.floor(entry.Storage * 1000) / 1000
	end
end

local function restoreCamera(player)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 12
end

function VehicleService.Despawn(player)
	local entry = active[player]
	if not entry then
		return false
	end
	active[player] = nil
	saveStorage(entry)
	if entry.Driver then
		restoreCamera(entry.Driver)
	end
	entry.Model:Destroy()
	player:SetAttribute("ActiveVehicle", nil)
	return true
end

local function pickSpawn()
	local spawns = refs.GarageSpawns or { CFrame.new(0, 10, 120) }
	for _, cframe in ipairs(spawns) do
		local free = true
		for _, entry in pairs(active) do
			if (entry.Chassis.Position - cframe.Position).Magnitude < 11 then
				free = false
				break
			end
		end
		if free then
			return cframe
		end
	end
	return spawns[#spawns] + Vector3.new(math.random(-6, 6), 4, math.random(-6, 6))
end

local function onOccupantChanged(entry)
	local seat = entry.Seat
	local humanoid = seat.Occupant
	if humanoid then
		local player = Players:GetPlayerFromCharacter(humanoid.Parent)
		if player ~= entry.Owner then
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			humanoid.Sit = false
			humanoid.Jump = true
			if player then
				notify(player, { Kind = "Toast", Text = "That's " .. entry.Owner.DisplayName .. "'s machine.", Color = "Terracotta" })
			end
			return
		end
		entry.Driver = player
		entry.DrivePrompt.Enabled = false
		pcall(function()
			entry.Chassis:SetNetworkOwner(player)
		end)
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = 60
		player.CameraMinZoomDistance = 16
	else
		local driver = entry.Driver
		entry.Driver = nil
		entry.DrivePrompt.Enabled = true
		entry.Drive.PlaneVelocity = Vector2.zero
		entry.Align.CFrame = yawOnly(entry.Chassis.CFrame)
		pcall(function()
			entry.Chassis:SetNetworkOwner(nil)
		end)
		if driver then
			restoreCamera(driver)
		end
	end
end

function VehicleService.Spawn(player, vehicleId)
	local config = GameConfig.GetVehicle(vehicleId)
	if not config then
		return false, "Unknown vehicle"
	end
	VehicleService.Despawn(player)

	local model = VehicleModels.Build(vehicleId, false)
	model.Name = player.Name .. "_" .. vehicleId
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Capacity", config.Capacity)
	model:SetAttribute("StorageKg", 0)
	local chassis = model.PrimaryPart
	local seat = model:FindFirstChild("DriverSeat", true)

	local root = Instance.new("Attachment")
	root.Name = "Root"
	root.Parent = chassis
	local drive = Instance.new("LinearVelocity")
	drive.Name = "Drive"
	drive.Attachment0 = root
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	drive.PrimaryTangentAxis = Vector3.xAxis
	drive.SecondaryTangentAxis = Vector3.zAxis
	drive.PlaneVelocity = Vector2.zero
	drive.MaxForce = 1e6
	drive.Parent = chassis
	local align = Instance.new("AlignOrientation")
	align.Name = "Align"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = root
	align.MaxTorque = 1e9
	align.Responsiveness = 25
	align.Parent = chassis

	local spawnCFrame = pickSpawn()
	model:PivotTo(spawnCFrame)
	align.CFrame = yawOnly(spawnCFrame)
	model.Parent = folder
	drive.MaxForce = chassis.AssemblyMass * 140
	pcall(function()
		chassis:SetNetworkOwner(nil)
	end)

	local drivePrompt = Instance.new("ProximityPrompt")
	drivePrompt.Name = "DrivePrompt"
	drivePrompt.ActionText = "Drive"
	drivePrompt.ObjectText = config.Name
	drivePrompt.HoldDuration = 0
	drivePrompt.MaxActivationDistance = 14
	drivePrompt.RequiresLineOfSight = false
	drivePrompt.Parent = seat
	local loadPrompt = Instance.new("ProximityPrompt")
	loadPrompt.Name = "LoadPrompt"
	loadPrompt.ActionText = "Load Bag"
	loadPrompt.ObjectText = config.Name
	loadPrompt.KeyboardKeyCode = Enum.KeyCode.F
	loadPrompt.HoldDuration = 0.25
	loadPrompt.MaxActivationDistance = 14
	loadPrompt.RequiresLineOfSight = false
	loadPrompt.UIOffset = Vector2.new(0, 60)
	loadPrompt.Parent = model:FindFirstChild("Hull", true) or chassis

	local data = VehicleService.Hooks.GetData and VehicleService.Hooks.GetData(player)
	local entry = {
		Owner = player,
		Config = config,
		Model = model,
		Chassis = chassis,
		Seat = seat,
		Drive = drive,
		Align = align,
		DrivePrompt = drivePrompt,
		Storage = math.clamp(data and data.VehicleStorage[vehicleId] or 0, 0, config.Capacity),
		Driver = nil,
		Unloading = false,
		CooldownUntil = 0,
		LastScoop = 0,
		LastFlip = 0,
		LastFx = 0,
		LastFullNotice = 0,
		Joints = {},
	}
	for _, name in ipairs({ "BedHinge", "BoomJoint", "StickJoint", "BucketJoint" }) do
		local weld = model:FindFirstChild(name, true)
		if weld then
			entry.Joints[name] = { Weld = weld, Base = weld.C0 }
		end
	end
	setFill(entry)
	active[player] = entry
	player:SetAttribute("ActiveVehicle", vehicleId)

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		onOccupantChanged(entry)
	end)
	drivePrompt.Triggered:Connect(function(who)
		if who ~= player then
			notify(who, { Kind = "Toast", Text = "Only " .. player.DisplayName .. " can drive this.", Color = "Terracotta" })
			return
		end
		local character = who.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not seat.Occupant then
			seat:Sit(humanoid)
		end
	end)
	loadPrompt.Triggered:Connect(function(who)
		if who == player and VehicleService.Hooks.LoadBag then
			VehicleService.Hooks.LoadBag(who, entry)
		end
	end)
	return true, "Your " .. config.Name .. " is waiting at the Garage!"
end

function VehicleService.Flip(player)
	local entry = active[player]
	if not entry then
		return
	end
	local now = os.clock()
	if now - entry.LastFlip < 2 then
		return
	end
	entry.LastFlip = now
	local yaw = yawOnly(entry.Chassis.CFrame)
	entry.Model:PivotTo(CFrame.new(entry.Chassis.Position + Vector3.new(0, 6, 0)) * yaw)
	entry.Align.CFrame = yaw
	entry.Chassis.AssemblyLinearVelocity = Vector3.zero
	entry.Chassis.AssemblyAngularVelocity = Vector3.zero
end

-- Move every vehicle standing inside the dig zone back to the garage (lot regeneration).
function VehicleService.EvacuateLot()
	for _, entry in pairs(active) do
		if LotService.IsInside(entry.Chassis.Position, 4) then
			local seat = entry.Seat
			if seat.Occupant then
				local weld = seat:FindFirstChild("SeatWeld")
				if weld then
					weld:Destroy()
				end
			end
			local target = pickSpawn()
			entry.Model:PivotTo(target)
			entry.Align.CFrame = yawOnly(target)
		end
	end
end

--------------------------------------------------------------------------
-- DIGGING MACHINES
--------------------------------------------------------------------------
local function digInto(entry, center, radius)
	local room = VehicleService.Room(entry)
	if room <= 0.5 then
		return 0
	end
	local maxVolume = room / Economy.SandDensity
	local typical = (4 / 3) * math.pi * radius ^ 3 * 0.5
	if typical > maxVolume then
		radius = math.max(1.5, radius * (maxVolume / typical) ^ (1 / 3))
	end
	local removed = LotService.Dig(center, radius)
	local kg = VehicleService.AddStorage(entry, removed * Economy.SandDensity)
	if kg > 0 then
		local data = VehicleService.Hooks.GetData and VehicleService.Hooks.GetData(entry.Owner)
		if data then
			data.Stats.TotalKg += kg
		end
		FindsService.MarkNear(center, radius + 6)
	end
	return kg
end

local function notifyFull(entry)
	local now = os.clock()
	if now - entry.LastFullNotice > 4 then
		entry.LastFullNotice = now
		notify(entry.Owner, { Kind = "Toast", Text = entry.Config.Name .. " is full! Drive onto a dump bay.", Color = "Terracotta", Icon = "🚚" })
	end
end

local function carveBlade(entry)
	local spray = entry.Model:FindFirstChild("BladeSpray", true)
	local cutting = false
	if entry.Driver and VehicleService.Room(entry) > 0.5 then
		local chassis = entry.Chassis
		local forwardSpeed = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
		local cut = chassis:FindFirstChild("BladeCut")
		if forwardSpeed > 1.5 and cut and LotService.IsInside(cut.WorldPosition, 3) then
			local right = chassis.CFrame.RightVector
			local total = 0
			for _, offset in ipairs({ -3.4, 0, 3.4 }) do
				total += digInto(entry, cut.WorldPosition + right * offset, entry.Config.BladeRadius)
			end
			cutting = total > 0
			local now = os.clock()
			if cutting and now - entry.LastFx > 0.3 and VehicleService.Hooks.DigFx then
				entry.LastFx = now
				VehicleService.Hooks.DigFx(entry.Owner, cut.WorldPosition, "Bulldozer", total)
			end
		end
	elseif entry.Driver then
		notifyFull(entry)
	end
	if spray then
		spray.Enabled = cutting
	end
end

local function setJoint(entry, name, angle)
	local joint = entry.Joints[name]
	if joint then
		joint.Weld.C0 = joint.Base * CFrame.Angles(angle, 0, 0)
	end
end

function VehicleService.Scoop(player)
	local entry = active[player]
	if not entry or entry.Config.Id ~= "Excavator" or entry.Driver ~= player then
		return
	end
	local now = os.clock()
	if now - entry.LastScoop < entry.Config.ScoopCooldown or entry.Scooping then
		return
	end
	if VehicleService.Room(entry) <= 0.5 then
		notifyFull(entry)
		return
	end
	entry.LastScoop = now
	entry.Scooping = true
	local bucketSand = entry.Model:FindFirstChild("BucketSand", true)
	local progress = Instance.new("NumberValue")
	progress.Name = "ScoopProgress"
	progress.Parent = entry.Model
	local dug = false
	progress.Changed:Connect(function(t)
		local swing = math.sin(math.pi * t)
		setJoint(entry, "BoomJoint", -0.45 * swing)
		setJoint(entry, "StickJoint", 0.55 * swing)
		local curl
		if t < 0.45 then
			curl = -0.6 * (t / 0.45)
		elseif t < 0.75 then
			curl = -0.6 + 1.7 * ((t - 0.45) / 0.3)
		else
			curl = 1.1 * (1 - (t - 0.75) / 0.25)
		end
		setJoint(entry, "BucketJoint", curl)
		if t >= 0.45 and not dug then
			dug = true
			local chassis = entry.Chassis
			local reachPoint = (chassis.CFrame * CFrame.new(1.4, 0, -entry.Config.ScoopReach)).Position
			local hit = Workspace:Raycast(reachPoint + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), terrainParams)
			if hit and hit.Material == Enum.Material.Sand and LotService.IsInside(hit.Position, 2) then
				local center = hit.Position - Vector3.new(0, 2, 0)
				local kg = digInto(entry, center, entry.Config.ScoopRadius)
				if kg > 0 then
					if bucketSand then
						bucketSand.Transparency = 0
					end
					if VehicleService.Hooks.DigFx then
						VehicleService.Hooks.DigFx(entry.Owner, hit.Position, "Excavator", kg)
					end
				end
			elseif hit and not LotService.IsInside(hit.Position, 2) then
				notify(player, { Kind = "Toast", Text = "Scoop inside the dig zone (past the flags).", Color = "Sky" })
			end
		end
		if t >= 0.95 and bucketSand then
			bucketSand.Transparency = 1
		end
	end)
	local tween = TweenService:Create(progress, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = 1 })
	tween.Completed:Connect(function()
		progress:Destroy()
		setJoint(entry, "BoomJoint", 0)
		setJoint(entry, "StickJoint", 0)
		setJoint(entry, "BucketJoint", 0)
		entry.Scooping = false
	end)
	tween:Play()
end

--------------------------------------------------------------------------
-- DUMP BAYS (hydraulic tilt + pour)
--------------------------------------------------------------------------
local function onPad(pad, position)
	if not pad then
		return false
	end
	local localPos = pad.CFrame:PointToObjectSpace(position)
	return math.abs(localPos.X) <= pad.Size.X / 2 + 1 and math.abs(localPos.Z) <= pad.Size.Z / 2 + 1 and localPos.Y > -2 and localPos.Y < 12
end

local function tiltBed(entry, angle, duration)
	local joint = entry.Joints.BedHinge
	if not joint then
		return
	end
	local value = Instance.new("NumberValue")
	value.Value = entry.BedAngle or 0
	value.Parent = entry.Model
	value.Changed:Connect(function(a)
		entry.BedAngle = a
		joint.Weld.C0 = joint.Base * CFrame.Angles(a, 0, 0)
	end)
	local tween = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Value = angle })
	tween:Play()
	tween.Completed:Wait()
	value:Destroy()
end

local function unload(entry, mode)
	entry.Unloading = true
	task.spawn(function()
		local pour = entry.Model:FindFirstChild("Pour", true)
		tiltBed(entry, 0.95, 0.7)
		if pour then
			pour.Enabled = true
		end
		task.wait(1.3)
		local kg = entry.Storage
		entry.Storage = 0
		setFill(entry)
		if kg > 0 and entry.Owner.Parent then
			if mode == "Sell" and VehicleService.Hooks.SellKg then
				VehicleService.Hooks.SellKg(entry.Owner, kg, entry.Chassis.Position)
			elseif mode == "Hopper" and VehicleService.Hooks.DepositHopper then
				VehicleService.Hooks.DepositHopper(entry.Owner, kg)
			end
		end
		task.wait(0.5)
		if pour then
			pour.Enabled = false
		end
		tiltBed(entry, 0, 0.8)
		entry.Unloading = false
		entry.CooldownUntil = os.clock() + 2
	end)
end

local function checkBays(entry)
	if entry.Unloading or entry.Storage <= 0.5 or os.clock() < entry.CooldownUntil then
		return
	end
	local position = entry.Chassis.Position
	if onPad(refs.KilnBay, position) then
		unload(entry, "Sell")
	elseif onPad(refs.HopperBay, position) then
		local data = VehicleService.Hooks.GetData and VehicleService.Hooks.GetData(entry.Owner)
		if data and data.Factory.Hopper then
			unload(entry, "Hopper")
		else
			entry.CooldownUntil = os.clock() + 4
			notify(entry.Owner, { Kind = "Toast", Text = "Buy the Input Hopper in Shop → Factory first.", Color = "Terracotta" })
		end
	end
end

--------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------
function VehicleService.Init(worldRefs)
	refs = worldRefs
	folder = Instance.new("Folder")
	folder.Name = "Vehicles"
	folder.Parent = Workspace:WaitForChild("SandsweepWorld")

	Players.PlayerRemoving:Connect(function(player)
		VehicleService.Despawn(player)
	end)

	local bladeTimer, bayTimer = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		bladeTimer += dt
		bayTimer += dt
		local bladeTick = bladeTimer >= 0.1
		local bayTick = bayTimer >= 0.25
		if bladeTick then
			bladeTimer = 0
		end
		if bayTick then
			bayTimer = 0
		end
		for player, entry in pairs(active) do
			if not entry.Model.Parent then
				active[player] = nil
			else
				if bladeTick and entry.Config.Id == "Bulldozer" and not LotService.Generating then
					carveBlade(entry)
				end
				if bayTick then
					checkBays(entry)
					if entry.Chassis.Position.Y < LotService.Min.Y - 20 then
						local target = pickSpawn()
						entry.Model:PivotTo(target)
						entry.Align.CFrame = yawOnly(target)
						entry.Chassis.AssemblyLinearVelocity = Vector3.zero
					end
				end
			end
		end
	end)
end

return VehicleService
