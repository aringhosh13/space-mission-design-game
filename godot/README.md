# Blue Horizon — native Godot game

**First Light campaign:** open `scenes/spaceflight/campaign.tscn` and press F6, or use the Windows package's
`Play First Light.cmd` (`BlueHorizon.exe -- --campaign`). Its twelve objectives include manual landing,
Moon surveys, Mars sample collection, storms, repairs and checkpoint recovery. Read
[the campaign play guide](spaceflight/CAMPAIGN.md). The configured F5 main scene remains the Moon sandbox.

**NASA traverse planning lab:** open it from the campaign planning menu or press P on a surface. It compares
distance- and energy-weighted return traverses on raw NASA LOLA/MOLA elevation, checks a slope/battery/reserve
model and exports planetary GeoJSON candidates. Read [scope, sources and limitations](ROUTE_PLANNING.md).
This is a regional screening prototype, not a flight-validated operations system.

**Cinematic story flow:** Begin First Light opens a skippable 18-second native 3D problem briefing,
then hands control to the NASA-data planning lab. Find a candidate that fits the stated constraints and
choose **Present This Plan**. Its short presentation explains the selected route's actual calculated
energy/reserve and slope values before starting the fictional field campaign. A closing cinematic uses
the expedition's actual results, including an honest incomplete outcome if ended early.
Space, Enter or Escape skips a cinematic; **Replay Briefing** repeats the introduction.
Read [the cinematic flow and checks](CINEMATICS.md).

The compact campaign surface HUD restores the circular minimap and clickable scan/sample/power/transmit/
station/boarding controls. Signal letters match the map, H marks the ship, and a ring marks the active
checkpoint. Full notes and the same recent mission-log messages remain available in scrollable compact
areas. All objective, confidence, resource, condition, weather and NASA-gravity information is retained.

This is the active game direction. It opens as a standalone 3D Windows game, using Godot 4.7.2,
not a browser wrapper. It has rover physics, terrain collisions, a following camera, scanning effects,
equipment selection, resource investigations, power, research station placement, pause and a debrief.

The Moon environment update adds procedural regolith detail, smoother craters, an irregular crater-rim
horizon, a landing module with approach lights, wheel tracks, terrain-following scan pulses and survey radar.
Read [the Moon/spaceflight integration notes](MOON_INTEGRATION.md) before combining the ship feature.

On `codex/nasa-moon`, the Moon's broad landforms now use NASA LOLA elevation, with an interactive whole-Moon
atlas (M during the standalone lunar mission). See [data provenance and distortions](data/terrain/README.md).
The campaign split and exact Claude task are in [NASA_CAMPAIGN_HANDOFF.md](NASA_CAMPAIGN_HANDOFF.md).

## Open and play

1. Download **Godot 4.7.2 standard** (not .NET) from https://godotengine.org/download/windows/.
2. Extract the editor. Import this directory's `project.godot`.
3. Press F6 only to run the selected scene, or F5 to run the whole project.
4. Choose equipment and launch. Scanner + drill is selected initially so sampling is available.

| Input | Action |
| --- | --- |
| WASD / arrows | Drive relative to the camera |
| Hold right mouse + move | Orbit the following camera |
| Mouse wheel | Change camera distance |
| E | Scan a signal within 6 m |
| Q | Analyse a scanned site's sample; drill required |
| R | Recharge; solar requires x >= -18, fuel cells have three uses |
| T | Transmit onboard evidence |
| B | Establish a research station at your location |
| M | Open/close the NASA elevation atlas (standalone lunar mission; pauses driving) |
| F | Finish the mission and show the report |
| Escape | Pause, resume or quit via the menu |

Look for the labeled amber rings in the world. HUD distances help navigation.
Ruled-out deposits still earn useful science. Return evidence before ending the mission.
New expeditions advance the seed during the same game session.

## Current implementation status

On `codex/native-integration`, the native adapter uses Claude's independent GDScript simulation from PR #3.
The former `preview/mission_preview.gd` remains a reference fixture, not the active simulation.
The TypeScript prototype's 83 tests remain reference behavior; native coverage comes from the Godot tests.
The native integration check covers launch immutability, station persistence, movement power,
duplicate scans, sample/transmit flow, mission closure, terrain collision and keyboard driving.

The optional Moon → Mars → home expedition from PR #4 is available by opening
`scenes/spaceflight/expedition_demo.tscn` and pressing F6. F5 still runs the lunar mission.
Claude's fix `762b0f8` resolves the transition and camera defects found in integration review.
Read [the integration review](INTEGRATION_REVIEW.md) for verification results and
[the flight instructions](spaceflight/README.md) for controls.
The Windows package's `Play Blue Horizon.cmd` opens the expedition via `BlueHorizon.exe -- --expedition`.
This explicit launch option works with official release templates, which disable command-line scene overrides.
Opening the executable directly still runs the lunar mission.

The Moon's broad terrain is derived from measured NASA LRO/LOLA elevation, with large scale distortions and
fictional fine detail. Resource distributions and equipment balancing values remain fictional educational
content created with AI assistance. The flight expedition uses cited NASA facts for gravity and a derived
solar factor; see [facts and simplifications](spaceflight/FACTS.md). No real resource quantities are represented.
No NASA logos or insignia are included.
Scenery is generated in code; there are no external artwork or texture dependencies.

Claude's PR #5 connects the enlarged renderer, checkpoint beacons and rover impact telemetry to First Light.
Campaign driving spans ±150 m on the Moon and ±220 m on Mars. The older standalone Moon mission keeps ±78 m.
The campaign implements story progress, controlled descent, forgiving damage/repair and Mars storms.
The atlas is global; detailed driving remains regional. Mars broad relief now uses measured NASA MOLA
topography; see [MOLA provenance](data/terrain/MOLA.md). Delta details, game routes and sites remain fictional.

## Native contract v1

Frontend imports `simulation/mission_engine.gd` as a RefCounted adapter. It exposes:

- `create_mission(config: Dictionary, mission_seed: int) -> Dictionary`
- `review_design(config: Dictionary) -> Dictionary`
- `move_rover(state: Dictionary, proposed_position: Vector3) -> Dictionary`
- `act(state: Dictionary, action: String) -> Dictionary`
- `get_report(state: Dictionary) -> Dictionary`

Use snake_case state fields, `Vector3` positions and the schema in `shared/mission_contract.gd` plus
the existing preview. `sites` is an Array of site dictionaries. Methods return a new state and do not mutate inputs.
Actions: `launch`, `scan`, `sample`, `recharge`, `transmit`, `deploy`, `finish`.
Scene physics proposes positions after collision resolution, and restores the position returned by the simulation.
Movement energy uses actual horizontal metres, independent of frame rate.
Do not move the rover to a different map coordinate scale when porting the old rules.

World boundary is +/-78 m. Interaction distance is 6 m. Western shadow is x < -18.
Native playability values: batteries 100/160, movement 0.16 energy/m, scan 4, sample 8,
transmit 3, deploy 12, recharge 40. Budget/mass and science rewards match the earlier prototype.
These changes deliberately suit continuous driving on the larger world; they are fictional balancing values.
Native seeded evidence need not match TypeScript bit-for-bit, but must reproduce within Godot across visits,
equipment choices, replays and frame rates. Document any intentional outcome differences.

## Ownership and branches

- `codex/godot-native`: shared native baseline, scene, camera, rover, HUD and integration.
- Friend branches **from this native baseline** to `claude/godot-engine`, implementing `simulation/` and tests.
- Do not continue new gameplay work on the old `claude/engine` TypeScript branch.
- Shared contract/configuration changes need agreement first.

Read [the Claude handoff](CLAUDE_HANDOFF.md) for the first native simulation task.

## Validate and export

With Godot on PATH:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/smoke.gd
```

Install matching export templates using Godot's Export Template Manager. The Windows Desktop preset
uses standard templates. For only a Windows release build, its `windows_release_x86_64.exe` template
is sufficient; debug exports need the corresponding debug template as well.

```sh
godot --headless --path . --export-release "Windows Desktop" builds/BlueHorizon.exe
```

The preset embeds the game data into the executable. Distribute the license notices with it.
The downloaded editor, build tools and executable outputs are not committed to Git.
