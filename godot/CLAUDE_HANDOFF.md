# Paste into your friend's Claude Code session

We are switching Blue Horizon to a native Godot 4.7.2 game, as the team agreed.
The active baseline is on `codex/godot-native` in:
https://github.com/aringhosh13/space-mission-design-game

Preserve all uncommitted work. Fetch that branch and create `claude/godot-engine` from it.
Do not branch from old main or continue adding TypeScript features.
Read root AGENTS.md, godot/AGENTS.md, godot/README.md and godot/shared/mission_contract.gd.

Your task is to port the production mission simulation into `godot/simulation/` using GDScript.
The adapter currently re-exports temporary playability rules from `godot/preview/mission_preview.gd`.
Replace that dependency with the real native implementation while preserving all five adapter methods
and the state schema consumed by the scene and HUD.

Use the TypeScript engine and its 83 tests as a behavioral reference, not a claim of native test coverage.
Keep native world coordinates, interaction distance and energy values from godot/README.md.
Movement is continuous: charge actual distance, independent of rendering/physics frame count.

First implement and test:
- Design validation and launch restrictions.
- Immutable state transitions and reproducible mission generation.
- Finite, bounded positions and non-negative distance-based power accounting.
- Scan/sample progression, hidden seeded false positives and integer finding confidence.
- Duplicate actions cannot give repeated science or reroll a result.
- Solar restrictions, finite fuel cell charges, transmission and closed-mission immutability.
- Persistent station coordinates and the unchanged returned-science/station scoring principle.
- Equivalent energy for equal travel split into different frame counts.

Keep simulation independent of Nodes, input, rendering, network and wall-clock time.
Own `godot/simulation/` and native simulation tests. Do not edit scenes, camera/rover/HUD scripts
or preview rules. Joint changes to the contract, project settings or export presets need agreement.
If more exact schema detail is needed, read the existing preview and document assumptions before changing it.

Install a compatible official headless Godot binary in your cloud environment if needed.
Run native simulation tests and godot/tests/smoke.gd. Update AI_USAGE.md honestly.
Commit and push `claude/godot-engine`, then open a PR targeting `codex/godot-native` while that baseline
is not merged into main. State the dependency clearly. Do not merge or change other PRs or repository visibility.
