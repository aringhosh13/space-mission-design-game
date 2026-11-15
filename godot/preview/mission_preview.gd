extends RefCounted
## Temporary native playability rules. All values are fictional; not NASA measurements.
## This is not yet Claude's tested TypeScript engine port, and does not claim 83 native tests.
const Contract = preload("res://shared/mission_contract.gd")
const PARTS: Dictionary = {
	"compact": {"cost": 15, "mass": 12, "capacity": 100.0},
	"extended": {"cost": 30, "mass": 28, "capacity": 160.0},
	"solar": {"cost": 20, "mass": 15}, "fuel-cell": {"cost": 30, "mass": 24},
	"scanner": {"cost": 15, "mass": 10}, "drill": {"cost": 35, "mass": 30}
}

func review_design(config: Dictionary) -> Dictionary:
	var cost: int = 35
	var mass: int = 30
	var warnings: Array[String] = []
	var choices: Dictionary = {"battery": ["compact", "extended"], "power": ["solar", "fuel-cell"], "instrument": ["scanner", "drill"]}
	for slot in choices:
		var choice: String = str(config.get(slot, ""))
		if not choice in choices[slot]:
			warnings.append("Choose valid " + str(slot) + ".")
			continue
		cost += int(PARTS[choice].cost)
		mass += int(PARTS[choice].mass)
	if cost > 110: warnings.append("Equipment exceeds the 110-credit budget.")
	if mass > 100: warnings.append("Payload exceeds the 100 kg launch allowance.")
	return {"cost": cost, "mass": mass, "budget": 110, "mass_limit": 100, "warnings": warnings}

func create_mission(config: Dictionary, mission_seed: int) -> Dictionary:
	var capacity: float = float(PARTS.get(config.get("battery", ""), {}).get("capacity", 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = mission_seed
	var sites: Array[Dictionary] = []
	var templates: Array = [
		["a", "SHACKLETON SIGNAL", "ice", Vector3(-35, 0, -36)],
		["b", "RIDGE ANOMALY", "minerals", Vector3(37, 0, -24)],
		["c", "EXPOSED FORMATION", "geology", Vector3(25, 0, 40)]
	]
	for entry in templates:
		var point: Vector3 = entry[3]
		point += Vector3(rng.randf_range(-3.0, 3.0), 0, rng.randf_range(-3.0, 3.0))
		sites.append({"id": entry[0], "name": entry[1], "kind": entry[2], "position": point,
			"scanned": false, "sampled": false, "finding": "unconfirmed", "confidence": rng.randi_range(15, 30)})
	return {"seed": mission_seed, "phase": "planning", "config": config.duplicate(true),
		"position": Vector3.ZERO, "energy": capacity, "max_energy": capacity, "fuel_cells": 3,
		"science_collected": 0, "science_returned": 0, "distance_travelled": 0.0,
		"outpost_deployed": false, "outpost_position": null, "sites": sites,
		"log": ["Orbital survey received. Three signals need investigation."]}

func move_rover(original: Dictionary, proposed: Vector3) -> Dictionary:
	if original.phase != "surface": return original
	if not proposed.is_finite(): return original
	var bounded := Vector3(clampf(proposed.x, -Contract.MAP_LIMIT, Contract.MAP_LIMIT), proposed.y,
		clampf(proposed.z, -Contract.MAP_LIMIT, Contract.MAP_LIMIT))
	var distance: float = Contract.flat_distance(original.position, bounded)
	# Cost depends on actual distance, not frame count. No rounding surcharge.
	var cost: float = distance * 0.16
	if float(original.energy) + 0.00001 < cost: return original
	var state: Dictionary = original.duplicate(true)
	state.position = bounded
	state.energy = maxf(0.0, float(state.energy) - cost)
	state.distance_travelled += distance
	return state

func _record(state: Dictionary, message: String) -> void:
	state.log.push_front(message)
	if state.log.size() > 8: state.log.resize(8)

func _spend(state: Dictionary, amount: float) -> bool:
	if state.energy < amount:
		_record(state, "Not enough power. Recharge or close the mission.")
		return false
	state.energy -= amount
	return true

func _evidence(seed_value: int, site: Dictionary, purpose: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(seed_value) + "|" + str(site.id) + "|" + purpose)
	return rng

func act(original: Dictionary, action: String) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase == "complete": return s
	if action == "launch":
		if s.phase == "planning" and review_design(s.config).warnings.is_empty():
			s.phase = "surface"
			_record(s, "Touchdown confirmed. Drive toward an orbital signal.")
		return s
	if s.phase != "surface": return s
	var near: Dictionary = {}
	var nearest_distance: float = Contract.INTERACTION_RANGE
	for site in s.sites:
		var d: float = Contract.flat_distance(s.position, site.position)
		if d <= nearest_distance:
			near = site
			nearest_distance = d
	match action:
		"scan":
			if near.is_empty(): _record(s, "Move within 6 m of a signal to scan.")
			elif near.scanned: _record(s, "Signal already scanned. A drill can settle it.")
			elif _spend(s, 4.0):
				near.scanned = true
				near.finding = "probable"
				near.confidence = _evidence(s.seed, near, "scan").randi_range(45, 70)
				s.science_collected += 15
				_record(s, str(near.name) + ": preliminary evidence recorded.")
		"sample":
			if s.config.instrument != "drill": _record(s, "Sampling needs the drill. Select it before launch.")
			elif near.is_empty() or not near.scanned: _record(s, "Scan a nearby signal before sampling.")
			elif near.sampled: _record(s, "Sample already analysed.")
			elif _spend(s, 8.0):
				var false_positive: bool = near.kind != "geology" and _evidence(s.seed, near, "truth").randf() < 0.32
				near.sampled = true
				near.finding = "ruled-out" if false_positive else "confirmed"
				near.confidence = _evidence(s.seed, near, "sample").randi_range(82, 95)
				s.science_collected += 25
				_record(s, str(near.name) + ": " + str(near.finding) + ". Both outcomes produce useful science.")
		"recharge":
			if s.energy >= s.max_energy - 0.01: _record(s, "Battery already full.")
			elif s.config.power == "solar" and s.position.x < -18.0: _record(s, "Solar charging unavailable in the western shadow. Drive east.")
			elif s.config.power == "fuel-cell" and s.fuel_cells <= 0: _record(s, "Fuel cell supplies exhausted.")
			else:
				if s.config.power == "fuel-cell": s.fuel_cells -= 1
				s.energy = minf(s.max_energy, s.energy + 40.0)
				_record(s, "Power restored by up to 40 units.")
		"transmit":
			if s.science_collected == s.science_returned: _record(s, "No new evidence to transmit.")
			elif _spend(s, 3.0):
				s.science_returned = s.science_collected
				_record(s, "Science received on Earth.")
		"deploy":
			if s.outpost_deployed: _record(s, "Station is already deployed.")
			elif s.position.x < -18.0: _record(s, "Find sunlight east of x = -18 for the solar research station.")
			elif _spend(s, 12.0):
				s.outpost_deployed = true
				s.outpost_position = s.position
				_record(s, "Research station deployed at this location.")
		"finish":
			s.phase = "complete"
			_record(s, "Expedition closed. Preparing mission report.")
	return s

func get_report(state: Dictionary) -> Dictionary:
	var confirmed: int = 0
	var ruled_out: int = 0
	for site in state.sites:
		if site.finding == "confirmed": confirmed += 1
		if site.finding == "ruled-out": ruled_out += 1
	return {"score": roundi(minf(100.0, float(state.science_returned) / 120.0 * 70.0 + (30.0 if state.outpost_deployed else 0.0))),
		"confirmed_sites": confirmed, "ruled_out_sites": ruled_out,
		"science_returned": state.science_returned,
		"science_lost": state.science_collected - state.science_returned,
		"outpost_operational": state.outpost_deployed}
