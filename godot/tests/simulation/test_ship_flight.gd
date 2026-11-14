extends "res://tests/simulation/test_case.gd"
## Stage 1: pure spaceship flight model.
const Ship = preload("res://simulation/ship_flight.gd")

func _fly(ship: Dictionary, input: Dictionary, seconds: float, frames: int) -> Dictionary:
	var s: Dictionary = ship
	for i in range(frames): s = Ship.step(s, input, seconds / frames)
	return s

func test_mass_includes_hull_cargo_and_fuel() -> void:
	var ship: Dictionary = Ship.create(650.0, 87.0)
	near(Ship.total_mass(ship), 900.0 + 87.0 + 650.0, "total mass")
	eq(ship.velocity, Vector3.ZERO, "starts at rest")

func test_thrust_accelerates_forward_and_burns_fuel() -> void:
	var ship: Dictionary = Ship.create(650.0, 0.0)
	var s: Dictionary = Ship.step(ship, {"thrust": 1.0}, 1.0)
	var burn: float = Ship.MAX_THRUST / Ship.EXHAUST_VELOCITY
	near(s.fuel, 650.0 - burn, "fuel burned = F*dt/ve")
	var expected_dv: float = Ship.EXHAUST_VELOCITY * log(1550.0 / (1550.0 - burn))
	check(s.velocity.is_equal_approx(Vector3.FORWARD * expected_dv), "rocket-equation delta-v along -Z")
	near(s.throttle, 1.0, "full throttle reported for engine effects")

func test_same_burn_split_into_different_frame_counts_gives_same_fuel_and_delta_v() -> void:
	var ship: Dictionary = Ship.create(650.0, 120.0)
	var reference: Dictionary = _fly(ship, {"thrust": 0.7}, 3.0, 1)
	for frames in [7, 60, 360]:
		var s: Dictionary = _fly(ship, {"thrust": 0.7}, 3.0, frames)
		near(s.fuel, reference.fuel, "fuel with %d frames" % frames, 0.0001)
		check(s.velocity.is_equal_approx(reference.velocity), "delta-v with %d frames" % frames)

func test_heavier_ships_get_less_delta_v_from_the_same_fuel() -> void:
	var light: Dictionary = _fly(Ship.create(650.0, 0.0), {"thrust": 1.0}, 2.0, 60)
	var heavy: Dictionary = _fly(Ship.create(650.0, 300.0), {"thrust": 1.0}, 2.0, 60)
	near(light.fuel, heavy.fuel, "same fuel burned")
	check(Ship.speed(heavy) < Ship.speed(light), "cargo reduces acceleration")
	check(Ship.delta_v_remaining(Ship.create(650.0, 300.0)) < Ship.delta_v_remaining(Ship.create(650.0, 0.0)), "and total delta-v")

func test_delta_v_remaining_matches_burning_all_fuel() -> void:
	var ship: Dictionary = Ship.create(450.0, 90.0)
	var budget: float = Ship.delta_v_remaining(ship)
	var empty: Dictionary = _fly(ship, {"thrust": 1.0}, 40.0, 2400)
	eq(empty.fuel, 0.0, "tank empty, never negative")
	near(Ship.speed(empty), budget, "achieved delta-v equals the budget", 0.01)
	near(Ship.fuel_for_delta_v(Ship.total_mass(ship), budget), 450.0, "inverse function", 0.01)

func test_braking_stops_without_reversing_and_costs_rocket_equation_fuel() -> void:
	var moving: Dictionary = Ship.create(650.0, 0.0)
	moving.velocity = Vector3(30, 0, -40)  # 50 u/s
	var mass: float = Ship.total_mass(moving)
	var stopped: Dictionary = _fly(moving, {"brake": 1.0}, 10.0, 600)
	eq(stopped.velocity, Vector3.ZERO, "stopped exactly")
	near(650.0 - stopped.fuel, Ship.fuel_for_delta_v(mass, 50.0), "fuel for 50 u/s of braking", 0.001)
	var idle: Dictionary = Ship.step(stopped, {"brake": 1.0}, 1.0)
	eq(idle.fuel, stopped.fuel, "braking at rest burns nothing")

func test_coasting_keeps_velocity_and_an_empty_tank_cannot_thrust() -> void:
	var dry: Dictionary = Ship.create(0.0, 0.0)
	dry.velocity = Vector3(5, 0, 0)
	var s: Dictionary = _fly(dry, {"thrust": 1.0, "brake": 1.0}, 2.0, 120)
	eq(s.velocity, Vector3(5, 0, 0), "no fuel: no thrust or braking")
	check(s.position.is_equal_approx(Vector3(10, 0, 0)), "coasts 10 u in 2 s")
	eq(s.throttle, 0.0, "no engine effect")

func test_steering_and_pitch_limit() -> void:
	var s: Dictionary = Ship.step(Ship.create(100.0, 0.0), {"yaw": 1.0}, (PI / 2.0) / Ship.TURN_RATE)
	check(Ship.forward(s).is_equal_approx(Vector3.RIGHT), "right steering turns toward +X")
	var up: Dictionary = _fly(Ship.create(100.0, 0.0), {"pitch": 1.0}, 10.0, 100)
	near(up.pitch, Ship.PITCH_LIMIT, "pitch clamped")
	check(Ship.forward(up).y > 0.9, "nose up")

func test_bad_input_and_time_are_harmless() -> void:
	var ship: Dictionary = Ship.create(650.0, 0.0)
	for input in [{"thrust": NAN}, {"thrust": "full"}, {"yaw": INF}, {"thrust": -5.0}, {}]:
		var s: Dictionary = Ship.step(ship, input, 0.1)
		eq(s.fuel, 650.0, "no burn for %s" % var_to_str(input))
		check(s.position.is_finite() and s.yaw == 0.0, "finite and unturned")
	for dt in [0.0, -1.0, NAN, INF]:
		var s: Dictionary = Ship.step(ship, {"thrust": 1.0}, dt)
		eq(s.fuel, 650.0, "dt %s ignored" % dt)
	near(Ship.step(ship, {"thrust": 3.0}, 1.0).fuel, 650.0 - Ship.MAX_THRUST / Ship.EXHAUST_VELOCITY, "thrust clamped to 1")

func test_step_never_mutates_input() -> void:
	var ship: Dictionary = Ship.create(650.0, 50.0)
	ship.velocity = Vector3(1, 2, 3)
	var snapshot: Dictionary = ship.duplicate(true)
	Ship.step(ship, {"thrust": 1.0, "brake": 0.5, "yaw": 1.0, "pitch": -1.0}, 0.5)
	eq(ship, snapshot, "input unchanged")
