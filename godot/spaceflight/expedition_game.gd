extends Node
## Playable spaceflight loop (demo scene root): plan → explore the Moon → board → take off → fly →
## land on Mars → rover investigates → board → fly home → land → debrief.
## The expedition state (simulation/expedition.gd) is authoritative. Scenes report changes back:
## the surface scene's mission state and the space scene's ship state are copied into it.
##
## Methods used by tests and integrators: start(config, fuel_load), board(), takeoff(target), land(id),
## disembark(), finish(), and the `expedition`, `current`, `ui` and `transition` members.
const Expedition = preload("res://simulation/expedition.gd")
const Ship = preload("res://simulation/ship_flight.gd")
const Travel = preload("res://simulation/travel.gd")
const Destinations = preload("res://simulation/destinations.gd")
const SurfaceScene = preload("res://spaceflight/surface_scene.gd")
const SpaceScene = preload("res://spaceflight/space_scene.gd")
const Transition = preload("res://spaceflight/transition_overlay.gd")
const ExpeditionUI = preload("res://spaceflight/expedition_ui.gd")
const SpaceSky = preload("res://spaceflight/space_sky.gd")
const ShipRig = preload("res://spaceflight/ship_rig.gd")

signal phase_changed(phase: String)

var expedition: Dictionary = {}
var current: Node
var ui: CanvasLayer
var transition: CanvasLayer
var expedition_seed: int = 42
var _config: Dictionary = {"battery": "compact", "power": "solar", "instrument": "drill"}
var _fuel_load: String = "standard"

func _ready() -> void:
	expedition_seed = int(get_tree().get_meta("blue_horizon_expedition_seed", 42))
	transition = Transition.new()
	add_child(transition)
	ui = ExpeditionUI.new()
	add_child(ui)
	ui.config_changed.connect(_on_config)
	ui.choice.connect(_on_choice)
	_planning_backdrop()
	ui.show_planning()

## A slowly turning ship against the stars behind the planning screen (removed when the expedition starts).
func _planning_backdrop() -> void:
	var backdrop := Node3D.new()
	backdrop.name = "PlanningBackdrop"
	backdrop.add_child(SpaceSky.new())
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25, 50, 0)
	backdrop.add_child(sun)
	var rig: Node3D = ShipRig.new()
	backdrop.add_child(rig)
	rig.position = Vector3(5.5, -0.5, 0)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.5, 17)
	camera.current = true
	backdrop.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(2.5, 0, 0))
	backdrop.set_meta("rig", rig)
	add_child(backdrop)
	current = backdrop

var _backdrop_clock: float = 0.0

func _process(delta: float) -> void:
	if current and current.name == "PlanningBackdrop":
		_backdrop_clock += delta
		var rig: Node3D = current.get_meta("rig")
		rig.rotation.y += delta * 0.25
		rig.rotation.z = sin(_backdrop_clock * 0.5) * 0.08

func _on_config(config: Dictionary, fuel_load: String) -> void:
	_config = config
	_fuel_load = fuel_load
	ui.update_review(Expedition.review(config, fuel_load))

func _on_choice(action: String, argument: String) -> void:
	match action:
		"start": start(_config, _fuel_load)
		"takeoff": takeoff(argument)
		"disembark": disembark()
		"finish": finish()
		"resume": _resume()
		"restart":
			get_tree().set_meta("blue_horizon_expedition_seed", expedition_seed + 1)
			get_tree().reload_current_scene()
		"quit": get_tree().quit()

func start(config: Dictionary, fuel_load: String) -> bool:
	expedition = Expedition.begin(Expedition.create(config, fuel_load, expedition_seed))
	if expedition.phase != "surface": return false
	ui.hide_screen()
	_show_surface()
	return true

func _surface_info() -> Dictionary:
	var def: Dictionary = Destinations.get_def(expedition.location)
	var notes: String = ""
	if expedition.location == "mars":
		notes = "Solar output is 43% of the Moon's (derived from Mars's 1.5 AU distance). Driving costs more in sand.\nOnly scan data can be transmitted: sample science counts when cores are flown home."
	else:
		notes = "Home base. Transmit data from here; land here with Mars sample cores to deliver them.\nSolar power works east of x = -18."
	return {"ship_fuel": expedition.ship.fuel, "cores": expedition.cores.size(), "notes": notes,
		"subtitle": "%s  /  SURFACE GRAVITY %.2f m/s² (NASA)" % [str(def.name).to_upper(), def.gravity]}

func _show_surface() -> void:
	_replace_current(SurfaceScene.new())
	current.setup(expedition.location, Expedition.mission(expedition), _surface_info())
	current.mission_changed.connect(_on_mission_changed)
	current.board_requested.connect(board)
	current.menu_requested.connect(_pause)
	add_child(current)
	phase_changed.emit(expedition.phase)

func _show_space(target: String) -> void:
	_replace_current(SpaceScene.new())
	var cores: String = "%d sample core%s aboard" % [expedition.cores.size(), "" if expedition.cores.size() == 1 else "s"]
	current.setup(expedition.ship, target, cores)
	current.ship_changed.connect(func(ship: Dictionary) -> void: expedition.ship = ship)
	current.land_requested.connect(land)
	current.menu_requested.connect(_pause)
	add_child(current)
	phase_changed.emit(expedition.phase)

func _replace_current(next: Node) -> void:
	if current and is_instance_valid(current):
		remove_child(current)
		current.queue_free()
	current = next

func _on_mission_changed(state: Dictionary) -> void:
	if expedition.phase != "surface": return
	expedition.missions[expedition.location] = state
	current.info = _surface_info()

func board() -> void:
	if current and current.has_method("try_board"): expedition.missions[expedition.location] = current.state
	expedition = Expedition.board(expedition)
	if expedition.phase != "aboard": return
	current.paused = true
	_show_aboard()

func _show_aboard(warning: String = "") -> void:
	var def: Dictionary = Destinations.get_def(expedition.location)
	var ship: Dictionary = expedition.ship
	var lines: Array = [
		"Fuel %d kg  ·  ship mass %d kg  ·  Δv left %d u/s" % [roundi(ship.fuel), roundi(Ship.total_mass(ship)), roundi(Ship.delta_v_remaining(ship))],
		"Ascent from %s needs %d kg now (gravity %.2f m/s², NASA)." % [def.name, ceili(Travel.ascent_fuel(Ship.total_mass(ship), expedition.location)), def.gravity],
	]
	if not expedition.cores.is_empty():
		var names: PackedStringArray = []
		for core in expedition.cores: names.append("%s (%s)" % [core.name, core.finding])
		lines.append("Sealed cores aboard (%d kg): %s" % [roundi(expedition.cores.size() * float(expedition.cores[0].mass)), ", ".join(names)])
	lines.append(str(expedition.log[0]))
	var targets: Array = []
	for id in Destinations.ids():
		if Destinations.is_explorable(id) and id != expedition.location: targets.append([id, Destinations.get_def(id).name])
	ui.show_aboard("%s pad" % def.name, lines, targets, warning)
	phase_changed.emit(expedition.phase)

func disembark() -> void:
	expedition = Expedition.disembark(expedition)
	if expedition.phase != "surface": return
	ui.hide_screen()
	_show_surface()

func takeoff(target: String) -> void:
	var next: Dictionary = Expedition.takeoff(expedition, target)
	if next.phase != "flight":
		expedition = next
		_show_aboard(str(next.log[0]))
		return
	var origin: Dictionary = Destinations.get_def(expedition.location)
	var burned: float = float(expedition.ship.fuel) - float(next.ship.fuel)
	expedition = next
	ui.hide_screen()
	transition.play("ASCENT FROM %s" % str(origin.name).to_upper(), [
		"Ascent burn: %d kg at %d kg ship mass." % [roundi(burned), roundi(Ship.total_mass(expedition.ship) + burned)],
		"Surface gravity %.2f m/s² (NASA). Ascent Δv in this game scales with it." % origin.gravity,
		"Real trip to %s: %s. Here distances and times are compressed." % [Destinations.get_def(target).name, Destinations.get_def(target).real_travel]])
	await transition.covered
	_show_space(target)

func land(id: String) -> void:
	if expedition.phase != "flight": return
	var before_fuel: float = float(expedition.ship.fuel)
	var delivered_before: int = int(expedition.delivered_science)
	var next: Dictionary = Expedition.land(expedition, id)
	if next.phase != "aboard": return
	expedition = next
	current.paused = true
	var def: Dictionary = Destinations.get_def(id)
	var lines: Array = ["Descent burn: %d kg. Fuel left: %d kg." % [roundi(before_fuel - float(expedition.ship.fuel)), roundi(expedition.ship.fuel)]]
	if int(expedition.delivered_science) > delivered_before:
		lines.append("Sample cores delivered to the base: +%d science." % (int(expedition.delivered_science) - delivered_before))
	for fact in def.facts.slice(0, 2): lines.append("%s (NASA)" % fact.text)
	lines.append(def.fiction)
	transition.play("TOUCHDOWN: %s" % str(def.name).to_upper(), lines, 2.2)
	await transition.covered
	expedition = Expedition.disembark(expedition)
	_show_surface()

func finish() -> void:
	expedition = Expedition.finish(expedition)
	if current and "paused" in current: current.paused = true
	ui.show_report(Expedition.report(expedition))
	phase_changed.emit(expedition.phase)

func _pause() -> void:
	if expedition.get("phase", "") == "complete": return
	if current and "paused" in current: current.paused = true
	ui.show_pause()

func _resume() -> void:
	if expedition.phase == "aboard":
		_show_aboard()
		return
	ui.hide_screen()
	if current and "paused" in current: current.paused = false
