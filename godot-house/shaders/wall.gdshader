shader_type spatial;
render_mode cull_disabled;
// Interior wall with a cutaway: `cut` (per instance, 0..1) lowers the wall to a short stub so the rooms
// behind it stay visible from the isometric camera. `base` is the floor the wall stands on. The plaster texture is projected in world space.

instance uniform float cut = 0.0;
instance uniform float base = 0.0;    // floor level of this wall (0 or the upper floor)
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float tile = 2.2;
uniform float stub = 0.35;
uniform float height = 2.7;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float limit = mix(height + 1.0, stub, cut);
	float y = wpos.y - base;
	if (y > limit) {
		discard;
	}
	vec2 uv = abs(wnorm.x) > 0.5 ? wpos.zy : (abs(wnorm.z) > 0.5 ? wpos.xy : wpos.xz);
	vec3 c = texture(albedo_tex, uv / tile).rgb * tint;
	float edge = 1.0 - smoothstep(0.0, 0.05, limit - y);   // dark line along the cut edge
	ALBEDO = mix(c, c * 0.3, edge * cut);
	ROUGHNESS = 0.9;
}
