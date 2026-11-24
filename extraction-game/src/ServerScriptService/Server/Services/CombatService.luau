--!strict
--[[
	CombatService
	Server-authoritative gunplay.

	Client predicts everything visual (tracer, flash, recoil, hitmarker
	preview) and sends Fire(shotId, muzzle, direction). The server owns the
	truth:

	  • equipped weapon, magazine + reserve ammo, reload timers, draw time
	  • fire rate via a token bucket (tolerates network jitter, blocks macros)
	  • muzzle must be near the shooter's head and in line of sight from it
	    (no shooting through walls from a muzzle poked through geometry)
	  • its own raycast decides what was hit; damage falloff + headshots
	  • PvP gate (safehouse is a safe zone in Phase 2)

	Results: HitConfirm -> shooter, ShotFx -> everyone else, AmmoSync -> owner.
	Also replicates stance/aim attributes that drive procedural poses.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Schema = require(Shared.Schema)
local Types = require(Shared.Types)
local WeaponBuilder = require(Shared.Builders.WeaponBuilder)

local CombatService = {}

type WeaponState = {
	Id: string,
	Slot: Types.WeaponSlot,
	Def: Types.WeaponDef,
	Mag: number,
	Reserve: number,
	Tokens: number,
	LastShot: number,
	Reloading: boolean,
	ReloadToken: number,
	Handles: WeaponBuilder.WeaponHandles,
	Joint: JointInstance?,
}

type Combatant = {
	Player: Player,
	Character: Model,
	Humanoid: Humanoid,
	Head: BasePart,
	Torso: BasePart,
	Weapons: { [Types.WeaponSlot]: WeaponState },
	Equipped: Types.WeaponSlot,
	ReadyAt: number,
	LastAim: number,
	LastStance: number,
	Holstered: boolean,
}

local SLOTS: { Types.WeaponSlot } = { "Primary", "Secondary" }
local VALID_STANCES = { Stand = true, Crouch = true, Slide = true }

local combatants: { [Player]: Combatant } = {}

local hitConfirm: RemoteEvent
local ammoSync: RemoteEvent
local shotFx: UnreliableRemoteEvent

local function isFiniteVector(v: Vector3): boolean
	return Schema.isFiniteNumber(v.X) and Schema.isFiniteNumber(v.Y) and Schema.isFiniteNumber(v.Z)
end

local function sync(player: Player, weapon: WeaponState)
	ammoSync:FireClient(player, weapon.Slot, weapon.Mag, weapon.Reserve, weapon.Reloading)
end

--------------------------------------------------------------------------------
-- Collision groups: shell casings and debris never push characters around.
--------------------------------------------------------------------------------
local function setupCollisionGroups()
	for _, name in { "Characters", "Debris" } do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(name)
		end)
	end
	PhysicsService:CollisionGroupSetCollidable("Debris", "Characters", false)
	PhysicsService:CollisionGroupSetCollidable("Debris", "Debris", false)
end

local function assignCharacterGroup(character: Model)
	local function apply(d: Instance)
		if d:IsA("BasePart") then
			d.CollisionGroup = "Characters"
		end
	end
	for _, d in character:GetDescendants() do
		apply(d)
	end
	character.DescendantAdded:Connect(apply)
end

--------------------------------------------------------------------------------
-- Holster / equip joints
--------------------------------------------------------------------------------
local function limb(character: Model, r15: string, r6: string): BasePart?
	local part = character:FindFirstChild(r15) or character:FindFirstChild(r6)
	return if part and part:IsA("BasePart") then part else nil
end

local function clearJoint(weapon: WeaponState)
	local joint = weapon.Joint
	if joint then
		joint:Destroy()
		weapon.Joint = nil
	end
end

local function holster(c: Combatant, weapon: WeaponState)
	clearJoint(weapon)
	local weld = Instance.new("Weld")
	weld.Name = "Holster"
	if weapon.Slot == "Primary" then
		-- Slung diagonally across the back, barrel up-left.
		weld.Part0 = c.Torso
		weld.C0 = CFrame.new(0.5, -0.3, 0.62) * CFrame.Angles(0, 0, math.rad(-40)) * CFrame.Angles(0, math.rad(90), 0)
	else
		-- Thigh holster, barrel down.
		local thigh = limb(c.Character, "RightUpperLeg", "Right Leg") or c.Torso
		weld.Part0 = thigh
		weld.C0 = CFrame.new(0.58, 0.15, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	end
	weld.Part1 = weapon.Handles.Handle
	weld.Parent = weld.Part0
	weapon.Joint = weld
	weapon.Handles.Model.Name = "Holstered_" .. weapon.Slot
end

-- R15 tool grip frame: barrel (-Z) runs along the hand's pointing direction.
local DEFAULT_GRIP = CFrame.new(0, -0.15, 0) * CFrame.Angles(math.rad(-90), 0, 0)

local function equip(c: Combatant, weapon: WeaponState)
	clearJoint(weapon)
	local hand = limb(c.Character, "RightHand", "Right Arm") or c.Torso
	local gripAttachment = hand:FindFirstChild("RightGripAttachment")
	local weld = Instance.new("Weld")
	weld.Name = "WeaponGrip"
	weld.Part0 = hand
	weld.Part1 = weapon.Handles.Handle
	weld.C0 = if gripAttachment and gripAttachment:IsA("Attachment") then gripAttachment.CFrame else DEFAULT_GRIP
	weld.Parent = hand
	weapon.Joint = weld
	weapon.Handles.Model.Name = "EquippedWeapon"
	c.Character:SetAttribute("EquippedWeapon", weapon.Id)
	c.Character:SetAttribute("WeaponClass", weapon.Def.Class)
end

local function cancelReload(player: Player, weapon: WeaponState)
	if weapon.Reloading then
		weapon.Reloading = false
		weapon.ReloadToken += 1
		sync(player, weapon)
	end
end

--------------------------------------------------------------------------------
-- Damage
--------------------------------------------------------------------------------
local function findHumanoid(part: BasePart): (Humanoid?, Model?)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid, model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil, nil
end

local function falloff(combat: Types.WeaponCombat, distance: number): number
	if distance <= combat.FalloffStart then
		return 1
	end
	local t = math.clamp((distance - combat.FalloffStart) / math.max(combat.Range - combat.FalloffStart, 1), 0, 1)
	return 1 + (combat.MinDamageRatio - 1) * t
end

local function applyHit(c: Combatant, weapon: WeaponState, result: RaycastResult, distance: number)
	local part = result.Instance
	if not part:IsA("BasePart") then
		return
	end
	local humanoid, model = findHumanoid(part)
	if not humanoid or not model or model == c.Character or humanoid.Health <= 0 then
		return
	end
	if Players:GetPlayerFromCharacter(model) and not Config.Combat.PvPEnabled then
		hitConfirm:FireClient(c.Player, "Blocked", 0, result.Position)
		return
	end

	local combat = weapon.Def.Combat
	local headshot = part.Name == "Head"
	local damage = combat.Damage * falloff(combat, distance) * (if headshot then combat.HeadMultiplier else 1)
	humanoid:TakeDamage(damage)
	model:SetAttribute("LastHitBy", c.Player.UserId)

	local kind = if humanoid.Health <= 0 then "Kill" elseif headshot then "Head" else "Body"
	hitConfirm:FireClient(c.Player, kind, math.round(damage), result.Position)
end

--------------------------------------------------------------------------------
-- Remote handlers
--------------------------------------------------------------------------------
local function onFire(player: Player, _shotId: any, origin: any, direction: any)
	local c = combatants[player]
	if not c or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if not isFiniteVector(origin) or not isFiniteVector(direction) or direction.Magnitude < 0.5 then
		return
	end
	if c.Humanoid.Health <= 0 or c.Holstered or player:GetAttribute("State") ~= "Deployed" then
		return
	end

	local now = os.clock()
	if now < c.ReadyAt then
		return
	end
	local weapon = c.Weapons[c.Equipped]
	local combat = weapon.Def.Combat
	if weapon.Reloading or weapon.Mag <= 0 then
		sync(player, weapon)
		return
	end

	-- Fire-rate token bucket
	local interval = 60 / combat.RPM
	local refill = (now - weapon.LastShot) / (interval * Config.Combat.FireRateTolerance)
	weapon.Tokens = math.min(Config.Combat.ShotBurstAllowance, weapon.Tokens + refill)
	weapon.LastShot = now
	if weapon.Tokens < 1 then
		return
	end
	weapon.Tokens -= 1

	-- Origin sanity + line of sight from the head to the claimed muzzle.
	local headPos = c.Head.Position
	if (origin - headPos).Magnitude > Config.Combat.MaxOriginDistance then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { c.Character }
	local blocked = Workspace:Raycast(headPos, origin - headPos, params)
	local shotOrigin = if blocked then headPos else origin

	weapon.Mag -= 1

	local dir = direction.Unit
	local result = Workspace:Raycast(shotOrigin, dir * combat.Range, params)
	local hitPos = shotOrigin + dir * combat.Range
	local normal = -dir
	local material = "Air"
	if result then
		hitPos = result.Position
		normal = result.Normal
		material = result.Material.Name
		applyHit(c, weapon, result, (hitPos - shotOrigin).Magnitude)
	end

	for _, other in Players:GetPlayers() do
		if other ~= player then
			shotFx:FireClient(other, c.Character, weapon.Id, shotOrigin, hitPos, normal, material)
		end
	end
end

local function onReload(player: Player)
	local c = combatants[player]
	if not c or c.Humanoid.Health <= 0 then
		return
	end
	local weapon = c.Weapons[c.Equipped]
	local combat = weapon.Def.Combat
	if weapon.Reloading or weapon.Mag >= combat.MagSize or weapon.Reserve <= 0 then
		sync(player, weapon)
		return
	end
	weapon.Reloading = true
	weapon.ReloadToken += 1
	local token = weapon.ReloadToken
	local duration = if weapon.Mag == 0 then combat.EmptyReloadTime else combat.ReloadTime
	task.delay(duration, function()
		if combatants[player] ~= c or weapon.ReloadToken ~= token or not weapon.Reloading then
			return
		end
		local take = math.min(combat.MagSize - weapon.Mag, weapon.Reserve)
		weapon.Mag += take
		weapon.Reserve -= take
		weapon.Reloading = false
		sync(player, weapon)
	end)
end

local function onEquip(player: Player, slot: any)
	local c = combatants[player]
	if not c or c.Holstered or (slot ~= "Primary" and slot ~= "Secondary") or c.Equipped == slot then
		return
	end
	if c.Humanoid.Health <= 0 then
		return
	end
	local current = c.Weapons[c.Equipped]
	cancelReload(player, current)
	holster(c, current)
	local nextWeapon = c.Weapons[slot :: Types.WeaponSlot]
	equip(c, nextWeapon)
	c.Equipped = slot
	c.ReadyAt = os.clock() + nextWeapon.Def.Combat.DrawTime * 0.85
end

local function onAim(player: Player, pitch: any, aiming: any)
	local c = combatants[player]
	if not c or not Schema.isFiniteNumber(pitch) then
		return
	end
	local now = os.clock()
	if now - c.LastAim < 1 / 30 then
		return
	end
	c.LastAim = now
	local clamped = math.round(math.clamp(pitch, -1.3, 1.2) * 100) / 100
	if c.Character:GetAttribute("AimPitch") ~= clamped then
		c.Character:SetAttribute("AimPitch", clamped)
	end
	local isAiming = aiming == true
	if c.Character:GetAttribute("Aiming") ~= isAiming then
		c.Character:SetAttribute("Aiming", isAiming)
	end
end

local function onStance(player: Player, stance: any, sprinting: any)
	local c = combatants[player]
	if not c or typeof(stance) ~= "string" or not VALID_STANCES[stance] then
		return
	end
	local now = os.clock()
	if now - c.LastStance < 0.05 then
		return
	end
	c.LastStance = now
	c.Character:SetAttribute("Stance", stance)
	c.Character:SetAttribute("Sprinting", sprinting == true and stance == "Stand")
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------
local function onDeployed(player: Player, character: Model, loadout: Types.Loadout)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = limb(character, "Head", "Head")
	local torso = limb(character, "UpperTorso", "Torso")
	if not humanoid or not head or not torso then
		warn("[Combat] character missing Humanoid/Head/Torso for", player.Name)
		return
	end
	assignCharacterGroup(character)

	local weapons: { [Types.WeaponSlot]: WeaponState } = {}
	local c: Combatant = {
		Player = player,
		Character = character,
		Humanoid = humanoid,
		Head = head,
		Torso = torso,
		Weapons = weapons,
		Equipped = "Primary",
		ReadyAt = os.clock() + 0.5,
		LastAim = 0,
		LastStance = 0,
		Holstered = false,
	}

	for _, slot in SLOTS do
		local id = if slot == "Primary" then loadout.Primary else loadout.Secondary
		local def = Config.Weapons[id]
		local handles = WeaponBuilder.build(id)
		weapons[slot] = {
			Id = id,
			Slot = slot,
			Def = def,
			Mag = def.Combat.MagSize,
			Reserve = def.Combat.Reserve,
			Tokens = Config.Combat.ShotBurstAllowance,
			LastShot = 0,
			Reloading = false,
			ReloadToken = 0,
			Handles = handles,
			Joint = nil,
		}
	end

	holster(c, weapons.Secondary)
	equip(c, weapons.Primary)
	for _, slot in SLOTS do
		weapons[slot].Handles.Model.Parent = character
	end

	combatants[player] = c
	for _, slot in SLOTS do
		sync(player, weapons[slot])
	end

	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil and combatants[player] == c then
			combatants[player] = nil
		end
	end)
	humanoid.Died:Once(function()
		if combatants[player] == c then
			combatants[player] = nil
		end
	end)
end

-- Vehicles: weapons go away while seated and come back on exit.
function CombatService.setHolstered(player: Player, holstered: boolean)
	local c = combatants[player]
	if not c or c.Holstered == holstered then
		return
	end
	c.Holstered = holstered
	local weapon = c.Weapons[c.Equipped]
	if holstered then
		cancelReload(player, weapon)
		holster(c, weapon)
		c.Character:SetAttribute("EquippedWeapon", nil)
		c.Character:SetAttribute("WeaponClass", nil)
	else
		equip(c, weapon)
		c.ReadyAt = os.clock() + weapon.Def.Combat.DrawTime
	end
	c.Character:SetAttribute("Holstered", holstered)
end

function CombatService.init(deployed: any, getLoadout: (Player) -> Types.Loadout)
	setupCollisionGroups()

	hitConfirm = Net.event(Net.Events.HitConfirm)
	ammoSync = Net.event(Net.Events.AmmoSync)
	shotFx = Net.unreliable(Net.Unreliable.ShotFx)

	Net.event(Net.Events.Fire).OnServerEvent:Connect(onFire)
	Net.event(Net.Events.Reload).OnServerEvent:Connect(onReload)
	Net.event(Net.Events.EquipSlot).OnServerEvent:Connect(onEquip)
	Net.event(Net.Events.SetStance).OnServerEvent:Connect(onStance)
	Net.unreliable(Net.Unreliable.AimState).OnServerEvent:Connect(onAim)

	deployed:Connect(function(player: Player, character: Model)
		onDeployed(player, character, getLoadout(player))
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		combatants[player] = nil
	end)
end

return CombatService
