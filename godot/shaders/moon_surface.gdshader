shader_type spatial;
render_mode diffuse_burley, specular_disabled;
varying vec3 ground_position;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
  vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
    mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}
void vertex() { ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
  vec2 p = ground_position.xz;
  float broad = noise2(p * 0.08) * 0.60 + noise2(p * 0.34) * 0.27 + noise2(p * 1.7) * 0.13;
  float grit = noise2(p * 24.0);
  float exposure = mix(0.48, 1.0, smoothstep(-26.0, -12.0, p.x));
  vec3 dark = vec3(0.20, 0.215, 0.24);
  vec3 light = vec3(0.44, 0.425, 0.40);
  ALBEDO = mix(dark, light, broad) * exposure * (0.90 + grit * 0.20);
  float dx = noise2((p + vec2(0.018, 0.0)) * 24.0) - grit;
  float dz = noise2((p + vec2(0.0, 0.018)) * 24.0) - grit;
  NORMAL_MAP = normalize(vec3(-dx * 0.35, -dz * 0.35, 1.0)) * 0.5 + 0.5;
  NORMAL_MAP_DEPTH = 0.4;
  ROUGHNESS = 0.97;
  AO = 0.82 + broad * 0.18;
}
