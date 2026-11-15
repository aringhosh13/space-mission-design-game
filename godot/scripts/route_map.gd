extends Control
signal point_selected(uv: Vector2, start_point: bool)
var data: Resource
var result: Dictionary = {}
var start := Vector2(0.5, 0.5)
var goal := Vector2(0.65, 0.35)
var slope_limit: float = 15.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		point_selected.emit((event.position / size).clamp(Vector2.ZERO, Vector2.ONE), event.shift_pressed)
		accept_event()

func _draw() -> void:
	if data == null: return
	var step_m: float = data.real_half_extent_m * 2.0 / 64.0
	var low: float = INF
	var high: float = -INF
	for elevation in data.elevations:
		low = minf(low, elevation)
		high = maxf(high, elevation)
	for y in range(64):
		for x in range(64):
			var uv := Vector2(x, y) / 64.0
			var h: float = data.sample_uv(uv.x, uv.y)
			var dx: float = data.sample_uv(uv.x + 1.0 / 64.0, uv.y) - h
			var dy: float = data.sample_uv(uv.x, uv.y + 1.0 / 64.0) - h
			var grade: float = rad_to_deg(atan(Vector2(dx, dy).length() / step_m))
			var color := Color("243e4b").lerp(Color("c2c8b3"), clampf((h - low) / maxf(1, high - low), 0, 1))
			if grade > slope_limit: color = color.lerp(Color("c6654d"), 0.75)
			draw_rect(Rect2(Vector2(x, y) * size / 64.0, size / 64.0 + Vector2.ONE), color)
	for leg in ["outbound", "return"]:
		var points := PackedVector2Array()
		for uv: Vector2 in result.get(leg, []): points.append(uv * size)
		if points.size() > 1: draw_polyline(points, Color("ffd184") if leg == "outbound" else Color("91e6d2"), 3 if leg == "outbound" else 1, true)
	draw_circle(start * size, 6, Color("a6e5bb"))
	draw_circle(goal * size, 6, Color("ffd184"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("8aa8ac"), false, 1)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, start * size + Vector2(8, -8), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(font, goal * size + Vector2(8, -8), "TARGET", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
