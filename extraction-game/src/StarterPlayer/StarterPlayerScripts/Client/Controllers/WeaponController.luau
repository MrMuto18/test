--!strict
--[[
	WeaponController
	Client gunplay with server-authoritative results.

	Per shot (predicted instantly, then confirmed by CombatService):
	  1. Ray from the camera through the crosshair, inside the current cone of
	     fire (hip/ADS base + movement + bloom, tighter when crouched).
	  2. Real bullet ray from the muzzle to that aim point — cover between gun
	     and target is respected, like the server.
	  3. Muzzle flash, tracer, impact, shell, sound, camera recoil (climb +
	     kick spring), weapon kick on the procedural pose, crosshair bloom.
	  4. Fire(shotId, muzzle, direction) → server validates and raycasts.

	Also: ADS (hold RMB / L2), reload with physical mag drop (R / X), slot
	switch (1 / 2 / wheel / Y) with draw time, dry-fire + auto reload, sprint
	interruption, AmmoSync reconciliation, hitmarkers from HitConfirm, and
	replicated shot FX for other players.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Trove = require(Shared.Trove)
local Types = require(Shared.Types)
local WeaponBuilder = require(Shared.Builders.WeaponBuilder)

local Controllers = script.Parent
local AudioController = require(Controllers.AudioController)
local CharacterPoser = require(Controllers.CharacterPoser)
local MovementController = require(Controllers.MovementController)
local TacticalCamera = require(Controllers.TacticalCamera)
local WeaponFx = require(Controllers.WeaponFx)
local HUD = require(Controllers.Parent.UI.HUD)

local player = Players.LocalPlayer
local KEYS = Config.Combat.Keybinds
local RENDER_NAME = "WeaponController"

local WeaponController = {}

local SLOTS: { Types.WeaponSlot } = { "Primary", "Secondary" }

type SlotState = {
	Id: string,
	Def: Types.WeaponDef,
	Mag: number,
	Reserve: number,
}

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local trove: Trove.Trove? = nil
local slots: { [Types.WeaponSlot]: SlotState } = {}
local equipped: Types.WeaponSlot = "Primary"
local handles: WeaponBuilder.WeaponHandles? = nil

local firingHeld = false
local aimingHeld = false
local dryClicked = false
local nextShotTime = 0
local readyAt = 0
local bloom = 0
local shotId = 0
local reloading = false
local reloadStart = 0
local reloadEnd = 0
local reloadToken = 0
local lastAimSend = 0
local rng = Random.new()

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function current(): SlotState?
	return slots[equipped]
end

local function refreshRayFilter()
	local ignore: { Instance } = {}
	if character then
		table.insert(ignore, character)
	end
	for _, name in { "ClientFX", "WeaponFX" } do
		local f = Workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	rayParams.FilterDescendantsInstances = ignore
end

local function resolveHandles(): WeaponBuilder.WeaponHandles?
	local model = character
	local state = current()
	if not model or not state then
		return nil
	end
	local h = handles
	if h and h.Model.Parent == model and h.Model.Name == "EquippedWeapon" and h.Model:GetAttribute("WeaponId") == state.Id then
		return h
	end
	local weaponModel = model:FindFirstChild("EquippedWeapon")
	if weaponModel and weaponModel:IsA("Model") and weaponModel:GetAttribute("WeaponId") == state.Id then
		handles = WeaponBuilder.resolve(weaponModel)
		return handles
	end
	handles = nil
	return nil
end

local function updateHudWeapon()
	local state = current()
	if not state then
		return
	end
	HUD.setWeapon(state.Def.DisplayName, state.Def.Combat.FireMode, state.Def.Combat.MagSize)
	HUD.setAmmo(state.Mag, state.Reserve)
end

local function currentSpread(): number
	local state = current()
	local r = root
	if not state or not r then
		return 0
	end
	local combat = state.Def.Combat
	local aim = TacticalCamera.getAim()
	local base = combat.HipSpread + (combat.AdsSpread - combat.HipSpread) * aim
	local v = r.AssemblyLinearVelocity
	local speed01 = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / Config.Movement.WalkSpeed, 0, 1.5)
	local move = speed01 * combat.MoveSpread * (1 - aim * 0.6)
	local airborne = if humanoid and humanoid.FloorMaterial == Enum.Material.Air then 2 else 0
	local stanceMul = if MovementController.getStance() ~= "Stand" then 0.75 else 1
	return (base + move + bloom + airborne) * stanceMul
end

-- Uniform random direction inside a cone of half-angle `angle` (radians).
local function coneDirection(forward: Vector3, angle: number): Vector3
	if angle <= 0 then
		return forward
	end
	local cosMax = math.cos(angle)
	local z = cosMax + (1 - cosMax) * rng:NextNumber()
	local r = math.sqrt(math.max(0, 1 - z * z))
	local phi = rng:NextNumber() * 2 * math.pi
	local basis = CFrame.lookAt(Vector3.zero, forward)
	return basis:VectorToWorldSpace(Vector3.new(r * math.cos(phi), r * math.sin(phi), -z)).Unit
end

--------------------------------------------------------------------------------
-- Reload
--------------------------------------------------------------------------------
local function cancelReload()
	if not reloading then
		return
	end
	reloading = false
	reloadToken += 1
	HUD.setReload(nil)
	local h = handles
	if h then
		WeaponFx.restoreMagazine(h.Magazine)
	end
end

local function reload()
	local state = current()
	local h = resolveHandles()
	if not state or reloading or not h then
		return
	end
	local combat = state.Def.Combat
	if state.Mag >= combat.MagSize or state.Reserve <= 0 then
		return
	end
	reloading = true
	reloadToken += 1
	local token = reloadToken
	local duration = (if state.Mag == 0 then combat.EmptyReloadTime else combat.ReloadTime) + 0.1
	reloadStart = os.clock()
	reloadEnd = reloadStart + duration
	MovementController.interruptSprint(0.2)
	Net.event(Net.Events.Reload):FireServer()

	WeaponFx.sound("ReloadOut", h.Handle)
	WeaponFx.dropMagazine(h.Magazine, duration * 0.62)
	task.delay(duration * 0.62, function()
		if token == reloadToken and h.Handle.Parent then
			WeaponFx.sound("ReloadIn", h.Handle)
		end
	end)
	task.delay(duration, function()
		if token ~= reloadToken or not reloading then
			return
		end
		-- Predicted fill; AmmoSync from the server is authoritative.
		local take = math.min(combat.MagSize - state.Mag, state.Reserve)
		state.Mag += take
		state.Reserve -= take
		reloading = false
		HUD.setReload(nil)
		HUD.setAmmo(state.Mag, state.Reserve)
	end)
end

--------------------------------------------------------------------------------
-- Fire
--------------------------------------------------------------------------------
local function fireOnce(state: SlotState, h: WeaponBuilder.WeaponHandles)
	local combat = state.Def.Combat
	local camCF = TacticalCamera.getCFrame()
	local muzzle = h.Muzzle.WorldPosition

	-- 1. Aim point through the crosshair (ray starts level with the muzzle so
	--    things between the camera and the player are never targeted).
	local dir = coneDirection(camCF.LookVector, math.rad(currentSpread()))
	local startT = math.max((muzzle - camCF.Position):Dot(dir), 0)
	local aimOrigin = camCF.Position + dir * startT
	local aimHit = Workspace:Raycast(aimOrigin, dir * combat.Range, rayParams)
	local aimPoint = if aimHit then aimHit.Position else aimOrigin + dir * combat.Range

	-- 2. Bullet from the muzzle.
	local shotDir = aimPoint - muzzle
	if shotDir.Magnitude < 0.05 then
		shotDir = dir
	end
	shotDir = shotDir.Unit
	local hit = Workspace:Raycast(muzzle, shotDir * combat.Range, rayParams)
	local hitPos = if hit then hit.Position else muzzle + shotDir * combat.Range

	-- 3. Feedback
	WeaponFx.muzzleFlash(h.Muzzle, combat.Suppressed)
	WeaponFx.tracer(muzzle, hitPos, combat.TracerColor)
	if hit then
		WeaponFx.impact(hit.Position, hit.Normal, hit.Material.Name, hit.Instance)
	end
	local r = root
	WeaponFx.shell(h.Ejection, state.Def.Class, if r then r.AssemblyLinearVelocity else Vector3.zero)
	WeaponFx.sound(combat.FireSound, h.Muzzle, if combat.Suppressed then 0.55 else 1)

	local aim = TacticalCamera.getAim()
	local stanceMul = if MovementController.getStance() ~= "Stand" then 0.8 else 1
	local recoilScale = (1 - aim * 0.3) * stanceMul
	TacticalCamera.addRecoil(combat.RecoilPitch * recoilScale, rng:NextNumber(-combat.RecoilYaw, combat.RecoilYaw) * recoilScale, combat.RecoilRecovery)
	local kickBack = if state.Def.Class == "PISTOL" then 0.12 else 0.08
	CharacterPoser.kick(kickBack, math.rad(combat.RecoilPitch * 1.6))
	bloom = math.min(bloom + combat.SpreadPerShot, combat.MaxBloom)
	HUD.pulse(4 + combat.SpreadPerShot * 6)

	state.Mag -= 1
	HUD.setAmmo(state.Mag, state.Reserve)

	-- 4. Server
	shotId += 1
	Net.event(Net.Events.Fire):FireServer(shotId, muzzle, shotDir)
end

local function tryFire(): boolean
	local state = current()
	local h = humanoid
	if not state or not h or h.Health <= 0 then
		return false
	end
	local now = os.clock()
	if now < readyAt or reloading then
		return false
	end
	if MovementController.isSprinting() then
		MovementController.interruptSprint(0.35)
		readyAt = now + 0.12 -- sprint-out time
		return false
	end
	local weapon = resolveHandles()
	if not weapon then
		return false
	end
	if state.Mag <= 0 then
		if not dryClicked then
			dryClicked = true
			WeaponFx.sound("DryFire", weapon.Handle)
			if state.Reserve > 0 then
				task.delay(0.2, reload)
			end
		end
		return false
	end
	local interval = 60 / state.Def.Combat.RPM
	if now < nextShotTime then
		return false
	end
	if nextShotTime < now - interval then
		nextShotTime = now
	end
	nextShotTime += interval
	MovementController.interruptSprint(0.35)
	fireOnce(state, weapon)
	return true
end

--------------------------------------------------------------------------------
-- Equip
--------------------------------------------------------------------------------
local function equip(slot: Types.WeaponSlot)
	if slot == equipped or not slots[slot] then
		return
	end
	cancelReload()
	equipped = slot
	handles = nil
	local state = slots[slot]
	readyAt = os.clock() + state.Def.Combat.DrawTime
	nextShotTime = readyAt
	bloom = 0
	dryClicked = false
	Net.event(Net.Events.EquipSlot):FireServer(slot)
	AudioController.play("Equip")
	updateHudWeapon()
end

--------------------------------------------------------------------------------
-- Frame loop
--------------------------------------------------------------------------------
local function step(dt: number)
	local state = current()
	local h = humanoid
	if not state or not h then
		return
	end
	local combat = state.Def.Combat
	local alive = h.Health > 0

	-- Aim
	local aiming = alive and aimingHeld and not reloading and os.clock() >= readyAt - combat.DrawTime * 0.5
	TacticalCamera.setAiming(aiming, combat.AdsFovMultiplier, combat.AdsTime)
	CharacterPoser.setLocalAim(aiming)
	MovementController.setAiming(aiming)
	MovementController.setSpeedMultiplier(combat.MoveSpeedMultiplier)

	-- Automatic fire
	if alive and firingHeld and combat.FireMode == "Auto" then
		local shots = 0
		while shots < 3 and tryFire() do
			shots += 1
		end
	end

	bloom = math.max(0, bloom - combat.BloomRecovery * dt)

	-- HUD
	local spread = currentSpread()
	HUD.setSpread(spread, TacticalCamera.getFieldOfView(), TacticalCamera.getAim(), not MovementController.isSprinting() and alive)
	HUD.setStamina(MovementController.getStamina01())
	if reloading then
		HUD.setReload((os.clock() - reloadStart) / math.max(reloadEnd - reloadStart, 0.01))
	end

	-- Replicate aim pitch for other players' views of you.
	local now = os.clock()
	if now - lastAimSend >= 1 / Config.Combat.AimSendRate then
		lastAimSend = now
		Net.unreliable(Net.Unreliable.AimState):FireServer(TacticalCamera.getPitch(), aiming)
	end
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------
local ACTIONS = { "WeaponFire", "WeaponAim", "WeaponReload", "WeaponPrimary", "WeaponSecondary", "WeaponSwap" }

local function bind()
	ContextActionService:BindAction("WeaponFire", function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			firingHeld = true
			dryClicked = false
			local s = current()
			if s and s.Def.Combat.FireMode == "Semi" then
				tryFire()
			end
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			firingHeld = false
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(KEYS.Fire))

	ContextActionService:BindAction("WeaponAim", function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			aimingHeld = true
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			aimingHeld = false
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(KEYS.Aim))

	ContextActionService:BindAction("WeaponReload", function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			reload()
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(KEYS.Reload))

	ContextActionService:BindAction("WeaponPrimary", function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			equip("Primary")
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(KEYS.Primary))

	ContextActionService:BindAction("WeaponSecondary", function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			equip("Secondary")
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(KEYS.Secondary))

	ContextActionService:BindAction("WeaponSwap", function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			equip(if equipped == "Primary" then "Secondary" else "Primary")
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(KEYS.SwapWeapon))
end

local function unbind()
	for _, name in ACTIONS do
		ContextActionService:UnbindAction(name)
	end
	firingHeld = false
	aimingHeld = false
end

--------------------------------------------------------------------------------
-- Network handlers (connected once)
--------------------------------------------------------------------------------
local function onAmmoSync(slot: any, mag: any, reserve: any, serverReloading: any)
	local state = slots[slot :: Types.WeaponSlot]
	if not state or typeof(mag) ~= "number" or typeof(reserve) ~= "number" then
		return
	end
	state.Mag = mag
	state.Reserve = reserve
	if slot == equipped then
		if serverReloading ~= true and reloading and os.clock() >= reloadEnd - 0.35 then
			reloading = false
			HUD.setReload(nil)
		end
		HUD.setAmmo(state.Mag, state.Reserve)
	end
end

local function onHitConfirm(kind: any, damage: any, position: any)
	if typeof(kind) ~= "string" then
		return
	end
	HUD.hitmarker(kind)
	if Config.Combat.DamageNumbers and kind ~= "Blocked" and typeof(damage) == "number" and typeof(position) == "Vector3" then
		WeaponFx.damageNumber(position, damage, kind)
	end
	if kind == "Kill" then
		AudioController.play("HitKill", 0.02)
	elseif kind == "Head" then
		AudioController.play("HitHead", 0.02)
	elseif kind == "Body" then
		AudioController.play("HitBody", 0.05)
	elseif kind == "Blocked" then
		HUD.toast("SAFE ZONE — PLAYERS PROTECTED")
	end
end

local function onShotFx(shooter: any, weaponId: any, origin: any, hitPos: any, normal: any, material: any)
	if typeof(shooter) ~= "Instance" or not shooter:IsA("Model") or shooter == character then
		return
	end
	if typeof(origin) ~= "Vector3" or typeof(hitPos) ~= "Vector3" or typeof(normal) ~= "Vector3" then
		return
	end
	local def = if typeof(weaponId) == "string" then Config.Weapons[weaponId] else nil
	if not def then
		return
	end
	local camera = Workspace.CurrentCamera
	local far = camera ~= nil and (camera.CFrame.Position - origin).Magnitude > 450

	local weaponModel = shooter:FindFirstChild("EquippedWeapon")
	local remote = if weaponModel and weaponModel:IsA("Model") then WeaponBuilder.resolve(weaponModel) else nil
	local from = if remote then remote.Muzzle.WorldPosition else origin
	if remote then
		WeaponFx.sound(def.Combat.FireSound, remote.Muzzle, if def.Combat.Suppressed then 0.55 else 1)
	end
	if far then
		return
	end
	if remote then
		WeaponFx.muzzleFlash(remote.Muzzle, def.Combat.Suppressed)
		WeaponFx.shell(remote.Ejection, def.Class, Vector3.zero)
	end
	WeaponFx.tracer(from, hitPos, def.Combat.TracerColor)
	if typeof(material) == "string" and material ~= "Air" then
		local probe = Workspace:Raycast(hitPos + normal * 0.2, -normal * 0.4, rayParams)
		WeaponFx.impact(hitPos, normal, material, if probe then probe.Instance else nil)
	end
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------
function WeaponController.init()
	WeaponFx.init()
	Net.event(Net.Events.AmmoSync).OnClientEvent:Connect(onAmmoSync)
	Net.event(Net.Events.HitConfirm).OnClientEvent:Connect(onHitConfirm)
	Net.unreliable(Net.Unreliable.ShotFx).OnClientEvent:Connect(onShotFx)

	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if processed or not trove or input.UserInputType ~= Enum.UserInputType.MouseWheel then
			return
		end
		equip(if equipped == "Primary" then "Secondary" else "Primary")
	end)
end

function WeaponController.attach(model: Model, loadout: Types.Loadout)
	WeaponController.detach()
	local h = model:FindFirstChildOfClass("Humanoid")
	local r = model:FindFirstChild("HumanoidRootPart")
	if not h or not r or not r:IsA("BasePart") then
		return
	end
	character = model
	humanoid = h
	root = r
	slots = {}
	for _, slot in SLOTS do
		local id = if slot == "Primary" then loadout.Primary else loadout.Secondary
		local def = Config.Weapons[id]
		slots[slot] = { Id = id, Def = def, Mag = def.Combat.MagSize, Reserve = def.Combat.Reserve }
	end
	equipped = "Primary"
	handles = nil
	reloading = false
	bloom = 0
	readyAt = os.clock() + slots.Primary.Def.Combat.DrawTime
	nextShotTime = readyAt
	refreshRayFilter()

	local t = Trove.new()
	trove = t
	t:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 5, step)
	t:Connect(h.HealthChanged, function(health: number)
		HUD.setHealth(health, h.MaxHealth)
	end)
	t:Connect(h.Died, function()
		unbind()
		cancelReload()
		TacticalCamera.setAiming(false)
		HUD.hide()
	end)

	bind()
	HUD.resetHealth(h.MaxHealth)
	updateHudWeapon()
	HUD.show()
end

function WeaponController.detach()
	unbind()
	cancelReload()
	if trove then
		local t = trove
		trove = nil
		t:Clean()
	end
	TacticalCamera.setAiming(false)
	CharacterPoser.setLocalAim(false)
	HUD.hide(true)
	character = nil
	humanoid = nil
	root = nil
	handles = nil
end

return WeaponController
