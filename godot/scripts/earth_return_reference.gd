extends Node3D
## Historical Artemis I explanation, not a continuation/claim about the fictional Mars expedition.
const EARTH = preload("res://shaders/earth.gdshader")
const TITLES = ["A REAL EARTH RETURN: ARTEMIS I", "HEAT SHIELD FIRST", "PARACHUTES, THEN PACIFIC SPLASHDOWN"]
const CAPTIONS = [
	"Historical reference, not your expedition: the uncrewed Artemis I Orion capsule separated from its service module before returning to Earth on 11 December 2022.",
	"Orion used atmospheric skip entry, with its heat shield protecting the capsule. This close-up illustrates the protected entry phase, not a calculated trajectory or powered spaceship landing.",
	"After staged parachute deployment, three main parachutes slowed the capsule for Pacific splashdown. NASA recovered Orion for inspection. Our Mars journey remains fictional; this sequence explains a real lunar-return mission."]
var camera: Camera3D
var capsule: Node3D
var service: Node3D
var earth: MeshInstance3D
var ocean: MeshInstance3D
var chutes: Node3D
var plasma: MeshInstance3D
var atmosphere: Environment

func finish(color: Color, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.65
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func mesh(parent: Node3D, shape: Mesh, at: Vector3, m: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = shape
	item.material_override = m
	item.position = at
	parent.add_child(item)
	return item

func line(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.025
	cylinder.bottom_radius = 0.025
	cylinder.height = a.distance_to(b)
	var item := mesh(parent, cylinder, (a + b) * 0.5, finish(Color("d4d9d6")))
	var axis: Vector3 = (b - a).normalized()
	var right: Vector3 = Vector3.FORWARD.cross(axis).normalized()
	item.basis = Basis(right, axis, right.cross(axis).normalized())

func _ready() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	atmosphere = settings
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("02040a")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("94a4be")
	settings.ambient_light_energy = 0.32
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var globe := SphereMesh.new()
	globe.radius = 65
	globe.height = 130
	globe.radial_segments = 96
	globe.rings = 48
	var earth_material := ShaderMaterial.new()
	earth_material.shader = EARTH
	earth = mesh(self, globe, Vector3(0, -70, -85), earth_material)
	capsule = Node3D.new()
	add_child(capsule)
	var shell := CylinderMesh.new()
	shell.top_radius = 0.75
	shell.bottom_radius = 2.1
	shell.height = 2.2
	shell.radial_segments = 48
	mesh(capsule, shell, Vector3(0, 1.1, 0), finish(Color("ced2d3")))
	var shield := CylinderMesh.new()
	shield.top_radius = 2.12
	shield.bottom_radius = 1.98
	shield.height = 0.3
	shield.radial_segments = 48
	mesh(capsule, shield, Vector3.ZERO, finish(Color("29252a")))
	for x in [-0.7, 0.7]:
		var window := BoxMesh.new()
		window.size = Vector3(0.42, 0.35, 0.04)
		mesh(capsule, window, Vector3(x, 1.5, 1.15), finish(Color("193244")))
	var glow := SphereMesh.new()
	glow.radius = 2.5
	glow.height = 0.5
	glow.radial_segments = 48
	plasma = mesh(capsule, glow, Vector3(0, -0.25, 0), finish(Color(1, 0.3, 0.06, 0.55), true))
	service = Node3D.new()
	add_child(service)
	var module := CylinderMesh.new()
	module.top_radius = 1.5
	module.bottom_radius = 1.5
	module.height = 3.5
	mesh(service, module, Vector3.ZERO, finish(Color("d2d3c8")))
	for side in [-1, 1]:
		var panel := BoxMesh.new()
		panel.size = Vector3(5.5, 0.07, 2)
		mesh(service, panel, Vector3(side * 4.2, 0, 0), finish(Color("23487b")))
	var sea := PlaneMesh.new()
	sea.size = Vector2(400, 400)
	ocean = mesh(self, sea, Vector3(0, -0.2, 0), finish(Color("1c4a67")))
	var water := Shader.new()
	water.code = "shader_type spatial; render_mode cull_disabled; varying vec3 at; void vertex(){ at=VERTEX; VERTEX.y += sin(VERTEX.x*0.18+TIME)*0.06+cos(VERTEX.z*0.22+TIME*0.8)*0.04; } void fragment(){ float ripple=0.45+0.045*sin(at.x*0.08+at.z*0.13+TIME*0.2)+0.02*sin(at.x*0.23-at.z*0.11-TIME*0.3); ALBEDO=mix(vec3(0.025,0.12,0.19),vec3(0.08,0.26,0.34),ripple); ROUGHNESS=0.28; METALLIC=0.1; }"
	var water_material := ShaderMaterial.new()
	water_material.shader = water
	sea.subdivide_width = 80
	sea.subdivide_depth = 80
	ocean.material_override = water_material
	chutes = Node3D.new()
	capsule.add_child(chutes)
	for centre in [Vector3(-4, 13, 0), Vector3(4, 13, 0), Vector3(0, 14, -4)]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for segment in range(32):
			for band in range(8):
				for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
					var angle: float = (segment + corner.x) / 32.0 * TAU
					var phi: float = (band + corner.y) / 8.0 * PI * 0.5
					surface.set_color(Color("d87742") if segment % 4 < 2 else Color("e9dfca"))
					surface.add_vertex(Vector3(cos(angle) * sin(phi) * 3, cos(phi) * 1.5, sin(angle) * sin(phi) * 3))
		var cloth := finish(Color.WHITE)
		cloth.vertex_color_use_as_albedo = true
		cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
		surface.generate_normals()
		mesh(chutes, surface.commit(), centre, cloth)
		for i in range(6):
			var angle: float = i / 6.0 * TAU
			line(chutes, Vector3(0, 2.1, 0), centre + Vector3(cos(angle) * 3, 0, sin(angle) * 3))
	camera = Camera3D.new()
	camera.current = true
	camera.far = 600
	add_child(camera)
	animate(0, 0)

func animate(shot: int, t: float) -> void:
	atmosphere.background_color = Color("8aa4b8") if shot == 2 else Color("02040a")
	atmosphere.fog_enabled = shot == 2
	atmosphere.fog_light_color = Color("8aa4b8")
	atmosphere.fog_density = 0.002
	earth.visible = shot < 2
	ocean.visible = shot == 2
	service.visible = shot == 0
	plasma.visible = shot == 1
	chutes.visible = shot == 2
	capsule.rotation.z = 0.3 if shot == 1 else 0
	capsule.position = Vector3(0, 5 if shot < 2 else lerpf(2, 0.3, smoothstep(0, 1, t)), 0)
	service.position = Vector3(0, -2 - t * 6, -t * 3)
	var target: Vector3 = capsule.position + Vector3(0, 5 if shot == 2 else 0, 0)
	camera.position = Vector3(17 - t * 2, 11, 24) if shot != 1 else Vector3(10, 1, 14)
	camera.look_at(target)
	camera.fov = 55
