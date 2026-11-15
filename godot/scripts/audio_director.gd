extends Node
## Original score and stylised player feedback. No claimed NASA recordings or sound in lunar air.
const FILES = ["horizon", "confirm", "checkpoint", "warning", "click", "scan", "mars_wind", "rover", "engine", "drill", "scanner", "impact"]
var streams: Dictionary = {}
var loops: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var voice_index: int = 0
var music_volume: float = 0.45
var effects_volume: float = 0.65
var muted: bool = false
var settings_open: bool = false
var panel: Panel
var _previous_tree_pause: bool = false
var tool: String = ""
var music_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("audio_director")
	for bus_name in ["HorizonMusic", "HorizonFeedback"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	var config := ConfigFile.new()
	if config.load("user://audio.cfg") == OK:
		music_volume = clampf(float(config.get_value("audio", "music", 0.45)), 0, 1)
		effects_volume = clampf(float(config.get_value("audio", "effects", 0.65)), 0, 1)
		muted = bool(config.get_value("audio", "muted", false))
	for id in FILES: streams[id] = load("res://audio/" + id + ".wav")
	music_player = make_player("horizon", "HorizonMusic", true)
	music_player.play()
	for id in ["rover", "engine", "mars_wind", "drill", "scanner"]:
		loops[id] = make_player(id, "HorizonFeedback", true)
		loops[id].volume_db = -80
		loops[id].play()
	for i in range(6):
		var voice := AudioStreamPlayer.new()
		voice.bus = "HorizonFeedback"
		add_child(voice)
		voices.append(voice)
	apply_levels()
	build_settings()

func make_player(id: String, bus: String, looping: bool) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	var stream: AudioStreamWAV = streams[id].duplicate()
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	player.stream = stream
	add_child(player)
	return player

func cue(id: String) -> void:
	if not streams.has(id) or voices.is_empty(): return
	var voice: AudioStreamPlayer = voices[voice_index]
	voice_index = (voice_index + 1) % voices.size()
	voice.stream = streams[id]
	voice.play()

func shutdown() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	streams.clear()

func _exit_tree() -> void:
	shutdown()
	# Drain the audio thread's playback references before the engine unloads WAV resources.
	OS.delay_msec(120)

func apply_levels(save: bool = false) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("HorizonMusic"), linear_to_db(maxf(0.0001, music_volume)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("HorizonFeedback"), linear_to_db(maxf(0.0001, effects_volume)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("HorizonMusic"), muted or music_volume <= 0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("HorizonFeedback"), muted or effects_volume <= 0)
	if save:
		var config := ConfigFile.new()
		config.set_value("audio", "music", music_volume)
		config.set_value("audio", "effects", effects_volume)
		config.set_value("audio", "muted", muted)
		config.save("user://audio.cfg")

func set_tool(value: String) -> void:
	tool = value

func update_context(phase: String, body: String, paused: bool, speed: float, thrust: float, storm: bool) -> void:
	level("rover", clampf(speed / 7, 0, 1) * 0.6 if phase == "surface" and not paused else 0)
	level("engine", clampf(thrust, 0, 1) * 0.7 if phase in ["flight", "landing"] and not paused else 0)
	level("mars_wind", 0.8 if body == "mars" and storm and not paused else 0)
	level("drill", 0.7 if tool == "drill" and not settings_open else 0)
	level("scanner", 0.65 if tool == "scanner" and not settings_open else 0)

func level(id: String, value: float) -> void:
	if loops.has(id): loops[id].volume_db = linear_to_db(maxf(0.0001, value))

func text(parent: Node, value: String, at: Vector2, size: Vector2, font: int = 16) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font)
	label.add_theme_color_override("font_color", Color("d8e5dd"))
	parent.add_child(label)
	return label

func build_settings() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	var button := Button.new()
	button.text = "AUDIO [F8]"
	button.position = Vector2(1168, 684)
	button.size = Vector2(100, 28)
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(toggle_settings)
	layer.add_child(button)
	panel = Panel.new()
	panel.position = Vector2(400, 155)
	panel.size = Vector2(480, 405)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("091a26")
	style.border_color = Color("8ce9d2")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	layer.add_child(panel)
	text(panel, "SOUNDS OF THE EXPEDITION", Vector2(26, 22), Vector2(430, 32), 23)
	text(panel, "Original ambient score and instrument feedback.\nMusic is a soundtrack; the Moon has no atmospheric wind.", Vector2(26, 65), Vector2(425, 55), 14)
	for i in range(2):
		text(panel, "Background music" if i == 0 else "Effects / instruments", Vector2(26, 138 + i * 70), Vector2(420, 24))
		var slider := HSlider.new()
		slider.position = Vector2(26, 171 + i * 70)
		slider.size = Vector2(420, 24)
		slider.max_value = 100
		slider.value = (music_volume if i == 0 else effects_volume) * 100
		var music: bool = i == 0
		slider.value_changed.connect(func(value: float) -> void:
			if music: music_volume = value / 100
			else: effects_volume = value / 100
			apply_levels(true))
		panel.add_child(slider)
	var mute := CheckButton.new()
	mute.text = "MUTE ALL AUDIO"
	mute.button_pressed = muted
	mute.position = Vector2(26, 287)
	mute.toggled.connect(func(value: bool) -> void:
		muted = value
		apply_levels(true))
	panel.add_child(mute)
	var close := Button.new()
	close.text = "RETURN TO GAME  [F8 / ESC]"
	close.position = Vector2(26, 345)
	close.size = Vector2(420, 38)
	close.pressed.connect(toggle_settings)
	panel.add_child(close)

func toggle_settings() -> void:
	var guide: Node = get_node_or_null("/root/PlayerGuide")
	if not settings_open and guide != null and guide.is_open: guide.close_guide()
	settings_open = not settings_open
	panel.visible = settings_open
	if settings_open:
		_previous_tree_pause = get_tree().paused
		for id in loops: level(id, 0)
		get_tree().paused = true
	else:
		get_tree().paused = _previous_tree_pause
		apply_levels(true)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F8 or (settings_open and event.physical_keycode == KEY_ESCAPE):
			get_viewport().set_input_as_handled()
			toggle_settings()
