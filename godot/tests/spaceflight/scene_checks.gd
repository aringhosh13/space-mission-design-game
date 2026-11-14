extends SceneTree
## Spaceflight scene checks (headless). Drives the real scenes with injected inputs, frame by frame.
##   godot --headless --path godot --script res://tests/spaceflight/scene_checks.gd
## Pure simulation rules are covered by tests/simulation; this checks scenes are wired to them.
const Ship = preload("res://simulation/ship_flight.gd")

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func _run() -> void:
	await stage_1_ship()
	for extra in ["stage_2_space_travel", "stage_3_mars_surface", "stage_4_expedition_loop"]:
		if has_method(extra): await call(extra)
	if failures.is_empty(): print("PASS: spaceflight scene checks (%d checks)" % checks)
	else: print("FAIL: ", failures)
	quit(0 if failures.is_empty() else 1)

func stage_1_ship() -> void:
	var scene: Node = load("res://scenes/spaceflight/ship_sandbox.tscn").instantiate()
	root.add_child(scene)
	await frames(2)
	var start: Dictionary = scene.ship.duplicate(true)
	scene.input_override = {"thrust": 1.0}
	await frames(60)
	var thrusted: Dictionary = scene.ship
	check(thrusted.position.z < start.position.z - 1.0, "Stage 1: thrust moves the ship forward (-Z)")
	check(thrusted.fuel < start.fuel, "Stage 1: thrust burns fuel")
	check(scene.rig.position.is_equal_approx(thrusted.position), "Stage 1: ship node mirrors the simulation")
	check(scene.rig.model.flame.visible, "Stage 1: engine flame visible while thrusting")
	scene.input_override = {"yaw": 1.0}
	await frames(30)
	check(scene.ship.yaw < -0.3, "Stage 1: D steering turns the ship right")
	check(not scene.rig.model.flame.visible, "Stage 1: flame off when coasting")
	scene.input_override = {"brake": 1.0}
	await frames(240)
	check(Ship.speed(scene.ship) < 0.001, "Stage 1: braking brings the ship to rest")
	check(scene.hud.speed_label.text == "0.0 u/s", "Stage 1: HUD shows velocity")
	check("kg propellant" in scene.hud.fuel_label.text, "Stage 1: HUD shows fuel")
	check(scene.camera.global_position.distance_to(scene.rig.global_position) < 40.0, "Stage 1: chase camera follows")
	scene.queue_free()
	await frames(2)
