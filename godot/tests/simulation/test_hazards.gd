extends "res://tests/simulation/test_case.gd"
## Mars dust storms, gentle rover damage and repairs.

func mars(config: Dictionary = DRILL) -> Dictionary:
	return engine.act(engine.create_surface_mission(config, 42, "mars"), "launch")

func moon() -> Dictionary:
	return engine.act(engine.create_surface_mission(DRILL, 42, "moon"), "launch")

func advance(state: Dictionary, seconds: float, step: float = 0.5) -> Dictionary:
	var s: Dictionary = state
	var t: float = 0.0
	while t < seconds - 0.000001:
		var dt: float = minf(step, seconds - t)
		s = engine.advance_time(s, dt)
		t += dt
	return s

func test_v1_missions_are_untouched_by_hazard_methods() -> void:
	var v1: Dictionary = launched()
	eq(engine.advance_time(v1, 100.0), v1, "no time fields on v1 states")
	eq(engine.report_impact(v1, 50.0), v1, "no damage on v1 states")
	eq(engine.repair(v1), v1, "no repair on v1 states")
	near(engine.move_rover(v1, Vector3(10, 0, 0)).energy, 100.0 - 1.6, "v1 movement cost unchanged")

func test_the_moon_has_no_weather() -> void:
	var s: Dictionary = advance(moon(), 1000.0, 5.0)
	eq(s.weather.phase, "clear", "always clear")
	eq(s.weather.solar_multiplier, 1.0, "full sunlight")

func test_mars_storm_cycle_is_deterministic_and_step_independent() -> void:
	var expectations: Array = [[74.0, "clear"], [76.0, "warning"], [86.0, "storm"], [109.0, "storm"], [111.0, "clear"], [201.0, "warning"]]
	for pair in expectations:
		var fine: Dictionary = advance(mars(), pair[0], 1.0 / 60.0)
		var coarse: Dictionary = engine.advance_time(mars(), pair[0])
		eq(fine.weather.phase, pair[1], "phase at %d s" % pair[0])
		for key in ["phase", "next_storm_at", "solar_multiplier"]:
			eq(coarse.weather[key], fine.weather[key], "same %s however time is stepped (%d s)" % [key, pair[0]])
		near(coarse.weather.remaining_seconds, fine.weather.remaining_seconds, "same countdown (%d s)" % pair[0], 0.000001)
	near(advance(mars(), 90.0).weather.solar_multiplier, 0.35, "storm solar multiplier")

func test_storms_reduce_solar_charging_but_not_fuel_cells_or_the_shelter() -> void:
	var stormy: Dictionary = with_energy(advance(mars(), 90.0), 10.0)
	near(engine.act(stormy, "recharge").energy, 10.0 + 40.0 * 0.43 * 0.35, "solar in a storm")
	var cells: Dictionary = with_energy(advance(engine.act(engine.create_surface_mission(FUEL_SCANNER, 42, "mars"), "launch"), 90.0), 10.0)
	near(engine.act(cells, "recharge").energy, 50.0, "fuel cells unaffected")
	var shelter: Vector3 = engine.surface_rules(stormy).shelter.position
	var sheltered: Dictionary = engine.act(at(stormy, shelter), "recharge")
	near(sheltered.energy, 50.0, "shelter power bank in any weather")
	eq(sheltered.fuel_cells, stormy.fuel_cells, "shelter uses no fuel cells")

func test_storms_never_move_or_damage_the_rover() -> void:
	var before: Dictionary = advance(mars(), 85.0)
	var during: Dictionary = advance(before, 20.0)
	eq(during.position, before.position, "no wind push")
	eq(during.integrity, 100.0, "no damage for being outdoors")
	eq(during.energy, before.energy, "no drain for waiting")

func test_forecast_brings_the_next_storm_forward() -> void:
	var s: Dictionary = engine.forecast_storm(advance(mars(), 5.0), 12.0)
	near(s.weather.next_storm_at, 17.0, "warning in 12 s")
	eq(advance(s, 13.0).weather.phase, "warning", "warning arrives")
	var storming: Dictionary = advance(mars(), 90.0)
	eq(engine.forecast_storm(storming, 1.0).weather, storming.weather, "no effect during a storm")

func test_weather_changes_are_logged() -> void:
	var s: Dictionary = advance(mars(), 76.0)
	check("warning" in last_log(s), "warning announced")
	s = advance(s, 35.0)
	check(s.log.slice(0, 3).any(func(line: String) -> bool: return "passed" in line), "clearing announced")

func test_impacts_damage_gently_with_threshold_cooldown_and_floor() -> void:
	var s: Dictionary = mars()
	eq(engine.report_impact(s, 4.9), s, "below 5 m/s: no damage")
	var hit: Dictionary = engine.report_impact(s, 5.0)
	near(hit.integrity, 95.0, "5 damage at the threshold")
	near(hit.impact_cooldown, 3.0, "cooldown starts")
	eq(engine.report_impact(hit, 20.0).integrity, hit.integrity, "no second hit during the cooldown")
	var later: Dictionary = engine.report_impact(advance(hit, 3.0), 30.0)
	near(later.integrity, 80.0, "capped at 15 damage per hit")
	var battered: Dictionary = s
	for i in range(50): battered = engine.report_impact(advance(battered, 3.0), 40.0)
	eq(battered.integrity, 35.0, "never below the floor")
	var moved: Dictionary = engine.move_rover(battered, battered.position + Vector3(10, 0, 0))
	check(moved.position.x > battered.position.x, "never immobilised")
	near(battered.energy - moved.energy, 10.0 * 0.2 * 1.4, "worn rover uses up to 40% more energy")
	for bad in [NAN, INF, -5.0]: eq(engine.report_impact(s, bad), s, "ignores bad speed %s" % bad)

func test_repairs_are_free_at_the_ship_or_shelter_only() -> void:
	var worn: Dictionary = engine.report_impact(mars(), 15.0)
	var field: Dictionary = engine.repair(at(worn, Vector3(80, 0, 80)))
	eq(field.integrity, worn.integrity, "no field repairs")
	check("free" in last_log(field), "says where repairs are")
	eq(engine.repair(at(worn, Vector3(0, 0, -8))).integrity, 100.0, "at the ship pad")
	eq(engine.repair(at(worn, engine.surface_rules(worn).shelter.position)).integrity, 100.0, "at the shelter")
	var moon_worn: Dictionary = engine.report_impact(moon(), 15.0)
	eq(engine.repair(at(moon_worn, Vector3(0, 0, -11))).integrity, 100.0, "Moon pad repairs too")

func test_hazard_methods_do_not_mutate_inputs() -> void:
	var s: Dictionary = advance(mars(), 80.0)
	var snapshot: Dictionary = s.duplicate(true)
	engine.advance_time(s, 10.0)
	engine.report_impact(s, 12.0)
	engine.repair(s)
	engine.forecast_storm(s, 1.0)
	eq(s, snapshot, "unchanged")
