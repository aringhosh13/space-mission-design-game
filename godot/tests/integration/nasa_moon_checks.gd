extends SceneTree
## Integration invariants for measured terrain, atlas pause/picking and physical impact telemetry.
const LocalElevation = preload("res://data/terrain/lola_south_pole.tres")
const GlobalElevation = preload("res://data/terrain/lola_global.tres")
const GameScene = preload("res://scenes/main.tscn")
const Rover = preload("res://scripts/rover.gd")
class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_notify: bool, _kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		errors.append("%s:%d %s %s" % [file, line, code, rationale])
	func _log_message(_message: String, _error: bool) -> void:
		pass
var failures: Array[String] = []
var catcher := ErrorCatcher.new()

func _initialize() -> void:
	OS.add_logger(catcher)
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func _run() -> void:
	check(GlobalElevation.elevations.size() == 720 * 360, "Global map must contain a complete measured grid")
	check(LocalElevation.elevations.size() == 257 * 257, "Polar patch must contain a complete measured grid")
	var low: float = INF
	var high: float = -INF
	for value in GlobalElevation.elevations:
		low = minf(low, value)
		high = maxf(high, value)
	check(low < -8000 and high > 9000,
		"Reference-sphere elevation conversion must preserve positive and negative relief in metres")
	check(absf(GlobalElevation.elevation_at(10, -0.001) - GlobalElevation.elevation_at(10, 359.999)) < 0.1,
		"Longitude wrapping must agree across the atlas seam")
	check(is_finite(GlobalElevation.elevation_at(90, 720)), "Polar/wrapped atlas sampling must be finite")
	var game: Node3D = GameScene.instantiate()
	root.add_child(game)
	await frames(60)
	check(game.world.terrain_half_extent >= 480, "Rendered Moon region must extend well beyond the old arena")
	var input: Array = [{"id": "ridge", "title": "Survey ridge", "position": Vector3(25, 0, -20), "active": true, "completed": false}]
	var untouched: Array = input.duplicate(true)
	game.world.update_checkpoints(input)
	check(input == untouched and game.world.checkpoint_nodes.size() == 1, "Waypoint visuals must not mutate campaign state")
	game.world.update_checkpoints([])
	check(game.world.checkpoint_nodes.is_empty(), "Removed waypoints must leave no stale markers")
	game._on_action("launch")
	var battery: float = game.state.energy
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.physical_keycode = KEY_M
	key.pressed = true
	Input.parse_input_event(key)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await frames(5)
	check(game.atlas.is_open() and game.paused and not game.rover.driving, "Atlas must pause driving")
	check(game.state.energy == battery, "Atlas must not consume rover power")
	game.atlas._pick(Vector2(640, 360))
	check(game.atlas.selection.text.contains("LOLA elevation"), "Atlas picking must expose elevation provenance")
	var mesh: MeshInstance3D = game.atlas.globe.get_child(0)
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	check(normals[100].dot(vertices[100]) > 0, "Globe normals must point outward")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--capture" and DisplayServer.get_name() != "headless":
		for i in range(8): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(args[1]) == OK, "Atlas preview must save")
	game.atlas.close_requested.emit()
	await frames(2)
	check(not game.atlas.is_open() and not game.paused and game.rover.driving, "Closing atlas must restore driving")
	game.paused = true
	game._sync()
	game._toggle_atlas()
	game.atlas.close_requested.emit()
	check(game.paused and not game.rover.driving, "Closing atlas must preserve a pre-existing pause")
	game.queue_free()
	await frames(2)
	await _check_impact()
	failures.append_array(catcher.errors)
	OS.remove_logger(catcher)
	for failure in failures: print("FAIL: ", failure)
	print("%s: NASA Moon terrain / atlas / impact checks (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check_impact() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(5000, -0.5, 5000)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 1, 100)
	collision.shape = shape
	floor_body.add_child(collision)
	root.add_child(floor_body)
	var rover: CharacterBody3D = Rover.new()
	rover.position = Vector3(5000, 12, 5000)
	rover.driving = true
	var hits: Array[float] = []
	rover.impact_reported.connect(func(speed: float) -> void: hits.append(speed))
	root.add_child(rover)
	await frames(180)
	check(rover.is_on_floor() and hits.size() == 1 and hits[0] >= 5, "A real hard landing must report exactly one impact")
	await frames(120)
	check(hits.size() == 1, "Resting on terrain must not cause repeated impact events")
	check(rover.integrity == 100, "Physical telemetry must not invent authoritative damage")
	rover.set_condition(35)
	check(is_equal_approx(rover.condition_speed_factor, 0.8), "Damage must never reduce mobility by more than 20%")
	rover.set_condition(100)
	check(is_equal_approx(rover.condition_speed_factor, 1), "Repair must restore normal mobility")
	rover.queue_free()
	floor_body.queue_free()
	await frames(2)
