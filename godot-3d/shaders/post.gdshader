shader_type canvas_item;
// Light film finish over the 3D picture: vignette, slight lens colour fringing and fine grain.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette = 0.38;
uniform float fringe = 0.0007;
uniform float grain = 0.022;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r2 = dot(d, d);
	vec2 off = d * fringe * r2 * 6.0;
	vec3 c = vec3(texture(screen_tex, uv + off).r, texture(screen_tex, uv).g, texture(screen_tex, uv - off).b);
	c *= 1.0 - vignette * smoothstep(0.12, 0.62, r2 * 2.0);
	float n = fract(sin(dot(uv * vec2(1920.0, 1080.0) + fract(TIME) * 97.0, vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
