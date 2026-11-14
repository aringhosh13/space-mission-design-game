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

func stage_3_mars_surface() -> void:
	var demo: Node = load("res://scenes/spaceflight/mars_surface.tscn").instantiate()
	root.add_child(demo)
	await frames(90)
	var surface: Node3D = demo.surface
	check(surface.world.get_script() == load("res://spaceflight/mars_world.gd"), "Stage 3: Mars uses its own world")
	check(surface.state.destination == "mars", "Stage 3: Mars mission state")
	check(surface.rover.is_on_floor(), "Stage 3: rover settles on Martian terrain")
	var before: Dictionary = surface.state.duplicate(true)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await frames(90)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await frames(5)
	var travelled: float = float(surface.state.distance_travelled) - float(before.distance_travelled)
	check(travelled > 2.0, "Stage 3: W drives the rover on Mars")
	check(absf((before.energy - surface.state.energy) - travelled * 0.2) < 0.001, "Stage 3: Mars driving costs 0.2 energy per metre")
	check(not surface.try_board() or surface.board_distance() <= 9.0, "Stage 3: boarding needs the ship in range")
	var target: Dictionary = surface.state.sites[1]
	surface.state.position = target.position
	surface.rover.global_position = target.position + Vector3(0, surface.world.terrain_height(target.position.x, target.position.z) + 0.5, 0)
	surface.act("scan")
	surface.act("sample")
	check(surface.state.sites[1].finding in ["confirmed", "ruled-out"], "Stage 3: scan and sample settle a Mars signal")
	check(surface.world.marker_nodes["mars-b"].label.text.find(str(surface.state.sites[1].confidence)) >= 0, "Stage 3: marker shows the reported confidence")
	surface.act("transmit")
	check(surface.state.science_returned == 20, "Stage 3: only scan data radioed from Mars")
	var boarded: Array[bool] = []
	surface.board_requested.connect(func() -> void: boarded.append(true))
	surface.state.position = Vector3(0, 0, -6)
	check(surface.try_board() and boarded.size() == 1, "Stage 3: G boards when the rover is at the ship")
	demo.queue_free()
	await frames(2)

## Put the rover somewhere on the current surface and tell the surface scene (as driving would).
func place_rover(game: Node, position: Vector3) -> void:
	var surface: Node3D = game.current
	surface.state.position = position
	surface.rover.global_position = Vector3(position.x, surface.world.terrain_height(position.x, position.z) + 0.5, position.z)
	surface.mission_changed.emit(surface.state)

func investigate(game: Node, index: int) -> void:
	var surface: Node3D = game.current
	surface.state.energy = surface.state.max_energy
	place_rover(game, surface.state.sites[index].position)
	surface.act("scan")
	surface.act("sample")

func stage_4_expedition_loop() -> void:
	var Destinations = load("res://simulation/destinations.gd")
	var game: Node = load("res://scenes/spaceflight/expedition_demo.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	check(game.ui.active == "planning", "Stage 4: planning screen first")
	check(game.start({"battery": "compact", "power": "solar", "instrument": "drill"}, "standard"), "Stage 4: expedition begins")
	await frames(30)
	check(game.current.destination_id == "moon" and game.current.world.get_script() == load("res://scripts/lunar_world.gd"), "Stage 4: starts on the Moon with Codex's lunar world")
	# Explore the Moon.
	investigate(game, 1)
	place_rover(game, Vector3.ZERO)
	game.current.act("transmit")
	check(game.expedition.missions.moon.science_returned == 40, "Stage 4: lunar science returned by transmission")
	# Board and take off.
	place_rover(game, Destinations.get_def("moon").pad + Vector3(0, 0, 5))
	check(game.current.try_board(), "Stage 4: G boards at the pad")
	check(game.expedition.phase == "aboard" and game.ui.active == "aboard", "Stage 4: aboard screen")
	var fuel_on_pad: float = game.expedition.ship.fuel
	game.takeoff("mars")
	await frames(45)
	check(game.expedition.phase == "flight" and game.current.has_method("try_land"), "Stage 4: takeoff transition into space")
	check(game.expedition.ship.fuel < fuel_on_pad, "Stage 4: ascent burned fuel")
	# Fly to Mars on player-equivalent inputs and land.
	var used: int = await fly_to(game.current, "mars")
	check(used > 0, "Stage 4: flew to Mars")
	check(game.current.try_land(), "Stage 4: landing accepted")
	await frames(60)
	check(game.expedition.location == "mars" and game.expedition.phase == "surface", "Stage 4: landed and rover deployed on Mars")
	check(game.current.world.get_script() == load("res://spaceflight/mars_world.gd"), "Stage 4: Martian surface scene")
	for i in range(3): investigate(game, i)
	place_rover(game, Vector3.ZERO)
	game.current.act("transmit")
	check(game.expedition.missions.mars.science_returned == 60, "Stage 4: Mars scan data transmitted")
	place_rover(game, Destinations.get_def("mars").pad + Vector3(0, 0, 5))
	check(game.current.try_board(), "Stage 4: boards on Mars")
	check(game.expedition.cores.size() == 3, "Stage 4: three sealed sample cores aboard")
	game.takeoff("moon")
	await frames(45)
	check(game.expedition.phase == "flight", "Stage 4: lifted off from Mars")
	used = await fly_to(game.current, "moon")
	check(used > 0, "Stage 4: flew home")
	check(game.current.try_land(), "Stage 4: landing at the Moon base")
	await frames(60)
	check(game.expedition.delivered_science == 105, "Stage 4: cores delivered home")
	game.finish()
	await frames(2)
	check(game.ui.active == "report", "Stage 4: debrief shown")
	var report: Dictionary = load("res://simulation/expedition.gd").report(game.expedition)
	check(report.home and report.science_returned == 40 + 60 + 105, "Stage 4: debrief counts every returned unit (%d)" % report.science_returned)
	game.queue_free()
	await frames(2)
