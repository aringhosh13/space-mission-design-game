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

## Fly a space scene to a destination with the autopilot (player-equivalent inputs). Returns frames used.
func fly_to(space: Node, id: String, max_frames: int = 6000) -> int:
	var Travel = load("res://simulation/travel.gd")
	var Autopilot = load("res://spaceflight/autopilot.gd")
	for i in range(max_frames):
		if Travel.guidance(space.ship, id).can_land: return i
		space.input_override = Autopilot.approach_input(space.ship, id)
		await physics_frame
	return -1

func stage_2_space_travel() -> void:
	var Travel = load("res://simulation/travel.gd")
	var Destinations = load("res://simulation/destinations.gd")
	var start: Dictionary = Travel.takeoff(Ship.create(650.0, 87.0), "moon", Destinations.get_def("mars").space.position).ship
	var space: Node3D = load("res://spaceflight/space_scene.gd").new()
	space.setup(start, "mars")
	var requested: Array[String] = []
	space.land_requested.connect(func(id: String) -> void: requested.append(id))
	root.add_child(space)
	await frames(2)
	check(space.planets.size() == 3, "Stage 2: Moon, Mars and Earth are in the scene")
	check(space.planets.mars.approach_ring.visible and not space.planets.moon.approach_ring.visible, "Stage 2: target's approach zone shown")
	check(not space.try_land(), "Stage 2: cannot land from far away")
	check(requested.is_empty(), "Stage 2: no landing request when refused")
	space.cycle_target()
	check(space.target_id == "earth", "Stage 2: TAB cycles destinations")
	space.cycle_target()
	check(space.target_id == "moon", "Stage 2: and wraps around")
	space.select_target("mars")
	var used: int = await fly_to(space, "mars")
	check(used > 0, "Stage 2: autopilot (player inputs) reaches the Mars approach zone (%d frames)" % used)
	check(space.ship.fuel < start.fuel, "Stage 2: the transfer burned fuel")
	check(space.try_land() and requested == ["mars"], "Stage 2: landing request emitted in the approach zone")
	check("LAND ON MARS" in space.hud.prompt_label.text, "Stage 2: HUD prompts the landing")
	space.paused = true
	var frozen: Vector3 = space.ship.position
	await frames(10)
	check(space.ship.position == frozen, "Stage 2: pause freezes flight")
	space.queue_free()
	await frames(2)

	var demo: Node = load("res://scenes/spaceflight/space_travel.tscn").instantiate()
	root.add_child(demo)
	await frames(60)
	check(demo.space != null and demo.space.is_inside_tree(), "Stage 2: demo takes off into the space scene")
	check(demo.ship.fuel < Ship.FUEL_LOADS.standard, "Stage 2: takeoff paid ascent fuel")
	demo.queue_free()
	await frames(2)
