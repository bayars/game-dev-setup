shader_type spatial;
// Terrain: baked grass and gravel PBR textures in world space, grass broken up with a second large-scale
// layer (no visible tiling), and the path as a noisy-edged mask instead of a separate mesh.

uniform sampler2D grass_a : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_n : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_r : hint_roughness_g, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D path_a : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D path_n : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D path_r : hint_roughness_g, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float grass_m = 2.5;
uniform float macro_m = 23.0;
uniform float path_m = 2.0;
uniform float path_half = 1.15;
uniform vec2 path_z = vec2(-13.9, 60.0);   // the path runs along z between these values

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	vec3 g1 = texture(grass_a, p / grass_m).rgb;
	vec3 g2 = texture(grass_a, rot * p / macro_m).rgb;
	float macro = dot(g2, vec3(0.333));
	vec3 grass = g1 * (0.55 + macro * 1.9);

	float wobble = texture(grass_a, p / 7.0).g * 1.1 + texture(grass_a, p / 1.3).g * 0.45;
	float d = abs(p.x) + (wobble - 0.45) * 0.9;
	float along = smoothstep(path_z.x - 0.4, path_z.x + 0.5, p.y) * (1.0 - smoothstep(path_z.y - 6.0, path_z.y, p.y));
	float m = (1.0 - smoothstep(path_half - 0.25, path_half + 0.2, d)) * along;
	vec3 gravel = texture(path_a, p / path_m).rgb;
	float edge = smoothstep(0.0, 0.5, m) * (1.0 - smoothstep(0.5, 1.0, m));   // darker, trampled rim
	gravel *= 1.0 - 0.25 * edge;

	ALBEDO = mix(grass, gravel, m);
	ROUGHNESS = mix(texture(grass_r, p / grass_m).g, texture(path_r, p / path_m).g, m);
	SPECULAR = mix(0.25, 0.45, m);
	NORMAL_MAP = mix(texture(grass_n, p / grass_m).rgb, texture(path_n, p / path_m).rgb, m);
	NORMAL_MAP_DEPTH = 1.1;
}
