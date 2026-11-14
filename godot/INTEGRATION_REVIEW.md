# Native integration review — 2026-11-14

Local integration branch: `codex/native-integration`.
Combines Codex's Moon environment (`eb7c9fd`), PR #3 (`4f00ba5`) and PR #4 (`ab4d9a2`).
The merge preserved both developers' AI disclosures. No GitHub PR was merged or retargeted.
No Claude-owned feature source, shared contract or project setting was edited during this review.

## Results on official Godot 4.7.2, Windows

- Native simulation: 92 tests, 45,587 assertions, zero failures.
- Existing spaceflight scene checks: 54 checks pass.
- Codex lunar mission/physics smoke check: passes with the real OpenGL renderer (RTX 4050), including track placement.
- Godot editor import and Windows release export: pass.
- New `tests/integration/expedition_smoke.gd`: fails on two reproduced integration defects below.

The new check drives to the mineral site on each world through real rover physics, scans/samples/transmits
through keyboard events, drives back to board, flies both legs through player-equivalent autopilot inputs,
lands through the L key and delivers one Mars core. It changes no position, energy or fuel fields. Camera yaw
is adjusted by the driver, equivalent to right-mouse steering. The normal route returns the expected 95 science
(40 Moon, 20 Mars scan data, 35 delivered core science). It is an automated integration check, not a human
assessment of steering/camera feel or proof that every site/equipment combination is reachable.

The earlier PR #4 full-loop fixture teleports the rover and refills its battery for investigations. It tests
scene wiring and flight, but should not be described as an entire mission using only player inputs.

## Fix before promoting PR #4

### 1. Takeoff continuation resumes flight after the player has ended the expedition

`spaceflight/expedition_game.gd`: `takeoff()` awaits `transition.covered` then calls `_show_space(target)`
without checking whether the expedition was completed while waiting. The existing surface scene accepts
Escape during the fade. Choose End Expedition from that pause screen: a debrief appears, but the continuation
then installs an unpaused flight scene underneath it. Holding thrust can change ship state behind the report.
`land()` has a similar unguarded continuation and should be audited too.

Recommended fix: make transitions exclusive with an explicit transition token/state; cancel or invalidate
pending continuations on finish/restart. After each await, check the token and expected expedition phase
before installing a scene. Ensure no scene can keep changing a completed expedition. If menus are locked
during transitions instead, document that policy and update the regression to assert the lock consistently.

Reproduction already included: begin → drive to ship → G → choose takeoff → Escape during the first fade →
End Expedition → wait for the fade. Expected: completed state and debrief, no unpaused flight scene.

### 2. Destination marker projects a point on the camera plane

`spaceflight/flight_hud.gd:167` unconditionally calls `camera.unproject_position(world_position)`.
The first flight frame can run before the chase camera has updated its transform. When camera-local target
depth is zero, Godot reports `Condition "p.d == 0" is true. Returning: Point2()`.
Reproduced with both headless and real graphics in the new driven mission check.

Recommended fix: initialise the chase camera before the first HUD update, and guard near-zero camera-local
target depth before projection. Keep edge markers well-defined for targets behind or beside the camera.
Add a focused regression with a target on the camera plane.

### Test reporting

Use the new check's Logger (or the simulation runner's equivalent) to make Godot runtime errors fail scene
tests. `tests/spaceflight/scene_checks.gd` currently only counts explicit `check()` failures. A pass there
alone cannot establish that no Godot runtime errors were raised.

## Run

```sh
godot --headless --path godot --script res://tests/simulation/run_tests.gd
godot --headless --fixed-fps 60 --path godot --script res://tests/spaceflight/scene_checks.gd
godot --headless --fixed-fps 60 --path godot --script res://tests/integration/expedition_smoke.gd
godot --path godot --script res://tests/smoke.gd
```

For captured views of the actual driven expedition (requires graphics):

```sh
godot --path godot --fixed-fps 60 --script res://tests/integration/expedition_smoke.gd -- --capture-dir /absolute/output/folder
```

The integration check is intentionally red until the two defects are fixed. It does not mask runtime errors.
It also verifies the current pause-then-end behaviour during ascent; change that assertion only if a documented
transition input lock intentionally replaces that behaviour.

## Coordination

PR #3's simulation is suitable for integration based on this review. Fix the PR #4 defects before promoting
the expedition to the default launch scene. Keep dependent PRs intact until their bases are correctly retargeted.
This branch is a combined review snapshot, not a substitute for the dependency order on GitHub.

The existing additive `create_surface_mission` API and separate expedition state are a reasonable direction.
No native contract v2, main-scene change or new destination work is approved or implemented by this review;
write the exact shared schema and per-destination rule access in the next joint handoff before editing them.

NASA primary pages were checked against the source catalogue: Moon Facts, Mars Facts, JPL's Mars at a Glance
and NASA's travel-time explainer. The gravity ratios, distances and travel-time descriptions are supported.
The 0.43 solar factor is an inverse-square approximation, not measured panel output. The simplified ascent
scaling, compressed routes, fictional terrain and resource distribution are not a validated mission model.
