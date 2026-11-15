# Blue Horizon: First Light — campaign guide

A fictional future expedition informed by NASA science, not a recreation of any real mission. Mission Control
sends you to assess routes and resources for a future lunar research outpost, then to investigate an
ancient-delta-inspired region on Mars and fly a sample core home. No combat, extra planets, crafting or
currencies. Ruling a signal out is valid science, and nothing in the game is presented as a real NASA observation.

## Play

Open `godot/project.godot` in Godot 4.7.2, open **`scenes/spaceflight/campaign.tscn`** and press **F6**.
From a terminal: `godot --path godot res://scenes/spaceflight/campaign.tscn`.
The project's main scene is unchanged.

1. **Plan.** The campaign needs the scanner + drill payload. Pick a fuel load (standard is comfortable).
2. **Briefing.** Read it, or skip with Enter. You start in lunar orbit above Shackleton Base.
3. **Moon chapter.** Press L to begin the final descent and land on the pad. Then drive to the survey ridge,
   scan the ice signal in the shadowed basin, scan the exposed formation, deploy the station (B) in sunlight,
   and board the ship (G).
4. **Mars chapter.** Take off for Mars, fly there, press L and land at Aurora Delta. Scan the layered delta front,
   drill a core (Q), then ride out the dust storm. The campaign brings the next storm forward so you never
   wait long. The dust shelter recharges you fully in any weather and repairs the rover.
5. **Home.** Board, fly home and land on the Moon pad: the core is delivered. Then press Esc and choose
   **End the expedition** for the debrief.

Beacons mark every objective: amber is active, green is done. Mission Control banners fade on their own (Enter
dismisses them). The top panel shows the current objective and its distance.

## Controls

| Where | Keys |
| --- | --- |
| Surface | WASD drive · right mouse look · E scan · Q sample · R recharge · T transmit · B station · G board · **H repair** (at the ship or shelter) · **M Moon atlas** (Moon only, planning only) · Esc menu |
| Flight | W thrust · S brake · A/D steer · R/F pitch · hold C align · Tab destination · **L begin descent** · Esc menu |
| **Final descent** | **W/S throttle lever** · X cut throttle · **arrow keys or I/J/K/L side thrusters** (camera faces north) · **T landing assist** · **R retry** after an unsafe touchdown · Esc menu |
| Menus | Enter skips the briefing · pause menu: Resume, **Recover to last checkpoint**, End, New, Quit |

## Forgiving by design

- **Landing.** The safe envelope is generous: slower than 3 m/s down, drifting under 2 m/s, within 15 m of the
  pad centre. An unsafe touchdown aborts safely; press R to retry from the approach point. The descent fuel is
  charged once, when you press L, so retries cost no fuel. The assist (T) can fly the whole descent.
- **Checkpoints.** Each completed objective saves a nearby checkpoint (the Mars shelter is one too).
  *Recover to last checkpoint* returns the rover to it with at least 60% battery, restarts a flight leg from just
  after takeoff, or restarts a descent. Science, findings, stations, cores, deliveries and completed objectives
  are never changed or duplicated, and sites never reroll.
- **Rover damage.** Only hard impacts of 5 m/s or more count: 5–15 damage, with a 3 s cooldown between hits.
  Integrity never drops below 35 and the rover is never immobilised. A worn rover uses up to 40% more energy per
  metre. Repairs are free with H at the ship or shelter, and boarding the ship repairs it too.
- **Dust storms (Mars only).** 10 s warning, then 25 s of storm. In a storm, solar charging drops to ×0.35 (on top
  of Mars's ×0.43) and visibility falls. Storms never push or damage the rover. Fuel cells, the shelter or a full
  battery all work.
- **Data relay.** Boarding the ship relays any data you haven't transmitted. Sample cores still have to be
  flown home physically.

## What is real and what is fictional

| Real (NASA, labelled in game) | Fictional game mechanic |
| --- | --- |
| Moon and Mars surface gravity (1.62 and 3.71 m/s²) set ascent and descent costs and final-descent gravity | Engine power, side thrusters, thrust allowance, safe envelope, assist |
| Mars ~1.5 AU from the Sun → the ×0.43 solar factor (derived) | Storm pacing and the ×0.35 storm factor; the shelter power bank |
| Martian dust reduces sunlight on solar panels; even big storms are unlikely to topple equipment | No wind forces, no storm damage (a design choice consistent with the source) |
| Polar ice in permanently shadowed regions; VIPER-style prospecting goals | Site positions, deposits, false-positive chances, confidence ranges |
| Perseverance studies delta and lake habitability and caches samples for possible return | Aurora Delta region, sample cores, science values, scores |
| Interplanetary travel takes months | Compressed map distances and travel times |

Terrain: the Moon uses Codex's NASA LRO/LOLA-derived relief (see `godot/data/terrain/README.md` for the product
and distortions). Mars broad relief now uses measured MOLA MEGT90N000EB topography around the Jezero region;
see `data/terrain/MOLA.md`. Fine delta shapes, dunes, craters and the expedition story remain fictional overlays.
Press P on either surface for a separate regional route-planning lab using physical DEM units, not game scales.

Sources are in `spaceflight/FACTS.md`.

## Larger regions and levels of detail

Space flight remains a compressed whole-system view, and Codex's lunar atlas (M on Moon surfaces) gives a
planning-only global overview. Each landing site is a separate, larger **local** surface region: the Moon survey
region allows ±150 m and Mars ±220 m (the v1 lunar game keeps ±78 m). Neither is a whole planet, and rover-level
detail exists only inside these regions. The surface and landing scenes call `world.configure_extent()` with the
destination's map limit; Codex's lunar renderer on this base supports it. For an older lunar world without it,
the scene falls back to invisible collision walls at ±107 m, and every campaign site lies inside that area.

## Integration notes for Codex

- **Agreed method names:** mission `advance_surface`, `apply_impact` and `repair_rover`; expedition
  `begin_landing`, `step_landing`, `recover_checkpoint` and `checkpoint_list`. Details are in `shared/CAMPAIGN_CONTRACT.md`.
- **Codex's atlas** (`scripts/moon_atlas.gd`) is connected to Moon surfaces: M toggles it, the pause state is saved and
  restored, and `survey_selected` only shows a planning note.
- **Hooks used when present** (all exist on the current base; no Codex files edited):
  - `world.configure_extent(limit)` before `build()`
  - `world.update_checkpoints(list)`; until it exists the surface scene draws `spaceflight/checkpoint_beacons.gd`
  - `rover.impact_reported(speed)` → `engine.apply_impact`
  - `rover.set_condition(integrity)` after each change
- New keys and methods are documented in `shared/CAMPAIGN_CONTRACT.md`. `mission_contract.gd`, project settings
  and export presets are unchanged.
- **`tests/integration/expedition_smoke.gd` needs one adaptation** (Codex-owned, so not edited here). Its `land()`
  helper presses L and expects the surface, but L now starts the final descent. A drop-in replacement that keeps
  every assertion:

  ```gdscript
  func land() -> void:
  	key(KEY_L, true)
  	key(KEY_L, false)
  	await wait_transition()                 # descent transition
  	key(KEY_T, true)                        # landing assist on (or fly it manually)
  	key(KEY_T, false)
  	for i in range(4000):
  		if game.expedition.phase != "landing": break
  		await physics_frame
  	await wait_transition()                 # touchdown transition
  	await frames(45)
  	check(game.expedition.phase == "surface", "Keyboard landing failed")
  ```

  With only this change, the unmodified rest of `expedition_smoke.gd` passes on this branch (checked from a
  scratch copy). `tests/spaceflight/campaign_route.gd` is the adapted driven route for the campaign. It flies
  every descent manually without the assist.
