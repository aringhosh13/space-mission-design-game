extends SceneTree
## Driven "First Light" campaign route: Moon → Mars → home through the real campaign scene.
##   godot --headless --fixed-fps 60 --path godot --script res://tests/spaceflight/campaign_route.gd
## The fixture never edits rover position, energy, ship position or fuel. The rover drives through real
## physics with held keys (camera yaw set as right-mouse look would); actions use the E/Q/R/T/B/G keys;
## flights and descents use player-equivalent inputs (autopilot/human pilot through input_override, the
## same channel Codex's driven check uses); menus go through the UI's own choices. Godot runtime errors
## fail the run. Adapted from Codex's tests/integration/expedition_smoke.gd for the new manual descent.
const Autopilot = preload("res://spaceflight/autopilot.gd")
const Travel = preload("res://simulation/travel.gd")
const Expedition = preload("res://simulation/expedition.gd")
const Campaign = preload("res://simulation/campaign.gd")
const Destinations = preload("res://simulation/destinations.gd")
const Landing = preload("res://simulation/landing.gd")

class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var mutex := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_notify: bool, _kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		mutex.lock()
		errors.append("%s:%d in %s(): %s %s" % [file, line, function, code, rationale])
		mutex.unlock()
	func _log_message(_message: String, _error: bool) -> void:
		pass

var failures: Array[String] = []
var checks: int = 0
var game: Node
var catcher := ErrorCatcher.new()
var capture_dir: String = ""

func _initialize() -> void:
	OS.add_logger(catcher)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--capture-dir")
	if index >= 0 and index + 1 < args.size(): capture_dir = args[index + 1]
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key(code, true)
	key(code, false)
	await frames(3)

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))

func mission() -> Dictionary:
	return game.current.state

## Hold W toward a target with the camera yaw a player would set; side-step if stuck, as a player would.
func drive_to(target: Vector3, tolerance: float = 4.5) -> bool:
	var surface: Node = game.current
	var reached: bool = false
	var last: Vector3 = mission().position
	var stuck_frames: int = 0
	var detour: int = 0
	key(KEY_W, true)
	for i in range(5400):
		var here: Vector3 = mission().position
		var offset := Vector2(target.x - here.x, target.z - here.z)
		if offset.length() <= tolerance:
			reached = true
			break
		var heading: float = atan2(-offset.x, -offset.y)
		if detour > 0:
			detour -= 1
			heading += 1.2
		surface.rover.yaw = heading
		await physics_frame
		if i % 45 == 44:
			if Vector2(here.x - last.x, here.z - last.z).length() < 1.0:
				stuck_frames += 1
				detour = 50
			last = here
		if float(mission().energy) <= 0.05: break
	key(KEY_W, false)
	await frames(15)
	check(reached, "Drive blocked on %s at %s toward %s (energy %.1f)" % [surface.destination_id, mission().position, target, float(mission().energy)])
	return reached

## Press R until the battery is at least `fraction` full (or recharging stops helping).
func top_up(fraction: float) -> void:
	for i in range(12):
		if float(mission().energy) >= float(mission().max_energy) * fraction: return
		var before: float = float(mission().energy)
		await tap(KEY_R)
		if float(mission().energy) <= before + 0.01: return

func fly_to(id: String) -> bool:
	for i in range(8000):
		if Travel.guidance(game.current.ship, id).can_land:
			game.current.input_override = {}
			return true
		game.current.input_override = Autopilot.approach_input(game.current.ship, id)
		await physics_frame
	check(false, "Flight did not reach " + id)
	return false

## L, then fly the final descent with on/off thrust and tapped side thrusters (no assist).
func manual_landing() -> bool:
	await tap(KEY_L)
	for i in range(150):
		if game.current != null and game.current.has_method("read_input"): break
		await physics_frame
	if game.current == null or not game.current.has_method("read_input"):
		check(false, "Descent scene did not appear")
		return false
	await capture("descent-" + str(game.expedition.landing.destination))
	for i in range(5000):
		if game.expedition.phase != "landing": break
		var l: Dictionary = game.expedition.landing
		if l.status == "failed":
			await tap(KEY_R)
			continue
		game.current.input_override = _pilot(l)
		await physics_frame
	await frames(160)
	check(game.expedition.phase == "surface", "Manual landing did not reach the surface")
	return game.expedition.phase == "surface"

func _pilot(l: Dictionary) -> Dictionary:
	var id: String = str(l.destination)
	var margin: float = 4.0 if float(l.altitude) > 30.0 else 1.6
	var stop_distance: float = pow(float(l.vertical_speed), 2) / (2.0 * (Landing.max_accel(id) - Landing.gravity(id)))
	var thrust: float = 1.0 if (stop_distance + margin >= float(l.altitude) or float(l.vertical_speed) < -6.0) else 0.0
	if float(l.vertical_speed) > -0.6: thrust = 0.0
	var offset: Vector2 = l.offset
	var velocity: Vector2 = l.lateral_velocity
	var tap_axis := func(v: float) -> float: return 0.0 if absf(v) < 0.4 else signf(v)
	return {"throttle": thrust, "x": tap_axis.call(-offset.x * 0.3 - velocity.x), "z": tap_axis.call(-offset.y * 0.3 - velocity.y)}

func site_position(kind: String) -> Vector3:
	for site in mission().sites:
		if site.kind == kind: return site.position
	return Vector3.ZERO

func objective() -> String:
	return str(game.expedition.campaign.objective)

func board_and_takeoff(target: String) -> bool:
	if not await drive_to(Destinations.get_def(game.expedition.location).pad + Vector3(0, 0, 5), 3.0): return false
	await tap(KEY_G)
	check(game.expedition.phase == "aboard", "Boarding with G failed on " + str(game.expedition.location))
	if game.expedition.phase != "aboard": return false
	game.ui.choice.emit("takeoff", target)
	for i in range(240):
		await physics_frame
		if game.current.has_method("try_land") and not game.transition.playing: break
	check(game.expedition.phase == "flight", "Takeoff for %s failed" % target)
	return game.expedition.phase == "flight"

func _run() -> void:
	game = load("res://scenes/spaceflight/campaign.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	# Cinematic/menu onboarding is covered separately; this fixture drives the actual full field mission.
	game.start(game._config, game._fuel_load)
	await frames(10)
	check(game.mission_control.briefing_open, "Briefing shown at the start")
	await capture("01-briefing")
	await tap(KEY_ENTER)
	check(not game.mission_control.briefing_open, "Enter skips the briefing")
	check(objective() == "moon-landing", "First objective is the Moon landing")
	# --- Moon chapter
	if await manual_landing():
		check("moon-landing" in game.expedition.campaign.completed, "Moon landing objective")
		await top_up(1.0)
		await drive_to(Destinations.surface_rules("moon").waypoints.ridge, 6.0)
		await frames(10)
		check("moon-ridge" in game.expedition.campaign.completed, "Survey ridge reached")
		await capture("02-moon-ridge")
		await top_up(1.0)
		await drive_to(site_position("ice"))
		await tap(KEY_E)
		check("moon-ice" in game.expedition.campaign.completed, "Ice signal investigated")
		await drive_to(Vector3(-10, 0, 10))
		await top_up(1.0)
		await drive_to(site_position("geology"))
		await tap(KEY_E)
		check("moon-geology" in game.expedition.campaign.completed, "Geology signal investigated")
		await top_up(0.9)
		await drive_to(Destinations.surface_rules("moon").waypoints.station)
		await tap(KEY_B)
		check("moon-station" in game.expedition.campaign.completed, "Research station established")
		if await board_and_takeoff("mars"):
			check("moon-return" in game.expedition.campaign.completed, "Evidence returned to the ship")
			# --- Mars chapter
			if await fly_to("mars") and await manual_landing():
				check("mars-landing" in game.expedition.campaign.completed, "Mars landing objective")
				await drive_to(site_position("geology"))
				await tap(KEY_E)
				await tap(KEY_Q)
				check("mars-layers" in game.expedition.campaign.completed, "Layered rock scanned")
				check("mars-core" in game.expedition.campaign.completed, "Core collected")
				check(objective() == "mars-storm", "Storm objective active")
				await drive_to(Destinations.surface_rules("mars").shelter.position, 4.0)
				await capture("03-mars-shelter")
				for i in range(80 * 60):
					if "mars-storm" in game.expedition.campaign.completed: break
					if i % 240 == 0: await tap(KEY_R)
					await physics_frame
				check("mars-storm" in game.expedition.campaign.completed, "Dust storm ridden out within 80 s")
				await top_up(0.8)
				if await board_and_takeoff("moon"):
					check(game.expedition.cores.size() == 1, "One sealed core aboard")
					# --- Home
					if await fly_to("moon") and await manual_landing():
						check("mars-return" in game.expedition.campaign.completed, "Core delivered home")
						await tap(KEY_ESCAPE)
						check(game.ui.active == "pause", "Escape opens the pause menu")
						game.ui.choice.emit("finish", "")
						await frames(5)
						await capture("04-debrief")
						check(Campaign.is_complete(game.expedition), "Campaign complete: %s" % str(game.expedition.campaign.completed))
						var report: Dictionary = Expedition.report(game.expedition)
						check(report.home and report.delivered_science == 35, "One Mars core (35 science) delivered at home")
						check(report.science_returned == 30 + 20 + 35, "Returned science: 30 Moon + 20 Mars data + 35 core (got %d)" % report.science_returned)
						check(game.ui.active == "report", "Debrief shown")
						check(game.debrief_film.playing and game.debrief_film.heading.text == "EVIDENCE RETURNED", "Completed campaign gets its closing cinematic")
						check(game.debrief_film.caption.text.contains("12 of 12 objectives") and game.debrief_film.caption.text.contains("%d science returned" % report.science_returned), "Closing cinematic uses actual completed objectives and returned science")
						game.debrief_film.elapsed = 18.0
						game.debrief_film._process(0)
						check(not game.debrief_film.playing and game.ui.active == "report", "Closing cinematic naturally completes into the report")
						check(Expedition.report(game.expedition) == report, "Closing presentation cannot change mission results")
	game.queue_free()
	await frames(2)
	OS.remove_logger(catcher)
	for error in catcher.errors: failures.append("Runtime error: " + error)
	for failure in failures: print("FAIL: ", failure)
	print("%s: driven First Light campaign route (%d checks, %d failures, %d runtime errors)" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size(), catcher.errors.size()])
	quit(0 if failures.is_empty() else 1)
