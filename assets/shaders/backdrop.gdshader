shader_type canvas_item;
render_mode unshaded;

// App background: flat base tint plus two very soft accent blooms.
uniform vec4 base : source_color = vec4(0.93, 0.945, 0.965, 1.0);
uniform vec4 base2 : source_color = vec4(0.90, 0.92, 0.95, 1.0);
uniform vec4 bloom : source_color = vec4(0.16, 0.62, 0.95, 1.0);
uniform float bloom_strength = 0.16;
uniform vec2 bloom_a = vec2(0.16, 0.06);
uniform vec2 bloom_b = vec2(0.94, 0.42);
uniform float aspect = 0.46;

float blob(vec2 uv, vec2 c, float r) {
	vec2 d = (uv - c) * vec2(1.0, 1.0 / max(aspect, 0.01));
	return exp(-dot(d, d) / (r * r));
}

void fragment() {
	vec3 col = mix(base.rgb, base2.rgb, clamp(UV.y * 1.15, 0.0, 1.0));
	float g = blob(UV, bloom_a, 0.55) * 1.0 + blob(UV, bloom_b, 0.42) * 0.7;
	col = mix(col, bloom.rgb, clamp(g, 0.0, 1.0) * bloom_strength);
	COLOR = vec4(col, 1.0);
}
