# First Light integration — 2026-11-15

PR #5 head reviewed: `7e0baa9`, based on the combined NASA Moon baseline `f6d4387`.
Codex integrated the PR on `codex/first-light`, without changing Claude's gameplay source or the configured
main scene. Codex adapted its own `tests/integration/expedition_smoke.gd` landing helper: L must enter
`landing`, T enables assist, the driver waits for descent and touchdown and retains every existing assertion.
Claude's separate campaign route flies manual descents and checks all twelve objectives.

Codex also added an explicit `-- --campaign` entry option to its main script so official Windows release
templates can launch the campaign. The release templates do not accept arbitrary command-line scene paths.
The Windows package's `Play First Light.cmd` passes this option; opening the EXE alone retains the Moon sandbox.

## Verification

- 125 simulation tests; 45,779 assertions, no failures.
- 115 scene checks; no failures or Godot runtime errors.
- Updated expedition route: passes without editing mission resources or rover positions.
- First Light route: 37 checks pass headless, including all twelve objectives and manual descents.
- Initial GPU input-driver runs stopped driving on two different approaches and missed three objectives.
  They reported no runtime errors, but were not campaign passes. A southern detour passed headless but
  did not solve the GPU automation stop. Codex's `tests/integration/first_light_route.gd` instead refreshes
  held W each driving frame to tolerate native-window focus/input resets. It inherits every campaign
  assertion and manually driven descent, never edits mission resources/positions, and changes no gameplay code.
- With refreshed drive input, the full route passes all 37 checks both headless and with the RTX 4050:
  all twelve objectives completed, one core delivered, no runtime errors. The evidence supports input-driver
  resets as the reason for the earlier stops, rather than an impassable lunar route.
- Moon smoke and NASA terrain/atlas/impact checks pass with the RTX 4050 OpenGL renderer.
- Windows release export and campaign startup pass.

NASA pages opened directly on 2026-11-15:

- https://www.nasa.gov/humans-in-space/artemis-science/ supports field geology, sample collection/return and
  deployed experiments as science activities. The game is a fictional future expedition, not mission history.
- https://www.nasa.gov/solar-system/the-fact-and-fiction-of-martian-dust-storms/ supports reduced solar energy
  and darker skies, and explains why high Martian wind speeds do not imply Earth-like destructive forces.
  The game's exact storm durations, multipliers and lack of storm damage are labelled design simplifications.

Codex corrected the old FACTS.md statement that storms are not modelled: the 0.43 factor describes the
clear-sky solar calculation, while First Light applies a separate fictional weather multiplier.

## Remaining scope

Human control/camera/difficulty playtesting is still required. Automated input drivers are not human playtests.
Moon terrain uses actual NASA LOLA elevations with documented distortions. Mars is still procedural and labelled
delta-inspired: no NASA Mars elevation product has been imported. The whole-Moon atlas is an overview, and
neither world is a complete drivable planet. Do not report those requests as fulfilled by this integration.
GitHub pull requests were not merged or retargeted by this local integration.
