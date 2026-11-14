# Working together

## First milestone

One mission that goes all the way from design through launch, rover operations and debrief.
Current scaffold: vanilla TypeScript, Three.js and Vite. No backend or accounts.
The lunar area is illustrative, not a reconstruction of real terrain.

## Branches and boundaries

The initial common starter goes on `main` in the private repository.
Once shared, both developers branch from that same baseline:

- `codex/frontend`: interface, 3D map, controls, integration.
- `claude/engine`: simulation implementation and its tests.

Keep commits small. Each person pushes their own branch and opens a pull request.
The lead merges the engine branch, pulls the merged code, then checks the complete mission.
Do not both edit the same files. If a new shared field is needed, agree on its name, type and meaning first.

## Shared contract v1

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
The present state has only an outpost flag; agree on an outpost position field before implementing location persistence or return-to-base logic.

## Claude's first deliverable

Replace the preview re-export in `src/engine/index.ts` with an independent engine under `src/engine/`.
Start with design validation, immutable movement, energy consumption, scanning/sampling progression,
finite recharges, transmission, deployment and a report. Match the contract before adding features.

Check invalid and duplicate actions, over-budget launches, non-finite moves, map limits,
non-negative resources, no duplicate science, and completed missions that cannot be modified.
Use meaningful tests to establish these rules. Replaying a seed and action sequence must produce the same state.

Second milestone: propose contract extensions for confidence, orbital choices, launch fuel, payload-dependent movement costs,
communication windows, station coordinates, seeded events and separate mission objectives.
Do not invent fields inside the renderer or silently change the contract.

## Current limitations

All rules in `src/preview/engine.ts` are temporary and fictional. Solar shade is a simple map zone.
Fuel cells are limited recharge tokens. No fuel production, extraction, construction materials,
resource processing, validated orbital mechanics, dynamic shadows or damage events are implemented.
The prototype reveals three candidate sites, not confirmed resource quantities.
Preview score rewards returned science and station deployment; efficiency scoring is pending.
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
pnpm build
```

For machines with only npm, `npm install` and `npm run dev` work, but coordinate before committing an npm lockfile.
