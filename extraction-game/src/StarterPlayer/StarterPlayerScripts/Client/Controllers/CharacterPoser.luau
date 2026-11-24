--!strict
--[[
	CharacterPoser
	Procedural third-person poses for EVERY character, solved locally on each
	client (no animation assets needed):

	  • Upper body follows aim pitch (Waist + Neck Motor6D C0 offsets)
	  • Weapon Motor6D ("WeaponGrip", created by the server) is posed from the
	    weapon class hold offsets: hip ↔ ADS blend, pitch, sprint low-ready,
	    and a local recoil kick spring for your own gun
	  • Both hands are IK-locked to the weapon's GripRight / GripLeft
	  • Crouch / slide: leg IK keeps feet planted while HipHeight drops, with a
	    procedural crouch-walk step cycle driven by velocity

	Inputs come from replicated character attributes (Stance, Sprinting,
	AimPitch, Aiming, WeaponClass). Your own character reads the live camera
	pitch instead, so it never lags behind your aim.

	Requires R15 rigs (Game Settings → Avatar → R15). R6 characters are skipped.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Spring = require(Shared.Spring)
local WeaponBuilder = require(Shared.Builders.WeaponBuilder)

local TacticalCamera = require(script.Parent.TacticalCamera)

local CharacterPoser = {}

local localPlayer = Players.LocalPlayer
local COMBAT = Config.Combat

type Record = {
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	UpperTorso: BasePart,
	Waist: Motor6D?,
	Neck: Motor6D?,
	WaistC0: CFrame,
	NeckC0: CFrame,
	BaseHip: number,
	IsLocal: boolean,
	Pitch: number,
	Aim: number,
	Crouch: number,
	Slide: number,
	Sprint: number,
	StepPhase: number,
	Kick: Spring.Spring?,
	WeaponModel: Model?,
	ArmRight: IKControl,
	ArmLeft: IKControl,
	LegRight: IKControl,
	LegLeft: IKControl,
	FootRight: Attachment,
	FootLeft: Attachment,
	Instances: { Instance },
}

local records: { [Model]: Record } = {}
local localAiming = false

local function smooth(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

local function newAttachment(parent: BasePart, name: string, position: Vector3, list: { Instance }): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = parent
	table.insert(list, attachment)
	return attachment
end

local function newIK(record: { Humanoid: Humanoid }, name: string, chainRoot: BasePart, endEffector: BasePart, pole: Attachment, list: { Instance }): IKControl
	local ik = Instance.new("IKControl")
	ik.Name = name
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot = chainRoot
	ik.EndEffector = endEffector
	ik.Pole = pole
	ik.Priority = 1
	ik.Weight = 0
	ik.Enabled = false
	pcall(function()
		(ik :: any).SmoothTime = 0.03
	end)
	ik.Parent = record.Humanoid
	table.insert(list, ik)
	return ik
end

local function part(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

local function register(character: Model, isLocal: boolean)
	if records[character] then
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local upper = character:WaitForChild("UpperTorso", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") or not upper or not upper:IsA("BasePart") then
		return -- R6 or broken rig: no procedural pose
	end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local rightUpperArm = part(character, "RightUpperArm")
	local rightHand = part(character, "RightHand")
	local leftUpperArm = part(character, "LeftUpperArm")
	local leftHand = part(character, "LeftHand")
	local rightUpperLeg = part(character, "RightUpperLeg")
	local rightFoot = part(character, "RightFoot")
	local leftUpperLeg = part(character, "LeftUpperLeg")
	local leftFoot = part(character, "LeftFoot")
	if not (rightUpperArm and rightHand and leftUpperArm and leftHand and rightUpperLeg and rightFoot and leftUpperLeg and leftFoot) then
		return
	end

	local waist = upper:FindFirstChild("Waist")
	local head = part(character, "Head")
	local neck = if head then head:FindFirstChild("Neck") else nil
	local instances: { Instance } = {}
	local holder = { Humanoid = humanoid }

	local armPoleR = newAttachment(upper, "PoseArmPoleR", Vector3.new(1.6, -1.4, 0.8), instances)
	local armPoleL = newAttachment(upper, "PoseArmPoleL", Vector3.new(-1.6, -1.4, 0.4), instances)
	local kneePoleR = newAttachment(root, "PoseKneePoleR", Vector3.new(0.6, -1, -3), instances)
	local kneePoleL = newAttachment(root, "PoseKneePoleL", Vector3.new(-0.6, -1, -3), instances)
	local footR = newAttachment(root, "PoseFootR", Vector3.new(0.45, -3, 0), instances)
	local footL = newAttachment(root, "PoseFootL", Vector3.new(-0.45, -3, 0), instances)

	local legR = newIK(holder, "PoseLegR", rightUpperLeg, rightFoot, kneePoleR, instances)
	local legL = newIK(holder, "PoseLegL", leftUpperLeg, leftFoot, kneePoleL, instances)
	legR.Target = footR
	legL.Target = footL

	local record: Record = {
		Character = character,
		Humanoid = humanoid,
		Root = root,
		UpperTorso = upper,
		Waist = if waist and waist:IsA("Motor6D") then waist else nil,
		Neck = if neck and neck:IsA("Motor6D") then neck else nil,
		WaistC0 = if waist and waist:IsA("Motor6D") then waist.C0 else CFrame.identity,
		NeckC0 = if neck and neck:IsA("Motor6D") then neck.C0 else CFrame.identity,
		BaseHip = humanoid.HipHeight,
		IsLocal = isLocal,
		Pitch = 0,
		Aim = 0,
		Crouch = 0,
		Slide = 0,
		Sprint = 0,
		StepPhase = 0,
		Kick = if isLocal then Spring.new(Vector3.zero, 11, 0.5) else nil,
		WeaponModel = nil,
		ArmRight = newIK(holder, "PoseArmR", rightUpperArm, rightHand, armPoleR, instances),
		ArmLeft = newIK(holder, "PoseArmL", leftUpperArm, leftHand, armPoleL, instances),
		LegRight = legR,
		LegLeft = legL,
		FootRight = footR,
		FootLeft = footL,
		Instances = instances,
	}
	records[character] = record

	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			for _, inst in record.Instances do
				inst:Destroy()
			end
			records[character] = nil
		end
	end)
end

local function attrNumber(model: Model, name: string): number
	local v = model:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

local function poseWeapon(record: Record, dt: number)
	local character = record.Character
	local grip = record.UpperTorso:FindFirstChild("WeaponGrip")
	local model = character:FindFirstChild("EquippedWeapon")
	if not grip or not grip:IsA("Motor6D") or not model or not model:IsA("Model") then
		record.ArmRight.Enabled = false
		record.ArmLeft.Enabled = false
		record.WeaponModel = nil
		return
	end

	if record.WeaponModel ~= model then
		local handles = WeaponBuilder.resolve(model)
		if not handles then
			return
		end
		record.WeaponModel = model
		record.ArmRight.Target = handles.GripRight
		record.ArmLeft.Target = handles.GripLeft
	end
	record.ArmRight.Enabled = true
	record.ArmLeft.Enabled = true
	record.ArmRight.Weight = 1
	record.ArmLeft.Weight = 1

	local class = character:GetAttribute("WeaponClass")
	local offsets = COMBAT.HoldOffsets[if typeof(class) == "string" then class else "RIFLE"] or COMBAT.HoldOffsets.RIFLE
	local position = offsets.Hip:Lerp(offsets.Ads, record.Aim)
	local pivot = COMBAT.PosePivot

	local kickBack, kickRot = 0, 0
	local kick = record.Kick
	if kick then
		kick.Target = Vector3.zero
		local k = kick:update(dt)
		kickBack, kickRot = k.X, k.Y
	end

	-- Low-ready when sprinting: barrel down and across the body.
	local sprint = record.Sprint
	local rotation = CFrame.Angles(record.Pitch * 0.55 - sprint * 0.75 + kickRot, sprint * 0.55, sprint * 0.2)
	grip.C0 = CFrame.new(pivot) * rotation * CFrame.new(position - pivot + Vector3.new(0, 0, kickBack))
end

local function poseLegs(record: Record, dt: number)
	local crouch = record.Crouch
	local enabled = crouch > 0.02
	record.LegRight.Enabled = enabled
	record.LegLeft.Enabled = enabled
	if not enabled then
		return
	end
	record.LegRight.Weight = crouch
	record.LegLeft.Weight = crouch

	local root = record.Root
	local hip = record.BaseHip - Config.Movement.CrouchHipDrop * crouch
	local groundY = -(hip + root.Size.Y * 0.5) + 0.12

	local velocity = root.AssemblyLinearVelocity
	local localVel = root.CFrame:VectorToObjectSpace(Vector3.new(velocity.X, 0, velocity.Z))
	local speed = localVel.Magnitude
	record.StepPhase += speed * dt * 1.4
	local stride = math.clamp(speed / 7, 0, 1) * 0.55 * (1 - record.Slide)
	local dir = if speed > 0.5 then localVel.Unit else Vector3.zero

	local function foot(attachment: Attachment, side: number, phaseOffset: number, idleZ: number, slideZ: number)
		local phase = record.StepPhase + phaseOffset
		local stepOffset = dir * math.sin(phase) * stride
		local lift = math.max(0, math.cos(phase)) * 0.3 * math.clamp(stride * 2, 0, 1)
		local z = idleZ + (slideZ - idleZ) * record.Slide
		attachment.Position = Vector3.new(side * 0.45 + stepOffset.X, groundY + lift + record.Slide * 0.25 * (if side > 0 then 1 else 0), z + stepOffset.Z)
	end
	foot(record.FootRight, 1, 0, -0.35, -1.2)
	foot(record.FootLeft, -1, math.pi, 0.25, -0.5)
end

local function step(dt: number)
	for character, record in records do
		if not character.Parent or record.Humanoid.Health <= 0 then
			record.ArmRight.Enabled = false
			record.ArmLeft.Enabled = false
			record.LegRight.Enabled = false
			record.LegLeft.Enabled = false
			continue
		end

		local pitchTarget = if record.IsLocal and TacticalCamera.isAttached()
			then TacticalCamera.getPitch()
			else attrNumber(character, "AimPitch")
		record.Pitch = smooth(record.Pitch, pitchTarget, if record.IsLocal then 30 else 12, dt)

		local aimTarget = if record.IsLocal then (if localAiming then 1 else 0) else (if character:GetAttribute("Aiming") == true then 1 else 0)
		record.Aim = smooth(record.Aim, aimTarget, 14, dt)

		local stance = character:GetAttribute("Stance")
		record.Crouch = smooth(record.Crouch, if stance == "Crouch" or stance == "Slide" then 1 else 0, 12, dt)
		record.Slide = smooth(record.Slide, if stance == "Slide" then 1 else 0, 14, dt)
		record.Sprint = smooth(record.Sprint, if character:GetAttribute("Sprinting") == true then 1 else 0, 10, dt)

		local waist = record.Waist
		if waist then
			waist.C0 = record.WaistC0 * CFrame.Angles(record.Pitch * 0.45 * (1 - record.Sprint * 0.6), 0, 0)
		end
		local neck = record.Neck
		if neck then
			neck.C0 = record.NeckC0 * CFrame.Angles(record.Pitch * 0.35, 0, 0)
		end

		poseWeapon(record, dt)
		poseLegs(record, dt)
	end
end

local function watchPlayer(player: Player)
	local isLocal = player == localPlayer
	if player.Character then
		task.spawn(register, player.Character, isLocal)
	end
	player.CharacterAdded:Connect(function(character: Model)
		register(character, isLocal)
	end)
end

function CharacterPoser.init()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	-- PreSimulation runs after the Animator, so these C0 offsets layer on top
	-- of the default animations and IK solves on the final pose.
	RunService.PreSimulation:Connect(step)
end

function CharacterPoser.setLocalAim(aiming: boolean)
	localAiming = aiming
end

-- Local weapon kick: back = studs pushed toward the shoulder, rise = radians.
function CharacterPoser.kick(back: number, rise: number)
	local character = localPlayer.Character
	local record = if character then records[character] else nil
	local spring = if record then record.Kick else nil
	if spring then
		spring:impulse(Vector3.new(back * 30, rise * 30, 0))
	end
end

return CharacterPoser
