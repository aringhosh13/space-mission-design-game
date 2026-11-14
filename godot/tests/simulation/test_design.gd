extends "res://tests/simulation/test_case.gd"
## Design validation, mission creation and launch restrictions.

func test_default_design_totals() -> void:
	var review: Dictionary = engine.review_design(SCANNER)
	eq(review.cost, 85, "cost")
	eq(review.mass, 67, "mass")
	eq(review.budget, 110, "budget")
	eq(review.mass_limit, 100, "mass limit")
	check(review.warnings.is_empty(), "no warnings")

func test_overrun_warnings_state_their_size() -> void:
	var review: Dictionary = engine.review_design(OVERWEIGHT)
	eq(review.cost, 130, "cost")
	eq(review.mass, 112, "mass")
	eq(review.warnings.size(), 2, "two warnings")
	check("20 credits" in review.warnings[0], "budget overrun named")
	check("12 kg" in review.warnings[1], "mass overrun named")

func test_exactly_on_budget_is_allowed() -> void:
	var review: Dictionary = engine.review_design({"battery": "extended", "power": "fuel-cell", "instrument": "scanner"})
	eq(review.cost, Rules.BUDGET, "cost equals budget")
	check(review.warnings.is_empty(), "allowed")

func test_over_budget_within_mass() -> void:
	var review: Dictionary = engine.review_design({"battery": "compact", "power": "fuel-cell", "instrument": "drill"})
	eq(review.cost, 115, "cost")
	eq(review.mass, 96, "mass")
	eq(review.warnings.size(), 1, "one warning")

func test_unknown_or_missing_components_block_launch() -> void:
	for config in [{"battery": "nuclear", "power": "solar", "instrument": "scanner"}, {}]:
		check(not engine.review_design(config).warnings.is_empty(), "warning for %s" % config)
		var planned: Dictionary = engine.create_mission(config, 1)
		eq(planned.max_energy, 0.0, "no battery capacity")
		eq(engine.act(planned, "launch").phase, "planning", "launch blocked")

func test_mission_starts_in_planning_with_full_battery() -> void:
	var compact: Dictionary = engine.create_mission(SCANNER, 1)
	eq(compact.phase, "planning", "phase")
	eq(compact.energy, 100.0, "energy")
	eq(compact.max_energy, 100.0, "max energy")
	eq(compact.position, Vector3.ZERO, "landing point")
	eq(compact.outpost_position, null, "no station")
	eq(engine.create_mission({"battery": "extended", "power": "solar", "instrument": "scanner"}, 1).max_energy, 160.0, "extended")

func test_fuel_cells_only_for_fuel_cell_designs() -> void:
	eq(engine.create_mission(FUEL_SCANNER, 1).fuel_cells, 3, "fuel-cell design")
	eq(engine.create_mission(SCANNER, 1).fuel_cells, 0, "solar design")

func test_config_is_copied() -> void:
	var config: Dictionary = DRILL.duplicate()
	var state: Dictionary = engine.create_mission(config, 1)
	config.instrument = "scanner"
	eq(state.config.instrument, "drill", "later edits do not leak in")

func test_valid_launch_and_duplicate_launch() -> void:
	var surface: Dictionary = engine.act(engine.create_mission(DRILL, 1), "launch")
	eq(surface.phase, "surface", "launched")
	var again: Dictionary = engine.act(surface, "launch")
	unchanged_except_log(again, surface, "duplicate launch changes nothing")
	check("already launched" in last_log(again), "explains duplicate launch")

func test_invalid_design_cannot_launch() -> void:
	var planned: Dictionary = engine.create_mission(OVERWEIGHT, 1)
	var after: Dictionary = engine.act(planned, "launch")
	eq(after.phase, "planning", "still planning")
	unchanged_except_log(after, planned, "nothing else changes")
	check(last_log(after).begins_with("Launch blocked"), "explains why")

func test_surface_actions_and_moves_rejected_before_launch() -> void:
	var planned: Dictionary = engine.create_mission(DRILL, 1)
	for action in ["scan", "sample", "recharge", "transmit", "deploy", "finish"]:
		unchanged_except_log(engine.act(planned, action), planned, "%s before launch" % action)
	eq(engine.move_rover(planned, Vector3(5, 0, 0)), planned, "no driving before launch")
