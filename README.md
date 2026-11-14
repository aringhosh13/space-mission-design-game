# Blue Horizon

A lunar mission design and exploration game for a four-person Space Apps team.

This is a playable prototype with an independent mission engine, not the finished challenge submission.
Choose equipment, review cost and launch mass, deploy a rover, investigate three signals,
manage power, return evidence and establish a research station. Signals can be confirmed or ruled out by sampling;
the interface shows confidence in each finding and keeps the station at its deployment location.

## Start locally

Node.js 22.12+ is recommended.

```sh
pnpm install
pnpm dev
```

Open the local address printed by Vite. Move with WASD, arrow keys or the onscreen buttons.
Gold rings are candidate signals. Get within 2.5 map units to scan. A drill is needed to analyse samples.
Solar charging works east of x = -3. Transmit evidence before ending the mission.

```sh
pnpm build
pnpm test
pnpm preview
```

## Who works where?

- Codex: screens, styling, 3D scene and integration.
- Claude: independent simulation in `src/engine/`.
- Research teammate: NASA sources, equipment and scientific explanations.
- Experience/demo teammate: playtests, instructions, demo and submission material.

Read [the collaboration plan](docs/COLLABORATION.md),
[Claude's starter prompt](docs/CLAUDE_HANDOFF.md), and [AI attribution](AI_USAGE.md).

The interface contract lives in `src/shared/types.ts`.
The active engine is in `src/engine/`; the old preview fixture remains in `src/preview/engine.ts`.
The repository is public by the owner's choice. NASA data, real fuel/orbit constraints,
resource processing and unexpected events are pending. Confidence values are fictional game values.
