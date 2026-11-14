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
const MissionEngine = preload("res://simulation/mission_engine.gd")
const Destinations = preload("res://simulation/destinations.gd")
const LunarWorld = preload("res://scripts/lunar_world.gd")
const MarsWorld = preload("res://spaceflight/mars_world.gd")
const Rover = preload("res://scripts/rover.gd")
const ShipModel = preload("res://spaceflight/ship_model.gd")
const SurfaceHUD = preload("res://spaceflight/surface_hud.gd")

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

func setup(id: String, mission_state: Dictionary, extra: Dictionary = {}) -> void:
	destination_id = id
	state = mission_state.duplicate(true)
	info = extra.duplicate(true)

func _ready() -> void:
	def = Destinations.get_def(destination_id)
	rules = Destinations.surface_rules(destination_id)
	world = LunarWorld.new() if def.world == "lunar" else MarsWorld.new()
	add_child(world)
	world.build(state.sites)
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

func _sync() -> void:
	world.update_mission(state)
	var hud_info: Dictionary = info.duplicate()
	hud_info["board_distance"] = board_distance()
	hud_info["boarding_range"] = def.boarding_range
	hud_info["interaction_range"] = rules.interaction_range
	hud_info["title"] = info.get("title", "BLUE HORIZON  /  %s SURFACE" % str(def.name).to_upper())
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
