extends CanvasLayer
## Full-screen fade card for takeoff and landing transitions. play() fades in, holds and emits `covered`
## at full black (swap scenes then), then fades out and emits `finished`.
## cancel() stops a transition at once and still emits `covered` and `finished`, so awaiting code resumes;
## owners must therefore check whether their transition is still current after every await.
signal covered
signal finished

var shade: ColorRect
var title: Label
var body: Label
var playing: bool = false
var _tween: Tween
var _covered_sent: bool = false

func _ready() -> void:
	layer = 20
	shade = ColorRect.new()
	shade.color = Color(0.008, 0.014, 0.03, 0.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	title = Label.new()
	title.position = Vector2(80, 250)
	title.size = Vector2(1120, 80)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("e3e8d4"))
	shade.add_child(title)
	body = Label.new()
	body.position = Vector2(84, 330)
	body.size = Vector2(1000, 260)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color("b9d7c6"))
	shade.add_child(body)
	_set_alpha(0.0)

func _set_alpha(alpha: float) -> void:
	shade.color.a = alpha * 0.97
	title.modulate.a = alpha
	body.modulate.a = alpha

## hold is in seconds; duration of each fade is `fade`.
func play(heading: String, lines: Array, hold: float = 1.6, fade: float = 0.45) -> void:
	if playing: cancel()
	playing = true
	_covered_sent = false
	title.text = heading
	body.text = "\n".join(PackedStringArray(lines))
	_tween = create_tween()
	_tween.tween_method(_set_alpha, 0.0, 1.0, fade)
	_tween.tween_callback(_emit_covered)
	_tween.tween_interval(hold)
	_tween.tween_method(_set_alpha, 1.0, 0.0, fade)
	_tween.tween_callback(func() -> void:
		playing = false
		_tween = null
		finished.emit())

func _emit_covered() -> void:
	if _covered_sent: return
	_covered_sent = true
	covered.emit()

## Stop immediately and clear the screen. Pending awaits on `covered` / `finished` resume.
func cancel() -> void:
	if not playing: return
	if _tween and _tween.is_valid(): _tween.kill()
	_tween = null
	playing = false
	_set_alpha(0.0)
	_emit_covered()
	finished.emit()
