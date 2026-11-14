# Blue Horizon collaboration

Two humans use separate AI coding tools. Do not spawn subagents automatically.

## Ownership

- ACTIVE NATIVE GAME: Godot 4.7.2 project under `godot/`. Read `godot/AGENTS.md` and `godot/README.md` before native changes.
- Native Codex: `godot/scripts/`, `godot/scenes/`, `godot/preview/`, frontend integration tests.
- Native Claude: `godot/simulation/` and native simulation tests.
- Native Claude also owns new spaceship/travel modules under `godot/spaceflight/` and `godot/scenes/spaceflight/`, as requested by the user. Coordinate changes to the existing main scene with Codex.
- Native joint: `godot/shared/mission_contract.gd`, `godot/project.godot`, export presets. Agree before changing these.
- The TypeScript directories below are the preserved browser prototype and behavioral reference, not the active native game.
- Codex: `src/main.ts`, `src/ui/`, `src/style.css`, UI preview in `src/preview/`.
- Claude: `src/engine/` and engine tests.
- Joint: `src/shared/`, package manifests, lockfile and project config. Propose a contract change to the other teammate before changing it.
- Research teammate: source catalogue and research content in `docs/research/`.
- Experience/demo teammate: playtest notes, instructions, demo script and submission material in `docs/demo/`.

## Rules

- Read `docs/COLLABORATION.md` and `src/shared/types.ts` first.
- The UI calls only the engine interface; real mission calculations belong in `src/engine/`.
- Keep simulation independent of Three.js, DOM, network calls and wall-clock time.
- Use a seeded random generator for reproducible missions.
- Never treat simulated deposits, mock values or prototype results as NASA observations.
- Cite NASA resources and identify simplifications when integrating real data.
- Keep AI contributions acknowledged in `AI_USAGE.md`; add provenance beside generated assets/data.
- After the initial shared baseline on `main`, make changes on your own branch. Do not force-push or overwrite another person's work.
- Run the production build after code changes; write meaningful tests for simulation invariants.
- Never commit secrets or `node_modules`. The owner has chosen a public repository; do not change visibility without permission.
