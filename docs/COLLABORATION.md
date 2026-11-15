# Working together

## Current work: NASA campaign

2026-11-15 update: Claude is inactive and the user has assigned Codex the whole project. The combined
`codex/native-integration` baseline includes measured MOLA Mars relief, the NASA traverse planning lab,
compact HUD/minimap and world-label decluttering. The cinematic update adds a problem briefing,
candidate-plan explanation and actual-results closing scene. Earlier ownership/task notes below are
historical; NASA-derived Mars terrain is now implemented. Human difficulty/feel playtesting remains needed.

First Light from PR #5 is integrated on `codex/first-light`. The old expedition landing helper now exercises
the new descent with assist; the separate campaign route exercises manual descent and all twelve objectives.
The Windows preview has a dedicated campaign launcher. Human playtesting and NASA-derived Mars terrain
remain outstanding; do not restart the campaign implementation task.

The combined native baseline is `codex/native-integration`, with Claude's flight fix `762b0f8` and Codex's
NASA Moon preparation. Read `godot/NASA_CAMPAIGN_HANDOFF.md` for the active split and agreed additions.
Codex owns Moon elevation/atlas/rover telemetry; Claude owns the new campaign/landing/Mars-weather rules.
The port and first flight review are complete; do not repeat those tasks. Older milestones below are history.

## Active native migration

The team chose a standalone Godot 4.7.2 game. The shared native baseline is `codex/godot-native`.
Read `godot/README.md` and `godot/CLAUDE_HANDOFF.md`. Claude's next branch is `claude/godot-engine`,
based on that native baseline. The browser contract and PR order below are historical reference.
Do not add new TypeScript gameplay features while the native simulation is being ported.

## First milestone

One mission that goes all the way from design through launch, rover operations and debrief.
Current scaffold: vanilla TypeScript, Three.js and Vite. No backend or accounts.
The lunar area is illustrative, not a reconstruction of real terrain.

## Branches and boundaries

The initial common starter goes on `main`. The owner has chosen to keep the repository public.
Once shared, both developers branch from that same baseline:

- `codex/frontend`: interface, 3D map, controls, integration.
- `claude/engine`: simulation implementation and its tests.
- `claude/engine-m2`: station position and confidence, stacked on the first engine PR.

Keep commits small. Each person pushes their own branch and opens a pull request.
The lead merges the engine branch, pulls the merged code, then checks the complete mission.
Do not both edit the same files. If a new shared field is needed, agree on its name, type and meaning first.

## Shared contract v2

`src/shared/types.ts` is the source of truth. The UI imports `engine` from `src/engine/index.ts`.

| Operation | Purpose |
| --- | --- |
| `createMission(config, seed)` | Create an unlaunched mission. |
| `reviewDesign(config)` | Return cost, mass, limits and launch warnings. |
| `step(state, action)` | Return a new state, never mutate the input. |
| `getReport(state)` | Produce a report from mission state. |

Actions: launch, move, scan, sample, recharge, transmit, deploy, finish.
Movement coordinates are x (east/west) and z (north/south); one commanded move is at most one map unit.
Sites are within the square from -10 to 10 on both axes. A 2.5-unit proximity threshold is the preview convention.
The present UI uses `scienceCollected - scienceReturned` as onboard data.
`outpostDeployed` remains, and `outpostPosition` records the deployment coordinates or is null before deployment.
The renderer always uses those coordinates; it must not infer station placement from the current rover position.

Each site exposes `confidence` (an integer from 0 to 100) and `finding`:
`unconfirmed` → `probable` → `confirmed` or `ruled-out`.
Confidence is certainty in the current finding, not the chance that a resource exists.
Use these engine fields for labels and colors; never infer the hidden outcome in the interface.
False-positive resource signals still earn science when sampled. Scoring remains unchanged.
`confirmedSites` counts confirmed field findings, including any that have not yet been transmitted.
Only returned science contributes to the science part of the score.

## Claude's first deliverable

Replace the preview re-export in `src/engine/index.ts` with an independent engine under `src/engine/`.
Start with design validation, immutable movement, energy consumption, scanning/sampling progression,
finite recharges, transmission, deployment and a report. Match the contract before adding features.

Check invalid and duplicate actions, over-budget launches, non-finite moves, map limits,
non-negative resources, no duplicate science, and completed missions that cannot be modified.
Use meaningful tests to establish these rules. Replaying a seed and action sequence must produce the same state.

Milestone 2 adds station coordinates, evidence confidence and seeded false positives. See `src/engine/README.md`.
Future work includes orbital choices, launch fuel, payload-dependent movement costs,
communication windows, mission events and separate objectives. Agree on further contract changes first.

## Integration order

PR #1 targets `main`; PR #2 initially targets `claude/engine` and contains only milestone 2.
Merge PR #1 first, then retarget PR #2 to `main` and merge it. Explicitly check the target before merging.
The frontend integration branch includes both engine commits locally and adds the contract v2 displays.
Merge its frontend changes after the two engine PRs, keeping the engine branches intact until their dependent PRs are retargeted.

## Current limitations

The active engine lives in `src/engine/`; `src/preview/engine.ts` is retained only as an old UI fixture.
All balancing rules are fictional. Solar shade is a simple map zone.
Fuel cells are limited recharge tokens. No fuel production, extraction, construction materials,
resource processing, validated orbital mechanics, dynamic shadows or damage events are implemented.
The prototype reveals three candidate sites, not confirmed resource quantities.
The score rewards returned science and station deployment; efficiency scoring is pending.
The camera is fixed. Controls work on keyboard or the directional buttons.

## Other teammates

Research owner: deliver eight sourced equipment records and three resource investigations,
with units, NASA URL, what the source supports, and which numerical values are fictional balancing values.
Experience/demo owner: watch three people attempt a mission, record where they get stuck,
write help text and prepare a demo of at most 30 seconds or seven slides.
Track submission text, NASA references and AI disclosures alongside development.

## Run

Install Node.js 22.12+ and use either npm or pnpm. This baseline commits a pnpm lockfile,
so use pnpm for dependency updates and keep one lockfile.

```sh
pnpm install
pnpm dev
pnpm test
pnpm build
```

For machines with only npm, `npm install` and `npm run dev` work, but coordinate before committing an npm lockfile.
