# Spaceflight: ship, travel between worlds and the Moon → Mars → home loop

Claude-owned feature branch `claude/spaceflight`, built on the native simulation port (`claude/godot-engine`).
Everything is native Godot 4.7.2 GDScript. Codex's rover, lunar terrain, main scene, HUD, preview rules,
shared contract, project settings and export presets are **not modified**. The rover and lunar world are
reused as-is.

## Run the demonstrations

Open `godot/project.godot` in Godot 4.7.2 standard, open a scene below and press **F6** (run current scene).
The project's main scene (F5) is still Codex's lunar game.

| Scene | What it shows |
| --- | --- |
| `scenes/spaceflight/campaign.tscn` | **First Light story campaign** (see [CAMPAIGN.md](CAMPAIGN.md)): guided Moon → Mars → home with manual landings, checkpoints, dust storms and gentle rover damage |
| `scenes/spaceflight/expedition_demo.tscn` | **The full playable loop:** plan → Moon → board → take off → fly → land on Mars → investigate → fly home → debrief |
| `scenes/spaceflight/ship_sandbox.tscn` | Stage 1: fly the ship through buoys |
| `scenes/spaceflight/space_travel.tscn` | Stage 2: Moon ⇄ Mars flights with landing and takeoff transitions |
| `scenes/spaceflight/mars_surface.tscn` | Stage 3: the Aurora Delta landing region with the rover |

From a terminal (Godot on PATH): `godot --path godot res://scenes/spaceflight/expedition_demo.tscn`

## Controls

**Surface (rover):** WASD drive · hold right mouse to look · wheel zoom · E scan · Q sample · R recharge ·
T transmit · B deploy station · **G board the ship** (within 9 m of it) · Esc menu.

**Flight:** W thrust · S brake (retro thrust against your velocity) · A/D steer · R/F pitch ·
**hold C to align with the target** · Tab change destination · **L land** (inside the approach zone,
below 6 u/s) · Esc menu.

**Final descent** (after L): W/S throttle lever · X cut · arrow keys or I/J/K/L side thrusters · T landing assist ·
R retry after an unsafe touchdown (no extra fuel).

**Aboard:** take off for another world, deploy the rover again, or end the expedition.

## How the loop plays

1. **Plan.** Choose battery, power and payload (the rover design review is unchanged), then a fuel load
   (light 450 / standard 650 / full 850 kg). The screen shows ship mass, delta-v and the estimated delta-v
   for a Mars round trip at 60 u/s cruise.
2. **Moon.** The rover starts at the home base. Investigate and transmit as in the lunar game, then drive to
   the parked ship and press G.
3. **Take off.** The ascent burn is paid at the current mass. In space you fly freely: there is no drag,
   so you coast until you brake. The HUD shows velocity, thrust, fuel, delta-v, mass, target distance,
   closing speed, ETA, approach status and real-world distance and travel time.
4. **Land on Mars.** Slow below 6 u/s inside the approach zone and press L. The descent burn is cheaper on
   Mars because its atmosphere does part of the braking (a fictional factor).
5. **Investigate.** Mars signals are worth more, driving costs more in sand, solar output is 43% of the Moon's,
   and only scan data can be radioed home. Samples become **sealed cores** when you board: 6 kg each.
6. **Fly home** and land at the Moon base. Cores are delivered and their science counts. Then end the
   expedition for the debrief.

### Decisions and consequences

| Choice | Consequence |
| --- | --- |
| Fuel load | More fuel gives more delta-v but adds mass (rocket equation, so diminishing returns). A light load can't make the round trip at 60 u/s, but succeeds at ~25 u/s (tested). |
| Cruise speed | Every u/s you speed up must be braked away again. Fast trips cost fuel. |
| Rover payload (battery, drill) | Heavier rovers raise ship mass, so every burn costs more. |
| Sample cores | Each adds 6 kg to the flight home, and Mars ascent is the costliest burn (real gravity ratio). |
| Solar vs fuel cells | Mars solar output is 43%. Fuel cells work anywhere, but one supply of 3 is shared across both worlds. |
| Scanner vs drill | Drill sample science on Mars only counts if the cores reach home. A scanner-only rover is lighter but data-only. |
| Where the expedition ends | Cores still aboard, samples never stowed and untransmitted data are listed as losses. Ending away from home is reported. |

## Architecture

Pure simulation (no Nodes, input, physics engine, rendering or wall-clock time; inputs never mutated):

| File | Role |
| --- | --- |
| `simulation/ship_flight.gd` | Ship state and flight model: thrust, braking, steering, rocket-equation fuel and delta-v |
| `simulation/destinations.gd` | **Reusable destination definitions:** space position and size, approach zone, gravity, facts with sources, surface rules and sites |
| `simulation/travel.gd` | Proximity guard, system boundary, approach guidance, landing and takeoff costs, round-trip estimate |
| `simulation/mission_engine.gd` | Contract v1 adapter plus additive `create_surface_mission(config, seed, destination_id)` |
| `simulation/expedition.gd` | The loop: begin, rover moves and actions, board, disembark, takeoff, fly, land, finish, report |

Scenes and presentation (`godot/spaceflight/`):

| File | Role |
| --- | --- |
| `ship_model.gd`, `ship_rig.gd` | Procedural ship, throttle-driven flame, exhaust particles, retro flares, engine light, landing legs |
| `chase_camera.gd` | Smoothed follow camera, speed-based FOV |
| `space_sky.gd` | Procedural star sky with sun disc (sky shader) |
| `planet_body.gd` | Procedural planet, atmosphere rim, camera-facing approach-zone outline, label |
| `flight_hud.gd` | Flight HUD and on-screen or edge target marker |
| `space_scene.gd` | **Reusable space scene** (see API below) |
| `mars_world.gd` | Aurora Delta terrain and lighting, with the same API as `scripts/lunar_world.gd` |
| `surface_scene.gd`, `surface_hud.gd` | **Reusable surface scene** for any explorable destination (reuses Codex's rover) |
| `transition_overlay.gd` | Takeoff and landing transition cards |
| `expedition_game.gd`, `expedition_ui.gd` | Demo orchestrator and its planning, aboard, pause and debrief screens |
| `pilot_input.gd`, `autopilot.gd` | Keyboard reading, the align assist, and the test autopilot (it only issues player inputs) |

### Adding a destination

Add one entry to `DESTINATIONS` in `simulation/destinations.gd`:

- `space` (position, radius, approach altitude, landing speed limit)
- `gravity`, `atmosphere_braking`, `pad`, `boarding_range`
- `facts` (each with a `source` id from `SOURCES`), `real_distance`, `real_travel`, `fiction`
- for explorable worlds, `surface` (rules with the same keys as `Rules.MOON`, plus optional `sample_return` and `core_mass`, with unique site ids)

Then give it a world script with the lunar world API: `build`, `terrain_height`, `update_mission`, `pulse`.
`tests/simulation/test_travel.gd` checks every destination for completeness, sources, separation and site
placement.

## Integration instructions for Codex

1. **Space scene** (`spaceflight/space_scene.gd`): call `setup(ship, target_id, status_line)` before
   `add_child`. Connect `land_requested(destination_id)`, `menu_requested()` and `ship_changed(ship)`.
   Set `paused` for menus. `input_override` (a Dictionary) replaces the keyboard for cutscenes or tests.
2. **Surface scene** (`spaceflight/surface_scene.gd`): call `setup(destination_id, mission_state, info)`
   before `add_child`. Connect `board_requested()`, `mission_changed(state)` and `menu_requested()`.
   `info` feeds the HUD (`ship_fuel`, `cores`, `notes`, `subtitle`). It reuses `scripts/rover.gd`, plus
   `scripts/lunar_world.gd` on the Moon.
3. **Expedition state** (`simulation/expedition.gd`) is authoritative. Copy scene changes back as
   `expedition_game.gd` does: mission state on `mission_changed`, ship on `ship_changed`. Sync the surface
   state before `Expedition.board()`.
4. **Your main scene and HUD** can host the loop by replacing the single mission with an expedition:
   `Expedition.create` / `begin` → surface → `board` → `takeoff` → space scene → `land` → `disembark`.
   `expedition_game.gd` is a working reference of about 200 lines.
5. **Station and findings rendering** is unchanged: both worlds read `outpost_position`, `finding` and
   `confidence` from the mission state and never see hidden truth.

## Shared-contract changes to agree (flagged, not made)

No shared file (`shared/mission_contract.gd`, `project.godot`, export presets) was edited. Codex's main game
still calls `create_mission` and gets exactly the contract v1 state; a test checks this.

1. **Additive engine method and state key.** `create_surface_mission(config, seed, destination_id)` adds a
   `destination` key to the mission state. Proposed for native contract v2.
2. **Per-destination constants.** `Contract.MAP_LIMIT` and `INTERACTION_RANGE` are lunar values. Mars uses the
   same numbers today, but future worlds may not. Proposal: read them from `destinations.gd` (for example a
   `Contract.rules_for(destination)` helper).
3. **Expedition state as a new contract.** Its phases (`planning`, `surface`, `aboard`, `flight`,
   `complete`), `ship`, `missions`, `cores` and `report` should be agreed before your HUD depends on them.
4. **Main scene.** `run/main_scene` still points to the lunar game. Switching it to the expedition (or merging
   the flows) is a joint project-setting change.
5. **Key bindings.** Flight reuses WASD (one scene is active at a time). G boards. R/F pitch in flight but
   R recharges on the surface.

## Facts and fiction

Real figures appear in the game with a "(NASA)" label. Sources and the values derived from them are listed in
[FACTS.md](FACTS.md). Everything else (map positions, body sizes, distances, travel times, ship masses,
thrust, exhaust velocity, delta-v scale, energy, science, site layouts, the atmosphere braking factor, core
mass, scores) is a **fictional balancing value** and is labelled as such in code and on screen.
Simplifications: bodies are fixed in place, with no orbital mechanics, gravity in flight or launch windows.

## Assets and provenance

All geometry, terrain, planets, sky, ship, effects and UI are generated in code by Claude (shaders and
procedural meshes). No external models, textures, images, audio or fonts are added. UI text uses Godot's
built-in default font, covered by the engine notices from `tools/license_notices.gd`. No NASA imagery,
logos or insignia are used.

## Tests

```sh
godot --headless --path godot --script res://tests/simulation/run_tests.gd   # pure simulation, all stages
godot --headless --path godot --script res://tests/spaceflight/scene_checks.gd   # scenes, stages 1-4
godot --headless --path godot --script res://tests/smoke.gd                 # Codex's lunar integration checks
```
