extends CanvasLayer
## Mission Control messages: a short briefing card (skippable) and an objective banner that fades on its
## own or dismisses with Enter. Presentational: the text comes from simulation/campaign.gd.
signal briefing_closed

var banner: Panel
var banner_label: Label
var card: Panel
var card_label: Label
var _banner_time: float = 0.0
var briefing_open: bool = false
const OBJECTIVE_TOP := Vector2(420, 14)
const OBJECTIVE_CENTRE := Vector2(244, 303)
var objective_panel: Panel
var objective_header: Label
var objective_title: Label
var objective_tween: Tween
var objective_key: String = ""
var objective_pending: bool = false
var objective_blocked: bool = true
var objective_announcing: bool = false

func _ready() -> void:
	layer = 12
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.1, 0.9)
	style.border_color = Color("8ce9d2")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	banner = Panel.new()
	banner.position = Vector2(365, 106)
	banner.size = Vector2(560, 64)
	banner.add_theme_stylebox_override("panel", style)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	add_child(banner)
	banner_label = Label.new()
	banner_label.position = Vector2(14, 6)
	banner_label.size = Vector2(532, 52)
	banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_label.add_theme_font_size_override("font_size", 13)
	banner_label.add_theme_color_override("font_color", Color("d8efe6"))
	banner.add_child(banner_label)
	card = Panel.new()
	card.position = Vector2(240, 180)
	card.size = Vector2(800, 330)
	card.add_theme_stylebox_override("panel", style)
	card.visible = false
	add_child(card)
	card_label = Label.new()
	card_label.position = Vector2(28, 24)
	card_label.size = Vector2(744, 240)
	card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_label.add_theme_font_size_override("font_size", 17)
	card_label.add_theme_color_override("font_color", Color("e3e8d4"))
	card.add_child(card_label)
	var go := Button.new()
	go.text = "BEGIN  [ENTER]"
	go.position = Vector2(28, 272)
	go.size = Vector2(220, 40)
	go.pressed.connect(close_briefing)
	card.add_child(go)
	objective_panel = Panel.new()
	objective_panel.position = OBJECTIVE_TOP
	objective_panel.size = Vector2(566, 82)
	var objective_style: StyleBoxFlat = style.duplicate()
	objective_style.bg_color = Color(0.02, 0.06, 0.1, 0.98)
	objective_panel.add_theme_stylebox_override("panel", objective_style)
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.visible = false
	add_child(objective_panel)
	objective_header = Label.new()
	objective_header.position = Vector2(16, 8)
	objective_header.size = Vector2(534, 20)
	objective_header.add_theme_font_size_override("font_size", 12)
	objective_header.add_theme_color_override("font_color", Color("a4c2c6"))
	objective_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.add_child(objective_header)
	objective_title = Label.new()
	objective_title.position = Vector2(16, 29)
	objective_title.size = Vector2(534, 48)
	objective_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_title.add_theme_font_size_override("font_size", 20)
	objective_title.add_theme_color_override("font_color", Color("f3c582"))
	objective_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.add_child(objective_title)

func show_objective(info: Dictionary) -> void:
	var key: String = str(info.get("id", info.get("title", "")))
	objective_header.text = str(info.get("header", ""))
	var distance: String = "  /  %d m" % roundi(info.distance) if info.has("distance") else ""
	objective_title.text = str(info.get("title", "")) + distance
	if key != objective_key:
		objective_key = key
		objective_pending = true
		if not objective_blocked: _announce_objective()

func block_objective(blocked: bool) -> void:
	if blocked:
		if objective_announcing:
			objective_pending = true
			if objective_tween: objective_tween.kill()
			objective_announcing = false
		objective_panel.visible = false
	elif not objective_key.is_empty():
		if objective_pending: _announce_objective()
		else: objective_panel.visible = true
	objective_blocked = blocked

func _announce_objective() -> void:
	if objective_tween: objective_tween.kill()
	objective_pending = false
	objective_announcing = true
	objective_panel.visible = true
	objective_panel.position = OBJECTIVE_CENTRE + Vector2(0, 12)
	objective_panel.scale = Vector2.ONE * 1.4
	objective_panel.modulate.a = 0
	objective_tween = create_tween()
	objective_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	objective_tween.tween_property(objective_panel, "modulate:a", 1.0, 0.25)
	objective_tween.parallel().tween_property(objective_panel, "position", OBJECTIVE_CENTRE, 0.25)
	objective_tween.tween_interval(2.1)
	objective_tween.tween_property(objective_panel, "modulate:a", 0.3, 0.2)
	objective_tween.tween_property(objective_panel, "position", OBJECTIVE_TOP, 0.6)
	objective_tween.parallel().tween_property(objective_panel, "scale", Vector2.ONE, 0.6)
	objective_tween.parallel().tween_property(objective_panel, "modulate:a", 1.0, 0.6)
	objective_tween.tween_callback(func() -> void: objective_announcing = false)

func show_briefing(title: String, lines: Array) -> void:
	card_label.text = "MISSION CONTROL  ·  %s\n\n%s" % [title.to_upper(), "\n\n".join(PackedStringArray(lines))]
	card.visible = true
	briefing_open = true

func close_briefing() -> void:
	if not briefing_open: return
	card.visible = false
	briefing_open = false
	briefing_closed.emit()

func say(text: String, seconds: float = 9.0) -> void:
	banner_label.text = "MISSION CONTROL  ·  " + text
	banner.visible = true
	_banner_time = seconds

func _process(delta: float) -> void:
	if _banner_time > 0.0:
		_banner_time -= delta
		if _banner_time <= 0.0: banner.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		if briefing_open: close_briefing()
		elif banner.visible:
			banner.visible = false
			_banner_time = 0.0
		get_viewport().set_input_as_handled()
