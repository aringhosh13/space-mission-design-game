# Native mission simulation (`godot/simulation/`)

Claude-owned GDScript port of the TypeScript engine, behind the existing adapter
`mission_engine.gd`. It keeps native contract v1: the five adapter methods and the state schema
in `shared/mission_contract.gd` and the preview. Scenes, HUD, preview rules and shared files are unchanged.

Pure state transitions: no Nodes, input, physics, rendering, network or wall-clock time.
Every method returns a new Dictionary and never mutates its input.

| File | Responsibility |
| --- | --- |
| `mission_engine.gd` | Adapter: `create_mission`, `review_design`, `move_rover`, `act`, `get_report` |
| `rules.gd` | Lunar rule set (native values from `godot/README.md`) and catalogue |
| `design.gd` | Budget and mass review |
| `evidence.gd` | Findings, integer confidence, seeded false positives |

## Rules in brief (fictional balancing values)

- **Design:** budget 110 credits, launch mass 100 kg. Invalid or unknown parts block launch.
- **Movement:** the scene proposes a collision-resolved position; the simulation clamps it to ±78 m and charges
  0.16 energy per horizontal metre actually travelled. Vertical settling is free. Cost is linear in distance,
  so equal travel split over any number of frames costs the same. If the battery cannot pay for the whole move,
  the rover travels exactly as far as it can along that path and the battery reaches 0 (never negative).
- **Science:** scan within 6 m (4 energy, +15 science), then sample with a drill (8 energy, +25 science).
  Repeated scans or samples are rejected and change nothing.
- **Power:** recharge +40, capped at capacity. Solar works only at x ≥ -18 (x < -18 is the western shadow).
  Fuel-cell designs carry 3 single-use supplies that work anywhere; solar designs carry none.
- **Transmit** (3 energy) returns all onboard science. **Deploy** (12 energy, sunlight, once) records the rover's
  position as `outpost_position`; later moves never change it. **Finish** closes the mission; a closed mission
  rejects every change.
- **Score** keeps the earlier principle: returned science / 120 × 70, plus 30 for an operational station.

## Findings and confidence

`confidence` is an integer 0–100: certainty in the current `finding`, not the probability that the resource exists.

```
unconfirmed --scan--> probable --sample (drill)--> confirmed | ruled-out
```

| Finding | Reached by | Confidence |
| --- | --- | --- |
| unconfirmed | orbital survey | 15–30 |
| probable | scan | 50–70 if genuine, 35–55 if a false positive (overlapping) |
| confirmed | sample of a genuine signal | 85–95 |
| ruled-out | sample of a false positive | 80–95 |

Ice signals are false positives with chance 0.35, minerals 0.30, geology never. Whether a signal is genuine is a
pure function of (mission seed, site id) through a 32-bit FNV-1a hash and Godot's `RandomNumberGenerator`.
It is never stored in state, so revisits, repeated actions, visit order, equipment choice, replays and frame
rate cannot reroll it. A ruled-out signal still earns full sample science.

## Intentional differences from the temporary preview (`preview/mission_preview.gd`)

- Solar designs start with `fuel_cells = 0` (the preview gave every design 3). The HUD does not show this field.
- A move the battery cannot fully pay for is shortened to what it can pay for. The preview dropped it, which
  could leave a rover with a little energy unable to move.
- Evidence ranges and false-positive chances follow the TypeScript engine (the preview used 45–70, 82–95 and 0.32).
- Site jitter (±3 m) uses a hashed seed stream, so layouts for a given seed differ from the preview's.
- Rejected actions add an explanatory log line. Movement rejections stay silent, except one depletion message,
  so the log is not flooded every frame.
- Native outcomes do not match the TypeScript engine bit-for-bit (different PRNG); they reproduce within Godot.

## Tests

```sh
godot --headless --path godot --script res://tests/simulation/run_tests.gd
godot --headless --path godot --script res://tests/smoke.gd
```

`tests/simulation/` holds native tests for design and launch, movement (bounds, finiteness, frame-count
independence, depletion), operations, evidence (transitions, rates, reproducibility, no rerolls) and lifecycle
(immutability, closed missions, report, replay, layouts). The runner captures GDScript runtime errors through
a `Logger`, so a crashing test fails instead of passing silently. The TypeScript engine's tests are a
behavioural reference only; they do not cover this port.
