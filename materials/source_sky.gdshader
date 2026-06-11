shader_type sky;

// Six-face Source-engine skybox (HL2 sky_*.vtf faces) sampled as a cubemap.
// Face placement (verified against texture edge continuity): ft at -Z,
// lf at +X, bk at +Z, rt at -X, up at +Y, dn at -Y. Source's left-handed
// X-forward/Z-up frame mirrors into Godot's Y-up/-Z-forward, so lf/rt land
// on the opposite sides of their names.

uniform sampler2D face_ft : source_color, filter_linear, repeat_disable;
uniform sampler2D face_bk : source_color, filter_linear, repeat_disable;
uniform sampler2D face_lf : source_color, filter_linear, repeat_disable;
uniform sampler2D face_rt : source_color, filter_linear, repeat_disable;
uniform sampler2D face_up : source_color, filter_linear, repeat_disable;
uniform sampler2D face_dn : source_color, filter_linear, repeat_disable;

uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float energy : hint_range(0.0, 4.0) = 1.0;

void sky() {
	vec3 d = EYEDIR;
	vec3 a = abs(d);
	vec3 col;

	if (a.y >= a.x && a.y >= a.z) {
		if (d.y > 0.0) {
			vec2 uv = vec2(0.5 - 0.5 * d.z / d.y, 0.5 - 0.5 * d.x / d.y);
			col = texture(face_up, uv).rgb;
		} else {
			vec2 uv = vec2(0.5 + 0.5 * d.z / d.y, 0.5 - 0.5 * d.x / d.y);
			col = texture(face_dn, uv).rgb;
		}
	} else if (a.x >= a.z) {
		vec2 uv = vec2(0.5 + 0.5 * d.z / d.x, 0.5 - 0.5 * d.y / a.x);
		if (d.x > 0.0) {
			col = texture(face_lf, uv).rgb;
		} else {
			col = texture(face_rt, uv).rgb;
		}
	} else {
		vec2 uv = vec2(0.5 - 0.5 * d.x / d.z, 0.5 - 0.5 * d.y / a.z);
		if (d.z < 0.0) {
			col = texture(face_ft, uv).rgb;
		} else {
			col = texture(face_bk, uv).rgb;
		}
	}

	COLOR = col * tint * energy;
}
