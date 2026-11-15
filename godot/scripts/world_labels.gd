extends RefCounted
## Declutter ground annotations in screen space. Full site/objective information remains in the HUD.
static func update(world: Node3D, camera: Camera3D) -> Array[Rect2]:
	var occupied: Array[Rect2] = []
	if camera == null or not camera.is_inside_tree(): return occupied
	var labels: Array = world.find_children("*", "Label3D", true, false)
	labels.sort_custom(func(a: Label3D, b: Label3D) -> bool:
		var pa: int = int(a.get_meta("annotation_priority", 0))
		var pb: int = int(b.get_meta("annotation_priority", 0))
		return pa > pb if pa != pb else camera.global_position.distance_squared_to(a.global_position) < camera.global_position.distance_squared_to(b.global_position))
	var viewport: Vector2 = camera.get_viewport().get_visible_rect().size
	var reserved: Array[Rect2] = [Rect2(0, 0, 1280, 100), Rect2(365, 106, 560, 64), Rect2(15, 118, 300, 245), Rect2(0, 360, 330, 250),
		Rect2(1000, 0, 280, 225), Rect2(1040, 460, 230, 210), Rect2(330, 510, 710, 155)]
	for label: Label3D in labels:
		var parent: Node3D = label.get_parent() as Node3D
		label.visible = false
		if parent == null or not parent.is_visible_in_tree() or not label.get_meta("annotation_enabled", true): continue
		var depth: float = -(camera.global_transform.affine_inverse() * label.global_position).z
		if depth < 1.0 or depth > 120.0: continue
		var screen: Vector2 = camera.unproject_position(label.global_position)
		if not Rect2(Vector2.ZERO, viewport).has_point(screen): continue
		var font_px: float = label.font_size * label.pixel_size * viewport.y / (2.0 * tan(deg_to_rad(camera.fov * 0.5)) * depth)
		if label.fixed_size: font_px = float(label.font_size)
		if font_px < 9.0: continue
		var longest: int = 0
		var lines: PackedStringArray = label.text.split("\n")
		for line in lines: longest = maxi(longest, line.length())
		var extent := Vector2(clampf(longest * font_px * 0.65 + 20, 60, 700), maxf(24, font_px * lines.size() * 1.4 + 12))
		var rect := Rect2(screen - extent * 0.5, extent)
		var collides: bool = false
		for panel in reserved:
			if panel.intersects(rect): collides = true; break
		for other in occupied:
			if other.grow(8).intersects(rect): collides = true; break
		if not collides:
			label.visible = true
			occupied.append(rect)
	return occupied
