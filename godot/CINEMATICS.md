# First Light cinematic flow

Choose **Begin First Light** in the campaign planning menu:

1. **Problem briefing:** an 18-second, three-shot 3D sequence introduces reaching a useful site while
   preserving terrain access and enough energy for the return journey and reserve.
2. **Your decision:** control passes to the NASA elevation planning lab. Set study points, slope limit,
   assumed battery capacity and reserve. Compare the distance- and energy-weighted return traverses.
3. **Explain the candidate:** **Present This Plan** is enabled only for a candidate that passes the model.
   Its 18-second presentation draws that candidate's outbound route and explains its actual calculated
   distance, energy, remaining reserve and maximum sampled slope. It then starts the field campaign.
4. **Field expedition:** the existing twelve objectives, controlled landings, resource investigations,
   storms and recovery remain playable. Study coordinates do not relocate the game objectives or rover.
5. **Closing explanation:** ending the expedition plays an 18-second results scene before revealing the
   detailed report. Captions use actual completed objectives, returned science, delivered sample science,
   stations and fuel. An early-ended expedition is described as incomplete rather than successful.

**Space, Enter, Escape or the on-screen button skips a cinematic.** Skipping the introduction opens the lab;
skipping the candidate presentation starts the campaign; skipping the closing scene reveals the report.
**Replay Briefing** repeats the problem introduction. Closing the lab cancels a pending campaign start.
The free-study menu option and surface **P** lab do not start a new expedition when a plan is presented.
Surface planning preserves the previous pause state. The underlying report remains available after a film.

## Presentation and provenance

These are native Godot 3D camera sequences, generated in code with captions, letterboxing and existing
procedural ship/rover geometry. They are not recorded NASA mission footage and contain no voiceover,
external artwork, generated raster assets or pre-rendered video. Hidden cinematic viewports stop rendering.

2026-11-15 visual/collision correction: surface films now instantiate the actual `lunar_world.gd` /
`mars_world.gd` renderers and `rover.gd` presentation mode, using the same mesh detail, lighting, sky and
materials as gameplay. The separate simplified terrain/rover were removed. The rover stays stationary
during camera shots; input, physics and its follow camera are disabled for the presentation instance.
MSAA smooths edges. Only a candidate presentation shows its route; a results scene no longer invents one.

The completed campaign report also offers a separate, optional **REAL EARTH RETURN: ARTEMIS I** reference.
See [its exact historical scope and NASA sources](EARTH_RETURN.md). This does not fly the fictional ship
to Earth or change campaign results. Space/Enter/Escape skips back to the report.

Broad relief comes from the same resampled NASA LOLA/MOLA patches as the planner. The cinematic compresses
horizontal and vertical scales for illustration; equipment and fine appearance are fictional. The selected
amber outbound route is mapped into this illustrative scene, not issued as a rover command sequence.
Read [LOLA provenance](data/terrain/README.md), [MOLA provenance](data/terrain/MOLA.md) and the
[planning model and limitations](ROUTE_PLANNING.md).

The demonstrated solution is a candidate under the stated simplified slope, energy and return-reserve
model. It is not flight validated. Illumination, thermal survival, communications, rocks and soil slip remain
unresolved operational checks. The field game uses separate fictional scales and energy balancing.

## Verification

`tests/integration/cinematic_checks.gd` checks animated cameras, actual keyboard skipping (including a
previously focused Present button), cancellation before launch, rejection of an infeasible candidate,
snapshot-based calculated captions, handoff without a duplicate briefing, and truthful early-end results.
It also fails on runtime errors and can capture rendered frames when given an output folder.

`tests/spaceflight/campaign_route.gd` retains the driven twelve-objective route and adds checks that its
actual successful results appear in the closing scene, natural completion reveals the report and the film
cannot change results. This field-route fixture calls `start()` directly; the separate cinematic fixture
exercises the real menu start and presentation handoff. Neither fixture edits campaign resources to win.

```sh
godot --headless --path . --script res://tests/integration/cinematic_checks.gd
godot --headless --path . --fixed-fps 60 --script res://tests/integration/first_light_route.gd
```

Automated checks cover the flow and rendered layout; they do not replace a human playtest of pacing and feel.

Verified on official Godot 4.7.2 for Windows: cinematic checks pass headless and on RTX 4050 OpenGL;
the complete driven campaign passes 41 checks, including its successful closing scene; the scene suite
passes 115 checks with no runtime errors; simulation passes 131 tests / 45,804 assertions. The Windows
release exports and starts in campaign mode. A headless input fixture initially sent successive presses
within one frame; separating real press/release events across process frames fixed the driver. Cinematic
keys are also captured before focused controls can consume them.

The subsequent shared-scenery/collision update passes 1,134 prop/geometry checks, 115 scene checks,
the Moon physics smoke test and the full 44-check campaign route on RTX 4050 OpenGL, with no runtime errors.
The completed route verifies unlocking the historical explanation without awarding any Earth delivery.
The hazards fixture now parks outside the solid ship before measuring storm-only effects; its original
no-wind-push/no-outdoor-drain assertions remain. The boarding driver uses the existing boarding radius.
These fixture corrections do not remove collision, weather or campaign requirements.
