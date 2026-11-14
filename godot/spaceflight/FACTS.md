# Facts used in spaceflight, and where they come from

Only these values are presented as real. Each appears in game with a "(NASA)" label, and each `facts` entry in
`simulation/destinations.gd` names its source id. Sources were accessed on 2026-11-14.

| Source id | Source |
| --- | --- |
| `nasa-moon-facts` | NASA Science, *Moon Facts*: https://science.nasa.gov/moon/facts/ |
| `nasa-mars-facts` | NASA Science, *Mars Facts*: https://science.nasa.gov/mars/facts/ |
| `jpl-mars-glance` | NASA JPL, InSight press kit, *Mars at a Glance*: https://www.jpl.nasa.gov/news/press_kits/insight/launch/facts/mars-at-a-glance |
| `nasa-travel-times` | NASA, *How Long Does it Take to Get to the Moon… Mars… Jupiter? We Asked a NASA Expert* (Episode 51): https://www.nasa.gov/directorates/smd/how-long-does-it-take-to-get-to-the-moon-mars-jupiter-we-asked-a-nasa-expert-episode-51/ |

| Fact shown | Source | Used in mechanics? |
| --- | --- | --- |
| The Moon averages 384,400 km from Earth | nasa-moon-facts | No (label only) |
| Lunar surface gravity is one-sixth of Earth's (≈1.62 m/s²) | nasa-moon-facts | Yes: ascent and descent delta-v scale with gravity |
| Lunar ice is concentrated in permanently shadowed polar regions | nasa-moon-facts | Flavour: the lunar ice signal sits in the shadow |
| Reaching the Moon takes several days | nasa-travel-times | No (label only) |
| Mars averages 228 million km from the Sun, about 1.5× Earth's distance | nasa-mars-facts | Yes: the derived solar factor below |
| Mars surface gravity is about 38% of Earth's (3.71 m/s²) | jpl-mars-glance | Yes: Mars ascent costs about 2.3× the Moon's |
| Mars has a thin, mostly carbon-dioxide atmosphere and reddish rusted dust | nasa-mars-facts | Look of the sky and terrain; "atmosphere helps descent" |
| Reaching Mars takes about 7–10 months on a fairly direct route | nasa-travel-times | No (label only) |
| Mars has two small moons, Phobos and Deimos | nasa-mars-facts | Flavour only (sky objects) |

## Derived value

- **Mars solar output ×0.43.** Sunlight intensity falls with the square of distance from the Sun.
  At ~1.52 times Earth's distance, 1 / 1.52² ≈ 0.43. The game applies it to solar recharging. Dust storms
  and seasonal changes are not modelled.

## Not real (fictional balancing values)

- Map positions, body sizes and the distances between them. The "u" unit is not a kilometre, and the
  Moon and Mars legs are compressed by different amounts.
- In-game travel times.
- Ship dry mass, thrust, exhaust velocity, turn rate and fuel loads. The rocket equation itself is real physics.
- The delta-v per unit of gravity scale (18.5 u/s per m/s²) and the Mars atmosphere braking factor (0.55).
- Rover energy costs, science values, false-positive chances, confidence ranges, site layouts and the
  sample-core mass.
- The Aurora Delta landing region and its landforms. Phobos and Deimos positions and sizes are illustrative.
- Scores.
