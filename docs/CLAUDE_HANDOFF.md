# Paste this into Claude Code after the starter is shared

Historical browser handoff. For the active native Godot game, use `godot/CLAUDE_HANDOFF.md` instead.

We are building Blue Horizon in this repo: https://github.com/aringhosh13/space-mission-design-game.
I own the simulation/game engine; my teammate uses Codex for the frontend and Three.js exploration.

First pull the shared starter and create my `claude/engine` branch. Read AGENTS.md,
docs/COLLABORATION.md, src/shared/types.ts and src/shared/catalog.ts.
Check git status and preserve existing work.

Implement the MissionEngine contract under src/engine/. Replace the temporary preview export in src/engine/index.ts.
Keep the engine free of UI, Three.js, network calls and real-time dependencies. Preserve input states;
return new states and keep seed-based behavior reproducible.

First implement and test:
1. Budget and mass validation; invalid designs cannot launch.
2. Bounded rover movement and non-negative power accounting.
3. Scan first, sample with the correct tool, no repeated science rewards.
4. Solar charging restricted to the lit zone; finite fuel-cell supplies.
5. Collected versus transmitted science, deployment cost and mission completion.
6. A report explaining concrete outcomes and losses.

Use src/preview/engine.ts as a behavior reference, not as a scientifically validated model.
Do not edit src/main.ts, src/ui/, src/style.css or src/preview/.
Treat src/shared/, package configuration and the lockfile as joint ownership.
If a contract change is required, describe it and wait for agreement from my teammate before editing those files.
Use the current contract for the first milestone. Propose confidence, fuel, communications and events for the next milestone.

Run meaningful engine tests and the production build. Add honest AI attribution for your contributions.
Commit on my branch and give me a summary plus the pull request steps. Never push directly to the other developer's branch.
