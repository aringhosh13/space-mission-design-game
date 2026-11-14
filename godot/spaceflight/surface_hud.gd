extends CanvasLayer
## Surface HUD for spaceflight destinations. Presentational only: shows simulation state and owner-supplied
## expedition info. Reveals findings and confidence exactly as the simulation reports them, never hidden truth.
const Contract = preload("res://shared/mission_contract.gd")

const TEXT := Color("d8e5dd")
const AMBER := Color("f3c582")
const DIM := Color("8fa6ae")

var title: Label
var subtitle: Label
var telemetry: Label
var energy_fill: ColorRect
var site_list: Label
var target_label: Label
var log_label: Label
var notes_label: Label
var flash_label: Label
var objective_panel: Panel
var objective_label: Label
var _flash_time: float = 0.0

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	title = _label(root, "", 24, TEXT, Vector2(32, 20))
	subtitle = _label(root, "", 12, Color("a4c2c6"), Vector2(34, 54))
	var panel := Panel.new()
	panel.position = Vector2(992, 22)
	panel.size = Vector2(264, 236)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.09, 0.85)
	style.border_color = Color("334a57")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	telemetry = _label(panel, "", 14, TEXT, Vector2(16, 12))
	var track := ColorRect.new()
	track.position = Vector2(16, 36)
	track.size = Vector2(232, 6)
	track.color = Color(1, 1, 1, 0.08)
	panel.add_child(track)
	energy_fill = ColorRect.new()
	energy_fill.size = Vector2(232, 6)
	energy_fill.color = Color("a7d9bb")
	track.add_child(energy_fill)
	var column := Panel.new()
	column.position = Vector2(22, 86)
	column.size = Vector2(486, 556)
	var column_style := StyleBoxFlat.new()
	column_style.bg_color = Color(0.02, 0.04, 0.07, 0.62)
	column_style.set_corner_radius_all(6)
	column.add_theme_stylebox_override("panel", column_style)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)
	var prompt_back := Panel.new()
	prompt_back.position = Vector2(500, 556)
	prompt_back.size = Vector2(500, 80)
	prompt_back.add_theme_stylebox_override("panel", column_style)
	prompt_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt_back)
	objective_panel = Panel.new()
	objective_panel.position = Vector2(500, 18)
	objective_panel.size = Vector2(470, 74)
	objective_panel.add_theme_stylebox_override("panel", column_style)
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.visible = false
	root.add_child(objective_panel)
	objective_label = _label(objective_panel, "", 14, AMBER, Vector2(14, 8))
	objective_label.size = Vector2(446, 60)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	site_list = _label(root, "", 13, Color("cbdad9"), Vector2(34, 92))
	site_list.size = Vector2(380, 260)
	notes_label = _label(root, "", 12, Color("b8c9b0"), Vector2(34, 372))
	notes_label.size = Vector2(420, 100)
	notes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label = _label(root, "", 13, Color("b7cccd"), Vector2(34, 500))
	log_label.size = Vector2(462, 120)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_label = _label(root, "", 18, AMBER, Vector2(510, 562))
	target_label.size = Vector2(480, 70)
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flash_label = _label(root, "", 15, Color("ff9b6b"), Vector2(510, 640))
	flash_label.size = Vector2(480, 40)
	flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(root, "WASD DRIVE   RMB LOOK   E SCAN   Q SAMPLE   R POWER   T TRANSMIT   B STATION   G BOARD   H REPAIR   ESC MENU", 12, Color("c1d7d4"), Vector2(34, 674))
	_label(root, "FICTIONAL GAME VALUES  ·  REAL FIGURES ARE LABELLED (NASA)", 10, Color("7f999f"), Vector2(34, 698))

func _label(parent: Node, text: String, font_size: int, color: Color, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

static func weather_text(weather: Dictionary) -> String:
	match str(weather.get("phase", "clear")):
		"warning": return "STORM WARNING  %d s" % ceili(weather.get("remaining_seconds", 0.0))
		"storm": return "DUST STORM %d s · SOLAR ×%.2f" % [ceili(weather.get("remaining_seconds", 0.0)), float(weather.get("solar_multiplier", 1.0))]
	return "WEATHER  CLEAR"

func flash(message: String) -> void:
	flash_label.text = message
	_flash_time = 3.5

func _process(delta: float) -> void:
	_flash_time = maxf(0.0, _flash_time - delta)
	if _flash_time <= 0.0: flash_label.text = ""

## info keys: title, subtitle, notes, ship_fuel, cores (int), board_distance, boarding_range,
## interaction_range, pad (Vector3)
func update_surface(state: Dictionary, info: Dictionary) -> void:
	title.text = str(info.get("title", "SURFACE"))
	subtitle.text = str(info.get("subtitle", ""))
	notes_label.text = str(info.get("notes", ""))
	var lines: PackedStringArray = []
	lines.append("POWER  %03d / %03d" % [roundi(state.energy), roundi(state.max_energy)])
	lines.append("")
	lines.append("ONBOARD  %d     RETURNED  %d" % [int(state.science_collected) - int(state.science_returned), int(state.science_returned)])
	if str(state.config.get("power", "")) == "fuel-cell": lines.append("FUEL CELLS  %d" % int(state.fuel_cells))
	if info.has("ship_fuel"): lines.append("SHIP FUEL  %d kg" % roundi(info.ship_fuel))
	if info.has("cores"): lines.append("SAMPLE CORES ABOARD  %d" % int(info.cores))
	if state.has("integrity"): lines.append("CONDITION  %d%%%s" % [roundi(state.integrity), "  (worn: more energy per metre)" if float(state.integrity) < 100.0 else ""])
	if state.has("weather"): lines.append(weather_text(state.weather))
	telemetry.text = "\n".join(lines)
	energy_fill.size.x = 232.0 * clampf(float(state.energy) / maxf(1.0, float(state.max_energy)), 0.0, 1.0)
	var interaction: float = float(info.get("interaction_range", Contract.INTERACTION_RANGE))
	var nearest: Dictionary = {}
	var nearest_distance: float = INF
	var text: String = "FIELD SIGNALS\n\n"
	for site in state.sites:
		var d: float = Contract.flat_distance(state.position, site.position)
		if d < nearest_distance:
			nearest = site
			nearest_distance = d
		text += "%s   %d m\n%s · %d%% certainty\n\n" % [site.name, roundi(d), Contract.FINDING_LABELS[site.finding], site.confidence]
	site_list.text = text
	var objective: Dictionary = info.get("objective", {})
	objective_panel.visible = not objective.is_empty()
	if objective_panel.visible:
		var distance: String = "  ·  %d m" % roundi(objective.distance) if objective.has("distance") else ""
		objective_label.text = "%s\n▶ %s%s" % [str(objective.get("header", "")), str(objective.get("title", "")), distance]
	var board_distance: float = float(info.get("board_distance", INF))
	var repair_hint: String = "    [H] Repair (free)" if info.get("can_repair", false) else ""
	if info.get("in_shelter", false):
		target_label.text = "DUST SHELTER\n[R] Full recharge in any weather%s" % repair_hint
	elif board_distance <= float(info.get("boarding_range", 0.0)):
		target_label.text = "SHIP IN RANGE\n[G] Board ship and stow the rover%s" % repair_hint
	elif not nearest.is_empty() and nearest_distance <= interaction:
		target_label.text = str(nearest.name) + "  /  IN RANGE\n[E] Scan    [Q] Analyse sample"
	elif not nearest.is_empty():
		target_label.text = "NEAREST SIGNAL  /  %d m     SHIP  /  %d m" % [roundi(nearest_distance), roundi(board_distance)]
	log_label.text = "MISSION LOG\n" + "\n".join(PackedStringArray(state.log.slice(0, 3)))
