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

## Before submission (native and browser reference)

Record Claude's engine contributions here. List actual NASA datasets/resources and where they affect
the game. Review the current submission guide for disclosure requirements and enter the team's
own accurate account of idea development, implementation and AI assistance.
