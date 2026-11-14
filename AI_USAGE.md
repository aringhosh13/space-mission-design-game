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

## Before submission (native and browser reference)

Record Claude's engine contributions here. List actual NASA datasets/resources and where they affect
the game. Review the current submission guide for disclosure requirements and enter the team's
own accurate account of idea development, implementation and AI assistance.
