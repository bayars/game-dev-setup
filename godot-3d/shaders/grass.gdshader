shader_type spatial;
render_mode cull_disabled;
// Grass blades: dark root to bright tip, wind that bends the upper part, translucency toward the sun,
// and a distance fade (blades shrink into the ground texture instead of popping).

uniform vec3 base_color : source_color = vec3(0.06, 0.13, 0.035);
uniform vec3 tip_color : source_color = vec3(0.36, 0.52, 0.16);
uniform float wind = 0.10;
uniform float fade_start = 26.0;
uniform float fade_end = 46.0;

varying float h;
varying float vary;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	h = UV.y;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 origin = MODEL_MATRIX[3].xyz;
	vary = hash(floor(origin.xz * 4.0));
	float w = sin(TIME * 1.5 + origin.x * 0.45 + origin.z * 0.31) + 0.45 * sin(TIME * 3.3 + origin.x * 1.3 + origin.z * 0.9);
	VERTEX.x += w * wind * h * h;
	VERTEX.z += w * wind * 0.6 * h * h;
	float dist = length((VIEW_MATRIX * vec4(origin, 1.0)).xyz);
	VERTEX.y *= 1.0 - smoothstep(fade_start, fade_end, dist);
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 c = mix(base_color, tip_color, smoothstep(0.0, 1.0, h));
	c *= 0.75 + 0.5 * vary;
	c = mix(c, c * vec3(1.25, 1.0, 0.55), step(0.82, vary) * 0.5 * h);   // a few dry yellowish blades
	ALBEDO = c;
	ROUGHNESS = 0.6;
	SPECULAR = 0.1;
	BACKLIGHT = c * 0.3;
	AO = mix(0.3, 1.0, h);
	AO_LIGHT_AFFECT = 0.6;
}
