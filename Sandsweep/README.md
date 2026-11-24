# Sandsweep: a cozy desert-digging incremental for Roblox

A first-person game about digging and vacuuming sand. You clear the **Sunbaked Desert** (an open 160×160 stud field of Smooth Terrain dunes, up to 22 studs tall) one scoop at a time. There are no walls: the dig zone is marked by small flags and blends into decorative dunes that run to the horizon. You sell the sand by weight at the Weigh Station and dig up 14 buried relics. Cash buys better tools, bigger bags and skill-tree upgrades. Clear 99.5% or more of the desert and fresh dunes are delivered with new relics buried in them.

Everything is built in code. There are no uploaded meshes, decals or audio. The only sounds are Roblox's built-in `rbxasset://sounds/...` files, shaped with EQ and distortion effects.

## Install (one paste)

1. Open a new place in Roblox Studio. The **Baseplate** template is fine.
2. Open **View → Command Bar**.
3. Paste the full contents of [`SandsweepInstaller.lua`](SandsweepInstaller.lua) and press **Enter**.
4. Press **Play** (F5).

The installer:
- builds the whole hierarchy below and fills in each script's `.Source`;
- sets `Lighting.Technology = Future` and first-person camera mode;
- removes the template `Baseplate` and `SpawnLocation`.

Running it again replaces an earlier install cleanly. On the server, the game calls `Terrain:Clear()` when it starts and builds its own terrain.

> **Saving in Studio:** enable *Game Settings → Security → Enable Studio Access to API Services*. If that's off, the game automatically falls back to in-memory saves and shows a toast telling you so.

If you'd rather not use the Command Bar, create each instance by hand from the table below and paste in the matching file from `src/`.

## Explorer hierarchy

```
ReplicatedStorage
└── Sandsweep                      Folder
    ├── Remotes                    Folder
    │   ├── DigRequest             RemoteEvent     client → server  (hitPos, rayDir)
    │   ├── DigResult              RemoteEvent     server → client  (kg, bagKg, capacity, pos)
    │   ├── DigFx                  RemoteEvent     server → all     (digger, pos, toolId, kg)
    │   ├── StateUpdate            RemoteEvent     server → client  (full state snapshot)
    │   ├── LotUpdate              RemoteEvent     server → all     (% cleared, regen state)
    │   ├── Notify                 RemoteEvent     server → client  (toasts, sells, finds…)
    │   ├── OpenMenu               RemoteEvent     server → client  (booth prompt)
    │   ├── Purchase               RemoteFunction  client → server  (kind, id) → ok, msg
    │   └── GetState               RemoteFunction  client → server  → snapshot
    ├── GameConfig                 ModuleScript    all tuning: tools, bags, skills, 14 finds, prices
    ├── Util                       ModuleScript    formatting, deep copy, vector validation
    ├── PartKit                    ModuleScript    procedural part/cylinder/ellipsoid helpers
    ├── ToolModels                 ModuleScript    Spoon, Shovel, Hand Vacuum, Turbine Vacuum models
    └── FindModels                 ModuleScript    the 14 relic models

ServerScriptService
└── Sandsweep                      Folder
    ├── Main                       Script          server authority: digging, bag, selling, shop, finds, saving
    ├── WorldBuilder               ModuleScript    lighting, terrain dunes, bedrock, walls, fence, stations
    ├── LotService                 ModuleScript    Smooth Terrain lot: generate, FillBall + voxel weighing, % cleared
    ├── FindsService               ModuleScript    bury, uncover detection, ProximityPrompt collection
    └── DataService                ModuleScript    DataStore load/save with pcall, retries, memory fallback

StarterPlayer
└── StarterPlayerScripts
    └── SandsweepClient            LocalScript     client entry point
        ├── ClientState            ModuleScript    mirror of server state + signals
        ├── Effects                ModuleScript    particles, suction beam, sounds, shake, floating text
        ├── DigController          ModuleScript    input, camera raycast, viewmodel animation
        └── Interface              ModuleScript    HUD, Shop, Skill Tree, Finds Journal, toasts
```

At runtime the server also creates `Workspace/SandsweepWorld/` (Map, Stations, Finds, spawn), and each client creates `Workspace/SandsweepFX_Local`.

## Controls

| Input | Action |
|---|---|
| Left click / R2 / **DIG** button (touch) | Dig. Spoon: click. Shovel: click or hold. Vacuums: hold. |
| `1`–`4` | Swap to an owned tool |
| `B` / `K` / `J` | Shop / Skill Tree / Finds Journal |
| `E` | Collect an uncovered relic · open the Upgrade Booth |
| Walk onto the scale | Sell your whole bag |

## How the core systems work

**Digging (server-authoritative).** The client raycasts from the centre of the screen. It fires `DigRequest` only when the hit is Sand inside the lot. The server then rejects the request if any of these checks fail:
- the vectors are finite;
- the tool cooldown has passed (with 20% latency tolerance);
- the hit is within the tool's range of the head;
- the hit is inside the lot bounds;
- nothing solid sits between the player and the sand (line-of-sight raycast);
- the bag has room.

If the request passes, the server runs `Terrain:ReadVoxels`, carves, then runs `ReadVoxels` again. It adds up only the drop in **Sand** occupancy, so swinging at air earns nothing. Weight = removed volume × `SandDensity`.
- Shovel and vacuums carve with `Terrain:FillBall(center, radius, Air)`.
- The spoon's ball is smaller than a 4-stud voxel, where `FillBall` often does nothing, so it carves the voxels directly with `WriteVoxels`. Every successful dig is also guaranteed to bite into the nearest sand.
- Voxels outside the dig zone are restored after each dig, so the outer desert never changes.
- Tiny leftover voxels near the dig are swept up automatically, so the desert can really reach ~100%. If the bag is nearly full, the scoop shrinks to fit.

**No void, ever.** The whole dig zone sits on a solid hardpan bedrock **Part** that terrain operations can't touch. The server also clamps the dig centre above the bedrock line. An invisible safety net, a far-out invisible world boundary and a teleport-to-spawn check catch anything that still falls or wanders off.

**Base camp.** Spawn, the Weigh Station and the Upgrade Booth sit on flat ground just south of the dig zone, under a gateway arch.

**Finds.** The 14 relics are anchored, non-collidable models buried at random within each relic's depth band. Their `ProximityPrompt` stays disabled until two checks pass. First, the voxel column at and just above the relic is mostly empty (average Sand occupancy below 0.3). Second, at least 3 of 5 vertical raycasts reach the relic without hitting sand. Once uncovered, a relic gets a highlight, sparkles and a light pillar. The first time you collect a relic it pays its full bonus. Repeats pay 35%.

**Persistence.** Saved: Cash, bag weight, owned tools, equipped tool, bag tier, skill levels, discovered finds and lifetime stats. Saves happen through `UpdateAsync` on leave, every 90 s, and on `BindToClose`. Loaded data is sanitised. If loading fails, that session is never saved, so it can't overwrite your real save.

## Balancing knobs (all in `GameConfig`)

| Tool | Price | Radius | Cooldown | Mode |
|---|---|---|---|---|
| Rusty Spoon | free | 1.8 | 0.45 s | Click |
| Trusty Shovel | $250 | 3.2 | 0.35 s | Click / Hold |
| Hand Vacuum | $2,500 | 3.8 | 0.12 s | Stream |
| Turbine Vacuum | $15,000 | 6.0 | 0.08 s | Stream |

Bags go from 15 kg up to 4,000 kg ($0 → $45,000). The skill tree has four branches: Dig Speed (−7% cooldown per level), Dig Radius (+5%), Sand Value (+20%) and Walk Speed (+2). Each branch's costs grow geometrically. The relics pay $120–$5,000.

## Rebuilding the installer

Edit the files in `src/`, then run:

```bash
python3 build_installer.py   # regenerates SandsweepInstaller.lua
```
