extends SceneTree
## Codex integration check: drive and fly through the combined Moon/Mars scenes.
## No rover teleporting, battery refills, ship relocation or fuel edits in the fixture.
## Optional: -- --capture-dir /absolute/output/folder (run with graphics enabled).
const Autopilot = preload("res://spaceflight/autopilot.gd")
const Travel = preload("res://simulation/travel.gd")
const Expedition = preload("res://simulation/expedition.gd")

class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_notify: bool, _kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		errors.append("%s:%d %s %s" % [file, line, code, rationale])
	func _log_message(_message: String, _error: bool) -> void:
		pass

var failures: Array[String] = []
var game: Node
var capture_dir: String = ""
var catcher := ErrorCatcher.new()

func _initialize() -> void:
	OS.add_logger(catcher)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--capture-dir")
	if index >= 0 and index + 1 < args.size(): capture_dir = args[index + 1]
	_run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK,
		"Capture failed: " + name)

func drive_to(target: Vector3, tolerance: float = 4.5) -> bool:
	var surface: Node = game.current
	key(KEY_W, true)
	var reached: bool = false
	for i in range(1800):
		var here: Vector3 = surface.state.position
		var offset := Vector2(target.x - here.x, target.z - here.z)
		if offset.length() <= tolerance:
			reached = true
			break
		# Same camera yaw available through right-mouse look; movement remains real physics.
		surface.rover.yaw = atan2(-offset.x, -offset.y)
		await physics_frame
	key(KEY_W, false)
	await frames(20)
	check(reached, "Driving route blocked on %s: %s toward %s" % [surface.destination_id, surface.state.position, target])
	return reached

func fly_to(id: String) -> bool:
	var space: Node = game.current
	for i in range(6000):
		if Travel.guidance(space.ship, id).can_land:
			space.input_override = {}
			return true
		space.input_override = Autopilot.approach_input(space.ship, id)
		await physics_frame
	check(false, "Flight route did not reach " + id)
	return false

func wait_transition() -> void:
	for i in range(360):
		await physics_frame
		if not game.transition.playing: return
	check(false, "Transition did not finish")

func investigate() -> bool:
	var site: Dictionary = game.current.state.sites[1]
	if not await drive_to(site.position): return false
	key(KEY_E, true)
	key(KEY_E, false)
	await frames(2)
	key(KEY_Q, true)
	key(KEY_Q, false)
	await frames(2)
	check(game.current.state.sites[1].sampled, "Keyboard scan/sample failed on " + game.current.destination_id)
	key(KEY_T, true)
	key(KEY_T, false)
	await frames(2)
	return game.current.state.sites[1].sampled

func board_and_takeoff(id: String) -> bool:
	if not await drive_to(Vector3(0, 0, -6), 2.5): return false
	key(KEY_G, true)
	key(KEY_G, false)
	await frames(2)
	check(game.expedition.phase == "aboard", "Keyboard boarding failed")
	if game.expedition.phase != "aboard": return false
	game.ui.choice.emit("takeoff", id)
	await wait_transition()
	check(game.expedition.phase == "flight", "Takeoff failed")
	return game.expedition.phase == "flight"

func land() -> void:
	key(KEY_L, true)
	key(KEY_L, false)
	await wait_transition()
	check(game.expedition.phase == "landing", "L must start controlled final descent")
	key(KEY_T, true)
	key(KEY_T, false)
	for i in range(4000):
		if game.expedition.phase != "landing": break
		await physics_frame
	await wait_transition()
	await frames(45)
	check(game.expedition.phase == "surface", "Keyboard landing failed")

func check_finish_during_takeoff() -> void:
	game = load("res://scenes/spaceflight/expedition_demo.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	game.ui.choice.emit("start", "")
	await frames(90)
	if await drive_to(Vector3(0, 0, -6), 2.5):
		key(KEY_G, true)
		key(KEY_G, false)
		await frames(2)
		game.ui.choice.emit("takeoff", "mars")
		await frames(5)
		key(KEY_ESCAPE, true)
		key(KEY_ESCAPE, false)
		await frames(2)
		check(game.ui.active == "pause", "Expected pause menu during ascent fade")
		game.ui.choice.emit("finish", "")
		await wait_transition()
		await frames(10)
		check(game.expedition.phase == "complete", "Ending during ascent must remain complete")
		check(game.ui.active == "report", "Ending during ascent must retain the debrief")
		check(not game.current.has_method("try_land") or game.current.paused,
			"Takeoff continuation started unpaused flight behind a completed expedition's debrief")
	game.queue_free()
	await frames(2)

func _run() -> void:
	game = load("res://scenes/spaceflight/expedition_demo.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	await capture("01-planning")
	game.ui.choice.emit("start", "")
	await frames(90)
	await capture("02-moon")
	if await investigate():
		if await board_and_takeoff("mars"):
			await capture("03-flight")
			if await fly_to("mars"):
				await land()
				await capture("04-mars")
				if await investigate():
					if await board_and_takeoff("moon"):
						if await fly_to("moon"):
							await land()
							game.ui.choice.emit("finish", "")
							await frames(3)
							var report: Dictionary = Expedition.report(game.expedition)
							check(report.home, "Expedition did not end at home")
							check(report.science_returned == 95, "Expected 40 Moon + 20 Mars data + 35 delivered core science")
							check(game.expedition.delivered.size() == 1, "Sample core was not delivered exactly once")
							await capture("05-debrief")
	game.queue_free()
	await frames(2)
	await check_finish_during_takeoff()
	failures.append_array(catcher.errors)
	OS.remove_logger(catcher)
	for failure in failures: print("FAIL: ", failure)
	print("%s: driven Moon → Mars → home integration (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
