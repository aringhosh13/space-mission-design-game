extends "res://tests/simulation/test_case.gd"
## Continuous, distance-based movement: bounds, finiteness, power accounting and frame independence.

const PER_M: float = 0.16

func test_charges_actual_horizontal_metres() -> void:
	var s: Dictionary = engine.move_rover(launched(), Vector3(3, 0, 4))
	eq(s.position, Vector3(3, 0, 4), "moved")
	near(s.energy, 100.0 - 5.0 * PER_M, "5 m costs 0.8")
	near(s.distance_travelled, 5.0, "distance recorded")

func test_vertical_change_is_free() -> void:
	var start: Dictionary = launched()
	var s: Dictionary = engine.move_rover(start, Vector3(0, 2.5, 0))
	eq(s.position, Vector3(0, 2.5, 0), "terrain height follows the scene")
	eq(s.energy, start.energy, "no horizontal travel, no charge")
	var sloped: Dictionary = engine.move_rover(start, Vector3(1, 3, 0))
	near(sloped.energy, 100.0 - PER_M, "only horizontal metres are charged")

func test_equal_travel_split_into_different_frame_counts_costs_the_same() -> void:
	var target := Vector3(12.5, 0, -7.25)
	for frames in [1, 7, 60, 600]:
		var s: Dictionary = launched()
		for i in range(1, frames + 1):
			s = engine.move_rover(s, target * (float(i) / frames))
		near(s.energy, 100.0 - target.length() * PER_M, "energy with %d frames" % frames, 0.00001)
		near(s.distance_travelled, target.length(), "distance with %d frames" % frames, 0.00001)
		check(s.position.is_equal_approx(target), "arrives with %d frames" % frames)

func test_rejects_non_finite_positions() -> void:
	var start: Dictionary = launched()
	for bad in [Vector3(NAN, 0, 0), Vector3(INF, 0, 0), Vector3(0, 0, -INF), Vector3(0, NAN, 0)]:
		eq(engine.move_rover(start, bad), start, "rejects %s" % bad)

func test_clamps_to_map_limit_and_charges_only_the_clamped_distance() -> void:
	var start: Dictionary = at(launched(), Vector3(77, 0, 0))
	var s: Dictionary = engine.move_rover(start, Vector3(80, 0, 0))
	eq(s.position, Vector3(78, 0, 0), "held at the boundary")
	near(s.energy, 100.0 - PER_M, "charged 1 m, not 3 m")
	var corner: Dictionary = engine.move_rover(at(launched(), Vector3(-78, 0, -78)), Vector3(-200, 0, -200))
	eq(corner.position, Vector3(-78, 0, -78), "pushing outward at the corner")
	eq(corner.energy, 100.0, "free when nothing is travelled")

func test_insufficient_energy_shortens_the_move_and_never_goes_negative() -> void:
	var low: Dictionary = with_energy(launched(), 0.8)  # pays for 5 m
	var s: Dictionary = engine.move_rover(low, Vector3(10, 0, 0))
	check(s.position.is_equal_approx(Vector3(5, 0, 0)), "travels exactly as far as 0.8 energy pays for")
	eq(s.energy, 0.0, "battery empty, not negative")
	check("depleted" in last_log(s), "explains depletion")
	var stuck: Dictionary = engine.move_rover(s, Vector3(6, 0, 0))
	eq(stuck.position, s.position, "no further horizontal travel at zero energy")
	eq(stuck.log.size(), s.log.size(), "depletion is not logged every frame")

func test_depletion_total_distance_is_frame_independent() -> void:
	for frames in [3, 50, 400]:
		var s: Dictionary = with_energy(launched(), 1.6)  # pays for exactly 10 m
		for i in range(1, frames + 1):
			s = engine.move_rover(s, Vector3(20.0 * i / frames, 0, 0))
		near(s.distance_travelled, 10.0, "10 m with %d frames" % frames, 0.00001)
		eq(s.energy, 0.0, "empty")

func test_long_seeded_random_drive_stays_finite_bounded_and_non_negative() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s: Dictionary = launched()
	for i in range(3000):
		if rng.randf() < 0.05:
			s = engine.act(s, "recharge")
			continue
		var p: Vector3 = s.position + Vector3(rng.randf_range(-4, 4), rng.randf_range(-0.5, 0.5), rng.randf_range(-4, 4))
		s = engine.move_rover(s, p)
		check(s.position.is_finite(), "finite position")
		check(absf(s.position.x) <= 78.0 and absf(s.position.z) <= 78.0, "inside the map")
		check(s.energy >= 0.0 and s.energy <= s.max_energy, "0 <= energy <= max")
	check(s.distance_travelled > 100.0, "the walk actually travelled")

func test_moves_rejected_after_completion() -> void:
	var done: Dictionary = engine.act(launched(), "finish")
	eq(engine.move_rover(done, Vector3(4, 0, 0)), done, "closed mission does not move")
