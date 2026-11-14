# Native Blue Horizon

The user chose a standalone Godot game. Do not convert it back to a website or embed the web UI.
Use Godot 4.7.2 standard edition and GDScript. Preserve the browser prototype as a reference.

Read `README.md`, `CLAUDE_HANDOFF.md` and `shared/mission_contract.gd` here before working.

Ownership:
- Codex: scenes, rover/camera/terrain/HUD scripts, preview rules and integration checks.
- Claude: `simulation/` and tests of the native production simulation.
- The user also assigned Claude spaceship/planet travel: new `spaceflight/` modules and `scenes/spaceflight/` scenes, after the simulation port. Existing main/Moon/rover/HUD integration remains with Codex.
- Joint: shared contract, project settings and export presets; agree before edits.

Simulation is pure state transitions, with no scene-tree, input, physics or rendering dependencies.
The scene measures actual collision-resolved displacement; the simulation authorizes it and charges energy.
Never charge a fixed rounded energy amount per rendered or physics frame.
Keep station position authoritative. Never reveal hidden signal truth through UI or scene nodes.
State confidence is certainty in a finding, not probability of resource presence.
All current terrain, resource distribution, confidence and equipment values are fictional.
Do not claim the 83 TypeScript tests cover the GDScript port. Add meaningful native tests.
Do not spawn subagents automatically or overwrite the other developer's files.
Do not commit `.godot/`, export templates, downloaded engines or large executable builds.
The user explicitly chose to keep the repository public. Do not change that setting.
