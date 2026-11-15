extends "res://tests/simulation/test_case.gd"
## Stage 2: destination definitions and travel rules.
const Ship = preload("res://simulation/ship_flight.gd")
const Travel = preload("res://simulation/travel.gd")
const Destinations = preload("res://simulation/destinations.gd")

func _ship_at(id: String, altitude: float, velocity: Vector3 = Vector3.ZERO, fuel: float = 650.0) -> Dictionary:
	var body: Dictionary = Destinations.get_def(id).space
	var ship: Dictionary = Ship.create(fuel, 87.0)
	ship.position = body.position + Vector3.UP * (float(body.radius) + altitude)
	ship.velocity = velocity
	return ship

func test_destination_definitions_are_complete_and_sourced() -> void:
	var surface_keys: Array = Rules.MOON.keys()
	for id in Destinations.ids():
		var def: Dictionary = Destinations.get_def(id)
		eq(def.id, id, "id matches key")
		for key in ["name", "kind", "space", "gravity", "facts", "real_distance", "real_travel", "fiction"]:
			check(def.has(key), "%s has %s" % [id, key])
		check(float(def.space.radius) > 0.0, "%s has a radius" % id)
		for fact in def.facts: check(Destinations.SOURCES.has(fact.source), "%s fact cites a known source" % id)
		if Destinations.is_explorable(id):
			var rules: Dictionary = Destinations.surface_rules(id)
			for key in surface_keys: check(rules.has(key), "%s surface rules have %s" % [id, key])
			for template in rules.sites:
				check(absf(template.position.x) + float(rules.site_jitter) <= float(rules.map_limit), "%s site inside map" % id)
				check(Engine_.flat_distance(template.position, Vector3.ZERO) - float(rules.site_jitter) > float(rules.interaction_range), "%s site not at the landing point" % id)
				check(Engine_.flat_distance(template.position, def.pad) - float(rules.site_jitter) > float(rules.interaction_range), "%s site clear of the ship pad" % id)
	check(not Destinations.is_explorable("earth"), "Earth is a landmark")
	eq(Destinations.surface_rules(""), Rules.MOON, "missions without a destination keep the contract v1 rules")
	check(float(Destinations.surface_rules("moon").map_limit) > float(Rules.MOON.map_limit), "lunar survey region is larger than the v1 map")
	check(float(Destinations.surface_rules("mars").map_limit) > float(Rules.MOON.map_limit), "Mars region is larger than the v1 map")

func test_bodies_do_not_overlap_including_approach_zones() -> void:
	var ids: Array = Destinations.ids()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a: Dictionary = Destinations.get_def(ids[i]).space
			var b: Dictionary = Destinations.get_def(ids[j]).space
			var gap: float = a.position.distance_to(b.position) - a.radius - b.radius - a.approach_altitude - b.approach_altitude
			check(gap > 100.0, "%s and %s are well separated" % [ids[i], ids[j]])

func test_ascent_and_descent_use_real_gravity_ratios() -> void:
	near(Destinations.ascent_delta_v("mars") / Destinations.ascent_delta_v("moon"), 3.71 / 1.62, "ascent ratio = gravity ratio")
	near(Destinations.descent_delta_v("moon"), Destinations.ascent_delta_v("moon"), "airless Moon: descent fully propulsive")
	check(Destinations.descent_delta_v("mars") < Destinations.ascent_delta_v("mars"), "Mars atmosphere helps descent")

func test_proximity_guard_and_system_boundary() -> void:
	var diving: Dictionary = _ship_at("mars", 10.0, Vector3.DOWN * 40.0)
	var s: Dictionary = diving
	for i in range(120): s = Travel.fly(s, {}, 1.0 / 60.0)
	check(Travel.altitude(s, "mars") >= Travel.SURFACE_CLEARANCE - 0.001, "cannot enter the planet")
	check(s.velocity.y >= -0.0001, "inward velocity removed")
	var far: Dictionary = Ship.create(650.0, 0.0, Vector3(3990, 0, 0))
	far.velocity = Vector3(100, 0, 0)
	s = Travel.fly(far, {}, 1.0)
	check(s.position.x <= Travel.SYSTEM_LIMIT and s.velocity == Vector3.ZERO, "held at the system boundary")

func test_guidance_reports_distance_closing_speed_and_eta() -> void:
	var body: Dictionary = Destinations.get_def("mars").space
	var ship: Dictionary = Ship.create(650.0, 87.0, body.position + Vector3(0, 0, 548.0))
	ship.velocity = Vector3(0, 0, -50.0)
	var g: Dictionary = Travel.guidance(ship, "mars")
	near(g.distance, 500.0, "distance to the surface", 0.001)
	near(g.closing_speed, 50.0, "closing speed")
	near(g.eta, 10.0, "eta")
	check(not g.in_approach and not g.can_land, "too far to land")
	ship.velocity = Vector3(0, 0, 50.0)
	eq(Travel.guidance(ship, "mars").eta, -1.0, "moving away: no eta")
	var earth: Dictionary = Travel.guidance(_ship_at("earth", 1.0), "earth")
	check(not earth.landable and not earth.can_land and not earth.reasons.is_empty(), "Earth cannot be landed on")

func test_landing_requires_approach_zone_low_speed_and_descent_fuel() -> void:
	check(Travel.guidance(_ship_at("mars", 50.0), "mars").can_land, "slow, close, fuelled: can land")
	check(not Travel.guidance(_ship_at("mars", 120.0), "mars").can_land, "outside approach zone")
	var fast: Dictionary = Travel.guidance(_ship_at("mars", 50.0, Vector3(7, 0, 0)), "mars")
	check(not fast.can_land and not fast.speed_ok, "too fast")
	var dry: Dictionary = Travel.guidance(_ship_at("mars", 50.0, Vector3.ZERO, 5.0), "mars")
	check(not dry.can_land and not dry.fuel_ok, "not enough descent fuel")

func test_landing_pays_rocket_equation_fuel_at_current_mass() -> void:
	var light: Dictionary = _ship_at("moon", 20.0)
	var heavy: Dictionary = light.duplicate(true)
	heavy.cargo_mass = 300.0
	var a: Dictionary = Travel.land(light, "moon")
	var b: Dictionary = Travel.land(heavy, "moon")
	check(a.ok and b.ok, "both land")
	near(a.fuel_burned, Ship.fuel_for_delta_v(Ship.total_mass(light), Destinations.descent_delta_v("moon")), "descent fuel")
	check(b.fuel_burned > a.fuel_burned, "heavier ship burns more to land")
	eq(a.ship.velocity, Vector3.ZERO, "parked")
	var refused: Dictionary = Travel.land(_ship_at("moon", 500.0), "moon")
	check(not refused.ok and refused.reason != "", "refusal explained")
	eq(refused.ship.fuel, 650.0, "refusal burns nothing")

func test_takeoff_costs_more_from_mars_and_needs_fuel() -> void:
	var parked: Dictionary = Ship.create(650.0, 87.0)
	var moon: Dictionary = Travel.takeoff(parked, "moon", Destinations.get_def("mars").space.position)
	var mars: Dictionary = Travel.takeoff(parked, "mars", Vector3.ZERO)
	check(moon.ok and mars.ok, "both take off")
	check(mars.fuel_burned > 2.0 * moon.fuel_burned, "Mars ascent costs over twice the Moon's")
	near(Travel.altitude(moon.ship, "moon"), Destinations.get_def("moon").space.approach_altitude * 0.6, "placed in the approach zone", 0.001)
	var heading: Vector3 = Ship.forward(moon.ship)
	var to_mars: Vector3 = (Destinations.get_def("mars").space.position - moon.ship.position).normalized()
	check(heading.dot(to_mars) > 0.95, "pointing toward the next destination")
	var stranded: Dictionary = Travel.takeoff(Ship.create(40.0, 87.0), "mars", Vector3.ZERO)
	check(not stranded.ok and "Not enough fuel" in stranded.reason, "stranded without ascent fuel")
	eq(stranded.ship.fuel, 40.0, "failed takeoff burns nothing")

func test_round_trip_estimate_grows_with_speed_and_distance_from_home() -> void:
	var at_rest: Dictionary = _ship_at("mars", 50.0)
	var moving: Dictionary = _ship_at("mars", 50.0, Vector3(30, 0, 0))
	check(Travel.round_trip_delta_v(moving, "mars") > Travel.round_trip_delta_v(at_rest, "mars"), "must brake first")
	check(Travel.round_trip_delta_v(at_rest, "mars") > Travel.round_trip_delta_v(_ship_at("moon", 50.0), "moon"), "Mars needs a return trip")

func test_travel_functions_do_not_mutate_inputs() -> void:
	var ship: Dictionary = _ship_at("mars", 40.0, Vector3(1, 0, 0))
	var snapshot: Dictionary = ship.duplicate(true)
	Travel.fly(ship, {"thrust": 1.0}, 0.5)
	Travel.guidance(ship, "mars")
	Travel.land(ship, "mars")
	Travel.takeoff(ship, "mars", Vector3.ZERO)
	eq(ship, snapshot, "unchanged")
