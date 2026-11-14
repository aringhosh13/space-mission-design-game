extends Control
## Presentation-only local survey map. No truth beyond engine-exposed findings is shown.
const Contract = preload("res://shared/mission_contract.gd")
var rover_position: Vector3 = Vector3.ZERO
var heading: float = 0.0
var sites: Array = []
var station_position: Variant = null
var base_position: Vector3 = Vector3(-9, 0, 5)
var range_m: float = 62.0
var checkpoints: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_view(state: Dictionary, camera_heading: float, info: Dictionary = {}) -> void:
	rover_position = state.position
	heading = camera_heading
	sites = state.sites
	station_position = state.outpost_position
	base_position = info.get("pad", Vector3(-9, 0, 5))
	range_m = maxf(20.0, float(info.get("radar_range", 62.0)))
	checkpoints = info.get("checkpoints", [])
	queue_redraw()

func _map(point: Vector3) -> Vector2:
	var delta := Vector2(point.x - rover_position.x, point.z - rover_position.z) * (65.0 / range_m)
	return Vector2(85, 85) + delta.limit_length(65.0)

func _draw() -> void:
	var center := Vector2(85, 85)
	draw_circle(center, 78.0, Color(0.015, 0.035, 0.06, 0.88))
	draw_arc(center, 78.0, 0, TAU, 64, Color("58737b"), 1.0, true)
	draw_arc(center, 39.0, 0, TAU, 48, Color(0.3, 0.4, 0.45, 0.35), 1.0, true)
	draw_line(Vector2(85, 12), Vector2(85, 158), Color(0.3, 0.4, 0.45, 0.3))
	draw_line(Vector2(12, 85), Vector2(158, 85), Color(0.3, 0.4, 0.45, 0.3))
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(81, 20), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d5e3d7"))
	draw_string(font, Vector2(30, 179), "SURVEY · %d m" % roundi(range_m), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("a3bbc3"))
	var base := _map(base_position)
	draw_rect(Rect2(base - Vector2(3, 3), Vector2(6, 6)), Color("e5dfc6"), false, 1.0)
	draw_string(font, base + Vector2(5, 8), "H", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e5dfc6"))
	for site in sites:
		var point: Vector2 = _map(site.position)
		var color: Color = Contract.FINDING_COLORS[site.finding]
		draw_circle(point, 3.2, color)
		draw_string(font, point + Vector2(5, -3), str(site.id).get_slice("-", str(site.id).get_slice_count("-") - 1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
	for checkpoint in checkpoints:
		if not checkpoint.get("active", false): continue
		var at: Vector2 = _map(checkpoint.position)
		draw_arc(at, 6.0, 0, TAU, 16, Color("ffe1a3"), 2.0, true)
	if station_position != null:
		var at: Vector2 = _map(station_position)
		draw_line(at - Vector2(4, 0), at + Vector2(4, 0), Color("a8e3b9"), 2.0)
		draw_line(at - Vector2(0, 4), at + Vector2(0, 4), Color("a8e3b9"), 2.0)
	var triangle := PackedVector2Array()
	for point in [Vector2(0, -7), Vector2(-4, 5), Vector2(4, 5)]: triangle.append(center + point.rotated(heading))
	draw_colored_polygon(triangle, Color("f0f3df"))
