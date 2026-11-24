# ZABOUR — Tactical Extraction (Roblox)

Gritty extraction game inspired by *Rob Run* × *Arc Raiders*. Built in 4 phases.

**Phase 1:** project architecture, the lighting/post-processing pipeline, the procedural rain-soaked safehouse alley with the matte-black "Zabour" getaway car, and the live 3D main menu (DEPLOY / LOADOUT / SETTINGS) with a seamless camera blend into the over-the-shoulder tactical camera.

---

## 1. Explorer hierarchy

Create exactly this tree (or let Rojo create it, see §2). Object types are in brackets. The source file for each script is shown on the right.

```
ReplicatedFirst
└── LoadingScreen                [LocalScript]   src/ReplicatedFirst/LoadingScreen.client.luau

ReplicatedStorage
└── Shared                       [Folder]
    ├── Config                   [ModuleScript]  src/ReplicatedStorage/Shared/Config.luau
    ├── Types                    [ModuleScript]  src/ReplicatedStorage/Shared/Types.luau
    ├── Schema                   [ModuleScript]  src/ReplicatedStorage/Shared/Schema.luau
    ├── Net                      [ModuleScript]  src/ReplicatedStorage/Shared/Net.luau
    ├── Signal                   [ModuleScript]  src/ReplicatedStorage/Shared/Signal.luau
    ├── Spring                   [ModuleScript]  src/ReplicatedStorage/Shared/Spring.luau
    ├── Trove                    [ModuleScript]  src/ReplicatedStorage/Shared/Trove.luau
    └── Builders                 [Folder]
        ├── PartFactory          [ModuleScript]  src/ReplicatedStorage/Shared/Builders/PartFactory.luau
        ├── GetawayCarBody       [ModuleScript]  src/ReplicatedStorage/Shared/Builders/GetawayCarBody.luau
        └── WeaponBuilder        [ModuleScript]  src/ReplicatedStorage/Shared/Builders/WeaponBuilder.luau   (Phase 2)

ServerScriptService
└── Server                       [Folder]
    ├── Bootstrap                [Script]        src/ServerScriptService/Server/Bootstrap.server.luau
    ├── Services                 [Folder]
    │   ├── LightingService      [ModuleScript]  src/ServerScriptService/Server/Services/LightingService.luau
    │   ├── PlayerDataService    [ModuleScript]  src/ServerScriptService/Server/Services/PlayerDataService.luau
    │   ├── DeployService        [ModuleScript]  src/ServerScriptService/Server/Services/DeployService.luau
    │   └── CombatService        [ModuleScript]  src/ServerScriptService/Server/Services/CombatService.luau   (Phase 2)
    └── World                    [Folder]
        ├── SafehouseBuilder     [ModuleScript]  src/ServerScriptService/Server/World/SafehouseBuilder.luau
        └── TrainingRange        [ModuleScript]  src/ServerScriptService/Server/World/TrainingRange.luau      (Phase 2)

StarterPlayer
└── StarterPlayerScripts
    └── Client                   [Folder]
        ├── ClientBootstrap      [LocalScript]   src/StarterPlayer/StarterPlayerScripts/Client/ClientBootstrap.client.luau
        ├── Controllers          [Folder]
        │   ├── SettingsController   [ModuleScript]  .../Client/Controllers/SettingsController.luau
        │   ├── AudioController      [ModuleScript]  .../Client/Controllers/AudioController.luau
        │   ├── CinematicGrade       [ModuleScript]  .../Client/Controllers/CinematicGrade.luau
        │   ├── AtmosphereController [ModuleScript]  .../Client/Controllers/AtmosphereController.luau
        │   ├── MenuCamera           [ModuleScript]  .../Client/Controllers/MenuCamera.luau
        │   ├── TacticalCamera       [ModuleScript]  .../Client/Controllers/TacticalCamera.luau
        │   ├── MenuController       [ModuleScript]  .../Client/Controllers/MenuController.luau
        │   ├── MovementController   [ModuleScript]  .../Client/Controllers/MovementController.luau   (Phase 2)
        │   ├── CharacterPoser       [ModuleScript]  .../Client/Controllers/CharacterPoser.luau       (Phase 2)
        │   ├── WeaponFx             [ModuleScript]  .../Client/Controllers/WeaponFx.luau             (Phase 2)
        │   ├── WeaponController     [ModuleScript]  .../Client/Controllers/WeaponController.luau     (Phase 2)
        │   └── LoadoutDisplay       [ModuleScript]  .../Client/Controllers/LoadoutDisplay.luau       (Phase 2)
        └── UI                   [Folder]
            ├── Theme            [ModuleScript]  .../Client/UI/Theme.luau
            ├── Widgets          [ModuleScript]  .../Client/UI/Widgets.luau
            ├── MenuUI           [ModuleScript]  .../Client/UI/MenuUI.luau
            └── HUD              [ModuleScript]  .../Client/UI/HUD.luau                           (Phase 2)
```

Created at runtime (don't make these by hand):

| Instance | Created by |
|---|---|
| `ReplicatedStorage.Remotes` (RemoteEvents/Functions) | `Net.init()` on the server |
| `Workspace.Safehouse` (environment, car, CameraRig, DeployPoints) | `SafehouseBuilder` (or baked with the Command Bar) |
| `Lighting` effects `Grade_*`, `Atmosphere`, `Sky`, `Terrain.Clouds` | `LightingService.apply()` |
| `PlayerGui.MainMenu`, `PlayerGui.Fader`, `PlayerGui.TacticalReticle` | client UI |
| `Workspace.ClientFX` (rain + splash volumes) | `AtmosphereController` (client-local) |

Script names matter: every `require` uses these exact names and parents.

---

## 2. Install

### Option 0: one file (easiest)
Open `build/Zabour.rbxlx` in Roblox Studio (double-click, or File → Open from File). Every script is already in place. Rebuild it after code changes with `python3 tools/build_place.py`.

### Option A: Rojo (recommended)
```
cd extraction-game
rojo serve
```
Connect from the Rojo Studio plugin. The project file also sets `Players.CharacterAutoLoads = false`, `Lighting.Technology = Future` and `MaterialService.Use2022Materials = true`.

### Option B: manual copy-paste
1. Build the tree from §1 in Explorer (Insert Object → Folder / Script / LocalScript / ModuleScript, then rename).
2. Open each script and replace its contents with the matching file.
3. Do the Studio settings in §3.

---

## 3. One-time Studio settings

| Setting | Where | Value |
|---|---|---|
| `Lighting.Technology` | Properties panel (scripts can't always write it) | **Future** |
| `Players.CharacterAutoLoads` | Properties panel | **false** (the server also sets it) |
| `MaterialService.Use2022Materials` | Properties panel | **true** |
| Baseplate / SpawnLocation from the template | Explorer | Delete. Optional: the safehouse sits 0.2 studs above y=0 so they can't z-fight |
| Real DataStore saves in Studio | Game Settings → Security → *Enable Studio Access to API Services* (place must be published) | Optional. Without it a mock store is used and data resets each session |

**Optional: bake the safehouse into the place** so you can see and edit it outside Play mode. Paste `tools/StudioCommandBar.luau` into View → Command Bar (edit mode) and press Enter. The server reuses a baked `Workspace.Safehouse` instead of rebuilding it. Re-run the command to rebuild from code. If you edited a module since the last run, restart Studio first, because the Command Bar caches `require` results.

**Audio:** `Shared/Config.luau → Config.Audio`. UI sounds use built-in `rbxasset://sounds/...` files. `RainLoop`, `Thunder` and `EngineIdle` start empty: paste `rbxassetid://<id>` values for Creator Store audio you have rights to. Empty IDs are skipped, and the Output window lists which ones are missing.

---

## 4. How Phase 1 works

```
Server Bootstrap
  Net.init → LightingService.apply → SafehouseBuilder.ensure → PlayerDataService.init → DeployService.init

Player state (attribute "State", server-authoritative)
  Menu ──RequestDeploy──▶ Deploying ──LoadCharacter + pivot──▶ Deployed
   ▲                                                              │
   └───────────────── death (+4 s) / later: extraction ───────────┘

Client
  LoadingScreen (ReplicatedFirst) ─ holds black card until "ClientMenuReady"
  ClientBootstrap
    SettingsController (GetProfile) → AudioController → CinematicGrade
    → AtmosphereController (rain, splashes, lightning, flicker, car idle)
    → MenuCamera → MenuController (MenuUI) → enter()
```

* **Seamless DEPLOY:** `TacticalCamera.evaluate()` computes the live OTS camera without writing it. During the 2.1 s transition the camera is `lerp(frozenMenuFrame, liveTacticalFrame, smootherstep(t))`. At t = 1 it is exactly the tactical camera, so control passes over with no cut. DOF, contrast, saturation and exposure blend from the menu grade to the gameplay grade at the same time, and the letterbox retracts.
* **Camera shots** are invisible parts in `Safehouse.CameraRig` (`MenuShot`, `LoadoutShot`, `SettingsShot`). Their attributes `FieldOfView`, `FocusDistance` and `InFocusRadius` drive the lens and DOF. Move a part in Studio to re-frame a shot.
* **Effects quality** (Low / Medium / High / Ultra) scales rain density, splashes, ground mist, volumetric beams, exhaust smoke, light shadows, DOF, sun rays and bloom on the client. It is separate from the engine graphics level, which only the player can change in the Roblox menu.
* **Anti-exploit groundwork:** all remote input goes through `Shared.Schema` on the server: settings are clamped, NaN is rejected, weapon ids are checked against their slot, loadout changes are locked once deployed, and deploy and save requests are rate-limited.

---

## 5. Controls

| Context | Input |
|---|---|
| Menu | Mouse hover/click · ↑↓ / W S / D-pad to navigate · ← → / A D to adjust or jump into the panel · Enter / (A) to select · Backspace / (B) to go back |
| Deployed | WASD move · mouse / right stick look · **V** / D-pad → shoulder swap |
| Movement | **Shift** / L3 sprint (hold) · **C** / Ctrl / (B) crouch · crouch while sprinting = **slide** · Space jump (costs stamina; cancels a slide into a hop) |
| Weapons | **LMB** / R2 fire · **RMB** / L2 aim · **R** / (X) reload · **1** / **2** / wheel / (Y) switch weapon |

---

## 6. Phase 1 test checklist

1. **Play** → a black ZABOUR card with a sweeping line, which dissolves into the rainy alley. The camera breathes and follows the mouse slightly, the car idles with exhaust smoke, the neon sign flickers, and lightning flashes now and then.
2. Output shows `[Safehouse] built N parts`, `[PlayerData] backend: Mock` (or `DataStore`), `[Bootstrap] Phase 2 server ready.`, and a lighting warning only for properties that need setting by hand.
3. Hover the options: the label slides right, the accent bar grows, a tick plays, and the hint text changes. Try the keyboard and a gamepad too.
4. **LOADOUT** → the camera glides to the workbench and the panel slides in. Select the SMG; the accent marker moves and the stat bars animate. Stop and Play again: with real DataStore on, the choice persists.
5. **SETTINGS** → the camera moves to the headlight close-up. Change quality to Low (rain thins, beams, mist and shadows switch off), then drag FOV and sensitivity.
6. **DEPLOY** → the UI sweeps out and the camera pushes in, then blends with no cut into the over-the-shoulder view behind your character. The mouse locks, the reticle dot fades in, and V swaps shoulder.
7. Reset your character (Esc → Reset) → about 4 s later, fade to black, then back into the menu.

---

## 7. Phase 2: movement + gunplay

**What it adds**
* **Movement:** walk 14, ADS 9, crouch 7, sprint 23 studs/s, all eased. Stamina drains while sprinting and on jumps; it regenerates after a delay and locks you out of sprint when it hits 0. Slide: a momentum burst that decays into a crouch, with an FOV kick. You can't stand up under low ceilings.
* **Weapons:** three procedural models of 40–70 parts each: VK-9 suppressed rifle (holographic sight with glowing reticle), KR-45 SMG (reflex dot, wire stock), M-50 pistol (micro red dot, compensator). The equipped weapon is held in front of you; the other is slung on your back or holstered on your thigh.
* **Poses with no animation assets:** both hands are IK-locked to the weapon grips, the upper body follows your aim, the gun drops to low-ready while sprinting, and crouching keeps your feet planted with a stepping cycle. Every client poses every player.
* **Shooting:** cone of fire (hip/ADS + movement + bloom), camera recoil (climb that partly recovers + a visual kick), weapon kick, muzzle flash, tracers, sparks/dust, bullet holes, shell casings, a magazine that drops on reload, dry-fire and auto reload.
* **Server hit validation:** the server tracks ammo, reloads and draw time, limits fire rate, checks the muzzle is near your head and visible from it, does its own raycast, and applies damage falloff and headshot multipliers. The safehouse is a **safe zone** (no PvP) until Phase 4.
* **HUD:** a crosshair whose gap matches the real spread, hitmarkers (white body / red head / gold kill), ammo, a reload line, stamina, health and a red flash when you take damage.
* **Training range:** three armoured mannequins (150 HP; they flash when hit, regenerate, collapse and respawn) plus a steel gong down the alley.
* **Menu:** your selected weapons now lie on the workbench in the LOADOUT shot.

**Phase 2 settings**
* **Avatar must be R15:** Game Settings → Avatar → R15 (the procedural poses need R15 joints).
* **Gunshot audio:** `Config.Audio.FireRifle` / `FireSMG` / `FirePistol` are empty until you add Creator Store audio ids you have rights to. Hit, reload and dry-fire sounds use built-in files.

**Phase 2 test checklist**
1. DEPLOY → the rifle is in your hands with the pistol on your thigh. The HUD fades in.
2. Hold Shift: the FOV kicks out, the gun drops to low-ready and the stamina line drains. Press C while sprinting to slide.
3. Shoot the mannequins: tracers, flash, shells, hitmarkers. Headshots show red; a kill shows gold and the mannequin collapses and comes back.
4. Hold RMB: the camera tucks in, FOV drops and spread shrinks to a dot. Spray and feel the climb recover when you let go.
5. R reloads (the magazine drops out). 2 / wheel switches to the pistol (semi-auto).
6. With 2 players (Test → Start, 2 players): each sees the other's poses, tracers and flashes, and bullets on another player show "SAFE ZONE".
