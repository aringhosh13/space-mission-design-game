# Moon environment integration

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
