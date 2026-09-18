shader_type canvas_item;
render_mode unshaded;

uniform sampler2D terrain_atlas : source_color, filter_linear, repeat_disable;
uniform sampler2D biome_map : filter_linear, repeat_disable;
uniform float world_size = 4096.0;
varying vec4 surface_tint;

void vertex() {
	surface_tint = COLOR;
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 h = fract(sin(vec4(dot(i, vec2(127.1, 311.7)), dot(i + vec2(1, 0), vec2(127.1, 311.7)), dot(i + vec2(0, 1), vec2(127.1, 311.7)), dot(i + vec2(1, 1), vec2(127.1, 311.7)))) * 43758.5453);
	return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}

vec3 material_at(vec2 p, vec2 quadrant) {
	// 镜像平铺维持边缘连续；留出纹素边距，防止采到邻接材质。
	vec2 tile_uv = 1.0 - abs(mod(p / 320.0, 2.0) - 1.0);
	vec2 safe_uv = mix(vec2(0.003), vec2(0.997), tile_uv);
	return texture(terrain_atlas, (quadrant + safe_uv) * 0.5).rgb;
}

void fragment() {
	vec2 p = UV * world_size;
	vec2 warp = vec2(noise(p / 47.0), noise(p / 47.0 + 17.0)) - 0.5;
	vec3 biome = texture(biome_map, UV + warp * 0.006).rgb;
	vec3 meadow = material_at(p, vec2(0, 0)) * vec3(0.91, 1.10, 0.94);
	vec3 soil = material_at(p + vec2(91, 37), vec2(1, 0));
	vec3 rock = material_at(p, vec2(0, 1));
	vec3 moss = material_at(p + vec2(29, 73), vec2(1, 1));
	float patches = smoothstep(0.50, 0.79, noise(p / 210.0) * 0.7 + noise(p / 79.0) * 0.3);
	vec3 ground = mix(meadow, soil, max(patches * 0.6, biome.b * 0.65));
	ground = mix(ground, moss, smoothstep(0.05, 0.8, biome.g) * 0.72);
	ground = mix(ground, rock * 0.84, smoothstep(0.12, 0.8, biome.r));
	COLOR = vec4(ground * (0.95 + 0.08 * noise(p / 125.0)), 1.0) * surface_tint;
}
