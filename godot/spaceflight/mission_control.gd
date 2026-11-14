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

func _ready() -> void:
	layer = 12
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.1, 0.9)
	style.border_color = Color("8ce9d2")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	banner = Panel.new()
	banner.position = Vector2(330, 610)
	banner.size = Vector2(620, 54)
	banner.add_theme_stylebox_override("panel", style)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	add_child(banner)
	banner_label = Label.new()
	banner_label.position = Vector2(14, 6)
	banner_label.size = Vector2(592, 44)
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
