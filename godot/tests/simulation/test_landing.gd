extends "res://tests/simulation/test_case.gd"
## Player-controlled final descent and its expedition integration.
const Landing = preload("res://simulation/landing.gd")
const Expedition = preload("res://simulation/expedition.gd")
const Travel = preload("res://simulation/travel.gd")
const Ship = preload("res://simulation/ship_flight.gd")
const Destinations = preload("res://simulation/destinations.gd")

const DT: float = 1.0 / 60.0

func descend(l: Dictionary, controller: Callable, max_steps: int = 6000) -> Dictionary:
	var s: Dictionary = l
	for i in range(max_steps):
		if s.status != "descending": return s
		s = Landing.step(s, controller.call(s), DT)
	return s

## A "player" using only the controls a person has: hold thrust (on/off) and tap lateral keys.
func human_pilot(l: Dictionary) -> Dictionary:
	var id: String = str(l.destination)
	var margin: float = 4.0 if float(l.altitude) > 30.0 else 1.6
	var stop_distance: float = pow(float(l.vertical_speed), 2) / (2.0 * (Landing.max_accel(id) - Landing.gravity(id)))
	var thrust: float = 1.0 if (stop_distance + margin >= float(l.altitude) or float(l.vertical_speed) < -6.0) else 0.0
	if float(l.vertical_speed) > -0.6: thrust = 0.0
	var offset: Vector2 = l.offset
	var velocity: Vector2 = l.lateral_velocity
	var key := Vector2(_tap(-offset.x * 0.3 - velocity.x), _tap(-offset.y * 0.3 - velocity.y))
	return {"throttle": thrust, "x": key.x, "z": key.y}

func _tap(value: float) -> float:
	return 0.0 if absf(value) < 0.4 else signf(value)

func parked(id: String, fuel_load: String = "standard") -> Dictionary:
	var s: Dictionary = Expedition.takeoff(Expedition.board(_at_pad(Expedition.begin(Expedition.create(DRILL, fuel_load, 42)))), "mars")
	var body: Dictionary = Destinations.get_def(id).space
	s.ship.position = body.position + Vector3.UP * (float(body.radius) + 30.0)
	s.ship.velocity = Vector3.ZERO
	return s

func _at_pad(s: Dictionary) -> Dictionary:
	var t: Dictionary = s.duplicate(true)
	t.missions[t.location].position = Destinations.get_def(t.location).pad + Vector3(0, 0, 4)
	return t

func test_start_is_deterministic_and_retries_start_from_the_same_approach() -> void:
	eq(Landing.create("mars", 7), Landing.create("mars", 7), "same seed, same approach")
	var a: Dictionary = Landing.create("mars", 7)
	var b: Dictionary = Landing.create("mars", 7, false, 3)
	eq(a.offset, b.offset, "retry starts at the same approach point")
	near(a.altitude, 120.0, "120 m above the pad")
	check((a.offset as Vector2).length() >= 14.0, "starts off to one side")

func test_uses_real_surface_gravity() -> void:
	near(Landing.gravity("moon"), 1.62, "Moon gravity (NASA)")
	near(Landing.gravity("mars"), 3.71, "Mars gravity (NASA)")
	var falling: Dictionary = Landing.step(Landing.create("mars", 1), {"throttle": 0.0}, 1.0)
	near(falling.vertical_speed, -6.0 - 3.71, "free fall accelerates at Mars gravity")

func test_assist_lands_safely_on_both_worlds() -> void:
	for id in ["moon", "mars"]:
		for mission_seed in [1, 42, 99]:
			var l: Dictionary = descend(Landing.create(id, mission_seed, true), func(_l: Dictionary) -> Dictionary: return {})
			eq(l.status, "landed", "assist lands on %s (seed %d): %s" % [id, mission_seed, l.reason])

func test_manual_controls_without_assist_can_land() -> void:
	for id in ["moon", "mars"]:
		var l: Dictionary = descend(Landing.create(id, 42, false), human_pilot)
		eq(l.status, "landed", "on/off thrust and tapped RCS land on %s: %s" % [id, l.reason])

func test_unsafe_touchdowns_fail_with_a_reason() -> void:
	var fall: Dictionary = descend(Landing.create("moon", 42), func(_l: Dictionary) -> Dictionary: return {"throttle": 0.0})
	eq(fall.status, "failed", "free fall is unsafe")
	check("descending at" in fall.reason, "says it was too fast")
	var drift := Landing.create("moon", 42, true)
	drift.lateral_velocity = Vector2(30, 0)
	var wide: Dictionary = descend(drift, func(_l: Dictionary) -> Dictionary: return {"x": 0.0001})
	eq(wide.status, "failed", "far from the pad is unsafe")

func test_player_input_overrides_assist_per_axis() -> void:
	var l: Dictionary = Landing.create("mars", 5, true)
	var cut: Dictionary = Landing.step(l, {"throttle": 0.0}, DT)
	eq(cut.throttle, 0.0, "explicit throttle overrides assist")
	var auto: Dictionary = Landing.step(l, {}, DT)
	near(auto.throttle, Landing.assist_input(l).throttle, "no input: assist flies")

func test_thrust_allowance_runs_out() -> void:
	var l: Dictionary = Landing.create("moon", 3)
	l.altitude = 1.0e9
	for i in range(int(Landing.ALLOWANCE_SECONDS / 0.5) + 4): l = Landing.step(l, {"throttle": 1.0}, 0.5)
	eq(l.allowance, 0.0, "allowance exhausted, never negative")
	eq(l.throttle, 0.0, "no thrust without allowance")

func test_bad_input_and_time_are_harmless_and_inputs_are_not_mutated() -> void:
	var l: Dictionary = Landing.create("mars", 2)
	var snapshot: Dictionary = l.duplicate(true)
	for dt in [0.0, -1.0, NAN, INF]: eq(Landing.step(l, {"throttle": 1.0}, dt), l, "dt %s ignored" % dt)
	var s: Dictionary = Landing.step(l, {"throttle": NAN, "x": INF, "z": "left"}, DT)
	check(s.offset.is_finite() and is_finite(s.altitude), "stays finite")
	eq(l, snapshot, "input unchanged")

func test_expedition_charges_descent_fuel_exactly_once() -> void:
	var s: Dictionary = parked("mars")
	var expected: float = Travel.descent_fuel(s.ship, "mars")
	var landing: Dictionary = Expedition.begin_landing(s, "mars")
	eq(landing.phase, "landing", "final descent phase")
	near(s.ship.fuel - landing.ship.fuel, expected, "descent burn charged at the current mass")
	var crashed: Dictionary = landing
	for i in range(3000):
		if crashed.landing.status != "descending": break
		crashed = Expedition.landing_step(crashed, {"throttle": 0.0}, DT)
	eq(crashed.landing.status, "failed", "free fall fails")
	var retry: Dictionary = Expedition.retry_landing(crashed)
	eq(retry.ship.fuel, landing.ship.fuel, "retry costs no fuel")
	eq(retry.landing.attempts, 2, "attempt counted")
	var down: Dictionary = Expedition.set_landing_assist(retry, true)
	for i in range(6000):
		if down.phase != "landing": break
		down = Expedition.landing_step(down, {}, DT)
	eq(down.phase, "aboard", "landed")
	eq(down.location, "mars", "on Mars")
	eq(down.ship.fuel, landing.ship.fuel, "touchdown charges nothing more")
	check(not down.has("landing"), "landing state cleared")

func test_begin_landing_needs_a_valid_approach() -> void:
	var far: Dictionary = parked("mars")
	far.ship.position += Vector3(0, 400, 0)
	var refused: Dictionary = Expedition.begin_landing(far, "mars")
	eq(refused.phase, "flight", "outside the approach zone")
	eq(refused.ship.fuel, far.ship.fuel, "no fuel charged")
	eq(Expedition.begin_landing(parked("earth"), "earth").phase, "flight", "Earth is a landmark")

func test_landing_home_delivers_cores_once_and_finish_mid_descent_closes_cleanly() -> void:
	var s: Dictionary = parked("moon")
	s.cores = [{"id": "mars:mars-b", "destination": "mars", "site_id": "mars-b", "name": "X", "finding": "confirmed", "science": 35, "mass": 6.0}]
	s = Expedition.set_landing_assist(Expedition.begin_landing(s, "moon"), true)
	var closed: Dictionary = Expedition.finish(s)
	eq(closed.phase, "complete", "finish during descent")
	check(not closed.has("landing"), "descent discarded")
	eq(closed.delivered_science, 0, "no delivery without touchdown")
	for i in range(6000):
		if s.phase != "landing": break
		s = Expedition.landing_step(s, {}, DT)
	eq(s.delivered_science, 35, "delivered on touchdown")
	eq(Expedition.landing_step(s, {}, DT).delivered_science, 35, "no second delivery")
