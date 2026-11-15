extends Node
## Playable spaceflight loop (demo scene root). Two modes:
##   expedition (default): plan → Moon → board → take off → fly → manual landing on Mars → investigate →
##     fly home → manual landing → debrief.
##   campaign (`campaign_mode = true`, scenes/spaceflight/campaign.tscn): "First Light", the same journey as
##     a guided story with Mission Control objectives, checkpoints and recovery (simulation/campaign.gd).
## The expedition state (simulation/expedition.gd) is authoritative. Scenes report changes back: the surface
## scene's mission state, the space scene's ship state; the landing scene only supplies input and the game
## steps the descent through Expedition.step_landing().
##
## Methods used by tests and integrators: start(config, fuel_load), board(), takeoff(target), land(id),
## retry_landing(), set_landing_assist(on), disembark(), recover(), finish(), and the `expedition`,
## `current`, `ui`, `transition` and `mission_control` members.
##
## Transition policy (unchanged from the PR #4 review fix): takeoff, descent and touchdown transitions are
## exclusive and identified by a token. The pause menu stays available, but finish() and restart invalidate
## the token and cancel the overlay. Every continuation re-checks its token and the expected expedition
## phase after each await, so a completed expedition never gets a new flight, landing or surface scene, and
## a scene installed while a menu is open starts paused. Only the scene for the current phase may write back.
const Expedition = preload("res://simulation/expedition.gd")
const Campaign = preload("res://simulation/campaign.gd")
const Ship = preload("res://simulation/ship_flight.gd")
const Travel = preload("res://simulation/travel.gd")
const Destinations = preload("res://simulation/destinations.gd")
const SurfaceScene = preload("res://spaceflight/surface_scene.gd")
const SpaceScene = preload("res://spaceflight/space_scene.gd")
const LandingScene = preload("res://spaceflight/landing_scene.gd")
const Transition = preload("res://spaceflight/transition_overlay.gd")
const ExpeditionUI = preload("res://spaceflight/expedition_ui.gd")
const MissionControl = preload("res://spaceflight/mission_control.gd")
const SpaceSky = preload("res://spaceflight/space_sky.gd")
const ShipRig = preload("res://spaceflight/ship_rig.gd")
const TraverseLab = preload("res://scripts/traverse_lab.gd")
const Cinematic = preload("res://scripts/mission_cinematic.gd")
var study_planner: CanvasLayer
var debrief_film: CanvasLayer
var _pending_campaign_start: bool = false

signal phase_changed(phase: String)

@export var campaign_mode: bool = false
## Start each descent with the landing assist on (players can toggle it with T at any time).
@export var landing_assist: bool = false

var expedition: Dictionary = {}
var current: Node
var ui: CanvasLayer
var transition: CanvasLayer
var mission_control: CanvasLayer
var expedition_seed: int = 42
var _config: Dictionary = {"battery": "compact", "power": "solar", "instrument": "drill"}
var _fuel_load: String = "standard"
var _transition_token: int = 0
var _message_id: int = 0
var _beacon_key: String = ""
var _flight_clock: float = 0.0

func _begin_transition() -> int:
	_transition_token += 1
	return _transition_token

func _transition_current(token: int, phase: String) -> bool:
	return token == _transition_token and expedition.get("phase", "") == phase and is_inside_tree()

func _cancel_transition() -> void:
	_transition_token += 1
	if transition: transition.cancel()

## A scene installed while a menu or the briefing is open starts paused; closing it releases the scene.
func _menu_open() -> bool:
	return ui.active in ["pause", "report"] or (mission_control != null and mission_control.briefing_open)

func _ready() -> void:
	expedition_seed = int(get_tree().get_meta("blue_horizon_expedition_seed", 42))
	transition = Transition.new()
	add_child(transition)
	ui = ExpeditionUI.new()
	add_child(ui)
	mission_control = MissionControl.new()
	add_child(mission_control)
	mission_control.briefing_closed.connect(_on_briefing_closed)
	ui.config_changed.connect(_on_config)
	ui.choice.connect(_on_choice)
	_planning_backdrop()
	ui.show_planning(campaign_mode)

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

func _review(config: Dictionary, fuel_load: String) -> Dictionary:
	return Campaign.review(config, fuel_load) if campaign_mode else Expedition.review(config, fuel_load)

func _on_config(config: Dictionary, fuel_load: String) -> void:
	_config = config
	_fuel_load = fuel_load
	ui.update_review(_review(config, fuel_load))

func _on_choice(action: String, argument: String) -> void:
	match action:
		"planner":
			_pending_campaign_start = false
			_open_study()
		"start":
			if campaign_mode:
				if not _review(_config, _fuel_load).warnings.is_empty(): return
				_pending_campaign_start = true
				_open_study()
			else: start(_config, _fuel_load)
		"takeoff": takeoff(argument)
		"disembark": disembark()
		"finish": finish()
		"recover": recover()
		"resume": _resume()
		"restart":
			_cancel_transition()
			get_tree().set_meta("blue_horizon_expedition_seed", expedition_seed + 1)
			get_tree().reload_current_scene()
		"quit": get_tree().quit()

func _open_study() -> void:
	if study_planner == null:
		study_planner = TraverseLab.new()
		study_planner.close_requested.connect(func() -> void:
			_pending_campaign_start = false
			study_planner.close())
		study_planner.solution_presented.connect(func(_plan: Dictionary) -> void:
			if not _pending_campaign_start: return
			_pending_campaign_start = false
			study_planner.close()
			if start(_config, _fuel_load): mission_control.close_briefing())
		add_child(study_planner)
	study_planner.open("moon")

func start(config: Dictionary, fuel_load: String) -> bool:
	if campaign_mode:
		expedition = Campaign.begin(Campaign.create(config, fuel_load, expedition_seed))
		if expedition.phase != "flight": return false
		ui.hide_screen()
		mission_control.show_briefing(Campaign.TITLE, Campaign.BRIEFING)
		_show_space("moon")
		_campaign_tick()
		return true
	expedition = Expedition.begin(Expedition.create(config, fuel_load, expedition_seed))
	if expedition.phase != "surface": return false
	ui.hide_screen()
	_show_surface()
	return true

func _on_briefing_closed() -> void:
	if ui.active == "" and current and "paused" in current: current.paused = false
	if expedition.has("campaign"): mission_control.say(str(expedition.campaign.message))

# ------------------------------------------------------------------------------------------- campaign

func _objective_info() -> Dictionary:
	if not expedition.has("campaign"): return {}
	var o: Dictionary = Campaign.current(expedition)
	if o.is_empty(): return {"header": "FIRST LIGHT  ·  COMPLETE", "title": "Campaign complete"}
	var info: Dictionary = {"header": "FIRST LIGHT  ·  %s CHAPTER  ·  %d/%d" % [str(o.chapter).to_upper(),
		expedition.campaign.completed.size(), Campaign.OBJECTIVES.size()], "title": o.title}
	if expedition.phase == "surface":
		for beacon in Campaign.checkpoints_for(expedition, expedition.location):
			if beacon.active:
				info["distance"] = Vector2(beacon.position.x - Expedition.mission(expedition).position.x,
					beacon.position.z - Expedition.mission(expedition).position.z).length()
	return info

## Re-evaluate the campaign, announce changes and push simulation-side changes (storm forecasts) and
## checkpoint beacons to the active scene.
func _campaign_tick() -> void:
	if not expedition.has("campaign"): return
	var location: String = str(expedition.location)
	var before: Dictionary = expedition.missions.get(location, {})
	expedition = Campaign.evaluate(expedition)
	if int(expedition.campaign.message_id) != _message_id:
		_message_id = int(expedition.campaign.message_id)
		if not mission_control.briefing_open: mission_control.say(str(expedition.campaign.message))
	if expedition.phase == "surface" and current and current.has_method("set_checkpoints"):
		var after: Dictionary = expedition.missions.get(location, {})
		if after.get("weather", {}) != before.get("weather", {}): current.state.weather = after.weather.duplicate(true)
		var beacons: Array = Campaign.checkpoints_for(expedition, location)
		var key: String = var_to_str(beacons)
		if key != _beacon_key:
			_beacon_key = key
			current.set_checkpoints(beacons)

# ------------------------------------------------------------------------------------------- surface

func _surface_info() -> Dictionary:
	var def: Dictionary = Destinations.get_def(expedition.location)
	var notes: String = ""
	if expedition.location == "mars":
		notes = "Solar output is 43% of the Moon's (derived from Mars's 1.5 AU distance) and drops further in dust storms (fictional ×0.35). The shelter recharges fully in any weather.\nOnly scan data can be transmitted: sample science counts when cores are flown home."
	else:
		notes = "Home base. Transmit data from here; land here with Mars sample cores to deliver them.\nSolar power works east of x = -18. The ship relays data and repairs the rover when you board."
	return {"ship_fuel": expedition.ship.fuel, "cores": expedition.cores.size(), "notes": notes,
		"subtitle": "%s  /  SURFACE GRAVITY %.2f m/s² (NASA)" % [str(def.name).to_upper(), def.gravity],
		"objective": _objective_info()}

func _show_surface() -> void:
	_replace_current(SurfaceScene.new())
	current.setup(expedition.location, Expedition.mission(expedition), _surface_info())
	current.mission_changed.connect(_on_mission_changed)
	current.board_requested.connect(board)
	current.menu_requested.connect(_pause)
	current.paused = _menu_open()
	add_child(current)
	_beacon_key = ""
	_campaign_tick()
	phase_changed.emit(expedition.phase)

func _on_mission_changed(state: Dictionary) -> void:
	if expedition.phase != "surface": return
	expedition.missions[expedition.location] = state
	_campaign_tick()
	current.info = _surface_info()

func board() -> void:
	if current and current.has_method("try_board"): expedition.missions[expedition.location] = current.state
	expedition = Expedition.board(expedition)
	if expedition.phase != "aboard": return
	current.paused = true
	_campaign_tick()
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
	var objective: Dictionary = _objective_info()
	if not objective.is_empty(): lines.append("Objective: %s" % objective.title)
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

# ------------------------------------------------------------------------------------------- flight

func _show_space(target: String) -> void:
	_replace_current(SpaceScene.new())
	var status: String = "%d sample core%s aboard" % [expedition.cores.size(), "" if expedition.cores.size() == 1 else "s"]
	if expedition.has("campaign"): status = "Objective: " + str(_objective_info().get("title", "")) + "  ·  " + status
	current.setup(expedition.ship, target, status)
	current.ship_changed.connect(_on_ship_changed)
	current.land_requested.connect(land)
	current.menu_requested.connect(_pause)
	current.paused = _menu_open()
	add_child(current)
	phase_changed.emit(expedition.phase)

func _replace_current(next: Node) -> void:
	if current and is_instance_valid(current):
		remove_child(current)
		current.queue_free()
	current = next

func _on_ship_changed(ship: Dictionary) -> void:
	if expedition.get("phase", "") != "flight": return
	expedition.ship = ship

func takeoff(target: String) -> void:
	var next: Dictionary = Expedition.takeoff(expedition, target)
	if next.phase != "flight":
		expedition = next
		_show_aboard(str(next.log[0]))
		return
	var origin: Dictionary = Destinations.get_def(expedition.location)
	var burned: float = float(expedition.ship.fuel) - float(next.ship.fuel)
	expedition = next
	_campaign_tick()
	ui.hide_screen()
	var token: int = _begin_transition()
	transition.play("ASCENT FROM %s" % str(origin.name).to_upper(), [
		"Ascent burn: %d kg at %d kg ship mass." % [roundi(burned), roundi(Ship.total_mass(expedition.ship) + burned)],
		"Surface gravity %.2f m/s² (NASA). Ascent Δv in this game scales with it." % origin.gravity,
		"Real trip to %s: %s. Here distances and times are compressed." % [Destinations.get_def(target).name, Destinations.get_def(target).real_travel]])
	await transition.covered
	if not _transition_current(token, "flight"): return
	_show_space(target)

# ------------------------------------------------------------------------------------------- landing

## L in the space scene: start the player-controlled final descent (descent fuel is charged once here).
func land(id: String) -> void:
	if expedition.phase != "flight": return
	var before_fuel: float = float(expedition.ship.fuel)
	var next: Dictionary = Expedition.begin_landing(expedition, id, landing_assist)
	if next.phase != "landing": return
	expedition = next
	current.paused = true
	var token: int = _begin_transition()
	var def: Dictionary = Destinations.get_def(id)
	transition.play("FINAL DESCENT: %s" % str(def.name).to_upper(), [
		"Descent burn: %d kg. Fuel left: %d kg." % [roundi(before_fuel - float(expedition.ship.fuel)), roundi(expedition.ship.fuel)],
		"You have the controls: W/S throttle, arrow keys to steer over the pad, T for the landing assist.",
		"Surface gravity %.2f m/s² (NASA). A missed landing can be retried from the approach point at no extra fuel." % def.gravity], 1.6)
	await transition.covered
	if not _transition_current(token, "landing"): return
	_show_landing(id)

func _show_landing(id: String) -> void:
	_replace_current(LandingScene.new())
	var known: Array = expedition.missions.get(id, {}).get("sites", [])
	current.setup(id, expedition.landing, known)
	current.retry_requested.connect(retry_landing)
	current.assist_toggled.connect(set_landing_assist)
	current.menu_requested.connect(_pause)
	current.paused = _menu_open()
	add_child(current)
	phase_changed.emit(expedition.phase)

func retry_landing() -> void:
	if expedition.get("phase", "") != "landing": return
	expedition = Expedition.retry_landing(expedition)
	if current and current.has_method("show_landing"): current.show_landing(expedition.landing)

func set_landing_assist(on: bool) -> void:
	if expedition.get("phase", "") != "landing": return
	expedition = Expedition.set_landing_assist(expedition, on)
	if current and current.has_method("show_landing"): current.show_landing(expedition.landing)

func _physics_process(delta: float) -> void:
	if expedition.get("phase", "") == "flight" and expedition.has("campaign"):
		_flight_clock += delta
		if _flight_clock >= 0.5:
			_flight_clock = 0.0
			_campaign_tick()
	if expedition.get("phase", "") != "landing" or current == null or not current.has_method("read_input") or current.paused: return
	var before: String = str(expedition.landing.status)
	var id: String = str(expedition.landing.destination)
	expedition = Expedition.step_landing(expedition, current.read_input(), delta)
	if expedition.phase == "aboard":
		_touchdown(id)
		return
	current.show_landing(expedition.landing)
	if expedition.landing.status == "failed" and before != "failed":
		mission_control.say("Unsafe touchdown, aborted safely. Press R to retry from the approach point.")

func _touchdown(id: String) -> void:
	var landed: Dictionary = current.landing.duplicate()
	landed.altitude = 0.0
	landed.status = "landed"
	landed.throttle = 0.0
	current.show_landing(landed)
	current.paused = true
	_campaign_tick()
	var token: int = _begin_transition()
	var def: Dictionary = Destinations.get_def(id)
	var lines: Array = [str(expedition.log[0])]
	for fact in def.facts.slice(0, 2): lines.append("%s (NASA)" % fact.text)
	lines.append(def.fiction)
	transition.play("TOUCHDOWN: %s" % str(def.name).to_upper(), lines, 2.0)
	await transition.covered
	if not _transition_current(token, "aboard"): return
	expedition = Expedition.disembark(expedition)
	_show_surface()

# ------------------------------------------------------------------------------------------- menus

## Campaign recovery from the pause menu: back to the last checkpoint for the current phase. Progress,
## science, findings, cores and deliveries are untouched (simulation/campaign.gd).
func recover() -> void:
	if not expedition.has("campaign") or expedition.phase in ["complete", "planning"]: return
	expedition = Campaign.recover(expedition)
	ui.hide_screen()
	match str(expedition.phase):
		"surface":
			if current.has_method("apply_state"): current.apply_state(Expedition.mission(expedition))
		"flight":
			if current.has_method("try_land"):
				current.ship = expedition.ship.duplicate(true)
				current.rig.apply(current.ship)
				current.camera.snap_now()
		"landing":
			if current.has_method("show_landing"): current.show_landing(expedition.landing)
		"aboard":
			_show_aboard()
			return
	# Same rule as resume: unpause unless a transition is still handing over to a different scene.
	if current and "paused" in current and not mission_control.briefing_open and (not transition.playing or _scene_matches_phase()):
		current.paused = false
	_campaign_tick()

func finish() -> void:
	var was_complete: bool = expedition.get("phase", "") == "complete"
	_cancel_transition()
	expedition = Expedition.finish(expedition)
	_campaign_tick()
	if current and "paused" in current: current.paused = true
	ui.show_report(Expedition.report(expedition), Campaign.summary(expedition))
	if campaign_mode and not was_complete:
		if debrief_film == null:
			debrief_film = Cinematic.new()
			add_child(debrief_film)
		var summary: Dictionary = Campaign.summary(expedition)
		debrief_film.play("debrief", {"body": expedition.get("location", "moon"), "report": Expedition.report(expedition),
			"complete": summary.get("complete", false), "completed": summary.get("completed", 0), "total": summary.get("total", 12)})
	phase_changed.emit(expedition.phase)

func _pause() -> void:
	if expedition.get("phase", "") == "complete": return
	if current and "paused" in current: current.paused = true
	ui.show_pause(expedition.has("campaign"))

func _resume() -> void:
	if expedition.phase == "aboard":
		_show_aboard()
		return
	ui.hide_screen()
	if not current or not "paused" in current or mission_control.briefing_open: return
	# During a takeoff, descent or touchdown transition the outgoing scene stays paused; the continuation
	# installs the next scene unpaused because the menu is now closed.
	if transition.playing and not _scene_matches_phase(): return
	current.paused = false

func _scene_matches_phase() -> bool:
	match expedition.phase:
		"surface": return current.has_method("try_board")
		"flight": return current.has_method("try_land")
		"landing": return current.has_method("read_input")
	return false
