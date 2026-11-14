extends RefCounted
## Native mission rules for the lunar surface (native contract v1).
##
## Every number here is a FICTIONAL BALANCING VALUE for gameplay, taken from godot/README.md
## ("native playability values"). None is a NASA measurement, flight specification or validated
## engineering figure. Budget, mass and science rewards match the TypeScript prototype.

const BASE_COST: int = 35
const BASE_MASS: int = 30
const BUDGET: int = 110
const MASS_LIMIT: int = 100

## Catalogue parts. Battery capacity is in energy units.
const PARTS: Dictionary = {
	"compact": {"label": "Compact battery", "cost": 15, "mass": 12, "capacity": 100.0},
	"extended": {"label": "Extended battery", "cost": 30, "mass": 28, "capacity": 160.0},
	"solar": {"label": "Solar array", "cost": 20, "mass": 15},
	"fuel-cell": {"label": "Fuel cell pack", "cost": 30, "mass": 24},
	"scanner": {"label": "Surface scanner", "cost": 15, "mass": 10},
	"drill": {"label": "Scanner + sample drill", "cost": 35, "mass": 30},
}
const SLOTS: Dictionary = {
	"battery": ["compact", "extended"],
	"power": ["solar", "fuel-cell"],
	"instrument": ["scanner", "drill"],
}
const SLOT_NAMES: Dictionary = {"battery": "energy storage", "power": "power source", "instrument": "science payload"}

## Lunar surface rules. Kept as one dictionary so other destinations can supply their own set.
const MOON: Dictionary = {
	"map_limit": 78.0,               # metres from the landing point on x and z
	"interaction_range": 6.0,        # metres; scan/sample range
	"shade_boundary_x": -18.0,       # x < -18 is the western shadow; x = -18 is lit
	"solar_efficiency": 1.0,         # fraction of recharge_amount a solar array delivers
	"move_energy_per_m": 0.16,       # energy per horizontal metre actually travelled
	"scan_energy": 4.0,
	"sample_energy": 8.0,
	"transmit_energy": 3.0,
	"deploy_energy": 12.0,
	"recharge_amount": 40.0,
	"scan_science": 15,
	"sample_science": 25,
	"fuel_cell_supplies": 3,
	"site_jitter": 3.0,              # seeded offset of each site from its template, metres per axis
	"sites": [
		{"id": "a", "name": "SHACKLETON SIGNAL", "kind": "ice", "position": Vector3(-35, 0, -36)},
		{"id": "b", "name": "RIDGE ANOMALY", "kind": "minerals", "position": Vector3(37, 0, -24)},
		{"id": "c", "name": "EXPOSED FORMATION", "kind": "geology", "position": Vector3(25, 0, 40)},
	],
	"intro": "Orbital survey received. Three signals need investigation.",
}

const MAX_LOG_LINES: int = 8
## Score: returned science is worth up to 70 points, an operational station 30 (unchanged principle).
const SCORE_SCIENCE_WEIGHT: float = 70.0
const SCORE_STATION_POINTS: float = 30.0
## Tolerance for floating-point energy comparisons.
const EPSILON: float = 0.000001
