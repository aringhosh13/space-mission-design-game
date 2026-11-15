extends Node3D
## Presentation-only waypoint beacons for campaign checkpoints (original procedural geometry).
## update_checkpoints(list) takes [{id, title, position, completed, active}] from simulation/campaign.gd;
## it never decides completion. `height_at` places beacons on the terrain.
var height_at: Callable = func(_x: float, _z: float) -> float: return 0.0
var _nodes: Dictionary = {}

const ACTIVE := Color("f3c582")
const DONE := Color("a6e5bb")
const IDLE := Color(0.75, 0.82, 0.88, 0.55)

func update_checkpoints(checkpoints: Array) -> void:
	var seen: Dictionary = {}
	for checkpoint in checkpoints:
		var id: String = str(checkpoint.id)
		seen[id] = true
		if not _nodes.has(id): _nodes[id] = _make(str(checkpoint.title))
		var node: Node3D = _nodes[id]
		var p: Vector3 = checkpoint.position
		node.position = Vector3(p.x, height_at.call(p.x, p.z), p.z)
		var color: Color = ACTIVE if checkpoint.active else (DONE if checkpoint.completed else IDLE)
		var beam: MeshInstance3D = node.get_meta("beam")
		var ring: MeshInstance3D = node.get_meta("ring")
		var label: Label3D = node.get_meta("label")
		(beam.material_override as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, 0.28 if checkpoint.active else 0.12)
		(ring.material_override as StandardMaterial3D).albedo_color = color
		beam.scale = Vector3(1, 1.0 if checkpoint.active else 0.45, 1)
		beam.position.y = 20.0 * beam.scale.y
		label.text = ("▶ " if checkpoint.active else ("✓ " if checkpoint.completed else "")) + str(checkpoint.title).to_upper()
		label.modulate = color
		label.position.y = 42.0 * beam.scale.y + 2.0
		label.set_meta("annotation_enabled", bool(checkpoint.active))
		label.set_meta("annotation_priority", 100 if checkpoint.active else 0)
		label.visible = bool(checkpoint.active)
	for id in _nodes.keys():
		if not seen.has(id):
			_nodes[id].queue_free()
			_nodes.erase(id)

func _make(title: String) -> Node3D:
	var node := Node3D.new()
	add_child(node)
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.35
	beam_mesh.bottom_radius = 0.9
	beam_mesh.height = 40.0
	beam_mesh.radial_segments = 12
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam := MeshInstance3D.new()
	beam.mesh = beam_mesh
	beam.material_override = beam_material
	node.add_child(beam)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 3.4
	ring_mesh.outer_radius = 3.7
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.material_override = ring_material
	ring.position.y = 0.3
	node.add_child(ring)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.font_size = 26
	label.outline_size = 8
	label.no_depth_test = true
	label.text = title
	node.add_child(label)
	node.set_meta("beam", beam)
	node.set_meta("ring", ring)
	node.set_meta("label", label)
	return node
