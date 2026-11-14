extends RefCounted
## Reusable destination definitions (Claude-owned). Add a world by adding one entry to DESTINATIONS.
##
## Each entry separates REAL facts (with a source id from spaceflight/FACTS.md) from FICTIONAL game rules.
## Real inputs used by mechanics: surface gravity ratios (ascent/descent cost) and Mars's ~1.5 AU distance
## from the Sun, from which the ~0.43 solar factor is derived (inverse-square law, 1 / 1.52²).
## Everything else (map positions, sizes, delta-v scale, energy, science values, site layouts,
## atmosphere braking factor, sample-core mass) is a fictional balancing value.
const Rules = preload("res://simulation/rules.gd")

const HOME: String = "moon"
## Sources for every real fact; details and access notes live in spaceflight/FACTS.md.
const SOURCES: Dictionary = {
	"nasa-moon-facts": "https://science.nasa.gov/moon/facts/",
	"nasa-mars-facts": "https://science.nasa.gov/mars/facts/",
	"jpl-mars-glance": "https://www.jpl.nasa.gov/news/press_kits/insight/launch/facts/mars-at-a-glance",
	"nasa-travel-times": "https://www.nasa.gov/directorates/smd/how-long-does-it-take-to-get-to-the-moon-mars-jupiter-we-asked-a-nasa-expert-episode-51/",
}
## Fictional scale: ascent delta-v in game units per m/s² of real surface gravity.
const ASCENT_DV_PER_G: float = 18.5

const DESTINATIONS: Dictionary = {
	"moon": {
		"id": "moon", "name": "Moon", "kind": "explorable", "home": true, "world": "lunar",
		"space": {"position": Vector3(0, 0, 0), "radius": 32.0, "approach_altitude": 70.0, "landing_speed_limit": 6.0,
			"color": Color("c9ccd2")},
		"gravity": 1.62, "atmosphere_braking": 0.0,
		"pad": Vector3(0, 0, -11), "boarding_range": 9.0,
		"facts": [
			{"text": "Average distance from Earth: 384,400 km.", "source": "nasa-moon-facts"},
			{"text": "Surface gravity is one-sixth of Earth's (about 1.62 m/s²).", "source": "nasa-moon-facts"},
			{"text": "Ice is concentrated in permanently shadowed regions near the poles.", "source": "nasa-moon-facts"},
		],
		"real_distance": "384,400 km from Earth on average (NASA)",
		"real_travel": "several days from Earth (NASA)",
		"fiction": "Home base. Map position and size are compressed; landing costs use the real gravity ratio.",
	},
	"mars": {
		"id": "mars", "name": "Mars", "kind": "explorable", "home": false, "world": "martian",
		"space": {"position": Vector3(-900, 60, -1500), "radius": 48.0, "approach_altitude": 90.0, "landing_speed_limit": 6.0,
			"color": Color("c8643c")},
		"gravity": 3.71, "atmosphere_braking": 0.55,
		"pad": Vector3(0, 0, -11), "boarding_range": 9.0,
		"facts": [
			{"text": "Average distance from the Sun: 228 million km, about 1.5 times Earth's.", "source": "nasa-mars-facts"},
			{"text": "Surface gravity is about 38% of Earth's (3.71 m/s²).", "source": "jpl-mars-glance"},
			{"text": "Thin atmosphere, mostly carbon dioxide; reddish rusted dust.", "source": "nasa-mars-facts"},
			{"text": "Reaching Mars takes about seven to ten months on a fairly direct route.", "source": "nasa-travel-times"},
		],
		"real_distance": "≈1.5 AU from the Sun; Earth–Mars distance changes with both orbits (NASA)",
		"real_travel": "about 7–10 months (NASA)",
		"fiction": "Aurora Delta is a fictional landing region. Solar output ×0.43 is derived from distance; dust, energy and science values are fictional.",
		"surface": {
			"map_limit": 78.0,
			"interaction_range": 6.0,
			"shade_boundary_x": -1000000.0,   # no shadow zone: the whole region is in daylight
			"solar_efficiency": 0.43,         # 1 / 1.52² from Mars's distance from the Sun (derived)
			"move_energy_per_m": 0.2,         # loose sand and rocks (fictional)
			"scan_energy": 5.0,
			"sample_energy": 10.0,
			"transmit_energy": 6.0,           # longer relay to Earth (fictional)
			"deploy_energy": 15.0,
			"recharge_amount": 40.0,
			"scan_science": 20,
			"sample_science": 35,
			"fuel_cell_supplies": 3,
			"sample_return": true,            # sample science counts only when cores reach the home base
			"core_mass": 6.0,                 # kg per sealed sample core (fictional)
			"site_jitter": 3.0,
			"sites": [
				{"id": "mars-a", "name": "SCARP ICE SIGNAL", "kind": "ice", "position": Vector3(-44, 0, 26)},
				{"id": "mars-b", "name": "CLAY-RICH TERRACE", "kind": "minerals", "position": Vector3(41, 0, 21)},
				{"id": "mars-c", "name": "LAYERED DELTA FRONT", "kind": "geology", "position": Vector3(6, 0, -52)},
			],
			"intro": "Aurora Delta touchdown. Three signals from orbit. Samples must be flown home to count.",
		},
	},
	"earth": {
		"id": "earth", "name": "Earth", "kind": "landmark", "home": false, "world": "",
		"space": {"position": Vector3(70, -30, 430), "radius": 78.0, "approach_altitude": 0.0, "landing_speed_limit": 0.0,
			"color": Color("3d7fc4")},
		"gravity": 9.81, "atmosphere_braking": 0.0,
		"facts": [{"text": "The Moon orbits 384,400 km from Earth on average.", "source": "nasa-moon-facts"}],
		"real_distance": "384,400 km to the Moon (NASA)",
		"real_travel": "home planet: a landmark in this version",
		"fiction": "Visible landmark only. Landing on Earth is not part of this milestone.",
	},
}

static func ids() -> Array:
	return ["moon", "mars", "earth"]

static func get_def(id: String) -> Dictionary:
	return DESTINATIONS.get(id, {})

static func is_explorable(id: String) -> bool:
	return get_def(id).get("kind", "") == "explorable"

## Surface rules for an explorable destination. The Moon keeps the native contract v1 rule set.
static func surface_rules(id: String) -> Dictionary:
	if id == "moon" or id == "": return Rules.MOON
	return get_def(id).get("surface", {})

static func ascent_delta_v(id: String) -> float:
	return float(get_def(id).get("gravity", 0.0)) * ASCENT_DV_PER_G

## Descent is cheaper where an atmosphere does part of the braking (fictional factor).
static func descent_delta_v(id: String) -> float:
	return ascent_delta_v(id) * (1.0 - float(get_def(id).get("atmosphere_braking", 0.0)))
