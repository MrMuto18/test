--!strict
--[[
	VehicleFx
	Per-client audio/visuals for EVERY drivable car, driven by replicated
	physics + the attributes the driver streams:

	  • engine loop pitch/volume from RPM + throttle (off when parked)
	  • tyre smoke + skid sound + skid marks painted on the road while the
	    rear slides (lateral slip) or the handbrake is pulled
	  • exhaust backfires: flame burst, sparks, light pop, bang
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)

local VehicleFx = {}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local MAX_MARKS = 260

type RearWheel = {
	Tire: BasePart,
	Smoke: ParticleEmitter,
	LastMark: Vector3?,
}

type CarFx = {
	Model: Model,
	Root: BasePart,
	Engine: Sound?,
	Skid: Sound?,
	Rear: { RearWheel },
	Exhausts: { Attachment },
	LastBackfires: number,
}

local cars: { [Model]: CarFx } = {}
local marks: { BasePart } = {}
local markFolder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function soundFor(name: string, fallback: string?): string
	local def = Config.Audio[name]
	if def and def.Id ~= "" then
		return def.Id
	end
	local alt = if fallback then Config.Audio[fallback] else nil
	return if alt then alt.Id else ""
end

local function loopSound(parent: Instance, name: string, id: string): Sound?
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 260
	local group = game:GetService("SoundService"):FindFirstChild("World")
	if group and group:IsA("SoundGroup") then
		sound.SoundGroup = group
	end
	sound.Parent = parent
	sound:Play()
	return sound
end

local function register(model: Instance)
	if not model:IsA("Model") or cars[model] then
		return
	end
	local root = model.PrimaryPart or model:WaitForChild("Root", 10)
	if not root or not root:IsA("BasePart") then
		return
	end
	local bay = model:FindFirstChild("EngineBay")
	local rear: { RearWheel } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Knuckle_RL" or d.Name == "Knuckle_RR") then
			local wheelModel = d.Parent
			local tire = if wheelModel and wheelModel:IsA("Model") then wheelModel.PrimaryPart else nil
			if tire then
				local contact = Instance.new("Attachment")
				contact.Name = "SmokeContact"
				contact.Position = Vector3.new(0, -1.1, 0)
				contact.Parent = d
				local smoke = Instance.new("ParticleEmitter")
				smoke.Name = "TyreSmoke"
				smoke.Texture = SMOKE
				smoke.Rate = 0
				smoke.Lifetime = NumberRange.new(1.4, 2.4)
				smoke.Speed = NumberRange.new(1, 3)
				smoke.SpreadAngle = Vector2.new(40, 40)
				smoke.Drag = 1.5
				smoke.Acceleration = Vector3.new(0, 1.5, 0)
				smoke.Rotation = NumberRange.new(0, 360)
				smoke.RotSpeed = NumberRange.new(-30, 30)
				smoke.LightInfluence = 1
				smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 6) })
				smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
				smoke.Color = ColorSequence.new(Color3.fromRGB(200, 200, 205))
				smoke.Parent = contact
				table.insert(rear, { Tire = tire, Smoke = smoke, LastMark = nil })
			end
		end
	end
	local exhausts: { Attachment } = {}
	for _, child in root:GetChildren() do
		if child:IsA("Attachment") and string.sub(child.Name, 1, 8) == "Exhaust_" then
			table.insert(exhausts, child)
		end
	end
	local backfires = model:GetAttribute("Backfires")
	cars[model] = {
		Model = model,
		Root = root,
		Engine = loopSound(bay or root, "EngineLoop", soundFor("EngineLoop", "EngineIdle")),
		Skid = loopSound(root, "TireSkid", soundFor("TireSkid")),
		Rear = rear,
		Exhausts = exhausts,
		LastBackfires = if typeof(backfires) == "number" then backfires else 0,
	}
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			cars[model] = nil
		end
	end)
end

local function backfire(fx: CarFx)
	for _, exhaust in fx.Exhausts do
		local flame = Instance.new("ParticleEmitter")
		flame.Texture = SPARK
		flame.EmissionDirection = Enum.NormalId.Back
		flame.Rate = 0
		flame.LightEmission = 1
		flame.LightInfluence = 0
		flame.Lifetime = NumberRange.new(0.06, 0.12)
		flame.Speed = NumberRange.new(8, 14)
		flame.SpreadAngle = Vector2.new(12, 12)
		flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1) })
		flame.Color = ColorSequence.new(Color3.fromRGB(120, 170, 255), Color3.fromRGB(255, 140, 50))
		flame.Parent = exhaust
		flame:Emit(4)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 150, 70)
		light.Range = 10
		light.Brightness = 6
		light.Parent = exhaust
		Debris:AddItem(flame, 0.4)
		Debris:AddItem(light, 0.07)
	end
	local def = Config.Audio.Backfire
	if def and def.Id ~= "" and fx.Exhausts[1] then
		local bang = Instance.new("Sound")
		bang.SoundId = def.Id
		bang.Volume = def.Volume
		bang.PlaybackSpeed = def.Speed * (0.9 + math.random() * 0.2)
		bang.RollOffMaxDistance = 300
		bang.Parent = fx.Exhausts[1]
		bang:Play()
		Debris:AddItem(bang, 2)
	end
end

local function skidMark(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	if length < 0.05 then
		return
	end
	local mark = Instance.new("Part")
	mark.Name = "SkidMark"
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	mark.CastShadow = false
	mark.Material = Enum.Material.SmoothPlastic
	mark.Color = Color3.fromRGB(12, 12, 12)
	mark.Transparency = 0.35
	mark.Size = Vector3.new(0.6, 0.02, length + 0.05)
	mark.CFrame = CFrame.lookAt((from + to) / 2, to)
	mark.Parent = markFolder
	table.insert(marks, mark)
	Debris:AddItem(mark, 15)
	if #marks > MAX_MARKS then
		local old = table.remove(marks, 1)
		if old and old.Parent then
			old:Destroy()
		end
	end
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else Vector3.zero
	for model, fx in cars do
		local root = fx.Root
		if (root.Position - camPos).Magnitude > 320 then
			if fx.Engine then
				fx.Engine.Volume = 0
			end
			continue
		end
		local velocity = root.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local speed = flat.Magnitude
		local slip = math.abs(root.CFrame.RightVector:Dot(velocity))
		local driven = (model:GetAttribute("Driver") or 0) ~= 0
		local handbrake = model:GetAttribute("Handbrake") == true
		local drifting = speed > 12 and (slip > 9 or handbrake)
		local intensity = if drifting then math.clamp(slip / 30 + (if handbrake then 0.3 else 0), 0.2, 1) else 0

		local engine = fx.Engine
		if engine then
			local rpm = model:GetAttribute("RPM")
			local throttle = model:GetAttribute("Throttle")
			local r = if typeof(rpm) == "number" then rpm else 0
			local t = if typeof(throttle) == "number" then math.abs(throttle) else 0
			local targetVolume = if driven then 0.3 + t * 0.35 + r * 0.15 else 0
			engine.Volume += (targetVolume - engine.Volume) * (1 - math.exp(-dt * 6))
			engine.PlaybackSpeed = 0.7 + r * 1.3
		end
		local skid = fx.Skid
		if skid then
			skid.Volume += (intensity * 0.6 - skid.Volume) * (1 - math.exp(-dt * 10))
			skid.PlaybackSpeed = 0.9 + intensity * 0.2
		end

		rayParams.FilterDescendantsInstances = { model, markFolder }
		for _, wheel in fx.Rear do
			wheel.Smoke.Rate = intensity * 45
			if drifting then
				local hit = Workspace:Raycast(wheel.Tire.Position, Vector3.new(0, -2, 0), rayParams)
				if hit then
					local point = hit.Position + hit.Normal * 0.012
					local last = wheel.LastMark
					if last and (point - last).Magnitude < 4 then
						if (point - last).Magnitude > 0.6 then
							skidMark(last, point)
							wheel.LastMark = point
						end
					else
						wheel.LastMark = point
					end
				else
					wheel.LastMark = nil
				end
			else
				wheel.LastMark = nil
			end
		end

		local count = model:GetAttribute("Backfires")
		if typeof(count) == "number" and count ~= fx.LastBackfires then
			if count > fx.LastBackfires then
				backfire(fx)
			end
			fx.LastBackfires = count
		end
	end
end

function VehicleFx.init()
	local folder = Instance.new("Folder")
	folder.Name = "SkidMarks"
	folder.Parent = Workspace
	markFolder = folder
	for _, model in CollectionService:GetTagged("DrivableCar") do
		task.spawn(register, model)
	end
	CollectionService:GetInstanceAddedSignal("DrivableCar"):Connect(function(model: Instance)
		task.spawn(register, model)
	end)
	RunService.RenderStepped:Connect(update)
end

return VehicleFx
