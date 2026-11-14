# Blue Horizon mission engine

Implements `MissionEngine` from `src/shared/types.ts` (contract v2). Pure and deterministic:
no DOM, Three.js, network or wall-clock time. `step()` never mutates its input.
All numbers are fictional balancing values (`rules.ts`, `evidence.ts`), not NASA data.

| File | Responsibility |
| --- | --- |
| `design.ts` | Design review: cost, mass, budget and mass-limit warnings |
| `mission.ts` | Seeded mission creation and site layout |
| `step.ts` | Action rules (launch, move, scan, sample, recharge, transmit, deploy, finish) |
| `evidence.ts` | Confidence, findings and reproducible false positives |
| `report.ts` | Debrief: score and concrete outcomes and losses |
| `random.ts` | Seeded PRNG (mulberry32) |

## Findings and confidence

`Site.confidence` is an integer 0–100: certainty in the current `Site.finding`,
not the probability that the resource exists.

```
unconfirmed --scan--> probable --sample (drill)--> confirmed | ruled-out
```

| Finding | Reached by | Confidence |
| --- | --- | --- |
| `unconfirmed` | orbital survey at mission creation | 15–30 |
| `probable` | scan: preliminary evidence | 50–70 if genuine, 35–55 if a false positive (overlapping, so a scan cannot settle it) |
| `confirmed` | sample of a genuine signal | 85–95 |
| `ruled-out` | sample of a false positive | 80–95 |

- Transitions only move forward and happen at most once per site. Repeated scans and samples are rejected and change nothing.
- Scanner-only designs stop at `probable`.
- Ice signals are false positives with chance 0.35 and mineral signals 0.30. Geology signals are always genuine.
- Whether a signal is genuine is a pure function of the mission seed and site id. Revisiting, repeating
  actions, visiting in a different order or choosing a different design cannot reroll it.
- A ruled-out signal still earns the full sample science: the analysis characterises what produced the signal.
  The score formula is unchanged from milestone 1.

## Research station

`outpostPosition` is `null` until deployment, then a copy of the rover's position at that moment.
Later moves, failed or repeated deployments and mission completion never change it.
