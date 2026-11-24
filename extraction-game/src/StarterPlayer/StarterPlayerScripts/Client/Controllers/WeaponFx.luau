--!strict
--[[
	WeaponFx
	Client-side gunfire visuals and audio, used for your own predicted shots
	and for other players' replicated shots:

	  muzzleFlash   PointLight pop + star burst + smoke wisp (smaller if suppressed)
	  tracer        neon streak travelling at bullet speed, culled when done
	  impact        sparks on metal, dust elsewhere, hit puff on characters,
	                plus pooled bullet holes on static geometry
	  shell         physical brass ejecting right/up (Debris collision group)
	  dropMagazine  physical mag falls out during reloads
	  sound         3D one-shots at the muzzle (skipped if no asset id)
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)

local WeaponFx = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TRACER_SPEED = 1100
local TRACER_LENGTH = 3.5
local MAX_TRACERS = 48
local MAX_HOLES = 60
local MAX_SHELLS = 30

local METALLIC: { [string]: boolean } = {
	Metal = true,
	DiamondPlate = true,
	CorrodedMetal = true,
	Foil = true,
}

type Tracer = {
	Part: BasePart,
	From: Vector3,
	Dir: Vector3,
	Total: number,
	Travelled: number,
}

local folder: Folder
local tracers: { Tracer } = {}
local holes: { BasePart } = {}
local shells: { BasePart } = {}
local rng = Random.new()

local function particle(parent: Instance, name: string, props: { [string]: any }): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Enabled = false
	emitter.Rate = 0
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = parent
	return emitter
end

-- Lazily equips a muzzle attachment with its flash rig.
local function flashRig(muzzle: Attachment): (PointLight, ParticleEmitter, ParticleEmitter)
	local light = muzzle:FindFirstChild("FxFlash")
	local core = muzzle:FindFirstChild("FxFlashCore")
	local smoke = muzzle:FindFirstChild("FxFlashSmoke")
	if light and light:IsA("PointLight") and core and core:IsA("ParticleEmitter") and smoke and smoke:IsA("ParticleEmitter") then
		return light, core, smoke
	end
	local newLight = Instance.new("PointLight")
	newLight.Name = "FxFlash"
	newLight.Color = Color3.fromRGB(255, 190, 110)
	newLight.Range = 12
	newLight.Brightness = 8
	newLight.Shadows = false
	newLight.Enabled = false
	newLight.Parent = muzzle
	local newCore = particle(muzzle, "FxFlashCore", {
		Texture = SPARK,
		LightEmission = 1,
		LightInfluence = 0,
		LockedToPart = true,
		Lifetime = NumberRange.new(0.04, 0.06),
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 360),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.1) }),
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 120, 40)),
		ZOffset = 0.5,
	})
	local newSmoke = particle(muzzle, "FxFlashSmoke", {
		Texture = SMOKE,
		EmissionDirection = Enum.NormalId.Front,
		LightInfluence = 1,
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(15, 15),
		Drag = 3,
		Acceleration = Vector3.new(0, 1.5, 0),
		Rotation = NumberRange.new(0, 360),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1.2) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(170, 170, 170)),
	})
	return newLight, newCore, newSmoke
end

function WeaponFx.muzzleFlash(muzzle: Attachment, suppressed: boolean)
	local light, core, smoke = flashRig(muzzle)
	light.Brightness = if suppressed then 2.5 else 8
	light.Range = if suppressed then 7 else 12
	light.Enabled = true
	task.delay(0.045, function()
		light.Enabled = false
	end)
	if not suppressed then
		core:Emit(2)
	end
	smoke:Emit(if suppressed then 2 else 1)
end

function WeaponFx.tracer(from: Vector3, to: Vector3, color: Color3)
	local offset = to - from
	local total = offset.Magnitude
	if total < 4 then
		return
	end
	if #tracers >= MAX_TRACERS then
		local oldest = table.remove(tracers, 1)
		if oldest then
			oldest.Part:Destroy()
		end
	end
	local part = Instance.new("Part")
	part.Name = "Tracer"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.25
	part.Size = Vector3.new(0.05, 0.05, 0.1)
	part.CFrame = CFrame.lookAt(from, to)
	part.Parent = folder
	table.insert(tracers, { Part = part, From = from, Dir = offset.Unit, Total = total, Travelled = 0 })
end

local function updateTracers(dt: number)
	for i = #tracers, 1, -1 do
		local t = tracers[i]
		t.Travelled += TRACER_SPEED * dt
		local headDist = math.min(t.Travelled, t.Total)
		local tailDist = math.clamp(t.Travelled - TRACER_LENGTH, 0, t.Total)
		if tailDist >= t.Total then
			t.Part:Destroy()
			table.remove(tracers, i)
		else
			local head = t.From + t.Dir * headDist
			local tail = t.From + t.Dir * tailDist
			local length = math.max((head - tail).Magnitude, 0.05)
			t.Part.Size = Vector3.new(0.05, 0.05, length)
			t.Part.CFrame = CFrame.lookAt((head + tail) / 2, head)
		end
	end
end

local function burst(position: Vector3, normal: Vector3, props: { [string]: any }, count: number)
	local attachment = Instance.new("Attachment")
	attachment.WorldCFrame = CFrame.lookAt(position, position + normal)
	attachment.Parent = Workspace.Terrain
	local emitter = particle(attachment, "Burst", props)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter:Emit(count)
	Debris:AddItem(attachment, 2)
end

function WeaponFx.impact(position: Vector3, normal: Vector3, materialName: string, hitInstance: Instance?)
	local isCharacter = false
	if hitInstance then
		local model = hitInstance:FindFirstAncestorOfClass("Model")
		isCharacter = model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
	end

	if isCharacter then
		burst(position, normal, {
			Texture = SMOKE,
			LightInfluence = 1,
			Lifetime = NumberRange.new(0.2, 0.35),
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(40, 40),
			Drag = 4,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.9) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
			Color = ColorSequence.new(Color3.fromRGB(110, 20, 20)),
		}, 4)
		return
	end

	if METALLIC[materialName] then
		burst(position, normal, {
			Texture = SPARK,
			LightEmission = 1,
			LightInfluence = 0,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Lifetime = NumberRange.new(0.12, 0.3),
			Speed = NumberRange.new(14, 28),
			SpreadAngle = Vector2.new(55, 55),
			Acceleration = Vector3.new(0, -60, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) }),
			Squash = NumberSequence.new(-2),
			Color = ColorSequence.new(Color3.fromRGB(255, 210, 140), Color3.fromRGB(255, 120, 40)),
		}, 9)
	end
	burst(position, normal, {
		Texture = SMOKE,
		LightInfluence = 1,
		Lifetime = NumberRange.new(0.5, 1.0),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(30, 30),
		Drag = 3,
		Acceleration = Vector3.new(0, -2, 0),
		Rotation = NumberRange.new(0, 360),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(120, 112, 104)),
	}, if METALLIC[materialName] then 2 else 5)

	-- Bullet hole on static geometry only.
	if hitInstance and hitInstance:IsA("BasePart") and hitInstance.Anchored then
		local hole = Instance.new("Part")
		hole.Name = "BulletHole"
		hole.Shape = Enum.PartType.Cylinder
		hole.Size = Vector3.new(0.02, 0.16, 0.16)
		hole.Anchored = true
		hole.CanCollide = false
		hole.CanQuery = false
		hole.CanTouch = false
		hole.CastShadow = false
		hole.Material = Enum.Material.SmoothPlastic
		hole.Color = Color3.fromRGB(14, 13, 12)
		hole.CFrame = CFrame.lookAt(position + normal * 0.012, position + normal * 2) * CFrame.Angles(0, math.rad(90), 0)
		hole.Parent = folder
		table.insert(holes, hole)
		if #holes > MAX_HOLES then
			local old = table.remove(holes, 1)
			if old then
				old:Destroy()
			end
		end
	end
end

local function debrisPart(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.CanCollide = true
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CollisionGroup = "Debris"
	part.Parent = folder
	return part
end

function WeaponFx.shell(ejection: Attachment, class: string, inheritVelocity: Vector3)
	local cf = ejection.WorldCFrame
	local length = if class == "PISTOL" then 0.1 else 0.16
	local shell = debrisPart("Shell", Vector3.new(0.05, 0.05, length), cf, Color3.fromRGB(190, 150, 70), Enum.Material.Metal)
	shell.Reflectance = 0.2
	shell.AssemblyLinearVelocity = inheritVelocity + cf.RightVector * rng:NextNumber(6, 9) + cf.UpVector * rng:NextNumber(4, 6) + cf.LookVector * rng:NextNumber(-1, 1)
	shell.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-30, 30), rng:NextNumber(-30, 30), rng:NextNumber(-30, 30))
	table.insert(shells, shell)
	if #shells > MAX_SHELLS then
		local old = table.remove(shells, 1)
		if old then
			old:Destroy()
		end
	end
	Debris:AddItem(shell, 2.5)
end

-- Clones the magazine parts as falling debris and hides the originals until restoreAfter.
function WeaponFx.dropMagazine(parts: { BasePart }, restoreAfter: number)
	if #parts == 0 then
		return
	end
	local first: BasePart? = nil
	for _, original in parts do
		local copy = debrisPart("DroppedMag", original.Size, original.CFrame, original.Color, original.Material)
		if first then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = first
			weld.Part1 = copy
			weld.Parent = copy
		else
			first = copy
		end
		Debris:AddItem(copy, 4)
		original.LocalTransparencyModifier = 1
	end
	local lead = first
	if lead then
		lead.AssemblyLinearVelocity = Vector3.new(0, -4, 0)
		lead.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
	end
	task.delay(restoreAfter, function()
		for _, original in parts do
			original.LocalTransparencyModifier = 0
		end
	end)
end

function WeaponFx.restoreMagazine(parts: { BasePart })
	for _, original in parts do
		original.LocalTransparencyModifier = 0
	end
end

function WeaponFx.sound(name: string, at: Instance, volumeScale: number?)
	local def = Config.Audio[name]
	if not def or def.Id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Volume = def.Volume * (volumeScale or 1)
	sound.PlaybackSpeed = def.Speed * rng:NextNumber(0.95, 1.05)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 350
	local group = game:GetService("SoundService"):FindFirstChild(def.Group)
	if group and group:IsA("SoundGroup") then
		sound.SoundGroup = group
	end
	sound.Parent = at
	sound:Play()
	Debris:AddItem(sound, 4)
end

function WeaponFx.getFolder(): Folder
	return folder
end

function WeaponFx.init()
	local f = Instance.new("Folder")
	f.Name = "WeaponFX"
	f.Parent = Workspace
	folder = f
	RunService.RenderStepped:Connect(updateTracers)
end

return WeaponFx
