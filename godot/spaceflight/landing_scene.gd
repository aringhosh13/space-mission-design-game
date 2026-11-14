extends Node3D
## Player-controlled final descent onto a destination's landing pad (presentation + input only).
## The authoritative descent lives in simulation/landing.gd via expedition.step_landing(); the owner feeds
## the result back with show_landing() every physics frame.
##
## Integration API:
##   setup(destination_id, landing: Dictionary, sites: Array = [])   call before add_child()
##   read_input() -> Dictionary        {throttle?, x, z} from the keyboard (or input_override)
##   show_landing(landing)              mirror the simulation state
##   signal retry_requested             R after an unsafe touchdown
##   signal assist_toggled(on: bool)    T
##   signal menu_requested              Escape
##   var paused: bool, var input_override: Variant (Dictionary for tests/drivers)
##
## Controls: W/S throttle lever up/down, X cut throttle, arrow keys or I/J/K/L for sideways thrusters
## (camera faces north: ↑ north, ↓ south, ← west, → east), T landing assist, R retry, Esc menu.
const Destinations = preload("res://simulation/destinations.gd")
const Landing = preload("res://simulation/landing.gd")
const LunarWorld = preload("res://scripts/lunar_world.gd")
const MarsWorld = preload("res://spaceflight/mars_world.gd")
const ShipModel = preload("res://spaceflight/ship_model.gd")

signal retry_requested
signal assist_toggled(on: bool)
signal menu_requested

const LEVER_RATE: float = 1.2
const SHIP_FOOT_HEIGHT: float = 2.62

var destination_id: String = "moon"
var landing: Dictionary = {}
var sites: Array = []
var paused: bool = false
var input_override: Variant = null
var world: Node3D
var ship: Node3D
var camera: Camera3D
var pad_position: Vector3
var lever: float = 0.0
var lever_touched: bool = false
var hud: CanvasLayer
var labels: Dictionary = {}
var alignment: Control

func setup(id: String, initial: Dictionary, known_sites: Array = []) -> void:
	destination_id = id
	landing = initial.duplicate(true)
	sites = known_sites.duplicate(true)

func _ready() -> void:
	var def: Dictionary = Destinations.get_def(destination_id)
	var rules: Dictionary = Destinations.surface_rules(destination_id)
	world = LunarWorld.new() if def.world == "lunar" else MarsWorld.new()
	if world.has_method("configure_extent"): world.configure_extent(float(rules.map_limit))
	add_child(world)
	world.build(sites)
	pad_position = def.pad
	pad_position.y = world.terrain_height(pad_position.x, pad_position.z)
	_pad_target()
	ship = ShipModel.new()
	add_child(ship)
	ship.landing_gear(true)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 2000.0
	add_child(camera)
	camera.current = true
	_build_hud()
	show_landing(landing)
	_place_camera(1.0)

func _pad_target() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("f3c582")
	var ring := TorusMesh.new()
	ring.inner_radius = Landing.PAD_RADIUS - 0.5
	ring.outer_radius = Landing.PAD_RADIUS
	ring.rings = 64
	var outer := MeshInstance3D.new()
	outer.mesh = ring
	outer.material_override = material
	outer.position = pad_position + Vector3(0, 0.15, 0)
	add_child(outer)
	for angle in [0.0, PI / 2.0]:
		var bar := BoxMesh.new()
		bar.size = Vector3(10, 0.1, 0.6)
		var cross := MeshInstance3D.new()
		cross.mesh = bar
		cross.material_override = material
		cross.position = pad_position + Vector3(0, 0.2, 0)
		cross.rotation.y = angle
		add_child(cross)
	var light := OmniLight3D.new()
	light.position = pad_position + Vector3(0, 3, 0)
	light.light_color = Color("ffd9a0")
	light.light_energy = 2.0
	light.omni_range = 30.0
	add_child(light)

func _ship_position(l: Dictionary) -> Vector3:
	var offset: Vector2 = l.get("offset", Vector2.ZERO)
	var x: float = pad_position.x + offset.x
	var z: float = pad_position.z + offset.y
	var ground: float = maxf(world.terrain_height(x, z), pad_position.y)
	return Vector3(x, ground + SHIP_FOOT_HEIGHT + float(l.get("altitude", 0.0)), z)

func show_landing(l: Dictionary) -> void:
	landing = l.duplicate(true)
	if ship == null: return
	ship.position = _ship_position(landing)
	var tilt: Vector2 = (landing.get("lateral_velocity", Vector2.ZERO) as Vector2) * 0.04
	ship.rotation = Vector3(clampf(-tilt.y, -0.25, 0.25), 0.0, clampf(-tilt.x, -0.25, 0.25))
	ship.set_engine(0.0, 0.0)
	ship.set_descent(float(landing.get("throttle", 0.0)))
	if not lever_touched or bool(landing.get("assist", false)): lever = float(landing.get("throttle", 0.0))
	_update_hud()

func _place_camera(weight: float) -> void:
	# Frame both the ship and the pad: behind and above the ship, looking at the point between them.
	var target: Vector3 = ship.position
	var altitude: float = maxf(0.0, target.y - pad_position.y)
	var desired: Vector3 = target + Vector3(0, 10.0 + altitude * 0.1, 26.0 + altitude * 0.18)
	camera.global_position = camera.global_position.lerp(desired, weight) if weight < 1.0 else desired
	camera.look_at(target.lerp(pad_position, 0.3), Vector3.UP)

func _process(delta: float) -> void:
	if camera and ship: _place_camera(1.0 - exp(-4.0 * delta))
	if paused or input_override is Dictionary: return
	var up: bool = Input.is_physical_key_pressed(KEY_W)
	var down: bool = Input.is_physical_key_pressed(KEY_S)
	if up or down:
		lever_touched = true
		lever = clampf(lever + (LEVER_RATE if up else -LEVER_RATE) * delta, 0.0, 1.0)

## Keyboard (or override) input for expedition.step_landing(). With the assist on, the throttle is only
## sent while the player holds W/S, so the assist flies whatever the player leaves alone.
func read_input() -> Dictionary:
	if input_override is Dictionary: return (input_override as Dictionary).duplicate()
	var x: float = float(_down([KEY_RIGHT, KEY_L])) - float(_down([KEY_LEFT, KEY_J]))
	var z: float = float(_down([KEY_DOWN, KEY_K])) - float(_down([KEY_UP, KEY_I]))
	var input: Dictionary = {"x": x, "z": z}
	var holding: bool = Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_S)
	if not bool(landing.get("assist", false)) or holding: input["throttle"] = lever
	return input

func _down(keys: Array) -> bool:
	for key in keys:
		if Input.is_physical_key_pressed(key): return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_ESCAPE: menu_requested.emit()
		KEY_T:
			if not paused: assist_toggled.emit(not bool(landing.get("assist", false)))
		KEY_R:
			if not paused and landing.get("status", "") == "failed": retry_requested.emit()
		KEY_X:
			lever = 0.0
			lever_touched = true

# ------------------------------------------------------------------------------------------- HUD

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.09, 0.82)
	style.border_color = Color("334a57")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	var panel := Panel.new()
	panel.position = Vector2(24, 86)
	panel.size = Vector2(320, 330)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	labels.title = _label(root, "FINAL DESCENT  /  " + str(Destinations.get_def(destination_id).name).to_upper(), 22, Color("d8e5dd"), Vector2(28, 18))
	labels.subtitle = _label(root, "Surface gravity %.2f m/s² (NASA). Engine, envelope and allowance are fictional game values." % Landing.gravity(destination_id), 11, Color("a4c2c6"), Vector2(30, 52))
	labels.readout = _label(panel, "", 16, Color("d8e5dd"), Vector2(16, 12))
	labels.envelope = _label(panel, "", 12, Color("b8c9b0"), Vector2(16, 236))
	labels.assist = _label(root, "", 20, Color("8ce9d2"), Vector2(930, 22))
	labels.status = _label(root, "", 20, Color("f3c582"), Vector2(240, 560))
	labels.status.size = Vector2(800, 80)
	labels.status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(root, "W/S THROTTLE   X CUT   ARROWS / IJKL SIDE THRUSTERS (↑ NORTH)   T LANDING ASSIST   R RETRY   ESC MENU", 12, Color("c1d7d4"), Vector2(30, 674))
	alignment = Control.new()
	alignment.position = Vector2(1040, 110)
	alignment.size = Vector2(200, 200)
	alignment.draw.connect(_draw_alignment)
	root.add_child(alignment)

func _label(parent: Node, text: String, size: int, color: Color, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _update_hud() -> void:
	if labels.is_empty(): return
	var ok: Dictionary = Landing.in_envelope(landing)
	var offset: Vector2 = landing.get("offset", Vector2.ZERO)
	var drift: float = (landing.get("lateral_velocity", Vector2.ZERO) as Vector2).length()
	labels.readout.text = "ALTITUDE      %5.1f m\nVERTICAL      %+5.1f m/s %s\nDRIFT          %4.1f m/s %s\nTO PAD         %4.1f m %s\n\nTHROTTLE      %3d%%\nALLOWANCE    %4.1f s of thrust\nATTEMPT        %d" % [
		float(landing.get("altitude", 0.0)), float(landing.get("vertical_speed", 0.0)), "✓" if ok.vertical else "!",
		drift, "✓" if ok.lateral else "!", offset.length(), "✓" if ok.pad else "!",
		roundi(float(landing.get("throttle", 0.0)) * 100.0), float(landing.get("allowance", 0.0)), int(landing.get("attempts", 1))]
	labels.envelope.text = "SAFE TOUCHDOWN (generous):\n  slower than %.0f m/s down\n  drifting under %.0f m/s\n  within %d m of the pad centre" % [Landing.MAX_TOUCHDOWN_SPEED, Landing.MAX_LATERAL_SPEED, int(Landing.PAD_RADIUS)]
	var assist: bool = bool(landing.get("assist", false))
	labels.assist.text = "LANDING ASSIST: %s  [T]" % ("ON" if assist else "OFF")
	labels.assist.add_theme_color_override("font_color", Color("8ce9d2") if assist else Color("8fa6ae"))
	match str(landing.get("status", "")):
		"failed": labels.status.text = "%s\n[R] Retry from the approach point (no extra fuel)" % str(landing.get("reason", ""))
		"landed": labels.status.text = "TOUCHDOWN"
		_: labels.status.text = "Ease the descent over the pad. Hold the vertical speed under %.0f m/s near the ground." % Landing.MAX_TOUCHDOWN_SPEED if float(landing.get("altitude", 0.0)) < 30.0 else ""
	alignment.queue_redraw()

func _draw_alignment() -> void:
	var centre := Vector2(100, 100)
	alignment.draw_circle(centre, 96, Color(0.02, 0.05, 0.09, 0.8))
	alignment.draw_arc(centre, 96, 0, TAU, 48, Color("334a57"), 1.5)
	var scale: float = 80.0 / 40.0
	alignment.draw_arc(centre, Landing.PAD_RADIUS * scale, 0, TAU, 48, Color("f3c582"), 2.0)
	var offset: Vector2 = landing.get("offset", Vector2.ZERO)
	var dot: Vector2 = centre + (offset * scale).limit_length(92.0)
	var velocity: Vector2 = landing.get("lateral_velocity", Vector2.ZERO)
	alignment.draw_line(dot, dot + (velocity * scale * 2.0).limit_length(60.0), Color("8ce9d2"), 2.0)
	alignment.draw_circle(dot, 6, Color("e3e8d4"))
	alignment.draw_string(ThemeDB.fallback_font, Vector2(76, 14), "N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8fa6ae"))
