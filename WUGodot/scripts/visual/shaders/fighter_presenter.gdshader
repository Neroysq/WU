shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float smear : hint_range(0.0, 1.0) = 0.0;
uniform vec2 smear_dir = vec2(1.0, 0.0);
uniform float dissolve : hint_range(0.0, 1.0) = 1.0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int idx = x + y * 4;
	float m[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};
	return m[idx] / 16.0;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	if (smear > 0.001) {
		vec2 step_uv = smear_dir * TEXTURE_PIXEL_SIZE * 6.0 * smear;
		for (int i = 1; i <= 3; i++) {
			vec4 s = texture(TEXTURE, UV - step_uv * float(i));
			col.a = max(col.a, s.a * (0.5 / float(i)) * smear);
			col.rgb = mix(col.rgb, s.rgb, 0.25 * smear);
		}
	}

	if (dissolve < 0.999) {
		if (bayer4(FRAGCOORD.xy) > dissolve) {
			col.a = 0.0;
		}
	}

	col.rgb = mix(col.rgb, vec3(1.0), flash);
	COLOR = col * COLOR;
}
