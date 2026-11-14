# Blue Horizon: First Light — next development split

User request: NASA-inspired story missions, multiple checkpoints, much larger explorable worlds,
player-controlled landing, NASA-derived terrain, Mars dust storms and gentle rover impact damage.
This is a fictional future expedition informed by NASA science, not a recreation of an actual mission.

Baseline: latest `codex/native-integration`, including the verified PR #4 fix `762b0f8` and Codex's NASA Moon
preparation. The pre-Moon integration point was `d940a44`; do not reset to it and lose the new Moon work.
Codex's next branch is `codex/nasa-moon`. Claude's new branch should be `claude/nasa-campaign`.
Preserve uncommitted work, read applicable AGENTS files and do not merge/retarget old PRs as part of this task.

## Codex builds in parallel

- Real lunar elevation import, metadata and reproducible processing under `godot/data/terrain/` and `godot/tools/`.
- Moon terrain, larger-region rendering and an interactive global lunar overview in `godot/scripts/`.
- Presentation-only checkpoint beacons with `world.update_checkpoints(checkpoints: Array)`.
- Rover impact telemetry and feedback in `scripts/rover.gd`:
  `signal impact_reported(impact_speed: float)` reports a hard landing or collision once, not every contact frame.
  `set_condition(integrity: float)` sets a visual condition indicator and limits speed loss to 20%.
  Health is NOT computed or stored authoritatively by the rover.
- Existing Moon main/HUD integration, terrain and physics checks.

Do not edit those files on Claude's branch. Codex will supply terrain provenance and explicit scene hooks.

## Claude builds

Own new campaign rules and tests in `simulation/`, plus expedition/landing/Mars scenes and HUD in
`spaceflight/` and `scenes/spaceflight/`. Implement the following as one bounded playable campaign.

### Story and checkpoints

Title: **First Light**. Mission Control sends the player to assess routes and resources for a future
research outpost, then investigate Mars and return evidence. Keep briefings short and skippable.

Moon chapter (VIPER/Artemis science inspired): manually land safely; reach a survey ridge; investigate an
ice signal; investigate a geology signal; establish a relay/research station; return evidence to the ship.
Mars chapter (Perseverance science inspired): land near an ancient-delta-inspired region; scan layered rock;
collect a core; demonstrate a dust-storm/power decision with an accessible shelter checkpoint; return cores
to the Moon base and debrief. Do not claim to find life or that our deposits/route are real NASA observations.

Each objective has a visible waypoint, short Mission Control message and a clear completion condition based
on authoritative actions. Do not require a positive resource finding: ruling a signal out is valid science.
Checkpoints should preserve campaign progress and offer a nearby recovery point. Avoid replaying an entire
planet after a landing mistake. Do not undo delivered science or duplicate cores/rewards after recovery.

### Manual landing

Replace the default expedition's automatic surface swap after L with a controllable final-descent stage.
Player adjusts descent thrust and lateral position toward a visible pad. Show altitude, vertical speed,
alignment and a generous safe envelope. Include a clearly labelled landing assist option and a forgiving
retry from approach. Keep touchdown fuel/science accounting authoritative and charge descent only once.
Preserve cancellation/paused-transition fixes. Update tests to actually exercise descent controls, rather
than bypassing the new landing phase. Legacy low-level Travel.land may remain for compatibility.

### Larger worlds

Keep whole-globe flight/overview and detailed local landing regions as separate levels of detail.
Expand the playable Moon and Mars regions substantially with per-destination map limits, sensible rover
travel speed and reachable science sites. Codex's lunar renderer will expose `configure_extent(limit: float)`
before build; default remains compatible with the old ±78 m mission. Do not silently call a flat square
an entire spherical planet, or promise uniform rover-level detail around a whole planet in this milestone.
Keep interplanetary compression explicit. Whole-sphere seamless rover traversal is a later milestone.

### Mars dust storms

Use deterministic simulation elapsed time, with warnings and short storms. Their main consequences are
reduced visibility and solar charging. Suggested fictional pacing: 10 s warning, 25 s active, generous clear
interval; active solar multiplier 0.35 on top of the existing Mars factor. Label balancing values fictional.
Allow shelter/wait or fuel-cell play; avoid long compulsory waiting. Do not fling the rover with wind or
damage it just for being outdoors. Render dust/fog in Mars world code; no moon weather.

### Gentle rover damage

Connect `rover.impact_reported(speed)` to the simulation. Integrity starts at 100; damage only for hard
impacts, with a cooldown. Suggested fictional tuning: threshold 5 m/s, 3 s cooldown, 5–15 damage per hit,
floor 35 integrity. Never immobilise or destroy the rover. Ordinary suspension bumps and stationary crater
contact must not repeatedly hurt it. At the ship or shelter, allow simple free repair, without parts or money.
Expose integrity in the HUD and call `rover.set_condition(integrity)`. Checkpoint recovery must not reroll sites.

## Agreed additive interface direction

Codex agrees to these additions for this task; no extra permission loop is needed for the listed fields.
Keep existing adapter methods and legacy state keys working. Document exact new keys beside the shared
contract before implementing them, and keep the simulation independent of Nodes, rendering and wall-clock time.

- Per-surface mission: `integrity: float` (35–100), `impact_cooldown: float` (seconds),
  `elapsed_seconds: float`, `weather: Dictionary` with `phase` (clear/warning/storm), `remaining_seconds`,
  `solar_multiplier: float`.
- Expedition: optional `campaign: Dictionary` with chapter/current objective/completed objective ids and
  checkpoint snapshot; optional `landing: Dictionary`; additive `landing` phase during final descent.
- Presentation checkpoints: array of `{id: String, title: String, position: Vector3, completed: bool, active: bool}`.
  Codex world only draws these; Claude campaign rules determine completion and rewards.
- Agreed pure mission methods: `advance_surface(state, dt) -> Dictionary`, `apply_impact(state, impact_speed)
  -> Dictionary`, `repair_rover(state) -> Dictionary`. Expedition rules authorize repair proximity; the
  rover scene never awards health itself. Keep existing lunar consumers working without optional fields.
- Agreed expedition methods: `begin_landing(state, destination_id)`, `step_landing(state, controls, dt)`,
  `recover_checkpoint(state)` (all return a new Dictionary), and `checkpoint_list(state) -> Array` for the
  public presentation entries. Document exact control keys and landing telemetry beside the contract.
- Read map bounds and interaction distances from destination rules rather than one global Moon constant.
  The configured main scene/export presets stay unchanged; the existing expedition launcher remains valid.

## NASA sources to use and credit

- Lunar topography (Codex): https://pds-geosciences.wustl.edu/missions/lro/lola.htm
- VIPER prospecting objectives: https://science.nasa.gov/mission/viper/science-and-exploration/
- Artemis south-pole science: https://www.nasa.gov/humans-in-space/artemis-science/
- Perseverance objectives: https://science.nasa.gov/mission/mars-2020-perseverance/science-objectives/
- Mars storm effects: https://www.nasa.gov/solar-system/the-fact-and-fiction-of-martian-dust-storms/
- Mars terrain: select a real NASA MOLA/HiRISE elevation product, document the exact product/extent/units,
  processing and distortions. If only procedural terrain is implemented, label it inspired, not data-derived.

No new planets, combat, complex repairs, crafting, multiplayer or additional currencies in this milestone.
Write meaningful tests for progress/recovery, no duplicate science, impact cooldown/repair, deterministic
storm/solar effects, manual touchdown and transition cancellation. Run the existing simulation, scene and
driven-route checks, adapting the input driver for deliberate new controls without weakening assertions.
Update NASA references and AI_USAGE honestly. Open one new PR with a short play guide and captures.
Target `codex/native-integration` so the diff shows your campaign additions, not the entire native migration.

## Codex Moon implementation now available on this branch

Read `data/terrain/README.md` for the actual NASA product and distortions, and `MOON_INTEGRATION.md` for
ready-to-use hooks. `scripts/moon_atlas.gd` implements show_map/hide_map/is_open and close_requested;
connect it to expedition pause state on Moon surfaces. It is already connected to M in the standalone Moon.
The renderer can draw a much larger region, but legacy movement bounds deliberately remain unchanged until
your destination-rule update. Physical impacts currently provide feedback/telemetry only; your simulation
owns damage and repairs. No engine, spaceflight or shared configuration source was changed by Codex.
