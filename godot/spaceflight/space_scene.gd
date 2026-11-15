extends Node3D
## Reusable space-travel scene: Moon, Earth and Mars at compressed distances, a player-controlled ship,
## destination selection, approach guidance and landing requests.
##
## Integration API:
##   setup(ship: Dictionary, target_id: String, home_line: String = "")  call before add_child()
##   signal land_requested(destination_id: String)   L pressed with a valid approach; the owner decides
##   signal menu_requested()                          Escape
##   signal ship_changed(ship: Dictionary)            every physics frame
##   var ship: Dictionary                             authoritative ship state (simulation/ship_flight.gd)
##   var paused: bool                                 freezes flight and input
##   var input_override: Variant                      tests/autopilots: a Dictionary replaces the keyboard
##   func select_target(id), cycle_target(), try_land() -> bool
const Ship = preload("res://simulation/ship_flight.gd")
const Travel = preload("res://simulation/travel.gd")
const Destinations = preload("res://simulation/destinations.gd")
const Pilot = preload("res://spaceflight/pilot_input.gd")
const ShipRig = preload("res://spaceflight/ship_rig.gd")
const ChaseCamera = preload("res://spaceflight/chase_camera.gd")
const SpaceSky = preload("res://spaceflight/space_sky.gd")
const FlightHUD = preload("res://spaceflight/flight_hud.gd")
const PlanetBody = preload("res://spaceflight/planet_body.gd")

signal land_requested(destination_id: String)
signal menu_requested
signal ship_changed(ship: Dictionary)

var ship: Dictionary = Ship.create(650.0, 87.0, Vector3(0, 0, 80))
var target_id: String = "mars"
var paused: bool = false
var input_override: Variant = null
var status_line: String = ""
var rig: Node3D
var camera: Camera3D
var hud: CanvasLayer
var planets: Dictionary = {}
var _flash: String = ""
var _flash_time: float = 0.0

func setup(start_ship: Dictionary, target: String, extra_status: String = "") -> void:
	ship = start_ship.duplicate(true)
	target_id = target
	status_line = extra_status

func _ready() -> void:
	add_child(SpaceSky.new())
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.4
	sun.light_color = Color("fff1dc")
	add_child(sun)
	sun.look_at_from_position(Vector3(4000, 900, 1200), Vector3.ZERO, Vector3.UP)
	for id in Destinations.ids():
		var planet: Node3D = PlanetBody.new()
		planet.setup(Destinations.get_def(id))
		add_child(planet)
		planets[id] = planet
	rig = ShipRig.new()
	add_child(rig)
	camera = ChaseCamera.new()
	camera.target = rig
	camera.current = true
	add_child(camera)
	rig.apply(ship)
	camera.snap_now()   # place the camera before the first HUD update projects anything
	hud = FlightHUD.new()
	add_child(hud)
	select_target(target_id)

func select_target(id: String) -> void:
	if not id in Destinations.ids(): return
	target_id = id
	for key in planets: planets[key].set_targeted(key == id)

func cycle_target() -> void:
	var ids: Array = Destinations.ids()
	select_target(ids[(ids.find(target_id) + 1) % ids.size()])

func try_land() -> bool:
	var g: Dictionary = Travel.guidance(ship, target_id)
	if g.can_land:
		land_requested.emit(target_id)
		return true
	_flash = " ".join(g.reasons)
	_flash_time = 3.0
	return false

func _unhandled_input(event: InputEvent) -> void:
	if paused or not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_TAB: cycle_target()
		KEY_L: try_land()
		KEY_ESCAPE: menu_requested.emit()

func _physics_process(delta: float) -> void:
	if paused:
		var idle: Dictionary = ship.duplicate()
		idle.throttle = 0.0
		idle.braking = 0.0
		rig.apply(idle)
		return
	var input: Dictionary = (input_override as Dictionary).duplicate() if input_override is Dictionary else Pilot.read()
	if input.get("align", false) or (input_override == null and Input.is_physical_key_pressed(KEY_C)):
		var direction: Vector3 = Destinations.get_def(target_id).space.position - (ship.position as Vector3)
		input.merge(Pilot.align_toward(ship, direction), true)
	ship = Travel.fly(ship, input, delta)
	rig.apply(ship)
	camera.speed_hint = Ship.speed(ship)
	ship_changed.emit(ship)
	_flash_time = maxf(0.0, _flash_time - delta)
	_update_hud()

func _update_hud() -> void:
	var g: Dictionary = Travel.guidance(ship, target_id)
	var def: Dictionary = Destinations.get_def(target_id)
	var names: PackedStringArray = []
	for id in Destinations.ids():
		var n: String = str(Destinations.get_def(id).name).to_upper()
		if not Destinations.is_explorable(id): n += " (landmark)"
		names.append(("▶ " + n) if id == target_id else n)
	var warnings: Array[String] = []
	var dv_left: float = Ship.delta_v_remaining(ship)
	if g.landable:
		var need: float = Travel.round_trip_delta_v(ship, target_id)
		if dv_left < need:
			warnings.append("Δv left %d u/s is below the ~%d u/s estimated to land here%s at %d u/s cruise." % [
				roundi(dv_left), roundi(need), "" if target_id == Destinations.HOME else " and fly home", roundi(Travel.PLANNING_CRUISE)])
	if float(ship.fuel) <= 0.0: warnings.append("Fuel exhausted: you can only coast.")
	if _flash_time > 0.0: warnings.append(_flash)
	var prompt: String = ""
	if g.can_land: prompt = "[L] LAND ON %s  ·  descent burns ~%d kg" % [str(def.name).to_upper(), roundi(g.landing_fuel)]
	elif g.landable and g.in_approach and not g.speed_ok: prompt = "BRAKE [S] BELOW %.0f u/s TO LAND" % g.landing_speed_limit
	elif g.landable and g.distance < 400.0 and not g.in_approach: prompt = "APPROACH ZONE: %d u ABOVE THE SURFACE" % int(def.space.approach_altitude)
	var target: Dictionary = g.duplicate()
	target["real_distance"] = def.real_distance
	target["real_travel"] = def.real_travel
	hud.show_flight({
		"speed": Ship.speed(ship), "throttle": ship.throttle, "braking": ship.braking,
		"fuel": ship.fuel, "fuel_capacity": ship.fuel_capacity, "delta_v": dv_left,
		"mass": {"hull": ship.dry_mass, "cargo": ship.cargo_mass, "fuel": ship.fuel, "total": Ship.total_mass(ship)},
		"destination_line": "DESTINATION [TAB]   " + "    ".join(names) + ("    ·  " + status_line if status_line != "" else ""),
		"target": target, "prompt": prompt, "warnings": warnings,
	})
	hud.place_marker(camera, def.space.position, "%s  %d u" % [str(def.name).to_upper(), roundi(g.distance)])
	# Keep the navigation tag clear of telemetry panels, warnings and controls.
	hud.marker.position = hud.marker.position.clamp(Vector2(334, 94), Vector2(714, 510))
