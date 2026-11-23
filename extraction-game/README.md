# ZABOUR — Tactical Extraction (Roblox)

Gritty extraction game inspired by *Rob Run* × *Arc Raiders*. Built in 4 phases.

**Phase 1 (this drop):** project architecture, the lighting/post-processing pipeline, the procedural rain-soaked safehouse alley with the matte-black "Zabour" getaway car, and the live 3D main menu (DEPLOY / LOADOUT / SETTINGS) with a seamless camera blend into the over-the-shoulder tactical camera.

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
        └── GetawayCarBody       [ModuleScript]  src/ReplicatedStorage/Shared/Builders/GetawayCarBody.luau

ServerScriptService
└── Server                       [Folder]
    ├── Bootstrap                [Script]        src/ServerScriptService/Server/Bootstrap.server.luau
    ├── Services                 [Folder]
    │   ├── LightingService      [ModuleScript]  src/ServerScriptService/Server/Services/LightingService.luau
    │   ├── PlayerDataService    [ModuleScript]  src/ServerScriptService/Server/Services/PlayerDataService.luau
    │   └── DeployService        [ModuleScript]  src/ServerScriptService/Server/Services/DeployService.luau
    └── World                    [Folder]
        └── SafehouseBuilder     [ModuleScript]  src/ServerScriptService/Server/World/SafehouseBuilder.luau

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
        │   └── MenuController       [ModuleScript]  .../Client/Controllers/MenuController.luau
        └── UI                   [Folder]
            ├── Theme            [ModuleScript]  .../Client/UI/Theme.luau
            ├── Widgets          [ModuleScript]  .../Client/UI/Widgets.luau
            └── MenuUI           [ModuleScript]  .../Client/UI/MenuUI.luau
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

---

## 6. Phase 1 test checklist

1. **Play** → a black ZABOUR card with a sweeping line, which dissolves into the rainy alley. The camera breathes and follows the mouse slightly, the car idles with exhaust smoke, the neon sign flickers, and lightning flashes now and then.
2. Output shows `[Safehouse] built N parts`, `[PlayerData] backend: Mock` (or `DataStore`), `[Bootstrap] Phase 1 server ready.`, and a lighting warning only for properties that need setting by hand.
3. Hover the options: the label slides right, the accent bar grows, a tick plays, and the hint text changes. Try the keyboard and a gamepad too.
4. **LOADOUT** → the camera glides to the workbench and the panel slides in. Select the SMG; the accent marker moves and the stat bars animate. Stop and Play again: with real DataStore on, the choice persists.
5. **SETTINGS** → the camera moves to the headlight close-up. Change quality to Low (rain thins, beams, mist and shadows switch off), then drag FOV and sensitivity.
6. **DEPLOY** → the UI sweeps out and the camera pushes in, then blends with no cut into the over-the-shoulder view behind your character. The mouse locks, the reticle dot fades in, and V swaps shoulder.
7. Reset your character (Esc → Reset) → about 4 s later, fade to black, then back into the menu.
