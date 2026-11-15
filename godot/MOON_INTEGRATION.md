# Moon environment integration

## NASA campaign hooks (codex/nasa-moon)

The latest Moon branch uses real LRO/LOLA broad elevation; read `data/terrain/README.md` before changing
terrain claims. Call `world.configure_extent(destination_rules.map_limit)` BEFORE `world.build(sites)`.
The default terrain patch spans 960 game units; engine movement limits remain authoritative.
`world.update_checkpoints(checkpoints)` draws only the supplied public checkpoint fields from
`NASA_CAMPAIGN_HANDOFF.md`, without awarding progress or revealing hidden outcomes.

Connect `rover.impact_reported(impact_speed)` to campaign damage rules; the scene coalesces contacts for one
second, while the simulation should enforce its agreed longer cooldown. Floor landings use actual pre-contact
vertical speed; side hits use speed into the collision normal. `rover.set_condition(integrity)` applies visual
wear and at most 20% speed reduction. The scene never invents or subtracts health.

For an expedition surface, instantiate `scripts/moon_atlas.gd`, connect its `close_requested` signal, then call
`show_map()`/`hide_map()` while saving/restoring the surface pause state. Picking a point emits
`survey_selected(latitude, longitude)` for planning only; do not teleport the rover or complete an objective.
The standalone lunar main already opens this with M. The atlas standalone scene is `scenes/moon_atlas.tscn`.
Claude owns connecting it to the expedition surface. No Claude files were edited by this branch.

Validation: 92 simulation tests, 74 flight scene checks, the driven Moon/Mars round trip, lunar smoke and
`tests/integration/nasa_moon_checks.gd` pass. Atlas, impact and lunar smoke checks also pass with the RTX 4050.
The Windows release export starts cleanly. These checks are not a claim of human playtesting.

## Earlier procedural environment baseline

The Moon presentation update is on `codex/moon-environment`, based on the shared `codex/godot-native` baseline.
It changes no simulation methods, state schema, project settings or resource truths.
Claude can continue the native simulation and spaceflight work on separate branches.

## Owned frontend additions

- `scripts/lunar_world.gd`: textured regolith, crater terrain/collision, horizon, Earth, beacons,
  a ground-following scan pulse and bounded wheel-track instances.
- `scripts/moon_landmarks.gd`: original procedural landing equipment, landing lights and a collision body.
- `scripts/moon_radar.gd`: presentation-only radar using only site positions/findings already in state.
- `shaders/`: original procedural lunar-surface and Earth shaders. No external images.
- Rover: slope-following visual body, suspension/solar-panel details and camera obstruction checks.
- HUD: local region, simulated exposure, speed, slope, distance to base and survey radar.

## Spaceflight hook

The world exposes `get_landing_anchor() -> Marker3D` at:
`MoonSurface/LandingSite/LandingAnchor`.
Use the marker's global transform as a proposed visual docking/takeoff anchor, and coordinate actual
vehicle transitions with the existing main scene owner. Do not modify the simulation's rover position just to
place a spaceship. The decorative module is `world.landmarks.landing_module`; it can be hidden when a real ship replaces it.
The anchor sits above the decorative lander so it is not the rover ground spawn.

`world.presentation_for(position)` returns region, exposure label, terrain slope and base distance for the HUD.
Those are presentation hints, not a replacement for simulation validation or a new resource/energy model.
The western shadow display matches the already agreed x < -18 fictional recharge region.

## Limits and checks

The terrain is illustrative; it is not a reconstruction of Shackleton or a NASA elevation product.
Earth position and scale are composed for the scene. No scientific accuracy is claimed for its size in the sky.
Camera collision is a ray-based obstruction check, not a full vehicle/spring-arm physics simulation.
Wheel tracks retain at most 1024 stamps, recycling the oldest. They are visual only and do not alter terrain physics.

Run `tests/smoke.gd` in headless mode for mission/terrain checks, and with real graphics for MultiMesh placement.
The dummy headless renderer does not retain instance transforms, so the track transform assertion is graphics-only.
For a deterministic render of the scene fixture:

```sh
godot --path . --script res://tests/smoke.gd -- --capture /absolute/output/moon.png
```
