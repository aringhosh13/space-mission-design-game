extends WorldEnvironment
## Procedural star sky with a sun disc (sky shader generated in code; no textures or external assets).
## Star positions come from a hash of the view direction, so they are stable and cost no geometry.

func _ready() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type sky;
uniform vec3 sun_color = vec3(1.0, 0.92, 0.78);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float stars(vec3 dir, float scale, float threshold) {
	vec3 cell = floor(dir * scale);
	float h = hash(cell);
	if (h < threshold) return 0.0;
	vec3 centre = (cell + 0.5) / scale;
	float d = length(dir - normalize(centre)) * scale;
	return smoothstep(0.55, 0.0, d) * (h - threshold) / (1.0 - threshold);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float band = exp(-pow(dir.y * 2.4 + 0.35 * sin(dir.x * 3.0), 2.0));
	vec3 col = vec3(0.004, 0.007, 0.016) + vec3(0.03, 0.025, 0.05) * band;
	col += vec3(0.05, 0.02, 0.06) * pow(max(0.0, dot(dir, normalize(vec3(-0.6, 0.2, 0.7)))), 6.0);
	col += vec3(0.85, 0.9, 1.0) * stars(dir, 220.0, 0.985) * 1.4;
	col += vec3(1.0, 0.85, 0.7) * stars(dir, 90.0, 0.992) * 2.0;
	col += vec3(0.7, 0.8, 1.0) * stars(dir, 520.0, 0.97) * 0.5 * (0.4 + band);
	float sun = dot(dir, -LIGHT0_DIRECTION);
	col += sun_color * (smoothstep(0.9993, 0.9997, sun) * 6.0 + pow(max(sun, 0.0), 400.0) * 0.8);
	COLOR = col;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var sky := Sky.new()
	sky.sky_material = material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6f7f9f")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	environment = env
