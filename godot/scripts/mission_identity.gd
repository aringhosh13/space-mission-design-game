extends RefCounted
## Original vector identity, distinct from NASA's official identifiers. No collision or mission state.
const BADGE = preload("res://assets/identity/blue-horizon-badge.svg")

static func patch(parent: Node3D, at: Vector3, angle: Vector3, width: float) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = "BlueHorizonBadge"
	var face := QuadMesh.new()
	face.size = Vector2.ONE * width
	item.mesh = face
	var finish := StandardMaterial3D.new()
	finish.albedo_texture = BADGE
	finish.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	finish.roughness = 0.9
	item.material_override = finish
	item.position = at
	item.rotation = angle
	parent.add_child(item)
	return item
