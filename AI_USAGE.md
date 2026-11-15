# AI assistance and provenance

## Current baseline

The human team supplied the mission-design, resource exploration and No Man's Sky inspiration.
OpenAI Codex assisted with discussion, concept elaboration, the TypeScript/Three.js frontend,
shared interfaces, temporary preview rules, styling and collaboration documentation.
These are AI-assisted contributions; the team must review and accurately disclose them in the final submission.

The terrain, equipment costs, site coordinates, energy values and scoring in this baseline are
fictional educational content created with AI assistance. They are not NASA measurements,
flight specifications or a validated engineering simulation. This notice is their descriptive metadata.

No NASA logo, mission insignia or external artwork is included. Geometry is generated in code.
Fonts, if reachable, are served by Google Fonts; system fallbacks work without them.
No AI-generated raster images, video or audio have been included. Add appropriate labels/watermarks
and provenance if such assets are introduced.

## Claude engine contributions (milestone 1, branch `claude/engine`)

Anthropic's Claude (Claude Opus 5.5, via Claude Code) wrote, under the engine owner's direction:

- The mission engine in `src/engine/` (`design.ts`, `mission.ts`, `step.ts`, `report.ts`, `random.ts`,
  `rules.ts`, `index.ts`), implementing shared contract v1 without changing `src/shared/`.
- The Vitest engine tests in `src/engine/tests/`.
- The Vitest dev dependency and `test` script in `package.json` / `pnpm-lock.yaml`, agreed with the frontend teammate.

The rule values in `src/engine/rules.ts` and the seeded site layouts in `src/engine/mission.ts` are
fictional balancing values carried over from the preview rules. They are not NASA measurements,
flight specifications or a validated engineering model; the files say so beside the values.
No NASA datasets are used by the engine yet. The human team must review this code and disclose
it accurately in the final submission.

## Claude engine contributions (milestone 2, branch `claude/engine-m2`)

Claude (Claude Opus 5.5, via Claude Code) implemented the contract v2 changes the team agreed:

- `src/shared/types.ts`: `outpostPosition`, `Site.confidence`, `Site.finding` and `MissionReport.confirmedSites`.
- `src/engine/evidence.ts`, plus updates to `mission.ts`, `step.ts`, `report.ts`, `index.ts` and a new `src/engine/README.md`:
  findings, confidence transitions, seeded false positives and station position.
- `src/preview/engine.ts`: only initialises the new fields so the project compiles; no preview rules changed.
- Vitest tests in `src/engine/tests/milestone2.test.ts`.

The false-positive chances and confidence ranges in `src/engine/evidence.ts` are fictional balancing
values, not NASA observations or a validated detection model.

## Codex frontend integration for contract v2

Codex connected the human-approved milestone 2 contract to the interface: finding labels,
confidence meters, candidate-site distances, a persistent station position and debrief counts.
Codex also updated collaboration documentation for contract v2 and the owner's decision to keep the repo public.
The renderer displays engine-provided findings and confidence; it does not infer the hidden resource outcomes.
No new scientific measurements, NASA datasets or generated media assets were introduced.

## Native Godot foundation

The human team chose Godot and a standalone rover exploration game. Codex created the native project,
GDScript terrain, collision, rover/camera controls, HUD, menu, scanner effect and temporary native simulation
adapter under `godot/`. Codex wrote and ran native physics/mission integration checks and exported a Windows build.
The native preview deliberately adapts map scale and power values for continuous driving; all are fictional.
The TypeScript engine's 83 tests were not ported and do not establish native simulation coverage.
Claude's next task is the independent GDScript production simulation and its own native tests.
Generated scenery is code-native geometry and shaders, not NASA imagery. No generated image, audio or video assets are bundled.

## Codex Moon environment update

Codex created the procedural regolith shader, fictional crater/rim terrain, decorative landing module,
approach lights, rover track rendering, terrain-following scan visualization, local radar and scene hooks for spaceflight.
Codex also improved rover/camera presentation and ran native physics and real-renderer integration checks.
All scene assets are generated from code; no NASA imagery, elevation products or third-party artwork is included.
The environment is illustrative, and Earth sky scale/position are composed for gameplay.

## Claude native simulation port (branch `claude/godot-engine`)

Claude (Claude Opus 5.5, via Claude Code) ported the mission simulation to GDScript in `godot/simulation/`
(`mission_engine.gd`, `rules.gd`, `design.gd`, `evidence.gd`, `README.md`). The adapter no longer uses the preview.
Claude also wrote the native tests and runner in `godot/tests/simulation/` and ran them, together with
Codex's `tests/smoke.gd`, on the official Godot 4.7.2 Linux headless binary. Scenes, HUD, preview rules,
the shared contract and project settings were not changed.
All rule values, evidence ranges and false-positive chances are fictional balancing values, not NASA data.
Differences from the preview are listed in `godot/simulation/README.md`.

## Claude spaceflight feature (branch `claude/spaceflight`)

Claude (Claude Opus 5.5, via Claude Code) designed and wrote the spaceflight feature:

- **Pure simulation modules:** `godot/simulation/ship_flight.gd`, `destinations.gd`, `travel.gd`, `expedition.gd`,
  and the additive `create_surface_mission` in `mission_engine.gd`.
- **Scenes and scripts:** everything in `godot/spaceflight/` and `godot/scenes/spaceflight/`.
- **Tests:** `godot/tests/simulation/test_ship_flight.gd`, `test_travel.gd`, `test_mars_surface.gd`,
  `test_expedition.gd` and `godot/tests/spaceflight/scene_checks.gd`.

All ship, planet, terrain, sky, effect and UI visuals are procedural geometry and shaders generated in code.
No external or AI-generated image, audio, model or font assets are bundled, and no NASA imagery or insignia is used.

Real facts shown in game come from NASA and JPL pages listed in `godot/spaceflight/FACTS.md`; Claude
retrieved them by web search on 2026-11-14. The only facts used in mechanics are the Moon and Mars surface
gravities (they scale ascent and descent costs) and Mars's ~1.5 AU distance from the Sun (from which the
×0.43 solar factor is derived). Every other number, the Aurora Delta region and the compressed map are
fictional and labelled as such.

Codex's rover, lunar world, main scene, HUD, preview rules and shared files were reused without modification.
Claude ran the tests on the official Godot 4.7.2 Linux binary and reviewed offscreen screenshots of the scenes.

## Codex native integration review

Codex combined the Moon environment and Claude's PR #3/#4 on `codex/native-integration`, preserving both
developers' work. Codex wrote `godot/tests/integration/expedition_smoke.gd`, a driven-and-flown scene check
with runtime-error capture, and documented reproduced camera/transition defects in `godot/INTEGRATION_REVIEW.md`.
The check uses real rover physics and simulated player inputs without teleporting or changing mission resources;
it is automated verification, not a claim of human playtesting. Captured game views are engine renders of the
AI-assisted procedural content. No new external artwork, NASA datasets or scientific observations were added.
Codex subsequently integrated Claude's fix `762b0f8` and verified the corrected mission on the RTX 4050.
Codex added a Windows preview launcher flag in its main script and packaged the combined native game;
the shared project settings and configured default lunar scene were preserved.

## Codex NASA Moon and campaign preparation

At the user's request, Codex wrote the campaign ownership/interface handoff and imported NASA LRO/LOLA
LDEM_16 V3.1 elevation into compact global and south-polar Godot resources. The source label, checksum,
conversion units, data producer, repro script and deliberate geometric distortions are recorded in
`godot/data/terrain/README.md`. Measured elevations were not generated by AI.
Codex wrote the globe overview/picking UI, connected it to the standalone lunar mission, replaced broad
Moon landforms with the sampled data, expanded renderer support, added public checkpoint visuals and
physical rover impact telemetry/condition feedback, and wrote native checks for these features.
Small craters, rocks, resources, buildings and fine detail remain AI-assisted fictional additions.
The story/landing/Mars-weather/damage-rule implementation is assigned to Claude and is not claimed complete
by the Moon work. No NASA imagery or insignia and no AI-generated raster/audio/video assets were added.

## Claude First Light campaign (branch `claude/nasa-campaign`)

Claude (Claude Opus 5.5, via Claude Code) wrote the campaign side of `godot/NASA_CAMPAIGN_HANDOFF.md`:

- **Simulation:** `godot/simulation/campaign.gd` (story, objectives, checkpoints, recovery) and
  `landing.gd` (player-controlled final descent with assist). In `mission_engine.gd`: time, Mars dust storms,
  gentle impact damage and free repair. In `expedition.gd`: the landing phase, data relay and repair on
  boarding. In `destinations.gd`: larger regions, shelter, storm pacing and NASA sources. Impact tuning in `rules.gd`.
- **Scenes:** `godot/spaceflight/landing_scene.gd`, `mission_control.gd`, `checkpoint_beacons.gd` and
  `scenes/spaceflight/campaign.tscn`. Updates to `expedition_game.gd`, `expedition_ui.gd`, `surface_scene.gd`,
  `surface_hud.gd`, `mars_world.gd` (larger region, shelter, storm visuals) and `ship_model.gd` (descent thrusters).
- **Docs:** `godot/shared/CAMPAIGN_CONTRACT.md` (the agreed additive keys, documented beside the contract;
  `mission_contract.gd` unchanged), `godot/spaceflight/CAMPAIGN.md` and source updates in `FACTS.md`.
- **Tests:** `tests/simulation/test_landing.gd`, `test_hazards.gd` and `test_campaign.gd`, updated region tests,
  new scene checks, and `tests/spaceflight/campaign_route.gd` (a driven route with no position, energy or fuel edits).

Claude checked the story framing against NASA's VIPER and Perseverance pages and the Mars dust-storm article on
2026-11-14. The dust-storm article was read through search results, because the page needed an approval that
could not be shown. The Artemis page was not opened, so no in-game fact relies on it alone. Mars terrain is
procedural and inspired by delta landforms; no NASA elevation product is used for Mars. Every tuning value
(storms, damage, landing envelope, assist, regions, checkpoints) is fictional and labelled. No Codex-owned file
was edited. All visuals are procedural, generated in code; no external or AI-generated media are bundled.

## Codex First Light integration

Codex integrated Claude's PR #5 on the combined NASA Moon baseline, adapted Codex's expedition landing
test for controlled descent without removing existing assertions, and added the Windows campaign launch
option in Codex's main script. Codex ran the native checks and packaged a Windows preview with source/engine
credits. Direct NASA Artemis-science and dust-storm source checks are recorded in FIRST_LIGHT_INTEGRATION.md.
Codex also added a campaign input-driver variant that refreshes held keyboard input during driving to tolerate
native-window focus resets. It inherits the original objectives and manual landing checks and changes neither
gameplay rules nor mission resources. Initial failed GPU driver runs are documented honestly.
This integration adds no NASA Mars data and does not claim human control/difficulty playtesting.

## Codex compact campaign HUD

At the user's request and using their earlier HUD screenshot as the layout reference, Codex made the campaign
surface HUD compact, restored the survey minimap on both worlds, connected clickable action buttons and moved
temporary Mission Control banners above the gameplay area. Full original notes and recent logs remain in
scrollable regions; objectives, findings/confidence, science, power, ship fuel, cores, integrity and weather
remain displayed. The minimap uses only public state, the ship position and public checkpoint markers.
Codex rendered isolated Moon/Mars fixtures and checked information retention and actual scan-button dispatch.
No simulation, damage, science, landing or campaign rules changed.

## Codex mission-planning prototype and annotation fixes

At the user's request to take over all code while Claude is inactive, Codex imported NASA MOLA MEGT90N000EB
V2.0 topography and added it to Mars broad relief and a new regional traverse-planning lab. Codex wrote the
grid-search, physical slope/illustrative energy comparison, return/reserve check, planetary route export,
interactive planning screen and tests. Actual LOLA/MOLA elevation values are measured NASA data, not AI-generated.
The exact source labels, SHA-256 hashes, resampling and distortions are documented beside the resources.
The planner is an AI-assisted regional screening prototype, not a NASA-used or flight-validated operations tool.
Codex also fixed collocated checkpoint labels, screen-space world-label overlap, overflowing menus and flight
navigation-tag placement. Full objective/site information remains in the compact HUD. No claim is made that
all possible bugs have been eliminated. Scenery details and numerical tuning remain fictional where labelled.

## Codex cinematic problem-to-solution story

At the user's request, Codex added native Godot 3D camera sequences for the rover return-planning problem,
the player's candidate-plan explanation and the actual campaign results. Codex wrote the presentation code,
captions, menu/lab handoff, validation gate, cancellation/focus handling and integration checks. The selected
candidate is copied for presentation and its actual calculated values are displayed. Closing captions use
the real expedition report and do not claim success for an unfinished campaign. The field-route test retains
its objectives and now checks the completed closing scene and unchanged results; onboarding has a separate
real-menu test. No mission scoring or resource rules changed.

Cinematic relief uses existing measured NASA LOLA/MOLA data, compressed for illustration. Models, camera
paths, story and equipment visuals are fictional and AI-assisted code; these are not NASA mission footage.
No external or AI-generated raster, audio or video media are bundled. See godot/CINEMATICS.md for scope.

## Codex shared scenery, solid props and historical return

Codex's subsequent visual/collision update replaces simplified film assets with the actual gameplay worlds
and rover, adds static collision to missing solid props, bakes nonuniform visual transforms into convex
shapes and aligns the rover's footprint with its wheels. Station hardware is offset from the authoritative
deployment anchor to avoid trapping the rover and is non-solid before deployment. Codex added actual-body
sweep checks and adapted the full-route driver to use the ship's existing boarding radius rather than
aim through the newly solid ship. No rewards, resources or scientific outcomes are edited to win the tests.

Codex also wrote an optional historical Artemis I explanation, accessible only from a completed campaign
report. Its procedural capsule, service module, parachutes and ocean are illustrative, not engineering
replicas. Exact NASA sources were read directly and are documented in godot/EARTH_RETURN.md. No footage,
logos, raster assets, voiceover or other external media was added. It does not depict the fictional Mars
ship as a real NASA Earth-return mission or change the campaign state.

## Codex interactive mission instruments and original audio

Codex subsequently added hands-on scanner tuning, illustrative drill-feed/heat control and a local
station power/return decision to human surface actions. Results explain the actual simulation finding
and next action. The authoritative engine still applies the same action costs/rewards once; controls
never determine hidden truth. New tests cover manual input, assist, cancellation/recovery, duplication,
constraints and audio pause/mute. The full-route driver now operates the tools through player controls.

Codex composed and synthesised an original ambient score and feedback effects using the deterministic
standard-library generator in godot/tools/generate_audio.py, then added contextual playback and persistent
volume/mute controls. No outside recordings, licensed songs, NASA audio, voiceover or external libraries
were used. All audio is optional and every state has visual feedback. The measured NASA terrain and prior
credits are retained. Scientific inspiration and exact sources checked on 2026-11-15 are documented in
godot/INTERACTIVE_MISSIONS.md; instrument thresholds and local operational estimates are fictional.

## Codex player guide and objective presentation

Codex added a global, context-aware F1 controls guide covering rover operation, instruments, spaceflight,
descent, planning, story and audio. Its printable export uses the same content. The guide preserves pause
and keyboard focus and can replace the audio panel safely. Codex also implemented the requested large
centre-screen announcement for each new objective, followed by a fade/move to a persistent top reminder.
Announcements wait behind briefings, menus, transitions and tool results. Live distances update without
restarting the animation; interrupted announcements cannot restore stale objective text. Nearby HUD and
planet labels were repositioned/culled to avoid overlap. No simulation, rewards or mission objectives changed.
Targeted rendered checks cover guide navigation, pause/audio handoff and objective animation/replacement.

## Before submission (native and browser reference)

Record Claude's engine contributions here. List actual NASA datasets/resources and where they affect
the game. Review the current submission guide for disclosure requirements and enter the team's
own accurate account of idea development, implementation and AI assistance.
