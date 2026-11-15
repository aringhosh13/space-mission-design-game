extends SceneTree
## Spaceflight scene checks (headless). Drives the real scenes with injected inputs, frame by frame.
##   godot --headless --path godot --script res://tests/spaceflight/scene_checks.gd
## Pure simulation rules are covered by tests/simulation; this checks scenes are wired to them.
## Any Godot runtime error (script errors, engine error macros) raised while the checks run is captured
## through a Logger and fails the run.
## Note: the stage 4 loop places the rover at sites and refills its battery to test scene wiring quickly;
## flight legs use player-equivalent inputs. tests/integration/expedition_smoke.gd (Codex) is the fully
## driven route with no state edits.
const Ship = preload("res://simulation/ship_flight.gd")

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
var catcher := ErrorCatcher.new()

func _initialize() -> void:
	OS.add_logger(catcher)
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func _run() -> void:
	await stage_1_ship()
	for extra in ["stage_2_space_travel", "marker_on_camera_plane", "stage_3_mars_surface",
			"stage_4_expedition_loop", "finish_during_takeoff", "pause_during_takeoff", "finish_during_descent",
			"landing_scene_controls", "surface_hazards_and_storm_visuals", "campaign_recovery_from_menu"]:
		if has_method(extra): await call(extra)
	OS.remove_logger(catcher)
	for error in catcher.errors: failures.append("Runtime error: " + error)
	for failure in failures: print("FAIL: ", failure)
	print("%s: spaceflight scene checks (%d checks, %d failures, %d runtime errors)" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size(), catcher.errors.size()])
	quit(0 if failures.is_empty() else 1)

## Regression (INTEGRATION_REVIEW #2): targets on, beside or behind the camera plane must not be projected.
func marker_on_camera_plane() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.current = true
	var hud: CanvasLayer = load("res://spaceflight/flight_hud.gd").new()
	holder.add_child(hud)
	await frames(2)
	var before: int = catcher.errors.size()
	var centre: Vector2 = hud.root.get_viewport_rect().size * 0.5
	hud.place_marker(camera, Vector3(25, 0, 0), "BESIDE  25 u")       # exactly on the camera plane, to the right
	check(hud.marker.visible and hud.marker.position.x + 110.0 > centre.x + 100.0, "Marker: on-plane target sits on the right edge")
	hud.place_marker(camera, Vector3(0, 0, 0), "AT CAMERA  0 u")      # at the camera position
	check(hud.marker.visible, "Marker: target at the camera position handled")
	hud.place_marker(camera, Vector3(0, -3, 40), "BEHIND  40 u")      # behind and below
	check(hud.marker.position.y + 10.0 > centre.y + 100.0, "Marker: behind-and-below target points down")
	hud.place_marker(camera, Vector3(0, 0, -50), "AHEAD  50 u")       # in front
	check(hud.marker.text.begins_with("◇"), "Marker: target ahead is projected on screen")
	hud.place_marker(camera, Vector3(NAN, 0, 0), "BAD")
	check(not hud.marker.visible, "Marker: non-finite target hidden")
	check(catcher.errors.size() == before, "Marker: no projection errors (%d new)" % (catcher.errors.size() - before))
	holder.queue_free()
	await frames(2)

## Regression (INTEGRATION_REVIEW #1): ending the expedition during the takeoff fade must cancel the
## continuation; no flight scene may start behind the debrief.
func finish_during_takeoff() -> void:
	var Destinations = load("res://simulation/destinations.gd")
	var game: Node = load("res://scenes/spaceflight/expedition_demo.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	game.start({"battery": "compact", "power": "solar", "instrument": "drill"}, "standard")
	await frames(20)
	place_rover(game, Destinations.get_def("moon").pad + Vector3(0, 0, 5))
	game.current.try_board()
	var ship_before: Dictionary = game.expedition.ship.duplicate(true)
	game.takeoff("mars")
	await frames(5)
	game.current.menu_requested.emit()          # Escape on the (paused) surface during the fade
	check(game.ui.active == "pause", "Finish during takeoff: pause menu available during the fade")
	game.ui.choice.emit("finish", "")
	check(not game.transition.playing, "Finish during takeoff: transition cancelled at once")
	await frames(90)
	check(game.expedition.phase == "complete" and game.ui.active == "report", "Finish during takeoff: debrief kept")
	check(not game.current.has_method("try_land"), "Finish during takeoff: no flight scene installed")
	var ship_after: Dictionary = game.expedition.ship.duplicate(true)
	await frames(30)
	check(game.expedition.ship == ship_after, "Finish during takeoff: nothing changes the completed expedition")
	check(float(ship_after.fuel) < float(ship_before.fuel), "Finish during takeoff: the ascent burn already paid is reported")
	game.queue_free()
	await frames(2)

## Pause during the takeoff fade: resume before the cover hands over to an unpaused flight scene;
## a menu still open at the cover installs the flight scene paused until resumed.
func pause_during_takeoff() -> void:
	var Destinations = load("res://simulation/destinations.gd")
	for hold_menu in [false, true]:
		var game: Node = load("res://scenes/spaceflight/expedition_demo.tscn").instantiate()
		root.add_child(game)
		await frames(5)
		game.start({"battery": "compact", "power": "solar", "instrument": "drill"}, "standard")
		await frames(20)
		place_rover(game, Destinations.get_def("moon").pad + Vector3(0, 0, 5))
		game.current.try_board()
		game.takeoff("mars")
		await frames(3)
		game.current.menu_requested.emit()
		if not hold_menu: game.ui.choice.emit("resume", "")
		check(game.current.paused, "Pause during takeoff (hold=%s): outgoing surface stays paused" % hold_menu)
		await frames(45)
		check(game.current.has_method("try_land"), "Pause during takeoff (hold=%s): flight scene installed" % hold_menu)
		check(game.current.paused == hold_menu, "Pause during takeoff (hold=%s): flight paused only while the menu is open" % hold_menu)
		if hold_menu:
			game.ui.choice.emit("resume", "")
			check(not game.current.paused and game.ui.active == "", "Pause during takeoff: resume releases the flight scene")
		game.queue_free()
		await frames(2)

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

## Player-equivalent descent inputs: on/off thrust and tapped side thrusters (no assist), as in test_landing.
static func human_pilot(l: Dictionary) -> Dictionary:
	var Landing = load("res://simulation/landing.gd")
	var id: String = str(l.destination)
	var margin: float = 4.0 if float(l.altitude) > 30.0 else 1.6
	var stop_distance: float = pow(float(l.vertical_speed), 2) / (2.0 * (Landing.max_accel(id) - Landing.gravity(id)))
	var thrust: float = 1.0 if (stop_distance + margin >= float(l.altitude) or float(l.vertical_speed) < -6.0) else 0.0
	if float(l.vertical_speed) > -0.6: thrust = 0.0
	var offset: Vector2 = l.offset
	var velocity: Vector2 = l.lateral_velocity
	var tap := func(v: float) -> float: return 0.0 if absf(v) < 0.4 else signf(v)
	return {"throttle": thrust, "x": tap.call(-offset.x * 0.3 - velocity.x), "z": tap.call(-offset.y * 0.3 - velocity.y)}

## Fly the final descent in the landing scene, manually or with the assist. Returns true on touchdown.
func descend(game: Node, manual: bool) -> bool:
	for i in range(120):
		if game.current != null and game.current.has_method("read_input"): break
		await physics_frame
	if game.current == null or not game.current.has_method("read_input"): return false
	if not manual: game.set_landing_assist(true)
	for i in range(4000):
		if game.expedition.phase != "landing": break
		game.current.input_override = {} if not manual else human_pilot(game.expedition.landing)
		await physics_frame
	await frames(150)
	return game.expedition.phase == "surface"

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
	await frames(2)
	check(game.expedition.phase == "landing", "Stage 4: L starts the player-controlled final descent")
	check(await descend(game, true), "Stage 4: manual descent (on/off thrust, tapped side thrusters) lands on Mars")
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
	check(game.expedition.delivered_science == 0, "Stage 4: nothing delivered before touchdown")
	check(await descend(game, false), "Stage 4: assisted descent lands at the Moon base")
	check(game.expedition.delivered_science == 105, "Stage 4: cores delivered on touchdown")
	game.finish()
	await frames(10)
	check(game.ui.active == "report" and game.expedition.phase == "complete", "Stage 4: debrief shown and kept")
	var report: Dictionary = load("res://simulation/expedition.gd").report(game.expedition)
	check(report.home and report.science_returned == 40 + 60 + 105, "Stage 4: debrief counts every returned unit (%d)" % report.science_returned)
	game.queue_free()
	await frames(2)

## Regression (INTEGRATION_REVIEW #1 applied to the new descent): ending during the descent transition or
## the final descent itself installs no further scene and changes nothing afterwards.
func finish_during_descent() -> void:
	var Travel = load("res://simulation/travel.gd")
	var Destinations = load("res://simulation/destinations.gd")
	for when in ["transition", "descent"]:
		var game: Node = load("res://scenes/spaceflight/expedition_demo.tscn").instantiate()
		root.add_child(game)
		await frames(5)
		game.start({"battery": "compact", "power": "solar", "instrument": "drill"}, "standard")
		await frames(20)
		place_rover(game, Destinations.get_def("moon").pad + Vector3(0, 0, 5))
		game.current.try_board()
		game.takeoff("moon")
		await frames(60)
		check(Travel.guidance(game.current.ship, "moon").can_land, "Finish during descent (%s): starts inside the approach zone" % when)
		game.current.try_land()
		if when == "descent":
			await frames(80)
			check(game.current.has_method("read_input") and game.expedition.phase == "landing", "Finish during descent: descent under way")
		else:
			await frames(5)
		game.finish()
		await frames(150)
		check(game.expedition.phase == "complete" and game.ui.active == "report", "Finish during descent (%s): debrief kept" % when)
		check(not game.current.has_method("try_board"), "Finish during descent (%s): no surface scene installed" % when)
		check(not game.expedition.has("landing"), "Finish during descent (%s): descent discarded" % when)
		game.queue_free()
		await frames(2)

## The landing scene: keyboard lever and thrusters, assist toggle, failure and free retry.
func landing_scene_controls() -> void:
	var Landing = load("res://simulation/landing.gd")
	var scene: Node3D = load("res://spaceflight/landing_scene.gd").new()
	scene.setup("moon", Landing.create("moon", 42))
	root.add_child(scene)
	await frames(3)
	var toggles: Array = []
	var retries: Array = []
	scene.assist_toggled.connect(func(on: bool) -> void: toggles.append(on))
	scene.retry_requested.connect(func() -> void: retries.append(true))
	key_event(KEY_W, true)
	await frames(30)
	key_event(KEY_W, false)
	var input: Dictionary = scene.read_input()
	check(input.has("throttle") and float(input.throttle) > 0.4, "Landing scene: W raises the throttle lever (%s)" % input)
	key_event(KEY_RIGHT, true)
	await frames(2)
	check(scene.read_input().x == 1.0, "Landing scene: → fires the east thruster")
	key_event(KEY_RIGHT, false)
	key_event(KEY_T, true)
	key_event(KEY_T, false)
	await frames(2)
	check(toggles == [true], "Landing scene: T toggles the assist")
	var failed: Dictionary = Landing.create("moon", 42)
	failed.status = "failed"
	failed.reason = "Unsafe touchdown: test."
	scene.show_landing(failed)
	key_event(KEY_R, true)
	key_event(KEY_R, false)
	await frames(2)
	check(retries.size() == 1, "Landing scene: R requests a retry after a failure")
	check("Retry" in scene.labels.status.text, "Landing scene: failure explains the free retry")
	scene.queue_free()
	await frames(2)

func key_event(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

## Impacts, repairs and storm presentation in the real surface scene (Mars demo scene).
func surface_hazards_and_storm_visuals() -> void:
	var demo: Node = load("res://scenes/spaceflight/mars_surface.tscn").instantiate()
	root.add_child(demo)
	await frames(60)
	var surface: Node3D = demo.surface
	var integrity_before: float = surface.state.integrity
	surface.report_impact(3.0)
	check(surface.state.integrity == integrity_before, "Hazards: soft bumps do no damage")
	surface.report_impact(9.0)
	check(surface.state.integrity < integrity_before, "Hazards: a hard impact reduces integrity")
	var worn: float = surface.state.integrity
	surface.report_impact(9.0)
	check(surface.state.integrity == worn, "Hazards: no second hit inside the cooldown")
	check("CONDITION  %d%%" % roundi(worn) in surface.hud.telemetry.text, "Hazards: HUD shows integrity")
	var field: Dictionary = surface.state.duplicate(true)
	field.position = Vector3(90, 0, 90)
	surface.apply_state(field)
	key_event(KEY_H, true)
	key_event(KEY_H, false)
	await frames(2)
	check(surface.state.integrity == worn, "Hazards: no field repairs")
	var at_pad: Dictionary = surface.state.duplicate(true)
	# Park within the repair radius but outside the newly solid ship footprint.
	at_pad.position = Vector3(0, 0, -3)
	surface.apply_state(at_pad)
	await frames(45) # Let the restored rover settle before measuring weather-only effects.
	key_event(KEY_H, true)
	key_event(KEY_H, false)
	await frames(2)
	check(surface.state.integrity == 100.0, "Hazards: H repairs for free at the ship")
	var clear_fog: float = surface.world.environment.fog_density
	surface.apply_state(surface.engine.forecast_storm(surface.state, 0.5))
	var parked: Vector3 = surface.state.position
	var energy: float = surface.state.energy
	await frames(60 * 12)
	check(surface.state.weather.phase == "storm" and surface.world.weather_phase == "storm", "Storm: the world shows the simulated storm")
	check(surface.world.environment.fog_density > clear_fog * 3.0, "Storm: visibility drops (fog %.4f)" % surface.world.environment.fog_density)
	check(surface.world.dust.emitting, "Storm: blowing dust visible")
	check(Vector2(surface.state.position.x - parked.x, surface.state.position.z - parked.z).length() < 0.01, "Storm: no wind push on the rover")
	check(surface.state.integrity == 100.0 and surface.state.energy == energy, "Storm: no damage or drain for being outdoors")
	demo.queue_free()
	await frames(2)

## Campaign pause-menu recovery returns the rover to the checkpoint and keeps progress and evidence.
func campaign_recovery_from_menu() -> void:
	var game: Node = load("res://scenes/spaceflight/campaign.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	check(game.start({"battery": "compact", "power": "solar", "instrument": "drill"}, "standard"), "Recovery: campaign begins")
	check(game.current.paused, "Recovery: flight waits while the briefing is open")
	game.mission_control.close_briefing()
	await frames(2)
	check(not game.current.paused, "Recovery: closing the briefing hands over control")
	game.current.try_land()
	check(await descend(game, false), "Recovery: assisted first landing")
	var surface: Node3D = game.current
	check(surface.beacons != null or surface.world.has_method("update_checkpoints"), "Recovery: checkpoint beacons drawn")
	var completed: Array = game.expedition.campaign.completed.duplicate()
	var sites: Array = surface.state.sites.duplicate(true)
	place_rover(game, Vector3(-60, 0, 70))
	surface.state.energy = 3.0
	surface.mission_changed.emit(surface.state)
	surface.menu_requested.emit()
	check(game.ui.active == "pause", "Recovery: pause menu")
	game.ui.choice.emit("recover", "")
	await frames(5)
	check(Vector2(surface.state.position.x, surface.state.position.z).length() < 0.5, "Recovery: rover back at the landing checkpoint (%s)" % surface.state.position)
	check(surface.state.energy >= surface.state.max_energy * 0.6 - 0.001, "Recovery: battery topped up")
	check(surface.state.sites == sites and game.expedition.campaign.completed == completed, "Recovery: sites and progress unchanged")
	check(not surface.paused and game.ui.active == "", "Recovery: play resumes")
	# Codex's global atlas on Moon surfaces: M opens it (pausing), a survey pick is planning-only, M closes it.
	var before_pick: Dictionary = surface.state.duplicate(true)
	key_event(KEY_M, true)
	key_event(KEY_M, false)
	await frames(3)
	check(surface.atlas != null and surface.atlas.is_open() and surface.paused, "Atlas: M opens the lunar atlas and pauses the surface")
	surface.atlas._select(-89.5, 222.0)
	await frames(2)
	check(surface.state.position == before_pick.position and surface.state.sites == before_pick.sites, "Atlas: survey pick does not move the rover or change the mission")
	key_event(KEY_M, true)
	key_event(KEY_M, false)
	await frames(3)
	check(not surface.atlas.is_open() and not surface.paused, "Atlas: M closes it and restores the pause state")
	game.queue_free()
	await frames(2)
