extends SceneTree
const Scene = preload("res://scenes/spaceflight/campaign.tscn")
class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var mutex := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_notify: bool, _kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		mutex.lock()
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
		mutex.unlock()
	func _log_message(_message: String, _error: bool) -> void: pass
var failures: Array[String] = []
var checks: int = 0
var catcher := ErrorCatcher.new()
var captures: String = ""
func _initialize() -> void:
	OS.add_logger(catcher)
	if OS.get_cmdline_user_args().size() == 1: captures = OS.get_cmdline_user_args()[0]
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func frames(count: int = 3) -> void:
	for i in range(count): await physics_frame
func tap(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await frames()
func capture(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(captures)
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(name + ".png"))
func run() -> void:
	var game: Node = Scene.instantiate()
	root.add_child(game)
	await frames()
	var guide: Node = root.get_node("PlayerGuide")
	var audio: Node = root.get_node("Soundscape")
	await tap(KEY_F1)
	check(guide.is_open and paused and guide.tabs.current_tab == 0, "F1 opens the start guide and pauses gameplay")
	await capture("01-controls-start")
	for i in [1, 2, 3, 4, 5, 6]:
		guide.tabs.current_tab = i
		await capture("controls-tab-" + str(i))
	await tap(KEY_ESCAPE)
	check(not guide.is_open and not paused and game.ui.active == "planning", "Escape closes only the guide and restores the planning screen")
	game.start(game._config, game._fuel_load)
	await frames()
	var mission: Node = game.mission_control
	check(not mission.objective_panel.visible, "Objective announcement waits behind the introductory briefing")
	await tap(KEY_ENTER)
	await frames(30)
	var centre: Vector2 = mission.objective_panel.position + mission.objective_panel.size * mission.objective_panel.scale * 0.5
	check(mission.objective_announcing and mission.objective_panel.scale.x > 1.3 and centre.distance_to(Vector2(640, 360)) < 3, "New objective appears large at the screen centre")
	await capture("02-objective-centre")
	await tap(KEY_F1)
	check(guide.tabs.current_tab == 3, "Guide opens the flight controls when flying")
	var stopped_at: Vector2 = mission.objective_panel.position
	await frames(60)
	check(mission.objective_panel.position == stopped_at, "Guide pauses the objective animation")
	await tap(KEY_F8)
	check(not guide.is_open and audio.settings_open and paused, "Audio can replace the guide without unpausing the mission")
	await tap(KEY_F1)
	check(guide.is_open and not audio.settings_open and paused, "Guide can replace audio without breaking pause restoration")
	await tap(KEY_ESCAPE)
	await frames(210)
	check(not mission.objective_announcing and mission.objective_panel.position.is_equal_approx(mission.OBJECTIVE_TOP), "Objective moves to the top after the centre presentation")
	check(mission.objective_panel.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(mission.objective_panel.modulate.a, 1), "Pinned objective remains fully readable")
	await capture("03-objective-top")
	# Presentation fixtures only: verify repeated/rapid objective changes cannot restore stale text.
	game.set_physics_process(false) # Do not let the real campaign overwrite these synthetic UI-only titles.
	mission.show_objective({"id":"next-one", "header":"FIRST LIGHT / NEXT OBJECTIVE", "title":"Investigate the exposed formation", "distance":169})
	await frames(20)
	check(mission.objective_announcing and mission.objective_title.text.contains("169 m"), "Next objective repeats the centre announcement with its distance")
	mission.show_objective({"id":"latest", "header":"FIRST LIGHT / NEXT OBJECTIVE", "title":"Return the core to the Moon base", "distance":245})
	await frames(220)
	check(mission.objective_title.text.contains("245 m") and not mission.objective_announcing, "Latest objective survives interrupted animation and pins at the top")
	mission.block_objective(true)
	check(not mission.objective_panel.visible, "Blocking menus hide the objective panel")
	mission.block_objective(false)
	check(mission.objective_panel.visible, "Objective reminder returns after the overlay closes")
	game.queue_free()
	await frames()
	OS.remove_logger(catcher)
	failures.append_array(catcher.errors)
	for failure in failures: print("FAIL: ", failure)
	print("%s: controls guide and objective transitions (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
