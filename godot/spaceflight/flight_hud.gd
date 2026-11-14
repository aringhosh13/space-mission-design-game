extends CanvasLayer
## Flight HUD. Purely presentational: show_flight() receives a dictionary prepared by the scene from
## simulation values (ship_flight.gd / expedition.gd). It never computes rules or hidden information.
##
## Expected keys of `data` (all optional except speed/fuel/fuel_capacity/mass):
##   speed, throttle, braking, fuel, fuel_capacity, delta_v, mass {hull, cargo, fuel, total},
##   destination_line, target {name, distance, closing_speed, eta, in_approach, speed_ok, landable,
##   landing_fuel, landing_speed_limit, real_distance, real_travel, note}, prompt, warnings: Array[String]

const AMBER := Color("f3c582")
const MINT := Color("a7d9bb")
const TEXT := Color("d8e5dd")
const DIM := Color("8fa6ae")
const WARN := Color("ff9b6b")

var root: Control
var speed_label: Label
var throttle_bar: ColorRect
var brake_label: Label
var fuel_bar: ColorRect
var fuel_label: Label
var dv_label: Label
var mass_label: Label
var destination_label: Label
var target_title: Label
var target_body: Label
var prompt_label: Label
var warning_label: Label
var marker: Label
var controls_label: Label

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_label(root, "BLUE HORIZON  /  FLIGHT", 22, TEXT, Vector2(28, 18))
	destination_label = _label(root, "", 14, AMBER, Vector2(30, 50))

	var left := _panel(Vector2(24, 92), Vector2(300, 286))
	_label(left, "VELOCITY", 11, DIM, Vector2(16, 10))
	speed_label = _label(left, "0.0 u/s", 30, TEXT, Vector2(16, 24))
	_label(left, "THRUST", 11, DIM, Vector2(16, 74))
	throttle_bar = _bar(left, Vector2(80, 80), Vector2(200, 8), MINT)
	brake_label = _label(left, "", 11, Color("ffb37a"), Vector2(16, 92))
	_label(left, "FUEL", 11, DIM, Vector2(16, 116))
	fuel_bar = _bar(left, Vector2(80, 122), Vector2(200, 8), AMBER)
	fuel_label = _label(left, "", 14, TEXT, Vector2(16, 136))
	dv_label = _label(left, "", 14, TEXT, Vector2(16, 160))
	mass_label = _label(left, "", 12, DIM, Vector2(16, 190))

	var right := _panel(Vector2(936, 92), Vector2(320, 286))
	target_title = _label(right, "", 18, AMBER, Vector2(16, 10))
	target_body = _label(right, "", 13, TEXT, Vector2(16, 40))
	target_body.size = Vector2(290, 240)
	target_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	marker = _label(root, "", 13, AMBER, Vector2.ZERO)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.size = Vector2(220, 40)

	prompt_label = _label(root, "", 22, AMBER, Vector2(240, 560))
	prompt_label.size = Vector2(800, 36)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label = _label(root, "", 15, WARN, Vector2(240, 600))
	warning_label.size = Vector2(800, 60)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label = _label(root, "W THRUST   S BRAKE   A/D STEER   R/F PITCH   C ALIGN TO TARGET   TAB DESTINATION   L LAND   ESC MENU", 12, Color("c1d7d4"), Vector2(30, 672))
	_label(root, "COMPRESSED DISTANCES AND TIMES  ·  FICTIONAL SHIP VALUES  ·  REAL FIGURES ARE LABELLED", 10, Color("7f999f"), Vector2(30, 696))

func _panel(at: Vector2, size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.09, 0.82)
	style.border_color = Color("334a57")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	return panel

func _label(parent: Node, text: String, font_size: int, color: Color, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

## Thin bar: a dim track with a coloured fill ColorRect returned for set_bar().
func _bar(parent: Node, at: Vector2, size: Vector2, color: Color) -> ColorRect:
	var track := ColorRect.new()
	track.position = at
	track.size = size
	track.color = Color(1, 1, 1, 0.08)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(track)
	var fill := ColorRect.new()
	fill.size = Vector2(0, size.y)
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_meta("full_width", size.x)
	track.add_child(fill)
	return fill

func set_bar(fill: ColorRect, ratio: float) -> void:
	fill.size.x = float(fill.get_meta("full_width")) * clampf(ratio, 0.0, 1.0)

func show_flight(data: Dictionary) -> void:
	speed_label.text = "%.1f u/s" % float(data.get("speed", 0.0))
	set_bar(throttle_bar, float(data.get("throttle", 0.0)))
	brake_label.text = "RETRO THRUSTERS FIRING" if float(data.get("braking", 0.0)) > 0.01 else ""
	var capacity: float = maxf(1.0, float(data.get("fuel_capacity", 1.0)))
	set_bar(fuel_bar, float(data.get("fuel", 0.0)) / capacity)
	fuel_label.text = "%d / %d kg propellant" % [roundi(data.get("fuel", 0.0)), roundi(capacity)]
	dv_label.text = "Δv LEFT  %d u/s" % roundi(data.get("delta_v", 0.0))
	var mass: Dictionary = data.get("mass", {})
	if not mass.is_empty():
		mass_label.text = "MASS  %d kg\nhull %d · cargo %d · fuel %d\nHeavier ships get less Δv per kg of fuel." % [
			roundi(mass.get("total", 0)), roundi(mass.get("hull", 0)), roundi(mass.get("cargo", 0)), roundi(mass.get("fuel", 0))]
	destination_label.text = str(data.get("destination_line", ""))
	var target: Dictionary = data.get("target", {})
	if target.is_empty():
		target_title.text = "NO DESTINATION"
		target_body.text = ""
	else:
		target_title.text = str(target.get("name", "")).to_upper()
		var lines: PackedStringArray = []
		lines.append("DISTANCE   %d u" % roundi(target.get("distance", 0.0)))
		var closing: float = float(target.get("closing_speed", 0.0))
		lines.append("CLOSING    %+.1f u/s" % closing)
		var eta: float = float(target.get("eta", -1.0))
		lines.append("ETA        %s" % ("%d s" % roundi(eta) if eta >= 0.0 else "not closing"))
		if target.has("real_distance"): lines.append("Real: %s" % target.real_distance)
		if target.has("real_travel"): lines.append("Real travel: %s" % target.real_travel)
		lines.append("")
		if bool(target.get("landable", false)):
			lines.append("APPROACH ZONE  %s" % ("INSIDE" if target.get("in_approach", false) else "outside"))
			lines.append("LANDING SPEED  below %.0f u/s %s" % [float(target.get("landing_speed_limit", 0.0)), "✓" if target.get("speed_ok", false) else ""])
			lines.append("DESCENT FUEL   %d kg" % roundi(target.get("landing_fuel", 0.0)))
		else:
			lines.append("LANDMARK ONLY. Not a landing destination yet.")
		if target.has("note"): lines.append(str(target.note))
		target_body.text = "\n".join(lines)
	prompt_label.text = str(data.get("prompt", ""))
	var warnings: Array = data.get("warnings", [])
	warning_label.text = "\n".join(PackedStringArray(warnings))

## Place the target marker over its on-screen position, or at the screen edge pointing toward it.
func place_marker(camera: Camera3D, world_position: Vector3, text: String) -> void:
	if camera == null or not camera.is_inside_tree():
		marker.visible = false
		return
	marker.visible = true
	var viewport_size: Vector2 = root.get_viewport_rect().size
	var behind: bool = camera.is_position_behind(world_position)
	var screen: Vector2 = camera.unproject_position(world_position)
	var centre: Vector2 = viewport_size * 0.5
	var margin := Vector2(90, 70)
	var on_screen: bool = not behind and Rect2(margin, viewport_size - margin * 2.0).has_point(screen)
	if on_screen:
		marker.text = "◇\n" + text
		marker.position = screen - Vector2(110, 10)
	else:
		var direction: Vector2 = (screen - centre)
		if behind: direction = -direction
		if direction.length() < 0.001: direction = Vector2.DOWN
		var half: Vector2 = centre - margin
		var scale: float = minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
		var edge: Vector2 = centre + direction * scale
		var arrows: Array[String] = ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
		var index: int = int(round(direction.angle() / (PI / 4.0))) % 8
		marker.text = arrows[(index + 8) % 8] + "\n" + text
		marker.position = edge - Vector2(110, 10)
