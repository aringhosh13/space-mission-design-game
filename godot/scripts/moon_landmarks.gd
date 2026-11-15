extends Node3D
## Original procedural landing equipment. Scenery only; it never changes mission rules.
var landing_module: Node3D

func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color = color
	value.metallic = metal
	value.roughness = 0.65
	return value

func shape(parent: Node3D, mesh: Mesh, at: Vector3, finish: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = finish
	parent.add_child(instance)
	return instance

func beam(parent: Node3D, from: Vector3, to: Vector3, radius: float, finish: Material) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = from.distance_to(to)
	var instance := shape(parent, cylinder, (from + to) * 0.5, finish)
	var direction: Vector3 = (to - from).normalized()
	var right: Vector3 = Vector3.FORWARD.cross(direction).normalized()
	if right.length() < 0.1: right = Vector3.RIGHT
	instance.basis = Basis(right, direction, right.cross(direction).normalized())

func build(world: Node3D) -> void:
	var gold := material(Color("9d7844"), 0.62)
	var white := material(Color("c7c9c7"), 0.25)
	var black := material(Color("202730"), 0.18)
	var blue := material(Color("1b3048"), 0.55)
	landing_module = Node3D.new()
	landing_module.name = "LandingModuleScenery"
	landing_module.position = Vector3(-9, world.terrain_height(-9, 5), 5)
	add_child(landing_module)
	var base := CylinderMesh.new()
	base.top_radius = 1.8
	base.bottom_radius = 2.2
	base.height = 1.5
	base.radial_segments = 8
	shape(landing_module, base, Vector3(0, 1.6, 0), gold)
	var cabin := CylinderMesh.new()
	cabin.top_radius = 1.25
	cabin.bottom_radius = 1.65
	cabin.height = 2.0
	cabin.radial_segments = 8
	shape(landing_module, cabin, Vector3(0, 3.3, 0), white)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var collision_shape := CylinderShape3D.new()
	collision_shape.radius = 1.8
	collision_shape.height = 3.4
	collision.shape = collision_shape
	collision.position.y = 2.2
	body.add_child(collision)
	landing_module.add_child(body)
	var window := BoxMesh.new()
	window.size = Vector3(1.1, 0.6, 0.1)
	shape(landing_module, window, Vector3(0, 3.6, -1.45), blue)
	for angle in [PI / 4.0, PI * 0.75, PI * 1.25, PI * 1.75]:
		var foot := Vector3(sin(angle) * 3.4, 0.2, cos(angle) * 3.4)
		beam(landing_module, Vector3(sin(angle) * 1.5, 2.0, cos(angle) * 1.5), foot, 0.09, white)
		beam(landing_module, Vector3(sin(angle) * 1.8, 1.2, cos(angle) * 1.8), foot, 0.055, gold)
		var pad := CylinderMesh.new()
		pad.top_radius = 0.55
		pad.bottom_radius = 0.65
		pad.height = 0.1
		shape(landing_module, pad, foot, black)
	beam(landing_module, Vector3(0, 4.2, 0), Vector3(0, 5.6, 0), 0.035, white)
	var dish := SphereMesh.new()
	dish.radius = 0.55
	dish.height = 0.35
	dish.radial_segments = 16
	shape(landing_module, dish, Vector3(0, 5.6, 0), white).rotation.z = 0.5
	var label := Label3D.new()
	label.text = "BH–01  /  LANDING SITE"
	label.position = Vector3(0, 6.3, 0)
	label.font_size = 30
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	landing_module.add_child(label)
	# Four low approach lights make the landing site recognizable when returning.
	for point in [Vector2(-15, 0), Vector2(-3, 0), Vector2(-15, 11), Vector2(-3, 11)]:
		var post := CylinderMesh.new()
		post.top_radius = 0.06
		post.bottom_radius = 0.09
		post.height = 0.9
		var position_3d := Vector3(point.x, world.terrain_height(point.x, point.y) + 0.45, point.y)
		shape(self, post, position_3d, white)
		var lamp := SphereMesh.new()
		lamp.radius = 0.12
		lamp.height = 0.24
		var glow := material(Color("ebbd71"))
		glow.emission_enabled = true
		glow.emission = Color("ebbd71")
		glow.emission_energy_multiplier = 1.5
		shape(self, lamp, position_3d + Vector3(0, 0.5, 0), glow)
	# Landing anchor is an integration hook for the separate spaceship feature.
	var anchor := Marker3D.new()
	anchor.name = "LandingAnchor"
	anchor.position = Vector3(-9, world.terrain_height(-9, 5) + 6.0, 5)
	add_child(anchor)
