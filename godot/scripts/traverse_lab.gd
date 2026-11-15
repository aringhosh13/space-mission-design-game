extends CanvasLayer
## Regional decision-support prototype using unscaled NASA DEMs, separate from fictional game physics.
signal close_requested
signal solution_presented(plan: Dictionary)
const Cinematic = preload("res://scripts/mission_cinematic.gd")
const Planner = preload("res://simulation/traverse_planner.gd")
const MapView = preload("res://scripts/route_map.gd")
const MOON = preload("res://data/terrain/lola_south_pole.tres")
const MARS = preload("res://data/terrain/mola_jezero.tres")
var root: Control
var map: Control
var slope: SpinBox
var battery: SpinBox
var reserve: SpinBox
var report: Label
var source: Label
var status: Label
var selected: Dictionary = {}
var map_body: String = "moon"
var start := Vector2(0.5, 0.5)
var goal := Vector2(0.78, 0.32)
var data: Resource
var body_choice: OptionButton
var film: CanvasLayer
var present_button: Button
var _intro_seen: bool = false
var _presented_snapshot: Dictionary = {}

func _ready() -> void:
	layer = 32
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var backdrop := ColorRect.new()
	backdrop.color = Color("07121c")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	label("TRAVERSE PLANNING LAB", Vector2(28, 18), Vector2(800, 40), 28)
	label("Real NASA elevation · regional screening prototype · not flight validated", Vector2(30, 60), Vector2(1000, 28), 14)
	body_choice = OptionButton.new()
	body_choice.position = Vector2(1060, 70)
	body_choice.size = Vector2(190, 30)
	body_choice.add_item("Moon · LOLA")
	body_choice.add_item("Mars · MOLA")
	body_choice.item_selected.connect(func(index: int) -> void: open("moon" if index == 0 else "mars"))
	root.add_child(body_choice)
	map = MapView.new()
	map.position = Vector2(30, 110)
	map.size = Vector2(500, 500)
	map.point_selected.connect(func(uv: Vector2, origin: bool) -> void:
		if origin: start = uv
		else: goal = uv
		recompute())
	root.add_child(map)
	label("Click: target   Shift-click: start\nAmber: outbound · Mint: return · Red: steep cell estimate", Vector2(30, 624), Vector2(540, 45), 13)
	source = label("", Vector2(570, 105), Vector2(665, 55), 15)
	slope = spin("Slope limit (degrees)", 166, 1, 45, 15, 0.5)
	battery = spin("Battery capacity (Wh)", 209, 100, 50000, 10000, 100)
	reserve = spin("Reserve (%)", 252, 0, 80, 20, 5)
	button("COMPARE ROUTES", Vector2(570, 306), recompute, Vector2(200, 42))
	button("EXPORT GEOJSON", Vector2(785, 306), export_route, Vector2(210, 42))
	present_button = button("PRESENT THIS PLAN", Vector2(1010, 306), present_solution, Vector2(220, 42))
	report = label("", Vector2(570, 362), Vector2(660, 205), 16)
	label("Illustrative power model: 0.02 Wh/m + 20 W idle, 0.2 m/s, uphill penalty ×10.\nNo real illumination, rocks, wheel slip, thermal survival or communication checks.\nCoarse DEM + 2.34 km grid: unsuitable for final rover driving commands.\nSlope default 15° is informed by NASA's VIPER design description.", Vector2(570, 580), Vector2(665, 90), 12)
	status = label("", Vector2(30, 681), Vector2(1040, 26), 12)
	button("RETURN [P / ESC]", Vector2(1040, 24), func() -> void: close_requested.emit(), Vector2(210, 40))
	button("REPLAY BRIEFING", Vector2(820, 24), show_problem, Vector2(200, 40))
	film = Cinematic.new()
	film.finished.connect(_on_film_finished)
	add_child(film)
	root.visible = false

func label(text: String, at: Vector2, extent: Vector2, font_size: int) -> Label:
	var item := Label.new()
	item.text = text
	item.position = at
	item.size = extent
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", Color("dce8df"))
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(item)
	return item

func spin(text: String, y: float, low: float, high: float, value: float, step_size: float) -> SpinBox:
	label(text, Vector2(570, y + 5), Vector2(310, 30), 16)
	var item := SpinBox.new()
	item.position = Vector2(920, y)
	item.size = Vector2(210, 36)
	item.min_value = low
	item.max_value = high
	item.step = step_size
	item.value = value
	item.value_changed.connect(func(_value: float) -> void: recompute())
	root.add_child(item)
	return item

func button(text: String, at: Vector2, action: Callable, extent: Vector2 = Vector2(300, 42)) -> Button:
	var item := Button.new()
	item.text = text
	item.position = at
	item.size = extent
	item.pressed.connect(action)
	root.add_child(item)
	return item

func open(body: String) -> void:
	map_body = body
	body_choice.select(1 if body == "mars" else 0)
	data = MARS if body == "mars" else MOON
	root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	recompute()
	if not _intro_seen: show_problem()

func is_open() -> bool:
	return root != null and root.visible

func close() -> void:
	film.stop("cancelled")
	root.visible = false

func show_problem() -> void:
	_intro_seen = true
	film.play("problem", {"body": map_body})

func present_solution() -> void:
	if film.playing: return
	if not selected.get("feasible", false) or selected.get("outbound", []).size() < 2:
		status.text = "First find a candidate that meets the slope, return-energy and reserve constraints."
		return
	_presented_snapshot = selected.duplicate(true)
	film.play("solution", {"body": map_body, "plan": _presented_snapshot})

func _on_film_finished(reason: String) -> void:
	if reason == "cancelled": return
	if film.kind == "solution":
		status.text = "Candidate presented. Export it for further reconnaissance; it is not a flight-approved route."
		solution_presented.emit(_presented_snapshot.duplicate(true))
	else:
		status.text = "Your turn: choose study points, compare routes and present a candidate that fits the stated constraints."

func recompute() -> void:
	if data == null or report == null: return
	var shortest: Dictionary = Planner.plan(data, start, goal, slope.value, battery.value, reserve.value / 100, false)
	selected = Planner.plan(data, start, goal, slope.value, battery.value, reserve.value / 100, true)
	present_button.disabled = not selected.feasible
	source.text = "%s · %s\nPhysical patch: 150 × 150 km. Elevation values remain unscaled." % [map_body.to_upper(), data.source_product]
	report.text = "SHORTEST GRID ROUTE (BOTH LEGS)\n%.1f km · %.0f Wh · max sampled slope %.1f°\nENERGY-WEIGHTED (BOTH LEGS)\n%.1f km · %.0f Wh · max sampled slope %.1f°\n\n%s\n%s" % [shortest.distance_m / 1000, shortest.energy_wh, shortest.max_slope_deg,
		selected.distance_m / 1000, selected.energy_wh, selected.max_slope_deg, "WITHIN MODEL BUDGET" if selected.feasible else "NOT FEASIBLE UNDER THESE ASSUMPTIONS", selected.reason]
	map.data = data
	map.start = start
	map.goal = goal
	map.slope_limit = slope.value
	map.result = selected
	map.queue_redraw()
	status.text = "Export contains source ID, both legs, planetary coordinates, power assumptions and limitations. It does not command the game rover."

func export_route() -> void:
	if selected.get("outbound", []).size() < 2 or selected.get("return", []).size() < 2:
		status.text = "Choose distinct connected points before exporting."
		return
	var path: String = "user://traverse-" + map_body + ".geojson"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		status.text = "Could not save route export."
		return
	file.store_string(JSON.stringify(Planner.geojson(data, selected), "  "))
	file.close()
	status.text = "Saved: " + ProjectSettings.globalize_path(path)

func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_P, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		close_requested.emit()
