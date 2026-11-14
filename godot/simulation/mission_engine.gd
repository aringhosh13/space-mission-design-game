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
## Spaceflight extension (additive, proposed for contract v2): create_surface_mission() creates a mission
## on any explorable destination and adds a "destination" key; the Moon's rules and create_mission() are
## unchanged. Destinations with "sample_return" only transmit scan data: sample science must be flown home.
##
## Intentional differences from the temporary preview, all documented in simulation/README.md:
## solar designs carry 0 fuel cells; moves the battery cannot fully pay for are shortened to what it
## can pay for (instead of being dropped); rejected actions explain themselves in the log.
const Rules = preload("res://simulation/rules.gd")
const Design = preload("res://simulation/design.gd")
const Evidence = preload("res://simulation/evidence.gd")
const Destinations = preload("res://simulation/destinations.gd")

const ACTIONS: Array[String] = ["launch", "scan", "sample", "recharge", "transmit", "deploy", "finish"]

# ----------------------------------------------------------------------------------------- adapter

func review_design(config: Dictionary) -> Dictionary:
	return Design.review(config)

func create_mission(config: Dictionary, mission_seed: int) -> Dictionary:
	return _new_mission(config, mission_seed, Rules.MOON, "layout")

## Additive spaceflight method: a mission on any explorable destination (see simulation/destinations.gd).
## Returns {} for landmarks or unknown destinations.
func create_surface_mission(config: Dictionary, mission_seed: int, destination_id: String) -> Dictionary:
	if not Destinations.is_explorable(destination_id): return {}
	var rules: Dictionary = Destinations.surface_rules(destination_id)
	var state: Dictionary = _new_mission(config, mission_seed, rules, "layout" if destination_id == "moon" else "layout-" + destination_id)
	state["destination"] = destination_id
	# Optional campaign fields (shared/CAMPAIGN_CONTRACT.md). v1 missions never carry them.
	state["integrity"] = 100.0
	state["impact_cooldown"] = 0.0
	state["elapsed_seconds"] = 0.0
	state["weather"] = _weather_at(rules, 0.0, float(rules.get("storms", {}).get("first_clear", INF)))
	return state

func _new_mission(config: Dictionary, mission_seed: int, rules: Dictionary, layout_stream: String) -> Dictionary:
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
		"sites": generate_sites(mission_seed, rules, layout_stream),
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
	var cost: float = distance * float(rules.move_energy_per_m) * movement_multiplier(s)
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

# ------------------------------------------------------------------- campaign additions (additive)

## Advance simulation time on the surface (seconds come from the scene's physics delta, never the
## wall clock). Decays the impact cooldown and updates weather deterministically.
func advance_time(original: Dictionary, seconds: float) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase != "surface" or not s.has("elapsed_seconds") or not is_finite(seconds) or seconds <= 0.0: return s
	var rules: Dictionary = surface_rules(s)
	var previous: String = str(s.weather.phase)
	s.elapsed_seconds = float(s.elapsed_seconds) + seconds
	s.impact_cooldown = maxf(0.0, float(s.impact_cooldown) - seconds)
	s.weather = _weather_at(rules, float(s.elapsed_seconds), float(s.weather.next_storm_at))
	var now: String = str(s.weather.phase)
	if now != previous:
		match now:
			"warning": _record(s, "Dust storm warning: about %d s. Shelter, fuel cells or a full battery will see you through." % ceili(s.weather.remaining_seconds))
			"storm": _record(s, "Dust storm: visibility down, solar charging at %d%%." % roundi(s.weather.solar_multiplier * float(rules.solar_efficiency) * 100.0))
			"clear": _record(s, "The dust storm has passed. Solar charging restored.")
	return s

## Hard impacts (reported once per event by the rover scene) gently reduce integrity. Never below the floor.
func report_impact(original: Dictionary, impact_speed: float) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase != "surface" or not s.has("integrity") or not is_finite(impact_speed): return s
	var tuning: Dictionary = Rules.IMPACT
	if impact_speed < float(tuning.threshold) or float(s.impact_cooldown) > 0.0: return s
	var damage: float = clampf(float(tuning.min_damage) + (impact_speed - float(tuning.threshold)) * float(tuning.damage_per_mps),
		float(tuning.min_damage), float(tuning.max_damage))
	s.integrity = maxf(float(tuning.floor), float(s.integrity) - damage)
	s.impact_cooldown = float(tuning.cooldown)
	_record(s, "Hard impact at %.1f m/s: integrity %d%%. Free repairs at the ship%s." % [impact_speed, roundi(s.integrity),
		" or shelter" if surface_rules(s).has("shelter") else ""])
	return s

## Free full repair at the ship pad or the shelter. Elsewhere only a hint is logged.
func repair(original: Dictionary) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase != "surface" or not s.has("integrity"): return s
	if not (at_pad(s) or in_shelter(s)):
		_record(s, "Repairs are free at the ship%s." % (" or the dust shelter" if surface_rules(s).has("shelter") else ""))
		return s
	if float(s.integrity) >= 100.0:
		_record(s, "Rover already in full condition.")
		return s
	s.integrity = 100.0
	_record(s, "Rover repaired: integrity 100%.")
	return s

## Bring the next storm warning forward (campaign pacing). No effect without storms or during a storm.
func forecast_storm(original: Dictionary, within_seconds: float) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if not s.has("weather"): return s
	var rules: Dictionary = surface_rules(s)
	if not rules.has("storms") or s.weather.phase != "clear": return s
	var at: float = float(s.elapsed_seconds) + maxf(0.0, within_seconds)
	if at < float(s.weather.next_storm_at):
		s.weather = _weather_at(rules, float(s.elapsed_seconds), at)
	return s

## Movement energy multiplier from rover condition: +0 % at 100 integrity up to +40 % at the floor.
static func movement_multiplier(state: Dictionary) -> float:
	if not state.has("integrity"): return 1.0
	var tuning: Dictionary = Rules.IMPACT
	var wear: float = clampf((100.0 - float(state.integrity)) / (100.0 - float(tuning.floor)), 0.0, 1.0)
	return 1.0 + wear * float(tuning.max_energy_penalty)

func at_pad(state: Dictionary) -> bool:
	if not state.has("destination"): return false
	var def: Dictionary = Destinations.get_def(str(state.destination))
	return flat_distance(state.position, def.pad) <= float(def.get("boarding_range", 0.0))

func in_shelter(state: Dictionary) -> bool:
	var shelter: Dictionary = surface_rules(state).get("shelter", {})
	return not shelter.is_empty() and flat_distance(state.position, shelter.position) <= float(shelter.radius)

## Deterministic storm cycle: clear until next_storm_at, warning, storm, then clear again.
static func _weather_at(rules: Dictionary, elapsed: float, next_storm_at: float) -> Dictionary:
	var storms: Dictionary = rules.get("storms", {})
	if storms.is_empty():
		return {"phase": "clear", "remaining_seconds": 0.0, "solar_multiplier": 1.0, "next_storm_at": INF}
	var start: float = next_storm_at
	var warning: float = float(storms.warning)
	var active: float = float(storms.active)
	while elapsed >= start + warning + active:
		start += warning + active + float(storms.clear)
	if elapsed < start:
		return {"phase": "clear", "remaining_seconds": start - elapsed, "solar_multiplier": 1.0, "next_storm_at": start}
	if elapsed < start + warning:
		return {"phase": "warning", "remaining_seconds": start + warning - elapsed, "solar_multiplier": 1.0, "next_storm_at": start}
	return {"phase": "storm", "remaining_seconds": start + warning + active - elapsed,
		"solar_multiplier": float(storms.storm_solar), "next_storm_at": start}

# ----------------------------------------------------------------------------------------- helpers

## Rules for the surface this mission is on. Missions without a "destination" key are lunar contract v1
## missions and keep the original ±78 m rule set.
func surface_rules(state: Dictionary) -> Dictionary:
	if not state.has("destination"): return Rules.MOON
	return Destinations.surface_rules(str(state.destination))

static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func generate_sites(mission_seed: int, rules: Dictionary, layout_stream: String = "layout") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = Evidence.stream_seed(mission_seed, layout_stream, "sites")
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
	elif in_shelter(s):
		var before_shelter: float = float(s.energy)
		s.energy = minf(float(s.max_energy), before_shelter + float(rules.recharge_amount))
		_record(s, "Shelter power bank: +%.1f energy." % (float(s.energy) - before_shelter))
	else:
		var weather_factor: float = float(s.get("weather", {}).get("solar_multiplier", 1.0)) if solar else 1.0
		var amount: float = float(rules.recharge_amount) * (float(rules.solar_efficiency) * weather_factor if solar else 1.0)
		if not solar: s.fuel_cells = int(s.fuel_cells) - 1
		var before: float = float(s.energy)
		s.energy = minf(float(s.max_energy), before + amount)
		var source: String = "Solar charge" if solar else "Fuel cell used (%d left)" % s.fuel_cells
		_record(s, "%s: +%.1f energy." % [source, float(s.energy) - before])

func _transmit(s: Dictionary, rules: Dictionary) -> void:
	var sendable: int = int(s.science_collected)
	if rules.get("sample_return", false):
		# Only scan data can be radioed home; sample science travels as physical cores.
		sendable = 0
		for site in s.sites:
			if site.scanned: sendable += int(rules.scan_science)
	var pending: int = sendable - int(s.science_returned)
	if pending <= 0:
		_record(s, "No new data to transmit. Sample cores must be flown home." if rules.get("sample_return", false) else "No new evidence to transmit.")
	elif _spend(s, float(rules.transmit_energy)):
		s.science_returned = sendable
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
