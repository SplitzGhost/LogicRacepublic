shader_type canvas_item;
render_mode unshaded;

// Rounded-rectangle gradient fill with analytic anti-aliasing.
uniform vec4 col_a : source_color = vec4(0.42, 0.79, 1.0, 1.0);
uniform vec4 col_b : source_color = vec4(0.05, 0.48, 0.91, 1.0);
uniform vec2 rect_size = vec2(200.0, 80.0);
uniform float radius = 28.0;
uniform vec2 grad_dir = vec2(0.35, 1.0);
uniform float gloss = 0.0;

float rrect_sdf(vec2 p, vec2 half_size, float r) {
	vec2 d = abs(p) - (half_size - vec2(r));
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

void fragment() {
	vec2 half_size = rect_size * 0.5;
	vec2 p = UV * rect_size - half_size;
	float r = min(radius, min(half_size.x, half_size.y));
	float d = rrect_sdf(p, half_size, r);
	float aa = fwidth(d) + 0.0001;
	float mask = 1.0 - smoothstep(-aa, aa, d);

	vec2 dir = normalize(grad_dir + vec2(0.00001));
	float t = clamp(dot(UV - vec2(0.5), dir) + 0.5, 0.0, 1.0);
	vec3 rgb = mix(col_a.rgb, col_b.rgb, t);
	// Soft specular sheen along the top edge (Apple-style).
	rgb += vec3(gloss) * pow(clamp(1.0 - UV.y * 2.2, 0.0, 1.0), 2.0);
	float a = mix(col_a.a, col_b.a, t) * mask;
	COLOR = vec4(rgb, a);
}
