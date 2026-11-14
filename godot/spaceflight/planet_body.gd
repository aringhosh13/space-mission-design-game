extends Node3D
## A planet or moon in the space scene, built from a destination definition (procedural shader; no textures).
## Appearance is illustrative and not derived from NASA imagery.

const TYPES: Dictionary = {"moon": 0, "mars": 1, "earth": 2}
const ATMOSPHERE: Dictionary = {"mars": Color(0.9, 0.5, 0.3), "earth": Color(0.35, 0.6, 1.0)}

var def: Dictionary
var label: Label3D
var approach_ring: MeshInstance3D

static var _surface_shader: Shader
static var _atmosphere_shader: Shader

func setup(definition: Dictionary) -> void:
	def = definition

func _ready() -> void:
	var space: Dictionary = def.space
	var radius: float = float(space.radius)
	position = space.position
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	var surface := MeshInstance3D.new()
	surface.mesh = sphere
	var material := ShaderMaterial.new()
	material.shader = _get_surface_shader()
	material.set_shader_parameter("planet_type", TYPES.get(def.id, 0))
	surface.material_override = material
	add_child(surface)
	if ATMOSPHERE.has(def.id):
		var shell := SphereMesh.new()
		shell.radius = radius * 1.06
		shell.height = radius * 2.12
		shell.radial_segments = 64
		shell.rings = 32
		var halo := MeshInstance3D.new()
		halo.mesh = shell
		var halo_material := ShaderMaterial.new()
		halo_material.shader = _get_atmosphere_shader()
		halo_material.set_shader_parameter("tint", ATMOSPHERE[def.id])
		halo.material_override = halo_material
		add_child(halo)
	if def.kind == "explorable":
		var ring := TorusMesh.new()
		var approach_radius: float = radius + float(space.approach_altitude)
		ring.inner_radius = approach_radius - 0.35
		ring.outer_radius = approach_radius + 0.35
		ring.rings = 96
		approach_ring = MeshInstance3D.new()
		approach_ring.mesh = ring
		var ring_material := StandardMaterial3D.new()
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_material.albedo_color = Color(0.95, 0.77, 0.5, 0.3)
		ring_material.no_depth_test = true
		approach_ring.material_override = ring_material
		add_child(approach_ring)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0012
	label.font_size = 26
	label.outline_size = 8
	label.no_depth_test = true
	label.position = Vector3(0, radius * 1.25, 0)
	label.text = str(def.name).to_upper() + ("" if def.kind == "explorable" else "\nlandmark")
	add_child(label)

## The approach-zone outline always faces the camera, so it reads as a guide circle rather than
## being mistaken for planetary rings.
func _process(_delta: float) -> void:
	if approach_ring == null or not approach_ring.visible: return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null: return
	var to_camera: Vector3 = camera.global_position - global_position
	if to_camera.length() < 0.001: return
	approach_ring.global_basis = Basis.looking_at(to_camera.normalized(), Vector3.UP if absf(to_camera.normalized().y) < 0.99 else Vector3.RIGHT) * Basis(Vector3.RIGHT, PI / 2.0)

func set_targeted(targeted: bool) -> void:
	if label: label.modulate = Color("f3c582") if targeted else Color(0.85, 0.9, 0.95, 0.75)
	if approach_ring: approach_ring.visible = targeted

static func _get_surface_shader() -> Shader:
	if _surface_shader: return _surface_shader
	_surface_shader = Shader.new()
	_surface_shader.code = """
shader_type spatial;
uniform int planet_type = 0;
varying vec3 obj;
void vertex() { obj = VERTEX; }
float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float noise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float a = 0.5; float s = 0.0; for (int i = 0; i < 5; i++) { s += a * noise(p); p *= 2.03; a *= 0.5; } return s; }
void fragment() {
	vec3 n = normalize(obj);
	vec3 col; float rough = 0.95;
	if (planet_type == 0) {
		float maria = fbm(n * 2.6 + 4.0);
		float detail = fbm(n * 14.0);
		col = mix(vec3(0.62, 0.62, 0.60), vec3(0.30, 0.30, 0.32), smoothstep(0.52, 0.62, maria));
		col *= 0.8 + 0.35 * detail;
	} else if (planet_type == 1) {
		float m = fbm(n * 2.4);
		float d = fbm(n * 6.0 + 3.0);
		col = mix(vec3(0.42, 0.15, 0.07), vec3(0.80, 0.42, 0.20), smoothstep(0.3, 0.72, m));
		col = mix(col, vec3(0.28, 0.11, 0.06), smoothstep(0.55, 0.72, d) * 0.6);
		col = mix(col, vec3(0.93, 0.90, 0.87), smoothstep(0.88, 0.93, abs(n.y)));
	} else {
		float m = fbm(n * 2.2 + 1.7);
		float land = smoothstep(0.50, 0.53, m);
		col = mix(vec3(0.03, 0.12, 0.33), mix(vec3(0.15, 0.34, 0.14), vec3(0.55, 0.48, 0.32), smoothstep(0.6, 0.72, m)), land);
		col = mix(col, vec3(0.92), smoothstep(0.82, 0.88, abs(n.y)));
		float cloud = fbm(n * 4.0 + vec3(TIME * 0.01, 0.0, 0.0));
		col = mix(col, vec3(0.96), smoothstep(0.55, 0.75, cloud) * 0.85);
		rough = mix(0.3, 0.9, land);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
}
"""
	return _surface_shader

static func _get_atmosphere_shader() -> Shader:
	if _atmosphere_shader: return _atmosphere_shader
	_atmosphere_shader = Shader.new()
	_atmosphere_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform vec3 tint = vec3(0.4, 0.6, 1.0);
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = tint * rim * 1.4;
	ALPHA = rim;
}
"""
	return _atmosphere_shader
