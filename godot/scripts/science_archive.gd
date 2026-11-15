extends CanvasLayer
## Read-only, offline science reference. Opening it preserves the prior pause/focus state.
const Catalog = preload("res://scripts/science_catalog.gd")
const Identity = preload("res://scripts/mission_identity.gd")
var overlay: Control
var tabs: TabContainer
var access: Button
var is_open: bool = false
var _previous_pause: bool = false
var _previous_mouse: Input.MouseMode
var _previous_focus: WeakRef

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	access = Button.new()
	access.add_theme_font_size_override("font_size", 12)
	access.text = "SCIENCE [F2]"
	access.position = Vector2(904, 684)
	access.size = Vector2(136, 28)
	access.pressed.connect(toggle)
	add_child(access)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("08151f")
	overlay.add_child(shade)
	var badge := TextureRect.new()
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.texture = Identity.BADGE
	badge.position = Vector2(40, 28)
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.size = Vector2(66, 66)
	overlay.add_child(badge)
	var heading := text_label("SCIENCE BEHIND FIRST LIGHT", 28, Color("dfebe3"))
	heading.position = Vector2(124, 30)
	heading.size = Vector2(1080, 38)
	overlay.add_child(heading)
	var subtitle := text_label("NASA observations · your mission choices · what the game simplifies", 16, Color("a5c5c9"))
	subtitle.position = Vector2(126, 74)
	subtitle.size = Vector2(1080, 26)
	overlay.add_child(subtitle)
	tabs = TabContainer.new()
	tabs.position = Vector2(40, 120)
	tabs.size = Vector2(1200, 512)
	tabs.add_theme_font_size_override("font_size", 16)
	overlay.add_child(tabs)
	for page in Catalog.PHOTO_PAGES: _photo_page(page)
	_data_page()
	_credits_page()
	var note := text_label("Independent educational game · NASA data and images credited · no NASA endorsement", 13, Color("a3b7bf"))
	note.position = Vector2(40, 656)
	note.size = Vector2(870, 34)
	overlay.add_child(note)
	var close := Button.new()
	close.text = "RETURN TO GAME  [F2 / ESC]"
	close.position = Vector2(940, 650)
	close.size = Vector2(300, 34)
	close.pressed.connect(close_archive)
	overlay.add_child(close)
	overlay.visible = false

func text_label(value: String, font: int, color: Color = Color("d1e1dd")) -> Label:
	var item := Label.new()
	item.text = value
	item.add_theme_font_size_override("font_size", font)
	item.add_theme_color_override("font_color", color)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return item

func _page(title: String) -> MarginContainer:
	var page := MarginContainer.new()
	page.name = title
	for side in ["left", "right", "top", "bottom"]: page.add_theme_constant_override("margin_" + side, 20)
	tabs.add_child(page)
	return page

func _scroll(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)
	return column

func _body(parent: Control, value: String) -> void:
	var item := RichTextLabel.new()
	item.bbcode_enabled = true
	item.text = value
	item.fit_content = true
	item.scroll_active = false
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_font_size_override("normal_font_size", 16)
	item.add_theme_font_size_override("bold_font_size", 16)
	item.add_theme_color_override("default_color", Color("d1e1dd"))
	parent.add_child(item)

func _source(parent: Control, title: String, url: String) -> void:
	var link := Button.new()
	link.text = title + "  ↗"
	link.tooltip_text = url + " (opens your browser)"
	link.custom_minimum_size.y = 34
	link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	link.pressed.connect(func() -> void: OS.shell_open(url))
	parent.add_child(link)

func _photo_page(page: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	_page(page.tab).add_child(row)
	var visual := VBoxContainer.new()
	visual.custom_minimum_size.x = 500
	visual.add_theme_constant_override("separation", 12)
	row.add_child(visual)
	var image := TextureRect.new()
	image.texture = load(page.image)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(500, 282)
	visual.add_child(image)
	visual.add_child(text_label(page.credit, 13, Color("a5d8cc")))
	visual.add_child(text_label(page.caption, 14))
	var reading := VBoxContainer.new()
	reading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reading.add_theme_constant_override("separation", 12)
	row.add_child(reading)
	var column := _scroll(reading)
	column.add_child(text_label(page.title, 24, Color("efc784")))
	_body(column, page.body)
	_source(reading, "OPEN NASA SOURCE", page.source)

func _data_page() -> void:
	var column := _scroll(_page("Terrain data"))
	column.add_child(text_label("The data that shapes your mission", 25, Color("efc784")))
	for data in Catalog.DATASETS:
		_body(column, "[b]" + data[0] + "[/b]\n" + data[1] + "\n\n" + data[2])
		_source(column, "OPEN " + data[0].to_upper() + " ARCHIVE", data[3])
	_body(column, Catalog.SCOPE)

func _credits_page() -> void:
	var column := _scroll(_page("Credits & scope"))
	column.add_child(text_label("Our project, its sources and its limits", 25, Color("efc784")))
	_body(column, Catalog.IDENTITY)
	_source(column, "PROJECT SOURCES AND AI CREDITS", "https://github.com/aringhosh13/space-mission-design-game")
	_source(column, "NASA IMAGES AND MEDIA GUIDELINES", "https://www.nasa.gov/nasa-brand-center/images-and-media/")
	_source(column, "NASA MOON FACTS", "https://science.nasa.gov/moon/facts/")
	_source(column, "NASA MARS FACTS", "https://science.nasa.gov/mars/facts/")
	_source(column, "ARTEMIS I RETURN REFERENCE", "https://www.nasa.gov/mission/artemis-i/")

func context_tab() -> int:
	for game in get_tree().root.get_children():
		if not "expedition" in game: continue
		var state: Dictionary = game.expedition
		if state.get("location", "moon") != "mars": return 0
		var weather: Dictionary = state.get("missions", {}).get("mars", {}).get("weather", {})
		return 2 if weather.get("phase", "") == "storm" else 1
	return 0

func toggle() -> void:
	if is_open: close_archive()
	else: open_archive()

func open_archive(page: int = -1) -> void:
	if is_open:
		if page >= 0: tabs.current_tab = clampi(page, 0, tabs.get_tab_count() - 1)
		return
	var guide: Node = get_node_or_null("/root/PlayerGuide")
	if guide != null and guide.is_open: guide.close_guide()
	var audio: Node = get_node_or_null("/root/Soundscape")
	if audio != null and audio.settings_open: audio.toggle_settings()
	_previous_pause = get_tree().paused
	_previous_mouse = Input.mouse_mode
	var focus: Control = get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	is_open = true
	overlay.visible = true
	access.visible = false
	tabs.current_tab = context_tab() if page < 0 else clampi(page, 0, tabs.get_tab_count() - 1)
	tabs.get_tab_bar().grab_focus()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if audio != null:
		for id in audio.loops: audio.level(id, 0)

func close_archive() -> void:
	if not is_open: return
	is_open = false
	overlay.visible = false
	access.visible = true
	get_tree().paused = _previous_pause
	Input.mouse_mode = _previous_mouse if _previous_mouse != Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else Input.MOUSE_MODE_VISIBLE
	if _previous_focus != null:
		var focus: Control = _previous_focus.get_ref() as Control
		if focus != null and focus.is_inside_tree() and focus.is_visible_in_tree(): focus.grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F2 or (is_open and event.physical_keycode == KEY_ESCAPE):
			get_viewport().set_input_as_handled()
			toggle()
