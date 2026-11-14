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
| `elapsed_seconds` | float | Simulation time on this surface. It advances only through `advance_time`, never from the wall clock. |
| `weather` | Dictionary | `{phase: "clear"/"warning"/"storm", remaining_seconds: float, solar_multiplier: float, next_storm_at: float}` |

Missions created by `create_mission` (v1) have none of these keys, and every method treats them as absent:
clear weather, integrity 100, no cooldown.

## Pure mission-engine methods (simulation/mission_engine.gd)

| Method | Effect |
| --- | --- |
| `advance_time(state, seconds) -> Dictionary` | Advances `elapsed_seconds`, decays `impact_cooldown` and updates `weather` deterministically. Surface phase only. |
| `report_impact(state, impact_speed) -> Dictionary` | Damages only at speeds of 5 m/s or more and when the cooldown is 0: 5–15 points, floor 35, then a 3 s cooldown |
| `repair(state) -> Dictionary` | Free full repair at the ship pad or the Mars shelter; otherwise only a log hint |
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
- Methods: `begin_landing(state, id)`, `landing_step(state, input, dt)`, `retry_landing(state)`,
  `set_landing_assist(state, on)`. Descent fuel is charged once, in `begin_landing`, and retries never
  charge it again. The legacy `land()` remains.
- `campaign: Dictionary` (present only in campaign mode):
  `{id, chapter, objective, completed: Array[String], reached: Array[String], checkpoint: Dictionary,
  flight_checkpoint: Dictionary, storm_seen: bool, recoveries: int, message: String}`

## Presentation checkpoints

`Campaign.checkpoints_for(state, destination) -> Array` of
`{id: String, title: String, position: Vector3, completed: bool, active: bool}`.
Worlds only draw these (`world.update_checkpoints(checkpoints)`); campaign rules decide completion.

## Scene hooks consumed when present (Codex-owned, not required)

- `world.configure_extent(limit: float)` before `build()`. Without it the lunar surface scene adds a plain
  collision apron beyond the legacy terrain, so the larger region stays drivable.
- `world.update_checkpoints(checkpoints)`. Without it the surface scene draws simple beacons itself.
- `rover.impact_reported(impact_speed)` → `report_impact`; `rover.set_condition(integrity)` after updates.
