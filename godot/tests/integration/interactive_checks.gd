extends SceneTree
const Surface = preload("res://spaceflight/surface_scene.gd")
const MissionEngine = preload("res://simulation/mission_engine.gd")
const Instrument = preload("res://simulation/field_instrument.gd")
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
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func tap(code: Key) -> void:
	key(code, true)
	await process_frame
	key(code, false)
	await process_frame
	await frames()
func capture(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(captures)
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(name + ".png"))
func operate(tool: Node) -> void:
	for i in range(750):
		if tool.stage == "result": break
		if tool.mode == "scan":
			var error: float = tool.slider.value / 100 - float(tool.instrument.target)
			key(KEY_LEFT, error > 0.015)
			key(KEY_RIGHT, error < -0.015)
		key(KEY_SPACE, true)
		await physics_frame
	key(KEY_SPACE, false)
	key(KEY_LEFT, false)
	key(KEY_RIGHT, false)
	await frames()
func run() -> void:
	var drill: Dictionary = Instrument.create("sample", 42)
	var original: Dictionary = drill.duplicate(true)
	for i in range(200): drill = Instrument.step(drill, {"hold":true, "value":100}, 0.05)
	check(drill.progress == 0 and drill.heat <= 100, "Excessive feed cannot collect a core or produce invalid heat")
	check(original == Instrument.create("sample", 42), "Instrument transitions are immutable")
	for i in range(80): drill = Instrument.step(drill, {"hold":false}, 0.05)
	check(not drill.cooling and drill.heat < 45, "Releasing the drill recovers from heat without resource penalties")
	var scan: Dictionary = Instrument.create("scan", 13)
	for i in range(200): scan = Instrument.step(scan, {"hold":true, "value":1.0}, 0.05)
	check(scan.progress == 0, "Off-peak holding cannot acquire a signal")
	var engine = MissionEngine.new()
	var state: Dictionary = engine.act(engine.create_surface_mission({"battery":"compact", "power":"solar", "instrument":"drill"}, 42, "moon"), "launch")
	state.position = state.sites[0].position # Fixture placement only; full campaign driver never teleports.
	var surface: Node = Surface.new()
	surface.setup("moon", state)
	root.add_child(surface)
	await frames(5)
	var science: int = surface.state.science_collected
	var energy: float = surface.state.energy
	surface.request_action("scan")
	var tool: Node = surface.operation
	check(surface.paused and tool.is_open(), "Scan opens a hands-on tool and holds the rover")
	check(surface.state.science_collected == science and surface.state.energy == energy, "Opening a tool cannot award science or spend energy")
	tool.confirm()
	check(surface.state.science_collected == science, "Premature confirmation cannot bypass signal lock")
	await capture("01-scanner")
	await tap(KEY_ESCAPE)
	check(not tool.is_open() and not surface.paused and surface.state.energy == energy, "Cancelling restores driving with no scan charge")
	surface.request_action("scan")
	energy = surface.state.energy
	await operate(tool)
	check(tool.stage == "result" and surface.state.sites[0].scanned, "Manual tuning and holding commits a scan")
	check(is_equal_approx(surface.state.energy, energy - 4) and surface.state.science_collected == science + 15, "Scan charges/rewards exactly once through the existing engine")
	await capture("02-scan-result")
	tool.confirm() # Continue button, not another scan.
	check(surface.state.science_collected == science + 15, "Continuing the result cannot duplicate science")
	surface.request_action("sample")
	energy = surface.state.energy
	await tap(KEY_ESCAPE)
	check(surface.state.energy == energy and not surface.state.sites[0].sampled, "Cancelling a sample cannot spend power or create a core")
	surface.request_action("sample")
	await capture("03-drill")
	await operate(tool)
	check(tool.stage == "result" and surface.state.sites[0].sampled, "Manual feed control completes a sample")
	check(is_equal_approx(surface.state.energy, energy - 8) and surface.state.science_collected == science + 40, "Sampling uses the existing cost and reward once")
	await tap(KEY_ENTER)
	var recovered: Dictionary = surface.state.duplicate(true)
	recovered.position = recovered.sites[1].position
	surface.apply_state(recovered)
	surface.request_action("scan")
	energy = surface.state.energy
	surface.apply_state(surface.state) # Checkpoint restore while a tool is open.
	tool.confirm()
	check(not tool.is_open() and surface.state.energy == energy and not surface.state.sites[1].scanned, "Recovery cancels pending tools; stale confirmation cannot award science")
	surface.request_action("scan")
	await tap(KEY_A)
	check(tool.assisted, "Player can enable instrument assist")
	var audio_settings: Node = root.get_node("Soundscape")
	await tap(KEY_F8)
	var stopped_progress: float = tool.instrument.progress
	await frames(30)
	check(tool.instrument.progress == stopped_progress and audio_settings.settings_open, "Audio settings freeze an active instrument, without silently completing it")
	await tap(KEY_ESCAPE)
	tool.primary.button_down.emit()
	await operate(tool)
	check(tool.stage == "result" and surface.state.sites[1].scanned, "Assist completes the same valid scan, without bypassing the mission engine")
	tool.primary.button_up.emit()
	tool.primary.pressed.emit()
	check(tool.is_open() and tool.stage == "result", "Releasing a held operation button keeps the result explanation visible")
	tool.primary.pressed.emit()
	check(not tool.is_open() and not surface.paused, "Continue button returns to driving")
	var elsewhere: Dictionary = surface.state.duplicate(true)
	elsewhere.position = Vector3(-40, 0, 0)
	surface.apply_state(elsewhere)
	surface.request_action("deploy")
	check(tool.is_open() and tool.primary.disabled, "Shadow deployment explains the problem and disables committing")
	await capture("04-shadow-site")
	await tap(KEY_ENTER)
	check(not surface.state.outpost_deployed, "Keyboard cannot bypass the sunlight requirement")
	await tap(KEY_ESCAPE)
	elsewhere = surface.state.duplicate(true)
	elsewhere.position = Vector3(20, 0, 16)
	surface.apply_state(elsewhere)
	surface.request_action("deploy")
	await capture("05-station-decision")
	await tap(KEY_ENTER)
	check(surface.state.outpost_deployed and tool.stage == "result", "Player commits station deployment after reviewing the return budget")
	await tap(KEY_ESCAPE)
	var audio: Node = root.get_node("Soundscape")
	var old_mute: bool = audio.muted
	var old_music: float = audio.music_volume
	var old_effects: float = audio.effects_volume
	check(audio.music_player.playing and audio.music_player.stream.get_length() > 40, "Original background score is loaded and looping")
	audio.muted = true
	audio.apply_levels()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("HorizonMusic")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("HorizonFeedback")), "Mute covers score, loops and one-shots")
	audio.muted = old_mute
	audio.music_volume = old_music
	audio.effects_volume = old_effects
	audio.apply_levels()
	audio.update_context("surface", "moon", false, 5, 0, true)
	check(audio.loops.mars_wind.volume_db <= -79, "No atmospheric wind sound plays on the Moon")
	audio.update_context("surface", "mars", false, 5, 0, true)
	check(audio.loops.mars_wind.volume_db > -10 and audio.loops.rover.volume_db > -20, "Mars storm and rover motion drive their feedback loops")
	await tap(KEY_F8)
	check(audio.settings_open and paused, "Audio settings pause the scene tree")
	await capture("06-audio-settings")
	await tap(KEY_ESCAPE)
	check(not audio.settings_open and not paused, "Closing audio settings restores the prior pause state")
	surface.queue_free()
	await frames()
	audio.shutdown()
	OS.delay_msec(120) # Allow the audio mixing thread to release playback references before a fast test exit.
	await frames()
	OS.remove_logger(catcher)
	failures.append_array(catcher.errors)
	for failure in failures: print("FAIL: ", failure)
	print("%s: interactive instruments, decisions and audio (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
