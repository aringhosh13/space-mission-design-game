extends SceneTree
## Cinematic onboarding, validation gate, cancellation and truthful result presentation.
const Scene = preload("res://scenes/spaceflight/campaign.tscn")
class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var mutex := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_notify: bool, _kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		mutex.lock()
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
		mutex.unlock()
	func _log_message(_message: String, _error: bool) -> void:
		pass
var failures: Array[String] = []
var catcher := ErrorCatcher.new()
var capture_dir: String = ""

func _initialize() -> void:
	OS.add_logger(catcher)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 1: capture_dir = args[0]
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Capture failed")

func skip() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await frames(2)

func _run() -> void:
	var cancelled: Node = Scene.instantiate()
	root.add_child(cancelled)
	await frames(3)
	cancelled.ui.choice.emit("start", "")
	check(cancelled.study_planner.film.playing, "Start must introduce the problem with a cinematic")
	cancelled.study_planner.close_requested.emit()
	await frames(3)
	check(cancelled.expedition.is_empty(), "Cancelling onboarding must not launch a mission")
	check(not cancelled.study_planner.film.playing, "Closing planner cancels its cinematic")
	cancelled.queue_free()
	await frames(2)
	var game: Node = Scene.instantiate()
	root.add_child(game)
	await frames(3)
	game.ui.choice.emit("start", "")
	var lab: Node = game.study_planner
	var film: Node = lab.film
	var position: Vector3 = film.camera.position
	await frames(30)
	check(film.camera.position.distance_to(position) > 0.1, "Cinematic must animate a real 3D camera")
	check(game.expedition.is_empty(), "Briefing must not spend mission resources")
	await capture("01-problem")
	await skip()
	check(not film.playing and lab.is_open(), "Skipping briefing hands control to the planner")
	lab.battery.value = 100
	check(not lab.selected.feasible and lab.present_button.disabled, "Infeasible candidate cannot be presented")
	lab.present_solution()
	check(not film.playing and game.expedition.is_empty(), "Infeasible plan cannot trigger success or launch")
	lab.battery.value = 10000
	check(lab.selected.feasible, "Default candidate can pass the stated model")
	var expected_energy: float = lab.selected.energy_wh
	lab.present_button.grab_focus()
	lab.present_solution()
	check(film.playing and film.kind == "solution", "Presenting a valid candidate starts its explanation")
	film.elapsed = 6.1
	film._process(0)
	check(film.caption.text.contains("%.0f Wh" % expected_energy), "Explanation must use the selected plan's actual energy")
	await capture("02-solution")
	check(game.expedition.is_empty(), "Presentation must finish before field mission starts")
	await skip()
	check(game.expedition.get("phase", "") == "flight", "Finished plan presentation starts the field expedition")
	check(not lab.is_open() and not game.mission_control.briefing_open, "No duplicate briefing or planner overlay after handoff")
	game.finish()
	check(game.debrief_film.playing and game.debrief_film.kind == "debrief", "Ending campaign opens results cinematic")
	check(game.debrief_film.heading.text == "THE EXPEDITION'S RESULTS", "Incomplete mission must not claim successful completion")
	await capture("03-incomplete-results")
	await skip()
	check(not game.debrief_film.playing, "Keyboard skips the closing cinematic even immediately after opening it")
	check(game.ui.active == "report" and game.expedition.phase == "complete", "Skipping results reveals the report and keeps mission complete")
	game.finish()
	check(not game.debrief_film.playing, "Repeated finish must not replay the cinematic")
	game.queue_free()
	await frames(3)
	OS.remove_logger(catcher)
	failures.append_array(catcher.errors)
	for failure in failures: print("FAIL: ", failure)
	print("%s: cinematic camera, gating, cancellation, handoff and truthful debrief (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
