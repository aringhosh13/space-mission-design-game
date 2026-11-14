extends CanvasLayer
## Expedition screens for the spaceflight demo: planning, aboard the ship, pause and debrief.
## Presentational: it emits the player's choices; expedition_game.gd applies them through the simulation.
signal config_changed(config: Dictionary, fuel_load: String)
signal choice(action: String, argument: String)

const TEXT := Color("e3e8d4")
const SOFT := Color("c5d2d0")
const DIM := Color("8fa6ae")
const AMBER := Color("f3c582")
const WARN := Color("ff9b6b")

var overlay: Panel
var content: VBoxContainer
var review_label: Label
var advice_label: Label
var start_button: Button
var options: Dictionary = {}
var active: String = ""

func _ready() -> void:
	layer = 10
	overlay = Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_stylebox_override("panel", _style(Color(0.012, 0.03, 0.055, 0.78), Color.TRANSPARENT))
	add_child(overlay)
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_stylebox("normal", "Button", _style(Color(0.05, 0.10, 0.15, 0.94), Color("58737b")))
	theme.set_stylebox("hover", "Button", _style(Color(0.10, 0.21, 0.26, 0.98), Color("c0e1c5")))
	theme.set_stylebox("pressed", "Button", _style(Color(0.10, 0.21, 0.26, 0.98), Color("c0e1c5")))
	theme.set_stylebox("disabled", "Button", _style(Color(0.04, 0.06, 0.08, 0.8), Color("33434a")))
	theme.set_color("font_color", "Button", Color("e0eadc"))
	theme.set_stylebox("normal", "OptionButton", _style(Color(0.05, 0.10, 0.15, 0.94), Color("58737b")))
	overlay.theme = theme
	content = VBoxContainer.new()
	content.position = Vector2(74, 48)
	content.size = Vector2(700, 630)
	content.add_theme_constant_override("separation", 10)
	overlay.add_child(content)
	hide_screen()

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _label(text: String, size: int, color: Color, wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 680
	content.add_child(label)
	return label

func _button(text: String, action: String, argument: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(520, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(func() -> void: choice.emit(action, argument))
	content.add_child(button)
	return button

func _clear(name: String) -> void:
	# The planning screen lets the backdrop show through; in-game screens cover the HUD beneath.
	var panel_style: StyleBoxFlat = overlay.get_theme_stylebox("panel")
	panel_style.bg_color.a = 0.78 if name == "planning" else 0.95
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	overlay.visible = true
	active = name
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_screen() -> void:
	overlay.visible = false
	active = ""

func show_planning(campaign: bool = false) -> void:
	_clear("planning")
	_label("BLUE HORIZON" if not campaign else "BLUE HORIZON: FIRST LIGHT", 50 if not campaign else 42, TEXT, false)
	_label("MOON  →  MARS  →  HOME" if not campaign else "A NASA-INSPIRED STORY CAMPAIGN  ·  MOON  →  MARS  →  HOME", 15, Color("a8d8c6"), false)
	_label("Explore the Moon, board your ship, fly to Mars, land and investigate, then bring the evidence home. Everything you carry has mass, and mass costs fuel." if not campaign else
		"Mission Control needs routes and resource data for a future lunar research outpost, then evidence from an ancient-delta-inspired region on Mars. You fly every landing yourself; the assist and checkpoints keep it forgiving. Fictional expedition informed by NASA science.", 17, SOFT)
	options.clear()
	_option("battery", "BATTERY", [["compact", "Compact battery · 100 energy · 12 kg"], ["extended", "Extended battery · 160 energy · 28 kg"]], 0)
	_option("power", "POWER", [["solar", "Solar array · weaker on Mars (43%)"], ["fuel-cell", "Fuel cells · 3 refills shared by both worlds"]], 0)
	_option("instrument", "PAYLOAD", [["scanner", "Surface scanner · data only"], ["drill", "Scanner + drill · sample cores"]], 1)
	_option("fuel", "SHIP FUEL", [["light", "Light · 450 kg"], ["standard", "Standard · 650 kg"], ["full", "Full · 850 kg"]], 1)
	review_label = _label("", 15, Color("b9d7c6"))
	advice_label = _label("", 14, AMBER)
	start_button = _button("BEGIN EXPEDITION ON THE MOON" if not campaign else "BEGIN FIRST LIGHT IN LUNAR ORBIT", "start")
	_label("Fictional ship and equipment values · real figures are labelled (NASA) · distances compressed", 11, DIM)
	_emit_config()

func _option(key: String, title: String, items: Array, selected: int) -> void:
	var row := HBoxContainer.new()
	content.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 110
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("a3b9bd"))
	row.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(470, 38)
	for item in items: option.add_item(item[1])
	option.select(selected)
	option.set_meta("values", items.map(func(item: Array) -> String: return item[0]))
	option.item_selected.connect(func(_i: int) -> void: _emit_config())
	row.add_child(option)
	options[key] = option

func selected(key: String) -> String:
	var option: OptionButton = options[key]
	return option.get_meta("values")[option.selected]

func _emit_config() -> void:
	if options.size() < 4: return
	config_changed.emit({"battery": selected("battery"), "power": selected("power"), "instrument": selected("instrument")}, selected("fuel"))

func update_review(review: Dictionary) -> void:
	if active != "planning": return
	var rover: Dictionary = review.rover
	review_label.text = "ROVER  %d / 110 credits  ·  %d / 100 kg\nSHIP   %d kg at launch  ·  Δv %d u/s  ·  Mars round trip needs ~%d u/s at 60 u/s cruise" % [
		rover.cost, rover.mass, roundi(review.ship_mass), roundi(review.delta_v), roundi(review.round_trip_delta_v)]
	for warning in review.warnings: review_label.text += "\n" + warning
	advice_label.text = "\n".join(PackedStringArray(review.advice))
	start_button.disabled = not review.warnings.is_empty()

## Aboard the ship at `location`. lines: summary lines prepared by the game from the simulation.
func show_aboard(place: String, lines: Array, destinations: Array, warning: String = "") -> void:
	_clear("aboard")
	_label("ABOARD  ·  %s" % place.to_upper(), 40, TEXT, false)
	for line in lines: _label(str(line), 16, SOFT)
	if warning != "": _label(warning, 16, WARN)
	for entry in destinations: _button("TAKE OFF FOR %s" % str(entry[1]).to_upper(), "takeoff", str(entry[0]))
	_button("DEPLOY THE ROVER AGAIN", "disembark")
	_button("END THE EXPEDITION HERE", "finish")

func show_pause(campaign: bool = false) -> void:
	_clear("pause")
	_label("EXPEDITION PAUSED", 38, TEXT, false)
	_button("RESUME", "resume")
	if campaign: _button("RECOVER TO LAST CHECKPOINT (keeps all progress and evidence)", "recover")
	_button("END THE EXPEDITION AND VIEW THE DEBRIEF", "finish")
	_button("NEW EXPEDITION", "restart")
	_button("QUIT", "quit")

func show_report(report: Dictionary, campaign: Dictionary = {}) -> void:
	_clear("report")
	_label("EXPEDITION DEBRIEF" if campaign.is_empty() else "FIRST LIGHT DEBRIEF  ·  %d/%d OBJECTIVES%s" % [campaign.completed, campaign.total,
		"  ·  CAMPAIGN COMPLETE" if campaign.complete else ""], 16, Color("a9d4bd"), false)
	_label("%d / 100" % report.score, 60, TEXT, false)
	_label("%d of %d possible science returned  ·  %d stations  ·  %s" % [report.science_returned, report.science_possible,
		report.stations, "home at the Moon base" if report.home else "ended away from home"], 18, SOFT)
	if not campaign.is_empty():
		_label("   ".join(PackedStringArray(campaign.objectives)), 13, Color("b9d7c6"))
		if int(campaign.recoveries) > 0: _label("Checkpoint recoveries used: %d (no penalty)." % campaign.recoveries, 13, DIM)
	for line in report.feedback: _label("• " + str(line), 14, SOFT)
	_button("PLAN ANOTHER EXPEDITION", "restart")
	_button("QUIT", "quit")
