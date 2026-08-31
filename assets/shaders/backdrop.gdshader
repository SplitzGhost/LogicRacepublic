shader_type canvas_item;
render_mode unshaded;

// App background: a vertical wash between two ground tones plus two saturated
// blooms that give the dark stage some depth.
uniform vec4 base : source_color = vec4(0.08, 0.05, 0.21, 1.0);
uniform vec4 base2 : source_color = vec4(0.14, 0.08, 0.33, 1.0);
uniform vec4 bloom : source_color = vec4(0.88, 0.36, 0.96, 1.0);
uniform vec4 bloom2 : source_color = vec4(0.55, 0.17, 0.88, 1.0);
uniform float bloom_strength = 0.34;
uniform vec2 bloom_a = vec2(0.14, 0.04);
uniform vec2 bloom_b = vec2(0.92, 0.52);
uniform float aspect = 0.46;

float blob(vec2 uv, vec2 c, float r) {
	vec2 d = (uv - c) * vec2(1.0, 1.0 / max(aspect, 0.01));
	return exp(-dot(d, d) / (r * r));
}

void fragment() {
	// Ground: darker at the top, opening up towards the bottom.
	vec3 col = mix(base.rgb, base2.rgb, smoothstep(0.0, 1.0, UV.y));
	float g1 = blob(UV, bloom_a, 0.50);
	float g2 = blob(UV, bloom_b, 0.44);
	col = mix(col, bloom.rgb, clamp(g1, 0.0, 1.0) * bloom_strength);
	col = mix(col, bloom2.rgb, clamp(g2, 0.0, 1.0) * bloom_strength * 0.85);
	// A soft vignette keeps the edges from competing with the content.
	float v = distance(UV, vec2(0.5)) ;
	col *= 1.0 - smoothstep(0.45, 1.05, v) * 0.35;
	COLOR = vec4(col, 1.0);
}
