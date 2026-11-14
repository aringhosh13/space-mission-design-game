extends RefCounted
## CLAUDE OWNERSHIP. Native production mission simulation (port of the tested TypeScript engine).
##
## Pure state transitions: no Nodes, input, physics, rendering, network or wall-clock time.
## Every public method returns a NEW state Dictionary and never mutates its input.
## Keeps the five adapter methods and the state schema in shared/mission_contract.gd plus the preview:
##   seed, phase, config, position (Vector3), energy, max_energy, fuel_cells, science_collected,
##   science_returned, distance_travelled, outpost_deployed, outpost_position (null | Vector3),
##   sites (Array of {id, name, kind, position, scanned, sampled, finding, confidence}), log (newest first).
##
## Intentional differences from the temporary preview, all documented in simulation/README.md:
## solar designs carry 0 fuel cells; moves the battery cannot fully pay for are shortened to what it
## can pay for (instead of being dropped); rejected actions explain themselves in the log.
const Rules = preload("res://simulation/rules.gd")
const Design = preload("res://simulation/design.gd")
const Evidence = preload("res://simulation/evidence.gd")

const ACTIONS: Array[String] = ["launch", "scan", "sample", "recharge", "transmit", "deploy", "finish"]

# ----------------------------------------------------------------------------------------- adapter

func review_design(config: Dictionary) -> Dictionary:
	return Design.review(config)

func create_mission(config: Dictionary, mission_seed: int) -> Dictionary:
	var rules: Dictionary = Rules.MOON
	var capacity: float = Design.battery_capacity(config)
	return {
		"seed": mission_seed,
		"phase": "planning",
		"config": config.duplicate(true),
		"position": Vector3.ZERO,
		"energy": capacity,
		"max_energy": capacity,
		"fuel_cells": int(rules.fuel_cell_supplies) if str(config.get("power", "")) == "fuel-cell" else 0,
		"science_collected": 0,
		"science_returned": 0,
		"distance_travelled": 0.0,
		"outpost_deployed": false,
		"outpost_position": null,
		"sites": generate_sites(mission_seed, rules),
		"log": [str(rules.intro)],
	}

## The scene proposes a collision-resolved position; the simulation authorizes it and charges
## energy for the horizontal metres actually travelled. Charging is linear in distance, so equal
## travel split across any number of frames costs the same energy.
func move_rover(original: Dictionary, proposed: Vector3) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase != "surface" or not proposed.is_finite(): return s
	var rules: Dictionary = surface_rules(s)
	var limit: float = float(rules.map_limit)
	var target := Vector3(clampf(proposed.x, -limit, limit), proposed.y, clampf(proposed.z, -limit, limit))
	var start: Vector3 = s.position
	var distance: float = flat_distance(start, target)
	if distance <= 0.0:
		s.position = target  # vertical settling only: free
		return s
	var cost: float = distance * float(rules.move_energy_per_m)
	var energy: float = float(s.energy)
	if cost <= energy + Rules.EPSILON:
		s.position = target
		s.energy = maxf(0.0, energy - cost)
		s.distance_travelled = float(s.distance_travelled) + distance
	else:
		# Travel only as far as the remaining energy pays for, along the proposed path.
		var fraction: float = energy / cost
		s.position = start.lerp(target, fraction)
		s.distance_travelled = float(s.distance_travelled) + distance * fraction
		s.energy = 0.0
		if energy > 0.0: _record(s, "Battery depleted. Recharge or close the mission.")
	return s

func act(original: Dictionary, action: String) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase == "complete": return s
	if not action in ACTIONS:
		_record(s, "Unrecognised command ignored.")
		return s
	if action == "launch":
		if s.phase != "planning":
			_record(s, "The expedition has already launched.")
			return s
		var review: Dictionary = Design.review(s.config)
		if not review.warnings.is_empty():
			_record(s, "Launch blocked. " + " ".join(review.warnings))
			return s
		s.phase = "surface"
		_record(s, "Touchdown confirmed. Drive toward an orbital signal.")
		return s
	if s.phase != "surface":
		_record(s, "Launch the expedition before surface operations.")
		return s
	var rules: Dictionary = surface_rules(s)
	match action:
		"scan": _scan(s, rules)
		"sample": _sample(s, rules)
		"recharge": _recharge(s, rules)
		"transmit": _transmit(s, rules)
		"deploy": _deploy(s, rules)
		"finish":
			s.phase = "complete"
			_record(s, "Expedition closed. Preparing mission report.")
	return s

func get_report(state: Dictionary) -> Dictionary:
	var rules: Dictionary = surface_rules(state)
	var confirmed: int = 0
	var ruled_out: int = 0
	for site in state.sites:
		if site.finding == "confirmed": confirmed += 1
		elif site.finding == "ruled-out": ruled_out += 1
	var max_science: float = float(state.sites.size() * (int(rules.scan_science) + int(rules.sample_science)))
	var share: float = minf(1.0, float(state.science_returned) / max_science) if max_science > 0.0 else 0.0
	var raw: float = share * Rules.SCORE_SCIENCE_WEIGHT + (Rules.SCORE_STATION_POINTS if state.outpost_deployed else 0.0)
	return {
		"score": clampi(roundi(raw), 0, 100),
		"confirmed_sites": confirmed,
		"ruled_out_sites": ruled_out,
		"science_returned": state.science_returned,
		"science_lost": maxi(0, int(state.science_collected) - int(state.science_returned)),
		"outpost_operational": state.outpost_deployed,
	}

# ----------------------------------------------------------------------------------------- helpers

## Rules for the surface this mission is on. Contract v1 has a single lunar surface.
func surface_rules(_state: Dictionary) -> Dictionary:
	return Rules.MOON

static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func generate_sites(mission_seed: int, rules: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = Evidence.stream_seed(mission_seed, "layout", "sites")
	var jitter: float = float(rules.site_jitter)
	var sites: Array = []
	for template in rules.sites:
		var point: Vector3 = template.position + Vector3(rng.randf_range(-jitter, jitter), 0.0, rng.randf_range(-jitter, jitter))
		var site: Dictionary = {"id": template.id, "name": template.name, "kind": template.kind,
			"position": point, "scanned": false, "sampled": false}
		site.merge(Evidence.orbital(mission_seed, str(template.id)))
		sites.append(site)
	return sites

## The single site within interaction range, choosing the closest if ranges ever overlap.
static func site_in_range(position: Vector3, sites: Array, interaction_range: float) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = INF
	for site in sites:
		var d: float = flat_distance(position, site.position)
		if d <= interaction_range + Rules.EPSILON and d < best_distance:
			best = site
			best_distance = d
	return best

static func is_lit(position: Vector3, rules: Dictionary) -> bool:
	return position.x >= float(rules.shade_boundary_x)

static func _record(s: Dictionary, message: String) -> void:
	s.log.push_front(message)
	if s.log.size() > Rules.MAX_LOG_LINES: s.log.resize(Rules.MAX_LOG_LINES)

static func _spend(s: Dictionary, amount: float) -> bool:
	if float(s.energy) + Rules.EPSILON < amount:
		_record(s, "Not enough power: %.1f needed, %.1f available. Recharge or close the mission." % [amount, float(s.energy)])
		return false
	s.energy = maxf(0.0, float(s.energy) - amount)
	return true

func _scan(s: Dictionary, rules: Dictionary) -> void:
	var site: Dictionary = site_in_range(s.position, s.sites, float(rules.interaction_range))
	if site.is_empty(): _record(s, "Move within %d m of a signal to scan." % int(rules.interaction_range))
	elif site.scanned: _record(s, "%s has already been scanned. A drill sample can settle it." % site.name)
	elif _spend(s, float(rules.scan_energy)):
		site.scanned = true
		site.merge(Evidence.scan(int(s.seed), site), true)
		s.science_collected = int(s.science_collected) + int(rules.scan_science)
		_record(s, "%s: preliminary %s evidence (%d%% confidence). A sample can confirm or rule it out." % [site.name, site.kind, site.confidence])

func _sample(s: Dictionary, rules: Dictionary) -> void:
	var site: Dictionary = site_in_range(s.position, s.sites, float(rules.interaction_range))
	if str(s.config.get("instrument", "")) != "drill": _record(s, "Sampling needs the drill. Select it before launch.")
	elif site.is_empty(): _record(s, "Move within %d m of a scanned signal to sample." % int(rules.interaction_range))
	elif not site.scanned: _record(s, "Scan %s before sampling." % site.name)
	elif site.sampled: _record(s, "%s sample already analysed. No new evidence." % site.name)
	elif _spend(s, float(rules.sample_energy)):
		site.sampled = true
		site.merge(Evidence.sample(int(s.seed), site), true)
		# A ruled-out signal is still a result: the sample characterises what produced the signal.
		s.science_collected = int(s.science_collected) + int(rules.sample_science)
		if site.finding == "confirmed":
			_record(s, "%s: %s confirmed by sample (%d%% confidence)." % [site.name, site.kind, site.confidence])
		else:
			_record(s, "%s: sample rules out %s (%d%% confidence). Still useful evidence." % [site.name, site.kind, site.confidence])

func _recharge(s: Dictionary, rules: Dictionary) -> void:
	var solar: bool = str(s.config.get("power", "")) == "solar"
	if float(s.energy) >= float(s.max_energy) - 0.01: _record(s, "Battery already full.")
	elif solar and not is_lit(s.position, rules):
		_record(s, "Solar charging unavailable in the shadow. Drive east of x = %d." % int(rules.shade_boundary_x))
	elif not solar and int(s.fuel_cells) <= 0: _record(s, "Fuel cell supplies exhausted.")
	else:
		var amount: float = float(rules.recharge_amount) * (float(rules.solar_efficiency) if solar else 1.0)
		if not solar: s.fuel_cells = int(s.fuel_cells) - 1
		var before: float = float(s.energy)
		s.energy = minf(float(s.max_energy), before + amount)
		var source: String = "Solar charge" if solar else "Fuel cell used (%d left)" % s.fuel_cells
		_record(s, "%s: +%.1f energy." % [source, float(s.energy) - before])

func _transmit(s: Dictionary, rules: Dictionary) -> void:
	var pending: int = int(s.science_collected) - int(s.science_returned)
	if pending <= 0: _record(s, "No new evidence to transmit.")
	elif _spend(s, float(rules.transmit_energy)):
		s.science_returned = s.science_collected
		_record(s, "%d science received on Earth." % pending)

func _deploy(s: Dictionary, rules: Dictionary) -> void:
	if s.outpost_deployed: _record(s, "Research station is already deployed.")
	elif not is_lit(s.position, rules):
		_record(s, "Find sunlight east of x = %d for the solar research station." % int(rules.shade_boundary_x))
	elif _spend(s, float(rules.deploy_energy)):
		s.outpost_deployed = true
		var here: Vector3 = s.position
		s.outpost_position = here
		_record(s, "Research station deployed at X %.0f / Z %.0f." % [here.x, here.z])
