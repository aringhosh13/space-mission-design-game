extends RefCounted
## Static prop collision, with mesh scale/rotation baked into convex vertices.
## No scaled physics bodies; non-solid markers, sky and effects opt out explicitly.
static func attach(visual: MeshInstance3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "SolidCollision"
	body.collision_layer = 3 # world + separately queryable solid props
	body.position = visual.position
	var points := PackedVector3Array()
	for vertex in visual.mesh.get_faces(): points.append(visual.transform.basis * vertex)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	visual.get_parent().add_child(body)
	body.set_meta("solid_visual", weakref(visual))
	visual.set_meta("solid_body", weakref(body))
	body.add_to_group("solid_props")
	return body

static func set_enabled(root: Node, enabled: bool) -> void:
	for child in root.get_children():
		if child is StaticBody3D and child.has_meta("solid_visual"):
			child.collision_layer = 3 if enabled else 0
		set_enabled(child, enabled)
