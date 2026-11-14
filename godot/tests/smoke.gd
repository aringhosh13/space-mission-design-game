extends SceneTree
## Native integration checks. These do not replace the future engine-port test suite.
const GameScene = preload("res://scenes/main.tscn")
const MissionAdapter = preload("res://simulation/mission_engine.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var engine = MissionAdapter.new()
	var config: Dictionary = {"battery": "compact", "power": "solar", "instrument": "drill"}
	var planned: Dictionary = engine.create_mission(config, 42)
	var launched: Dictionary = engine.act(planned, "launch")
	check(planned.phase == "planning" and launched.phase == "surface", "Launch must not mutate its input.")
	var station: Dictionary = engine.act(launched, "deploy")
	var moved: Dictionary = engine.move_rover(station, Vector3(1, 0, 0))
	check(moved.outpost_position == Vector3.ZERO, "Station must remain at its deployment position.")
	check(is_equal_approx(station.energy - moved.energy, 0.16), "Movement must charge distance, not frames.")
	var at_site: Dictionary = launched.duplicate(true)
	at_site.position = at_site.sites[1].position
	var scanned: Dictionary = engine.act(at_site, "scan")
	var duplicate: Dictionary = engine.act(scanned, "scan")
	check(scanned.science_collected == duplicate.science_collected, "Repeated scans must not duplicate science.")
	var sampled: Dictionary = engine.act(scanned, "sample")
	var returned: Dictionary = engine.act(sampled, "transmit")
	check(returned.science_returned == 40, "Scan/sample/transmit must return 40 science.")
	var finished: Dictionary = engine.act(returned, "finish")
	check(engine.act(finished, "scan") == finished, "Completed missions must reject further operations.")
	var game = GameScene.instantiate()
	root.add_child(game)
	for i in range(90): await physics_frame
	check(game.rover.is_on_floor(), "Rover must settle on the terrain collision surface.")
	check(game.rover.position.y > -10.0, "Rover must not fall through the lunar surface.")
	check(game.world.get_landing_anchor() != null, "Moon must expose its landing anchor for spaceflight integration.")
	check(game.world.marker_nodes.size() == game.state.sites.size(), "Every engine site must have a Moon survey marker.")
	check(game.world.presentation_for(Vector3(-25, 0, 0)).exposure == "SHADOW", "Western basin display must match the agreed shadow zone.")
	check(game.world.presentation_for(Vector3(25, 0, -20)).region == "SUNLIT SURVEY RIDGE", "Eastern survey ridge must be recognizable.")
	var center_height: float = game.world.terrain_height(-35, -36)
	var rim_height: float = game.world.terrain_height(-22, -36)
	check(center_height < rim_height, "Primary crater must have a depressed floor below its rim.")
	game._on_action("launch")
	var initial_position: Vector3 = game.rover.global_position
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	for i in range(120): await physics_frame
	key = InputEventKey.new()
	key.keycode = KEY_W
	key.physical_keycode = KEY_W
	key.pressed = false
	Input.parse_input_event(key)
	check(game.rover.global_position.distance_to(initial_position) > 1.0, "W must physically drive the rover.")
	check(game.state.energy < game.state.max_energy, "Driving must consume mission power.")
	check(game.world.track_count > 0 and game.world.track_count <= 1024, "Driving must leave a bounded set of rover tracks.")
	# The headless dummy renderer does not retain MultiMesh instance transforms.
	if DisplayServer.get_name() != "headless":
		var track: Transform3D = game.world.track_mesh.multimesh.get_instance_transform(0)
		check(absf(track.origin.y - game.world.terrain_height(track.origin.x, track.origin.z) - 0.035) < 0.01, "Rover tracks must follow the ground height.")
	game.paused = true
	game._sync()
	var paused_position: Vector3 = game.rover.global_position
	var paused_energy: float = game.state.energy
	for i in range(30): await physics_frame
	check(Vector2(game.rover.position.x - paused_position.x, game.rover.position.z - paused_position.z).length() < 0.001, "Pause must stop horizontal drift immediately.")
	check(is_equal_approx(game.state.energy, paused_energy), "Pause must not consume movement power.")
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--capture" and DisplayServer.get_name() != "headless":
		# Render an isolated scene fixture for visual QA; this captures no other desktop windows.
		game.state = engine.act(engine.create_mission(config, 42), "launch")
		game.state.position = Vector3(0, game.world.terrain_height(0, 0) + 0.1, 0)
		game.rover.global_position = game.state.position
		game.rover.yaw = 0.65
		game.rover.pitch = 0.29
		game.rover.camera_distance = 15.0
		game._sync()
		for i in range(80): await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = game.get_viewport().get_texture().get_image()
		check(image.save_png(arguments[1]) == OK, "Scene preview must be written successfully.")
	game.queue_free()
	await process_frame
	if failures.is_empty(): print("PASS: native mission and physics integration checks")
	else: print("FAIL: ", failures)
	quit(0 if failures.is_empty() else 1)
