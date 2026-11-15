# Regional traverse planning prototype

## Operational problem addressed

Rover teams must choose traverses that reach useful investigation sites while staying inside terrain and
resource constraints and preserving the ability to return. NASA's VIPER description discusses crater mobility,
15-degree inclines, prospecting and solar-panel orientation:
https://science.nasa.gov/mission/viper/rover-and-instruments/

Blue Horizon now includes a working **regional candidate-traverse screening prototype**, separate from the
game's fictional motion/energy rules. It computes and compares routes over actual NASA LOLA and MOLA elevations.
This is an implementation of a real planning problem, not a claim that NASA uses it, that it improves on
NASA's existing planners, or that it produces flight-approved commands.

## Use

Open from the campaign planning menu without launching, or on a surface press **P** / **Plan [P]**.
The game pauses and restores its previous pause
state when closed. Click the terrain map for a study target; Shift-click sets a study start/base. Select a
slope limit, assumed battery capacity and reserve. Compare distance-optimised and energy-weighted routes.
Each includes a separately computed return leg. Red cells are coarse slope estimates; amber/mint lines are
outbound/return. Candidate study points do not become discoveries or change campaign objectives.

Export writes `traverse-moon.geojson` or `traverse-mars.geojson` to the game user-data folder; the full path is
shown on screen. Exports contain both legs, planet identity, original product URL, local projection centre,
model assumptions, energy/reserve decision and limitations. Coordinates are planetary longitude/latitude,
**not Earth WGS84**. Import into GIS with an appropriate planetary coordinate system. Elevations are omitted
from GeoJSON positions to avoid implying an Earth altitude datum.

## Calculation and assumptions

- Inputs: physical 150 × 150 km NASA-data patches; raw source-specific elevation metres, not game mesh heights.
- 65 × 65 search grid, about 2344 m spacing. Eight-neighbour A* search, no diagonal corner cutting across
  disabled steep cells. Two-axis finite-difference slope excludes steep nodes; along-edge slopes are checked too.
- Distance policy minimises physical grid distance. Energy policy minimises the explicitly stated illustrative
  energy formula; admissible distance-based heuristics are used. This is grid optimality, not continuous-path optimality.
- Illustrative energy: `distance × 0.02 Wh/m × (1 + 10 × positive_grade) + travel_seconds × 20 W / 3600`.
  Illustrative speed is 0.2 m/s. Values are exposed on the planner screen and exported; they are not calibrated
  rover specifications. The 15° default is informed by VIPER's published description, not a universal rover limit.
- Both outbound and return costs must fit `battery × (1 - reserve)`. Missing grids, identical grid endpoints,
  nonfinite inputs, blocked routes and insufficient return energy are not approved by the model.

## Operational limitations

This DEM resolution is too coarse for local driving commands. Interpolation can hide hazards. There are no
validated slip, soil, wheel-load, rock, illumination, moving-shadow, thermal-survival, communications, charging
or uncertainty models. A candidate that passes is only feasible under the stated model and requires local
reconnaissance. Physical traverse times can span days; the game compresses those same regions heavily.
Do not call this a solved flight-operations problem or claim safety certification.

## Validation and fixes

Native tests check flat-grid energy/distance, both-leg/reserve rejection, an impassable elevation barrier,
relaxing the threshold, reproducibility, energy optimisation versus distance policy on both NASA patches,
planetary export metadata and invalid inputs. UI fixtures check unchanged campaign resources while planning,
export creation and return to driving.

The reported label pile-up was caused by multiple completed/future objectives sharing the base coordinates.
Only the active checkpoint now gets a world title. Screen-space decluttering hides other colliding world
annotations and reserves HUD regions; full objectives/findings remain available in the HUD. Planning/report
menus scroll rather than overflow. The flight navigation tag stays clear of fixed telemetry and controls.
These are the reproduced problems fixed; exhaustive absence of all possible bugs is not claimed.

Verified on official Godot 4.7.2, Windows: 131 simulation tests (45,804 assertions), 115 scene checks with
no runtime errors, and the full 37-check manually landed campaign route headless and with RTX 4050 OpenGL.
Moon physics, atlas, and the planning/annotation/menu/export review fixtures pass with real graphics.
The Windows release exports and starts. These are automated checks, not operational validation or human playtests.
