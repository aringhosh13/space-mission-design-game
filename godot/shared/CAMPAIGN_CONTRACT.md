# Native contract additions for the First Light campaign (additive)

Agreed in `godot/NASA_CAMPAIGN_HANDOFF.md` (codex/nasa-moon `d06d778`). `mission_contract.gd` is unchanged.
Every addition is optional. The five v1 adapter methods, `create_mission()` and states without these keys keep
their old behaviour: a mission without a `destination` key uses the original lunar rules (`Rules.MOON`, ±78 m).
All tuning values are fictional balancing values unless a NASA source is named.

## Per-surface mission state (created by `create_surface_mission`)

| Key | Type | Meaning |
| --- | --- | --- |
| `destination` | String | `"moon"` or `"mars"` (already in PR #4) |
| `integrity` | float 35–100 | Rover condition. Starts at 100 and never drops below 35. Above 35 the rover is never immobilised. |
| `impact_cooldown` | float, seconds | Time before another hard impact can cause damage |
| `elapsed_seconds` | float | Simulation time on this surface. It advances only through `advance_surface`, never from the wall clock. |
| `weather` | Dictionary | `{phase: "clear"/"warning"/"storm", remaining_seconds: float, solar_multiplier: float, next_storm_at: float}` |

Missions created by `create_mission` (v1) have none of these keys, and every method treats them as absent:
clear weather, integrity 100, no cooldown.

## Pure mission-engine methods (simulation/mission_engine.gd)

| Method | Effect |
| --- | --- |
| `advance_surface(state, seconds) -> Dictionary` | Advances `elapsed_seconds`, decays `impact_cooldown` and updates `weather` deterministically. Surface phase only. |
| `apply_impact(state, impact_speed) -> Dictionary` | Damages only at speeds of 5 m/s or more and when the cooldown is 0: 5–15 points, floor 35, then a 3 s cooldown |
| `repair_rover(state) -> Dictionary` | Free full repair at the ship pad or the Mars shelter; otherwise only a log hint |
| `forecast_storm(state, within_seconds) -> Dictionary` | Brings the next storm warning forward (used by the campaign so nobody waits long) |

Rule effects: movement energy rises gently as integrity falls (up to +40% at 35, fictional). Solar recharge is
multiplied by `weather.solar_multiplier` (0.35 during a storm, fictional). The Mars shelter supplies full
recharges in any weather (fictional). Map bounds, interaction range, rover speed and the shelter position come
from destination rules (`simulation/destinations.gd`), not from the global lunar constants.

## Expedition state (simulation/expedition.gd)

- New phase `landing` between `flight` and `aboard`.
- `landing: Dictionary` (present only during final descent):
  `{destination, altitude, vertical_speed, offset: Vector2 (x, z from the pad), lateral_velocity: Vector2,
  throttle, allowance (seconds of full thrust), assist: bool, status: "descending"/"landed"/"failed",
  reason, attempts, fuel_charged: bool}`
- Methods (agreed names): `begin_landing(state, destination_id, assist = false)`,
  `step_landing(state, controls, dt)`, `retry_landing(state)`, `set_landing_assist(state, on)`,
  `recover_checkpoint(state)` (campaign recovery; unchanged state without a campaign) and
  `checkpoint_list(state) -> Array` (public beacons for the current location). Descent fuel is charged once, in `begin_landing`, and retries never
  charge it again. The legacy `land()` remains.
- `campaign: Dictionary` (present only in campaign mode):
  `{id, chapter, objective, completed: Array[String], reached: Array[String], checkpoint: Dictionary,
  flight_checkpoint: Dictionary, storm_seen: bool, recoveries: int, message: String}`

## Landing controls and telemetry

`step_landing` controls: `{throttle: float 0..1 (optional; omitted = assist decides when assist is on, else 0),
x: float -1..1 (east +), z: float -1..1 (south +)}`. Telemetry is the `landing` dictionary above: altitude (m above
the pad), vertical_speed (m/s, up +), offset (m from the pad centre), lateral_velocity (m/s), throttle actually
used, allowance (seconds of full thrust left), status and reason. Safe envelope (fictional, generous): ≤ 3 m/s
down, ≤ 2 m/s drift, within 15 m of the pad centre. Gravity is the destination's real surface gravity (NASA).
Scene keys: W/S throttle lever, X cut, arrows or I/J/K/L side thrusters, T assist, R retry, Esc menu.

## Presentation checkpoints

`Campaign.checkpoints_for(state, destination) -> Array` of
`{id: String, title: String, position: Vector3, completed: bool, active: bool}`.
Worlds only draw these (`world.update_checkpoints(checkpoints)`); campaign rules decide completion.

## Scene hooks consumed when present (Codex-owned, not required)

- `world.configure_extent(limit: float)` before `build()`. Without it the lunar surface scene adds a plain
  collision apron beyond the legacy terrain, so the larger region stays drivable.
- `world.update_checkpoints(checkpoints)`. Without it the surface scene draws simple beacons itself.
- `rover.impact_reported(impact_speed)` → `report_impact`; `rover.set_condition(integrity)` after updates.
