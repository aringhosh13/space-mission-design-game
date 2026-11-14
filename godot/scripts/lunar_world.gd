extends Node3D
## Procedural illustrative terrain and assets. No NASA terrain measurements are used.
const Contract = preload("res://shared/mission_contract.gd")
var marker_nodes: Dictionary = {}
var station: Node3D
var scanner_ring: MeshInstance3D
var scan_age: float = 2.0
var scan_origin: Vector3 = Vector3.ZERO
var craters: Array = [Vector3(-35, 11, -36), Vector3(30, 14, 22), Vector3(-54, 16, 36), Vector3(50, 10, -52), Vector3(5, 9, -59)]

func terrain_height(x: float, z: float) -> float:
	var height: float = sin(x * 0.035) * 1.6 + cos(z * 0.045) * 1.2 + sin((x + z) * 0.12) * 0.25
	for crater: Vector3 in craters:
		var d: float = Vector2(x - crater.x, z - crater.z).length() / crater.y
		if d < 1.6:
			height += -3.0 * exp(-d * d * 2.8) + 1.3 * exp(-pow((d - 1.0) * 4.0, 2.0))
	return height

func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.95
	if emission > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission
	return result

func _mesh(parent: Node, shape: Mesh, location: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material
	instance.position = location
	parent.add_child(instance)
	return instance

func build(sites: Array) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("030713")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8fa3c3")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe4c0")
	sun.light_energy = 1.6
	sun.rotation_degrees = Vector3(-22, -42, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var resolution: int = 90
	var extent: float = 110.0
	for x_index in range(resolution):
		for z_index in range(resolution):
			var x: float = -extent + x_index * extent * 2.0 / resolution
			var z: float = -extent + z_index * extent * 2.0 / resolution
			var step_size: float = extent * 2.0 / resolution
			var points: Array[Vector3] = [Vector3(x, terrain_height(x, z), z),
				Vector3(x + step_size, terrain_height(x + step_size, z), z),
				Vector3(x, terrain_height(x, z + step_size), z + step_size),
				Vector3(x + step_size, terrain_height(x + step_size, z + step_size), z + step_size)]
			for index in [0, 1, 2, 1, 3, 2]:
				var point: Vector3 = points[index]
				var tint: float = 0.30 + 0.045 * sin(point.x * 0.5 + point.z * 0.3)
				if point.x < -18.0: tint *= 0.48
				surface.set_color(Color(tint * 0.9, tint * 0.98, tint * 1.12))
				surface.add_vertex(point)
	surface.generate_normals()
	var ground_material := _material(Color.WHITE)
	ground_material.vertex_color_use_as_albedo = true
	var terrain := _mesh(self, surface.commit(), Vector3.ZERO, ground_material)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = terrain.mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 289
	var rock_material := _material(Color("666975"))
	for i in range(180):
		var x: float = rng.randf_range(-94, 94)
		var z: float = rng.randf_range(-94, 94)
		if Vector2(x, z).length() < 7.0: continue
		var shape := SphereMesh.new()
		shape.radial_segments = 6
		shape.rings = 3
		shape.radius = rng.randf_range(0.3, 1.2)
		shape.height = shape.radius * 1.3
		var rock := _mesh(self, shape, Vector3(x, terrain_height(x, z), z), rock_material)
		rock.rotation.y = rng.randf() * TAU
		rock.scale = Vector3(rng.randf_range(0.7, 1.7), 1.0, rng.randf_range(0.7, 1.5))
		if i % 5 == 0:
			var rock_body := StaticBody3D.new()
			var rock_collision := CollisionShape3D.new()
			rock_collision.shape = shape.create_convex_shape()
			rock_body.add_child(rock_collision)
			rock.add_child(rock_body)
	# Distant crater rims create a horizon rather than a board floating in space.
	for i in range(36):
		var angle: float = float(i) / 36.0 * TAU
		var mountain := SphereMesh.new()
		mountain.radius = 1.0
		mountain.height = 2.0
		mountain.radial_segments = 6
		mountain.rings = 3
		var ridge := _mesh(self, mountain, Vector3(sin(angle) * 118.0, -2, cos(angle) * 118.0), rock_material)
		ridge.scale = Vector3(18, rng.randf_range(8, 20), 18)
	var star_material := _material(Color("c6d9ef"), 1.8)
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.12
	star_mesh.height = 0.24
	star_mesh.radial_segments = 4
	star_mesh.rings = 2
	for i in range(220):
		var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.15, 1), rng.randf_range(-1, 1)).normalized()
		_mesh(self, star_mesh, direction * 230.0, star_material)
	var earth_mesh := SphereMesh.new()
	earth_mesh.radius = 9
	earth_mesh.height = 18
	var earth_shader := Shader.new()
	earth_shader.code = "shader_type spatial; render_mode unshaded; void fragment(){ vec3 p=VERTEX; float n=sin(p.x*0.85+sin(p.y*0.7))*cos(p.z*0.8-p.y*0.5); vec3 c=mix(vec3(0.04,0.18,0.40),vec3(0.20,0.43,0.32),smoothstep(0.0,0.4,n)); float cloud=sin(p.x*1.7+p.z*0.9+sin(p.y))*cos(p.y*1.5); c=mix(c,vec3(0.78,0.85,0.90),smoothstep(0.45,0.8,cloud)*0.8); ALBEDO=c; }"
	var earth_material := ShaderMaterial.new()
	earth_material.shader = earth_shader
	_mesh(self, earth_mesh, Vector3(-72, 60, -150), earth_material)
	for site in sites:
		var node := Node3D.new()
		node.position = site.position
		node.position.y = terrain_height(node.position.x, node.position.z)
		var ring := TorusMesh.new()
		ring.inner_radius = 1.3
		ring.outer_radius = 1.45
		var marker := _mesh(node, ring, Vector3(0, 0.25, 0), _material(Color("f3c582"), 0.6))
		var label := Label3D.new()
		label.position.y = 3.5
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 40
		label.pixel_size = 0.016
		label.outline_size = 10
		node.add_child(label)
		add_child(node)
		marker_nodes[site.id] = {"node": node, "ring": marker, "label": label}
	station = Node3D.new()
	station.visible = false
	var module := BoxMesh.new()
	module.size = Vector3(2.5, 1.5, 2.2)
	_mesh(station, module, Vector3(0, 0.85, 0), _material(Color("dedccc")))
	var panel := BoxMesh.new()
	panel.size = Vector3(5.0, 0.1, 2.0)
	_mesh(station, panel, Vector3(0, 1.9, 0), _material(Color("284e89")))
	var station_name := Label3D.new()
	station_name.text = "RESEARCH STATION"
	station_name.position.y = 3.5
	station_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station_name.font_size = 32
	station.add_child(station_name)
	add_child(station)
	var scan_mesh := TorusMesh.new()
	scan_mesh.inner_radius = 0.95
	scan_mesh.outer_radius = 1.0
	var scan_material := _material(Color("8ce9d2"), 1.0)
	scan_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	scanner_ring = _mesh(self, scan_mesh, Vector3.ZERO, scan_material)
	scanner_ring.visible = false

func update_mission(state: Dictionary) -> void:
	for site in state.sites:
		var marker: Dictionary = marker_nodes[site.id]
		var color: Color = Contract.FINDING_COLORS[site.finding]
		marker.ring.material_override.albedo_color = color
		marker.ring.material_override.emission = color
		marker.label.modulate = color
		marker.label.text = str(site.name) + "\n" + str(site.confidence) + "% · " + str(Contract.FINDING_LABELS[site.finding])
	station.visible = state.outpost_deployed and state.outpost_position != null
	if station.visible:
		station.position = state.outpost_position
		station.position.y = terrain_height(station.position.x, station.position.z)

func pulse(origin: Vector3) -> void:
	scan_origin = origin
	scan_age = 0.0

func _process(delta: float) -> void:
	scan_age += delta
	if scanner_ring == null: return
	scanner_ring.visible = scan_age < 1.6
	if scanner_ring.visible:
		var radius: float = 1.0 + scan_age * 11.0
		scanner_ring.scale = Vector3(radius, 1, radius)
		scanner_ring.position = Vector3(scan_origin.x, terrain_height(scan_origin.x, scan_origin.z) + 0.22, scan_origin.z)
		scanner_ring.material_override.albedo_color.a = 1.0 - scan_age / 1.6
