extends SceneTree
const Scene = preload("res://scenes/spaceflight/campaign.tscn")
const Console = preload("res://scripts/field_console.gd")
class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_notify: bool, _kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
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
	var archive: Node = root.get_node("ScienceArchive")
	var guide: Node = root.get_node("PlayerGuide")
	var audio: Node = root.get_node("Soundscape")
	var before: Dictionary = game.expedition.duplicate(true)
	var config: Dictionary = game._config.duplicate(true)
	game.ui.start_button.grab_focus()
	await capture("01-mission-badge-and-science-entry")
	check(not archive.access.get_global_rect().intersects(guide.get_child(0).get_global_rect()), "Science and controls access buttons do not overlap")
	await tap(KEY_F2)
	check(archive.is_open and paused, "F2 opens science and pauses the game")
	check(archive.tabs.get_tab_count() == 5, "Offline science includes photos, elevation sources and project credits")
	var badge: TextureRect = archive.overlay.find_children("*", "TextureRect", true, false)[0]
	check(badge.size.x <= 66 and badge.size.y <= 66, "Archive badge stays within its header instead of covering text")
	for page in range(5):
		archive.tabs.current_tab = page
		await capture("science-page-" + str(page + 1))
		check(archive.tabs.get_current_tab_control().size.x <= 1200, "Science page fits the reference viewport")
	for page in archive.Catalog.PHOTO_PAGES:
		var image: Texture2D = load(page.image)
		check(image != null and image.get_width() >= 1000, "NASA reference image is bundled and loads offline")
	check(game.expedition == before and game._config == config, "Browsing sources cannot change mission resources or equipment")
	await tap(KEY_ESCAPE)
	check(not archive.is_open and not paused and game.ui.active == "planning", "Escape returns to planning without opening the mission menu")
	check(root.gui_get_focus_owner() == game.ui.start_button, "Closing science restores the previous keyboard focus")
	await tap(KEY_F1)
	await tap(KEY_F2)
	check(archive.is_open and not guide.is_open and paused, "Science replaces controls without stacking paused overlays")
	await tap(KEY_F8)
	check(not archive.is_open and audio.settings_open and paused, "Audio can replace science safely")
	await tap(KEY_F2)
	check(archive.is_open and not audio.settings_open and paused, "Science can replace audio safely")
	await tap(KEY_F1)
	check(guide.is_open and not archive.is_open and paused, "Controls can replace science safely")
	await tap(KEY_ESCAPE)
	check(not paused, "Closing the replacement guide restores the original running state")
	# A pre-existing pause belongs to the caller, not to the reference window.
	paused = true
	archive.open_archive(4)
	await tap(KEY_ESCAPE)
	check(paused and not archive.is_open, "Closing sources preserves a pre-existing pause")
	paused = false
	# This entry point starts the real introduction, with no campaign-state edits.
	game.ui.choice.emit("start", "")
	await frames()
	var film: Node = game.study_planner.film
	check(film.playing, "Actual campaign menu opens the introductory cinematic")
	await tap(KEY_F2)
	var clock: float = film.elapsed
	await frames(100)
	check(film.elapsed == clock and film.playing, "Reading science freezes a cinematic instead of skipping it")
	await tap(KEY_ESCAPE)
	check(film.playing and not archive.is_open and not paused, "Escape closes only science and resumes the same cinematic")
	# UI-only instrument fixture: source browsing must not operate a drill or commit an action.
	film.stop("skipped")
	var tool := Console.new()
	root.add_child(tool)
	tool.open("sample", {"name":"REFERENCE FIXTURE", "seed":42, "can_commit":false})
	archive.open_archive(1)
	var progress: Dictionary = tool.instrument.duplicate(true)
	await frames(90)
	check(tool.instrument == progress and not tool._committed, "Reading sources cannot advance or commit a field operation")
	await tap(KEY_ESCAPE)
	check(tool.is_open() and tool.stage == "operate", "Closing science preserves the underlying instrument screen")
	tool.close()
	tool.queue_free()
	game.queue_free()
	await frames()
	OS.remove_logger(catcher)
	failures.append_array(catcher.errors)
	for failure in failures: print("FAIL: ", failure)
	print("%s: NASA learning gallery (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
