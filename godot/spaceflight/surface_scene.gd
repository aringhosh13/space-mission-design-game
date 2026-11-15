extends Node3D
## Reusable surface scene for any explorable destination. Reuses Codex's rover (scripts/rover.gd) and
## lunar world (scripts/lunar_world.gd) unchanged; Mars uses spaceflight/mars_world.gd (same API).
##
## Integration API:
##   setup(destination_id: String, mission_state: Dictionary, info: Dictionary = {})  call before add_child()
##   signal board_requested            G pressed with the rover within boarding range of the parked ship
##   signal mission_changed(state)     after every simulation change (moves are throttled to 10 Hz)
##   signal menu_requested             Escape
##   var state: Dictionary             authoritative mission state (simulation/mission_engine.gd)
##   var info: Dictionary              extra HUD info from the owner (ship fuel, cores, notes)
##   var paused: bool
##   func act(action: String), try_board() -> bool, board_distance() -> float
##   func report_impact(speed), repair(), set_checkpoints(list), apply_state(state)   (campaign additions)
##
## Campaign additions: simulation time advances every physics frame (engine.advance_surface, never the wall
## clock); Mars weather drives world.set_weather(); hard impacts from Codex's rover.impact_reported (when
## present) go to engine.apply_impact; H repairs at the ship or shelter; integrity is shown in the HUD and
## passed to rover.set_condition() when present. Larger regions use world.configure_extent() when present;
## otherwise the lunar scene keeps the rover on the rendered terrain with invisible collision walls.
const MissionEngine = preload("res://simulation/mission_engine.gd")
const Destinations = preload("res://simulation/destinations.gd")
const LunarWorld = preload("res://scripts/lunar_world.gd")
const MarsWorld = preload("res://spaceflight/mars_world.gd")
const Rover = preload("res://scripts/rover.gd")
const ShipModel = preload("res://spaceflight/ship_model.gd")
const SurfaceHUD = preload("res://spaceflight/surface_hud.gd")
const Beacons = preload("res://spaceflight/checkpoint_beacons.gd")
const MoonAtlas = preload("res://scripts/moon_atlas.gd")
const WorldLabels = preload("res://scripts/world_labels.gd")
const TraverseLab = preload("res://scripts/traverse_lab.gd")
const FieldConsole = preload("res://scripts/field_console.gd")
const Sound = preload("res://scripts/audio_feedback.gd")
var operation: CanvasLayer
var _operation_previous_pause: bool = false
var _operation_site: String = ""
var planner: CanvasLayer
var _planner_previous_pause: bool = false
## Legacy lunar terrain half-size (Codex's lunar_world.gd before configure_extent exists).
const LEGACY_LUNAR_EXTENT: float = 107.0

signal board_requested
signal mission_changed(state: Dictionary)
signal menu_requested

var engine = MissionEngine.new()
var destination_id: String = "mars"
var def: Dictionary
var rules: Dictionary
var state: Dictionary
var info: Dictionary = {}
var paused: bool = false
var world: Node3D
var rover: CharacterBody3D
var parked_ship: Node3D
var hud: CanvasLayer
var _ui_clock: float = 0.0
var beacons: Node3D
var physical_limit: float = INF
var _weather_phase: String = ""
var _last_integrity: float = -1.0
var atlas: CanvasLayer
var _atlas_previous_pause: bool = false
var _hud_checkpoints: Array = []

func setup(id: String, mission_state: Dictionary, extra: Dictionary = {}) -> void:
	destination_id = id
	state = mission_state.duplicate(true)
	info = extra.duplicate(true)

func _ready() -> void:
	def = Destinations.get_def(destination_id)
	rules = Destinations.surface_rules(destination_id)
	world = LunarWorld.new() if def.world == "lunar" else MarsWorld.new()
	var limit: float = float(engine.surface_rules(state).map_limit)
	if world.has_method("configure_extent"): world.configure_extent(limit)
	elif limit > LEGACY_LUNAR_EXTENT: physical_limit = LEGACY_LUNAR_EXTENT
	add_child(world)
	world.build(state.sites)
	if physical_limit < INF: _boundary_walls(physical_limit)
	if not world.has_method("update_checkpoints"):
		beacons = Beacons.new()
		beacons.height_at = world.terrain_height
		add_child(beacons)
	parked_ship = ShipModel.new()
	add_child(parked_ship)
	parked_ship.landing_gear(true)
	var pad: Vector3 = def.pad
	parked_ship.position = Vector3(pad.x, world.terrain_height(pad.x, pad.z) + 2.62, pad.z)
	parked_ship.rotation.y = 0.6
	rover = Rover.new()
	add_child(rover)
	var start: Vector3 = state.position
	rover.position = Vector3(start.x, world.terrain_height(start.x, start.z) + 0.4, start.z)
	rover.attempted_move.connect(_on_move)
	if "drive_speed" in rover: rover.drive_speed = float(rules.get("rover_speed", rover.drive_speed))
	if rover.has_signal("impact_reported"): rover.impact_reported.connect(report_impact)
	hud = SurfaceHUD.new()
	add_child(hud)
	hud.action_requested.connect(func(action: String) -> void:
		if paused: return
		if action == "plan": toggle_planner()
		elif action == "board": try_board()
		else: request_action(action))
	_sync()

func board_distance() -> float:
	return MissionEngine.flat_distance(state.position, def.pad)

func toggle_planner() -> void:
	if planner == null:
		planner = TraverseLab.new()
		planner.close_requested.connect(func() -> void:
			planner.close()
			paused = _planner_previous_pause
			_sync())
		add_child(planner)
	_planner_previous_pause = paused
	paused = true
	_sync()
	planner.open(destination_id)

func try_board() -> bool:
	if state.phase != "surface": return false
	if board_distance() <= float(def.boarding_range):
		board_requested.emit()
		return true
	hud.flash("Drive within %d m of the ship to board (now %d m)." % [int(def.boarding_range), roundi(board_distance())])
	return false

func act(action: String) -> void:
	if paused: return
	var before: Dictionary = state
	state = engine.act(state, action)
	if state.science_collected > before.science_collected or state.outpost_deployed != before.outpost_deployed:
		Sound.cue(self, "confirm")
	elif state.energy != before.energy or state.science_returned != before.science_returned: Sound.cue(self, "click")
	else: Sound.cue(self, "warning")
	if action == "scan" and state.phase == "surface": world.pulse(rover.global_position)
	mission_changed.emit(state)
	_sync()

## Human actions use a hands-on tool; act() remains the authoritative integration entry point.
func request_action(action: String) -> void:
	if paused or state.phase != "surface": return
	if action not in ["scan", "sample", "deploy"]:
		act(action)
		return
	var candidate: Dictionary = engine.act(state, action)
	var valid: bool = candidate.science_collected > state.science_collected or candidate.outpost_deployed != state.outpost_deployed
	if not valid and action != "deploy":
		act(action)
		return
	if action == "deploy" and state.outpost_deployed:
		act(action)
		return
	if operation == null:
		operation = FieldConsole.new()
		operation.commit_requested.connect(_commit_operation)
		operation.closed.connect(func() -> void:
			paused = _operation_previous_pause
			_sync())
		add_child(operation)
	var site: Dictionary = MissionEngine.site_in_range(state.position, state.sites, float(rules.interaction_range))
	_operation_site = str(site.get("id", ""))
	var cost: float = float(rules.get({"scan":"scan_energy", "sample":"sample_energy", "deploy":"deploy_energy"}[action], 0))
	var return_cost: float = board_distance() * float(rules.move_energy_per_m) * MissionEngine.movement_multiplier(state)
	var reserve_energy: float = float(state.max_energy) * 0.2
	var after: float = float(state.energy) - cost
	var assessment: String = "SITE: %s\nBattery now: %.1f  /  deploy cost: %.1f  /  after deployment: %.1f\nStraight-line drive to ship: %.0f m  /  estimated cost: %.1f\nSuggested 20%% reserve: %.1f  /  %s\n\nThis game estimate excludes detours and charging. Return to the rover to choose another location." % [
		"sunlit in the game model" if MissionEngine.is_lit(state.position, rules) else "SHADOW — solar station cannot operate here",
		state.energy, cost, after, board_distance(), return_cost, reserve_energy,
		"budget covers this estimate + reserve" if after >= return_cost + reserve_energy else "recharge or move before committing; return budget is tight"]
	_operation_previous_pause = paused
	paused = true
	rover.velocity = Vector3.ZERO
	_sync()
	operation.open(action, {"name": site.get("name", "SITE"), "seed": int(state.seed) + _operation_site.hash(),
		"cost": cost, "can_commit": valid, "assessment": assessment})

func _commit_operation(action: String) -> void:
	# Re-check site, phase, position and resources through the engine. UI never writes science/confidence.
	var site: Dictionary = MissionEngine.site_in_range(state.position, state.sites, float(rules.interaction_range))
	if state.phase != "surface" or (action != "deploy" and str(site.get("id", "")) != _operation_site):
		operation.close()
		return
	paused = false
	act(action)
	paused = true
	_sync()
	var next: String = "Next: return evidence to the ship, or choose another investigation."
	if action == "scan": next = "Solution: a stable measurement gives preliminary evidence, not proof. Use Q to collect a core if you want to test the finding."
	elif action == "sample": next = "Solution: characterise the sample even if the signal is ruled out. On Mars, board the ship and fly the core home before its science counts."
	else: next = "Solution: deploy where power is available while retaining a path home. The station position is saved; avoid its solid hardware when driving."
	operation.show_result(str(state.log[0]) + "\n\n" + next + "\n\nRover power remaining: %.1f / %.1f." % [state.energy, state.max_energy])

func cancel_operation() -> void:
	if operation != null and operation.is_open(): operation.close()

func _on_move(proposed: Vector3) -> void:
	if state.phase != "surface" or paused: return
	state = engine.move_rover(state, proposed)
	rover.global_position = state.position

## Invisible walls keep the rover on the rendered legacy terrain until the renderer supports larger extents.
func _boundary_walls(half: float) -> void:
	var body := StaticBody3D.new()
	body.name = "LegacyTerrainBoundary"
	for side in [Vector3(half + 1.0, 0, 0), Vector3(-half - 1.0, 0, 0), Vector3(0, 0, half + 1.0), Vector3(0, 0, -half - 1.0)]:
		var shape := BoxShape3D.new()
		shape.size = Vector3(2, 60, half * 2.0 + 4.0) if side.x != 0.0 else Vector3(half * 2.0 + 4.0, 60, 2)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = side
		body.add_child(collision)
	add_child(body)

## Codex's global lunar atlas (M on Moon surfaces). Planning only: a survey pick never moves the rover,
## changes the mission or completes an objective. The surface pause state is saved and restored.
func toggle_atlas() -> void:
	if def.world != "lunar":
		hud.flash("The global atlas covers the Moon (NASA LRO/LOLA elevation).")
		return
	if atlas == null:
		atlas = MoonAtlas.new()
		atlas.close_requested.connect(_close_atlas)
		atlas.survey_selected.connect(_on_survey_selected)
		add_child(atlas)
	if atlas.is_open():
		_close_atlas()
		return
	_atlas_previous_pause = paused
	paused = true
	_sync()
	atlas.show_map()

func _close_atlas() -> void:
	if atlas == null or not atlas.is_open(): return
	atlas.hide_map()
	paused = _atlas_previous_pause
	_sync()

func _on_survey_selected(latitude: float, longitude: float) -> void:
	hud.flash("Survey marker %.2f°, %.2f° E noted for planning. It does not move the rover." % [latitude, longitude])

func report_impact(impact_speed: float) -> void:
	if paused: return
	var before: float = float(state.get("integrity", 100))
	state = engine.apply_impact(state, impact_speed)
	if float(state.get("integrity", 100)) < before: Sound.cue(self, "impact")
	mission_changed.emit(state)
	_sync()

func repair() -> void:
	if paused: return
	state = engine.repair_rover(state)
	mission_changed.emit(state)
	_sync()

func set_checkpoints(checkpoints: Array) -> void:
	_hud_checkpoints = checkpoints.duplicate(true)
	if world.has_method("update_checkpoints"): world.update_checkpoints(checkpoints)
	elif beacons: beacons.update_checkpoints(checkpoints)

## Replace the mission state from outside (campaign recovery) and move the rover to match.
func apply_state(next: Dictionary) -> void:
	cancel_operation()
	state = next.duplicate(true)
	var p: Vector3 = state.position
	rover.global_position = Vector3(p.x, world.terrain_height(p.x, p.z) + 0.6, p.z)
	rover.velocity = Vector3.ZERO
	_sync()

func _physics_process(delta: float) -> void:
	if paused or state.phase != "surface": return
	state = engine.advance_surface(state, delta)
	var phase: String = str(state.get("weather", {}).get("phase", "clear"))
	if phase != _weather_phase:
		_weather_phase = phase
		if world.has_method("set_weather"): world.set_weather(state.get("weather", {}))
		if phase == "warning":
			Sound.cue(self, "warning")
			hud.flash("Dust warning: check your power reserve. Shelter offers charging and free repairs.")

func _sync() -> void:
	world.update_mission(state)
	var integrity: float = float(state.get("integrity", 100.0))
	if integrity != _last_integrity:
		_last_integrity = integrity
		if rover.has_method("set_condition"): rover.set_condition(integrity)
	var hud_info: Dictionary = info.duplicate()
	hud_info["board_distance"] = board_distance()
	hud_info["boarding_range"] = def.boarding_range
	hud_info["interaction_range"] = rules.interaction_range
	hud_info["title"] = info.get("title", "BLUE HORIZON  /  %s SURFACE" % str(def.name).to_upper())
	hud_info["can_repair"] = integrity < 100.0 and (engine.at_pad(state) or engine.in_shelter(state))
	hud_info["in_shelter"] = engine.in_shelter(state)
	hud_info["heading"] = rover.yaw
	hud_info["pad"] = def.pad
	hud_info["radar_range"] = ceilf(float(rules.map_limit) / 100.0) * 100.0
	hud_info["checkpoints"] = _hud_checkpoints
	hud_info["paused"] = paused
	hud.update_surface(state, hud_info)
	rover.driving = state.phase == "surface" and not paused
	rover.can_drive = float(state.energy) > 0.02

func _process(delta: float) -> void:
	_ui_clock += delta
	if _ui_clock >= 0.1:
		_ui_clock = 0.0
		mission_changed.emit(state)
		_sync()
		WorldLabels.update(world, rover.camera)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_ESCAPE:
		menu_requested.emit()
		return
	if paused or state.phase != "surface": return
	var actions: Dictionary = {KEY_E: "scan", KEY_Q: "sample", KEY_R: "recharge", KEY_T: "transmit", KEY_B: "deploy"}
	if actions.has(event.physical_keycode): request_action(actions[event.physical_keycode])
	elif event.physical_keycode == KEY_G: try_board()
	elif event.physical_keycode == KEY_H: repair()
	elif event.physical_keycode == KEY_P: toggle_planner()
	elif event.physical_keycode == KEY_M:
		get_viewport().set_input_as_handled()
		toggle_atlas()
