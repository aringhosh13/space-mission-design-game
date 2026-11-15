shader_type spatial;
render_mode unshaded;
varying vec3 globe_position;
void vertex() { globe_position = normalize(VERTEX); }
void fragment() {
  vec3 p = globe_position;
  float continents = sin(p.x*9.0 + sin(p.y*7.0)) * cos(p.z*8.0 - p.y*5.0) + sin(p.x*17.0+p.z*12.0)*0.22;
  vec3 water = vec3(0.025, 0.14, 0.32);
  vec3 land = vec3(0.20, 0.32, 0.20);
  vec3 color = mix(water, land, smoothstep(0.0, 0.35, continents));
  float clouds = sin(p.x*21.0+p.z*13.0+sin(p.y*10.0)) * cos(p.y*18.0-p.z*7.0);
  color = mix(color, vec3(0.83, 0.88, 0.94), smoothstep(0.30, 0.65, clouds) * 0.8);
  color = mix(color, vec3(0.85, 0.89, 0.94), smoothstep(0.78, 0.97, abs(p.y)));
  float daylight = smoothstep(-0.2, 0.5, dot(p, normalize(vec3(1.0, 0.4, 0.8))));
  ALBEDO = color * mix(0.08, 1.0, daylight);
}
