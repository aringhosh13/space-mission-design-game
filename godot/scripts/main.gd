extends Node3D
const Contract = preload("res://shared/mission_contract.gd")
const MissionEngine = preload("res://simulation/mission_engine.gd")
const LunarWorld = preload("res://scripts/lunar_world.gd")
const Rover = preload("res://scripts/rover.gd")
const HUD = preload("res://scripts/hud.gd")
var engine = MissionEngine.new()
var mission_seed: int = 42
var config: Dictionary = {"battery": "compact", "power": "solar", "instrument": "drill"}
var state: Dictionary
var world: Node3D
var rover: CharacterBody3D
var hud: CanvasLayer
var paused: bool = false
var ui_clock: float = 0.0

func _ready() -> void:
	DisplayServer.window_set_title("Blue Horizon · Moon Expedition")
	mission_seed = int(get_tree().get_meta("blue_horizon_seed", 42))
	state = engine.create_mission(config, mission_seed)
	world = LunarWorld.new()
	add_child(world)
	world.build(state.sites)
	rover = Rover.new()
	add_child(rover)
	rover.position = Vector3(0, world.terrain_height(0, 0) + 0.4, 0)
	rover.attempted_move.connect(_on_move)
	hud = HUD.new()
	add_child(hud)
	hud.action_requested.connect(_on_action)
	hud.config_changed.connect(_on_config)
	hud.show_planning()
	_sync()

func _on_config(next_config: Dictionary) -> void:
	if state.phase != "planning": return
	config = next_config
	state = engine.create_mission(config, mission_seed)
	hud.update_review(engine.review_design(config))
	_sync()

func _on_move(proposed: Vector3) -> void:
	if state.phase != "surface" or paused: return
	state = engine.move_rover(state, proposed)
	rover.global_position = state.position

func _on_action(action: String) -> void:
	if action == "quit":
		get_tree().quit()
		return
	if action == "restart":
		get_tree().set_meta("blue_horizon_seed", mission_seed + 1)
		get_tree().reload_current_scene()
		return
	if action == "resume":
		paused = false
		hud.hide_overlay()
		_sync()
		return
	if paused and action != "finish": return
	var previous_phase: String = state.phase
	state = engine.act(state, action)
	if action == "launch" and state.phase == "surface" and previous_phase == "planning":
		state.position = rover.global_position
		hud.hide_overlay()
	if action == "scan" and state.phase == "surface": world.pulse(rover.global_position)
	if state.phase == "complete":
		paused = false
		hud.show_report(engine.get_report(state))
	_sync()

func _sync() -> void:
	world.update_mission(state)
	hud.update_mission(state)
	hud.update_environment(world.presentation_for(state.position), state, rover.yaw, Vector2(rover.velocity.x, rover.velocity.z).length())
	rover.driving = state.phase == "surface" and not paused
	rover.can_drive = state.energy > 0.02

func _process(delta: float) -> void:
	ui_clock += delta
	if ui_clock >= 0.1:
		ui_clock = 0.0
		_sync()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE and state.phase == "surface":
		paused = not paused
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if paused: hud.show_pause()
		else: hud.hide_overlay()
		_sync()
		return
	if paused or state.phase != "surface": return
	var actions: Dictionary = {KEY_E: "scan", KEY_Q: "sample", KEY_R: "recharge", KEY_T: "transmit", KEY_B: "deploy", KEY_F: "finish"}
	if actions.has(event.keycode): _on_action(actions[event.keycode])
