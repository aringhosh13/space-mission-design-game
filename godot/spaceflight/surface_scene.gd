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
## Campaign additions: simulation time advances every physics frame (engine.advance_time, never the wall
## clock); Mars weather drives world.set_weather(); hard impacts from Codex's rover.impact_reported (when
## present) go to engine.report_impact; H repairs at the ship or shelter; integrity is shown in the HUD and
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
	_sync()

func board_distance() -> float:
	return MissionEngine.flat_distance(state.position, def.pad)

func try_board() -> bool:
	if state.phase != "surface": return false
	if board_distance() <= float(def.boarding_range):
		board_requested.emit()
		return true
	hud.flash("Drive within %d m of the ship to board (now %d m)." % [int(def.boarding_range), roundi(board_distance())])
	return false

func act(action: String) -> void:
	if paused: return
	state = engine.act(state, action)
	if action == "scan" and state.phase == "surface": world.pulse(rover.global_position)
	mission_changed.emit(state)
	_sync()

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

func report_impact(impact_speed: float) -> void:
	if paused: return
	state = engine.report_impact(state, impact_speed)
	mission_changed.emit(state)
	_sync()

func repair() -> void:
	if paused: return
	state = engine.repair(state)
	mission_changed.emit(state)
	_sync()

func set_checkpoints(checkpoints: Array) -> void:
	if world.has_method("update_checkpoints"): world.update_checkpoints(checkpoints)
	elif beacons: beacons.update_checkpoints(checkpoints)

## Replace the mission state from outside (campaign recovery) and move the rover to match.
func apply_state(next: Dictionary) -> void:
	state = next.duplicate(true)
	var p: Vector3 = state.position
	rover.global_position = Vector3(p.x, world.terrain_height(p.x, p.z) + 0.6, p.z)
	rover.velocity = Vector3.ZERO
	_sync()

func _physics_process(delta: float) -> void:
	if paused or state.phase != "surface": return
	state = engine.advance_time(state, delta)
	var phase: String = str(state.get("weather", {}).get("phase", "clear"))
	if phase != _weather_phase:
		_weather_phase = phase
		if world.has_method("set_weather"): world.set_weather(state.get("weather", {}))

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
	hud.update_surface(state, hud_info)
	rover.driving = state.phase == "surface" and not paused
	rover.can_drive = float(state.energy) > 0.02

func _process(delta: float) -> void:
	_ui_clock += delta
	if _ui_clock >= 0.1:
		_ui_clock = 0.0
		mission_changed.emit(state)
		_sync()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_ESCAPE:
		menu_requested.emit()
		return
	if paused or state.phase != "surface": return
	var actions: Dictionary = {KEY_E: "scan", KEY_Q: "sample", KEY_R: "recharge", KEY_T: "transmit", KEY_B: "deploy"}
	if actions.has(event.physical_keycode): act(actions[event.physical_keycode])
	elif event.physical_keycode == KEY_G: try_board()
	elif event.physical_keycode == KEY_H: repair()
