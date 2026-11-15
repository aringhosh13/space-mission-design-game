extends CanvasLayer
## Interactive instrument presentation. The surface owner revalidates and commits through the engine once.
signal commit_requested(action: String)
signal closed
const Instrument = preload("res://simulation/field_instrument.gd")
const Scope = preload("res://scripts/field_scope.gd")
const Sound = preload("res://scripts/audio_feedback.gd")
var root: Control
var title: Label
var explanation: Label
var instruction: Label
var status: Label
var scope: Control
var slider: HSlider
var progress: ProgressBar
var assist_button: Button
var primary: Button
var mode: String = "scan"
var stage: String = "idle"
var instrument: Dictionary = {}
var context: Dictionary = {}
var assisted: bool = false
var _committed: bool = false
var _button_held: bool = false
var _wait_release: bool = false

func _ready() -> void:
	layer = 40
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.012, 0.02, 0.58)
	root.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(240, 106)
	panel.size = Vector2(800, 504)
	var finish := StyleBoxFlat.new()
	finish.bg_color = Color(0.025, 0.06, 0.09, 0.97)
	finish.border_color = Color("77b5b0")
	finish.set_border_width_all(1)
	finish.set_corner_radius_all(9)
	panel.add_theme_stylebox_override("panel", finish)
	root.add_child(panel)
	title = label("", Vector2(270, 124), Vector2(740, 38), 25)
	explanation = label("", Vector2(270, 172), Vector2(740, 70), 16)
	scope = Scope.new()
	scope.position = Vector2(270, 250)
	scope.size = Vector2(740, 124)
	root.add_child(scope)
	instruction = label("", Vector2(270, 385), Vector2(740, 27), 14)
	slider = HSlider.new()
	slider.position = Vector2(270, 417)
	slider.size = Vector2(740, 23)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 0.5
	root.add_child(slider)
	progress = ProgressBar.new()
	progress.position = Vector2(270, 452)
	progress.size = Vector2(740, 18)
	progress.show_percentage = false
	root.add_child(progress)
	status = label("", Vector2(270, 484), Vector2(740, 42), 14)
	assist_button = button("ASSIST: OFF [A]", Vector2(270, 537), Vector2(190, 36), toggle_assist)
	primary = button("", Vector2(475, 537), Vector2(330, 36), _primary_pressed)
	primary.button_down.connect(func() -> void: _button_held = true)
	primary.button_up.connect(func() -> void: _button_held = false)
	button("RETURN [ESC]", Vector2(820, 537), Vector2(190, 36), close)
	label("Illustrative game controls and thresholds · evidence and energy come from the mission simulation", Vector2(270, 584), Vector2(740, 20), 10)
	root.visible = false
	set_process(false)

func label(value: String, at: Vector2, extent: Vector2, font: int) -> Label:
	var item := Label.new()
	item.text = value
	item.position = at
	item.size = extent
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", font)
	item.add_theme_color_override("font_color", Color("d8e5dd"))
	root.add_child(item)
	return item
func button(value: String, at: Vector2, extent: Vector2, callback: Callable) -> Button:
	var item := Button.new()
	item.text = value
	item.position = at
	item.size = extent
	item.add_theme_font_size_override("font_size", 14)
	item.pressed.connect(callback)
	root.add_child(item)
	return item

func open(action: String, details: Dictionary) -> void:
	mode = action
	context = details.duplicate(true)
	instrument = Instrument.create(action, int(details.get("seed", 0)))
	stage = "operate"
	assisted = false
	_committed = false
	_button_held = false
	_wait_release = false
	assist_button.text = "ASSIST: OFF [A]"
	assist_button.visible = mode != "deploy"
	slider.visible = mode != "deploy"
	progress.visible = mode != "deploy"
	scope.visible = mode != "deploy"
	slider.value = 50
	primary.disabled = not bool(details.get("can_commit", true))
	primary.text = "DEPLOY AT THIS SITE [ENTER]" if mode == "deploy" else "HOLD TO OPERATE [SPACE]"
	title.text = {"scan": "SIGNAL LOCK / " + str(details.get("name", "SURVEY")), "sample": "CORE SAMPLER / " + str(details.get("name", "ROCK")), "deploy": "OUTPOST / POWER AND RETURN CHECK"}[mode]
	explanation.text = {"scan": "Problem: an orbital signal is only a clue. Tune the instrument to its peak and hold a stable lock. A scan yields preliminary evidence; a sample may confirm it or rule it out.",
		"sample": "Problem: collecting a core needs controlled tool operation. Keep the feed in the green band and watch heat. Release Space to cool. This is an illustration, not a real NASA drill procedure.",
		"deploy": "Problem: the station needs sunlight, and deployment spends energy you may need to return. Review this site's power and your rover's remaining budget before committing."}[mode]
	instruction.text = "ARROWS / SLIDER: TUNE     HOLD SPACE: LOCK     A: ASSIST" if mode == "scan" else "ARROWS / SLIDER: FEED     HOLD SPACE: DRILL     RELEASE: COOL"
	if mode == "deploy":
		instruction.text = str(details.get("assessment", ""))
		instruction.position.y = 270
		instruction.size.y = 172
	else:
		instruction.position.y = 385
		instruction.size.y = 27
	status.text = "Commit cost: %.1f energy. Nothing is charged until this operation completes." % float(details.get("cost", 0))
	root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	primary.grab_focus()
	set_process(true)
	Sound.cue(self, "scan" if mode == "scan" else "click")
	refresh()

func is_open() -> bool:
	return root != null and root.visible
func toggle_assist() -> void:
	if stage != "operate" or mode == "deploy": return
	assisted = not assisted
	assist_button.text = "ASSIST: ON [A]" if assisted else "ASSIST: OFF [A]"
	Sound.cue(self, "click")

func _process(delta: float) -> void:
	if stage != "operate" or mode == "deploy": return
	var dt: float = minf(delta, 0.05)
	var held: bool = _button_held or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and scope.get_global_rect().has_point(scope.get_global_mouse_position())
	if assisted:
		slider.value = float(instrument.target) * 100 if mode == "scan" else 45
		held = not bool(instrument.cooling)
	else:
		var direction: float = float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
		slider.value = clampf(slider.value + direction * dt * 30, 0, 100)
	instrument = Instrument.step(instrument, {"value": slider.value / 100 if mode == "scan" else slider.value, "hold": held}, dt)
	Sound.tool(self, ("scanner" if mode == "scan" else "drill") if held and not instrument.cooling else "")
	refresh()
	if instrument.done: confirm()

func refresh() -> void:
	scope.instrument = instrument
	scope.queue_redraw()
	progress.value = float(instrument.progress) * 100
	if mode == "scan":
		status.text = "LOCK %d%%   /   signal strength %d%%   /   scan cost %.1f energy" % [roundi(instrument.progress * 100), roundi(instrument.strength * 100), context.get("cost", 0)]
	elif mode == "sample":
		status.text = "CORE %d%%   /   feed %d   /   heat %d%% %s" % [roundi(instrument.progress * 100), roundi(instrument.pressure), roundi(instrument.heat), "— cooling; release to recover" if instrument.cooling else "— green feed: 25–70"]

func _primary_pressed() -> void:
	if _wait_release:
		_wait_release = false
		return
	confirm()

func confirm() -> void:
	if stage == "result":
		close()
		return
	if stage != "operate" or _committed: return
	if not bool(context.get("can_commit", true)): return
	if mode != "deploy" and not instrument.done: return
	_committed = true
	stage = "committing"
	Sound.tool(self, "")
	commit_requested.emit(mode)

func show_result(value: String) -> void:
	_wait_release = _button_held
	_button_held = false
	stage = "result"
	Sound.tool(self, "")
	scope.visible = false
	slider.visible = false
	progress.visible = false
	assist_button.visible = false
	instruction.position.y = 270
	instruction.size.y = 172
	instruction.text = value
	status.text = "Your evidence is recorded by the mission simulation. Ruling out a signal is useful science too."
	primary.disabled = false
	primary.text = "CONTINUE EXPLORING [ENTER]"
	primary.grab_focus()

func close() -> void:
	if not is_open(): return
	root.visible = false
	stage = "idle"
	Sound.tool(self, "")
	set_process(false)
	closed.emit()

func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
	elif event.physical_keycode == KEY_ENTER:
		get_viewport().set_input_as_handled()
		if stage == "result": close()
		elif mode == "deploy": confirm()
	elif event.physical_keycode == KEY_A:
		get_viewport().set_input_as_handled()
		toggle_assist()
	elif event.physical_keycode in [KEY_SPACE, KEY_LEFT, KEY_RIGHT]:
		get_viewport().set_input_as_handled() # poll physical holds; don't activate controls behind the modal
