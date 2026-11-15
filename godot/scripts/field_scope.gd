extends Control
var instrument: Dictionary = {}
func _draw() -> void:
	if instrument.is_empty(): return
	draw_style_box(background(), Rect2(Vector2.ZERO, size))
	for x in range(0, int(size.x), 37): draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.6, 0.8, 0.8, 0.08))
	for y in range(0, int(size.y), 24): draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.6, 0.8, 0.8, 0.08))
	if instrument.mode == "scan":
		var peak: float = instrument.target * size.x
		draw_rect(Rect2(peak - size.x * 0.045, 6, size.x * 0.09, size.y - 12), Color(0.3, 0.8, 0.65, 0.17))
		var points := PackedVector2Array()
		for i in range(int(size.x)):
			var strength: float = exp(-pow((i / size.x - instrument.target) / 0.07, 2))
			points.append(Vector2(i, size.y - 20 - strength * (size.y - 40) + sin(i * 0.19) * 2))
		draw_polyline(points, Color("a7e2cb"), 2, true)
		var x: float = instrument.tuning * size.x
		draw_line(Vector2(x, 4), Vector2(x, size.y - 4), Color("f3c582"), 3)
	else:
		var pressure: float = float(instrument.get("pressure", 50))
		draw_rect(Rect2(35, 25, (size.x - 70) * 0.7, 24), Color("183a3f"))
		draw_rect(Rect2(35 + (size.x - 70) * 0.25, 25, (size.x - 70) * 0.45, 24), Color("46766c"))
		draw_line(Vector2(35 + (size.x - 70) * pressure / 100, 17), Vector2(35 + (size.x - 70) * pressure / 100, 57), Color("f3c582"), 4)
		draw_rect(Rect2(35, 80, size.x - 70, 18), Color("352b2c"))
		draw_rect(Rect2(35, 80, (size.x - 70) * float(instrument.get("heat", 0)) / 100, 18), Color("eb9c69"))
func background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("07131d")
	style.set_corner_radius_all(6)
	return style
