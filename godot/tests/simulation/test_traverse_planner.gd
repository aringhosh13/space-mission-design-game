extends "res://tests/simulation/test_case.gd"
const Planner = preload("res://simulation/traverse_planner.gd")
const Data = preload("res://scripts/lunar_elevation_data.gd")
const MOON = preload("res://data/terrain/lola_south_pole.tres")
const MARS = preload("res://data/terrain/mola_jezero.tres")

func flat() -> Resource:
	var data := Data.new()
	data.width = 65
	data.height = 65
	data.real_half_extent_m = 32
	data.elevations.resize(65 * 65)
	return data

func test_round_trip_budget_counts_both_legs_and_reserve() -> void:
	var result: Dictionary = Planner.plan(flat(), Vector2(0, 0.5), Vector2(1, 0.5), 15, 10, 0.2)
	near(result.distance_m, 128.0, "both legs counted")
	near(result.energy_wh, 128.0 * (0.02 + 20.0 / (0.2 * 3600)), "traction and idle energy counted")
	check(result.feasible, "enough energy with reserve")
	var low: Dictionary = Planner.plan(flat(), Vector2(0, 0.5), Vector2(1, 0.5), 15, 5, 0.2)
	check(not low.feasible and low.energy_wh > 4, "cannot approve outbound-only budget")

func test_cliff_barrier_is_not_crossed_and_can_be_relaxed() -> void:
	var data: Resource = flat()
	for y in range(65):
		for x in range(33, 65): data.elevations[y * 65 + x] = 1
	var blocked: Dictionary = Planner.plan(data, Vector2(0, 0.5), Vector2(1, 0.5), 15)
	check(not blocked.feasible and blocked.outbound.is_empty(), "impassable barrier blocks traverse")
	var allowed: Dictionary = Planner.plan(data, Vector2(0, 0.5), Vector2(1, 0.5), 46)
	check(allowed.feasible, "explicitly relaxed threshold allows crossing")

func test_nasa_routes_reproduce_and_optimise_stated_energy() -> void:
	for data in [MOON, MARS]:
		var shortest: Dictionary = Planner.plan(data, Vector2(0.5, 0.5), Vector2(0.65, 0.35), 15, 50000, 0.2, false)
		var efficient: Dictionary = Planner.plan(data, Vector2(0.5, 0.5), Vector2(0.65, 0.35), 15, 50000, 0.2, true)
		check(not efficient.outbound.is_empty() and not efficient["return"].is_empty(), "NASA grid has both legs")
		check(efficient.energy_wh <= shortest.energy_wh + 0.01, "energy search does not underperform distance policy")
		check(efficient.max_slope_deg <= 15.001, "sampled edge slope respects threshold")
		eq(efficient, Planner.plan(data, Vector2(0.5, 0.5), Vector2(0.65, 0.35), 15, 50000, 0.2, true), "repeatable planning")

func test_export_preserves_planetary_source_and_model_warnings() -> void:
	var route: Dictionary = Planner.plan(MARS, Vector2(0.5, 0.5), Vector2(0.65, 0.35))
	var exported: Dictionary = Planner.geojson(MARS, route)
	eq(exported.features.size(), 2, "two route legs")
	eq(exported.features[0].properties.body, "Mars", "planet specified")
	check(exported.properties.warning.contains("not Earth WGS84"), "non-Earth CRS caveat")
	near(Planner.geographic(MARS, Vector2(0.5, 0.5)).x, 77.58, "physical longitude", 0.001)
	near(Planner.geographic(MARS, Vector2(0.5, 0.5)).y, 18.38, "physical latitude", 0.001)

func test_energy_policy_can_choose_a_longer_but_cheaper_route() -> void:
	var data: Resource = flat()
	for y in range(65):
		for x in range(65):
			data.elevations[y * 65 + x] = 2.0 * maxf(0, 1.0 - absf(x - 32.0) / 10.0) * maxf(0, 1.0 - absf(y - 32.0) / 4.0)
	var shortest: Dictionary = Planner.plan(data, Vector2(0, 0.5), Vector2(1, 0.5), 45, 10000, 0.2, false)
	var efficient: Dictionary = Planner.plan(data, Vector2(0, 0.5), Vector2(1, 0.5), 45, 10000, 0.2, true)
	check(efficient.energy_wh < shortest.energy_wh - 0.01, "avoiding the ridge reduces stated energy")
	check(efficient.distance_m > shortest.distance_m, "energy policy accepts a longer traverse")

func test_invalid_or_identical_inputs_never_approve() -> void:
	check(not Planner.plan(null, Vector2.ZERO, Vector2.ONE).feasible, "missing DEM rejected")
	check(not Planner.plan(flat(), Vector2(-1, 0), Vector2.ONE).feasible, "outside map rejected")
	check(not Planner.plan(flat(), Vector2.ZERO, Vector2.ONE, 15, NAN).feasible, "nonfinite budget rejected")
	check(not Planner.plan(flat(), Vector2.ZERO, Vector2.ZERO).feasible, "identical endpoints rejected")
