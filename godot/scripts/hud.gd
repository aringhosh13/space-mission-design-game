extends CanvasLayer
signal action_requested(action: String)
signal config_changed(config: Dictionary)
const Contract = preload("res://shared/mission_contract.gd")
var root: Control
var overlay: Panel
var overlay_content: VBoxContainer
var telemetry: Label
var energy_bar: ProgressBar
var target_label: Label
var log_label: Label
var objective: Label
var site_list: Label
var review_label: Label
var launch_button: Button
var battery: OptionButton
var power: OptionButton
var instrument: OptionButton
var active_overlay: String = ""

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 16
	var normal := _style(Color(0.05, 0.10, 0.15, 0.94), Color("58737b"))
	var hover := _style(Color(0.10, 0.21, 0.26, 0.98), Color("c0e1c5"))
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", hover)
	theme.set_color("font_color", "Button", Color("e0eadc"))
	theme.set_stylebox("normal", "OptionButton", normal)
	root.theme = theme
	var brand := _label(root, "BLUE HORIZON", 26, Color("e4ebd8"))
	brand.position = Vector2(34, 22)
	var subtitle := _label(root, "SOUTH POLAR EXPEDITION  /  NATIVE PROTOTYPE", 11, Color("a4c2c6"))
	subtitle.position = Vector2(36, 57)
	objective = _label(root, "INVESTIGATE  /  TRANSMIT  /  ESTABLISH", 14, Color("d7ddc5"))
	objective.position = Vector2(36, 96)
	var power_panel := Panel.new()
	power_panel.position = Vector2(1012, 22)
	power_panel.size = Vector2(235, 140)
	power_panel.add_theme_stylebox_override("panel", _style(Color(0.02, 0.05, 0.09, 0.85), Color("334a57")))
	root.add_child(power_panel)
	telemetry = _label(power_panel, "", 15, Color("d8e5dd"))
	telemetry.position = Vector2(16, 12)
	energy_bar = ProgressBar.new()
	energy_bar.position = Vector2(16, 111)
	energy_bar.size = Vector2(203, 8)
	energy_bar.show_percentage = false
	energy_bar.add_theme_stylebox_override("fill", _style(Color("a7d9bb"), Color("a7d9bb")))
	power_panel.add_child(energy_bar)
	site_list = _label(root, "", 13, Color("cbdad9"))
	site_list.position = Vector2(36, 141)
	site_list.size = Vector2(340, 230)
	log_label = _label(root, "", 13, Color("b7cccd"))
	log_label.position = Vector2(36, 492)
	log_label.size = Vector2(470, 112)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_label = _label(root, "", 18, Color("f3d29a"))
	target_label.position = Vector2(390, 546)
	target_label.size = Vector2(510, 66)
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var controls := _label(root, "WASD  DRIVE     RMB  LOOK     E  SCAN     Q  SAMPLE     R  POWER     T  TRANSMIT     B  STATION     F  FINISH     ESC  MENU", 12, Color("c1d7d4"))
	controls.position = Vector2(36, 674)
	var disclaimer := _label(root, "FICTIONAL GAME VALUES  ·  NASA DATA INTEGRATION PENDING", 10, Color("7f999f"))
	disclaimer.position = Vector2(36, 698)
	# Clickable controls keep all actions accessible without memorizing shortcuts.
	var bar := HBoxContainer.new()
	bar.position = Vector2(390, 618)
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	for item in [["Scan [E]", "scan"], ["Sample [Q]", "sample"], ["Power [R]", "recharge"], ["Transmit [T]", "transmit"], ["Station [B]", "deploy"]]:
		var button := _button(bar, item[0], _action.bind(item[1]))
		button.custom_minimum_size = Vector2(112, 36)
	overlay = Panel.new()
	overlay.position = Vector2(0, 0)
	overlay.size = Vector2(1280, 720)
	overlay.add_theme_stylebox_override("panel", _style(Color(0.015, 0.035, 0.06, 0.91), Color.TRANSPARENT))
	root.add_child(overlay)
	overlay_content = VBoxContainer.new()
	overlay_content.position = Vector2(74, 70)
	overlay_content.size = Vector2(570, 590)
	overlay_content.add_theme_constant_override("separation", 14)
	overlay.add_child(overlay_content)

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style

func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _action(action: String) -> void:
	action_requested.emit(action)

func _clear_overlay() -> void:
	for child in overlay_content.get_children():
		overlay_content.remove_child(child)
		child.queue_free()
	overlay.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_planning() -> void:
	_clear_overlay()
	active_overlay = "planning"
	_label(overlay_content, "BLUE HORIZON", 54, Color("e3e8d4"))
	_label(overlay_content, "A FOOTHOLD IN THE UNKNOWN", 15, Color("a8d8c6"))
	var description := _label(overlay_content, "Design an expedition, drive the lunar surface and investigate what the orbital survey could not settle.", 18, Color("c5d2d0"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(overlay_content, "YOUR EXPEDITION", 12, Color("8faeb7"))
	battery = _option("BATTERY", ["Compact battery · 100 energy", "Extended battery · 160 energy"])
	power = _option("POWER", ["Solar array · needs sunlight", "Fuel cells · 3 refills"])
	instrument = _option("PAYLOAD", ["Surface scanner", "Scanner + drill"])
	instrument.select(1)
	review_label = _label(overlay_content, "", 15, Color("b9d7c6"))
	review_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	launch_button = _button(overlay_content, "LAUNCH EXPEDITION", _action.bind("launch"))
	_label(overlay_content, "Native 3D prototype · All equipment and confidence values are fictional.", 11, Color("8fa6ae"))
	_emit_config()

func _option(title: String, choices: Array) -> OptionButton:
	var row := HBoxContainer.new()
	overlay_content.add_child(row)
	var title_label := _label(row, title, 12, Color("a3b9bd"))
	title_label.custom_minimum_size.x = 100
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(420, 40)
	for choice in choices: option.add_item(choice)
	option.item_selected.connect(func(_index: int): _emit_config())
	row.add_child(option)
	return option

func _emit_config() -> void:
	if battery == null or power == null or instrument == null: return
	config_changed.emit({"battery": "extended" if battery.selected == 1 else "compact",
		"power": "fuel-cell" if power.selected == 1 else "solar",
		"instrument": "drill" if instrument.selected == 1 else "scanner"})

func update_review(review: Dictionary) -> void:
	if not is_instance_valid(review_label): return
	review_label.text = "BUDGET  %d / 110 credits     PAYLOAD  %d / 100 kg" % [review.cost, review.mass]
	for warning in review.warnings: review_label.text += "\n" + warning
	launch_button.disabled = not review.warnings.is_empty()

func hide_overlay() -> void:
	overlay.visible = false
	active_overlay = ""

func show_pause() -> void:
	_clear_overlay()
	active_overlay = "pause"
	_label(overlay_content, "EXPEDITION PAUSED", 38, Color("e3e8d4"))
	_label(overlay_content, "Take a moment to plan your next investigation.", 18, Color("afc8c6"))
	_button(overlay_content, "RESUME", _action.bind("resume"))
	_button(overlay_content, "END MISSION AND VIEW REPORT", _action.bind("finish"))
	_button(overlay_content, "NEW EXPEDITION", _action.bind("restart"))
	_button(overlay_content, "QUIT GAME", _action.bind("quit"))

func show_report(report: Dictionary) -> void:
	_clear_overlay()
	active_overlay = "report"
	_label(overlay_content, "EXPEDITION DEBRIEF", 16, Color("a9d4bd"))
	_label(overlay_content, str(report.score) + " / 100", 66, Color("e3e8d4"))
	var summary: String = "%d science returned to Earth\n%d findings confirmed · %d signals ruled out\n%d science left onboard\nResearch station: %s" % [report.science_returned, report.confirmed_sites,
		report.ruled_out_sites, report.science_lost, "OPERATIONAL" if report.outpost_operational else "NOT ESTABLISHED"]
	_label(overlay_content, summary, 22, Color("c8d8d2"))
	_label(overlay_content, "Ruling out a signal is useful evidence. Only transmitted science contributes to your science score.", 16, Color("9fb7bc")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(overlay_content, "PLAN ANOTHER EXPEDITION", _action.bind("restart"))
	_button(overlay_content, "QUIT GAME", _action.bind("quit"))

func update_mission(state: Dictionary) -> void:
	telemetry.text = "POWER  %03d / %03d\n\nONBOARD  %d     RETURNED  %d" % [roundi(state.energy), roundi(state.max_energy), state.science_collected - state.science_returned, state.science_returned]
	energy_bar.max_value = state.max_energy
	energy_bar.value = state.energy
	var nearest: Dictionary = {}
	var nearest_distance: float = INF
	var site_text: String = "FIELD SIGNALS\n\n"
	for site in state.sites:
		var d: float = Contract.flat_distance(state.position, site.position)
		if d < nearest_distance:
			nearest = site
			nearest_distance = d
		site_text += "%s   %d m\n%s · %d%% certainty\n\n" % [site.name, roundi(d), Contract.FINDING_LABELS[site.finding], site.confidence]
	site_list.text = site_text
	if nearest.is_empty(): target_label.text = ""
	elif nearest_distance <= Contract.INTERACTION_RANGE:
		target_label.text = str(nearest.name) + "  /  IN RANGE\n[E] Scan    [Q] Analyse sample"
	else: target_label.text = "NEAREST SIGNAL  /  %d m\nDrive within 6 m to investigate" % roundi(nearest_distance)
	var lines: Array = state.log.slice(0, 3)
	log_label.text = "MISSION LOG\n" + "\n".join(lines)
	objective.text = "RETURN EVIDENCE TO EARTH  /  STATION " + ("OPERATIONAL" if state.outpost_deployed else "NOT DEPLOYED")
