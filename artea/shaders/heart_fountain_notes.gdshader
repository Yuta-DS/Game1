shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

varying float life;
varying vec3 note_color;

void vertex() {
	life = fract(INSTANCE_CUSTOM.x + TIME * 0.045);
	float angle = INSTANCE_CUSTOM.x * 25.132741 + TIME * 0.22;
	float radius = 3.0 + life * 23.0;
	VERTEX += vec3(cos(angle) * radius, 7.0 + life * 74.0, sin(angle) * radius);
	note_color = mix(vec3(1.0, 0.72, 0.34), vec3(0.55, 0.95, 1.0), INSTANCE_CUSTOM.y);
}

void fragment() {
	ALBEDO = note_color;
	EMISSION = note_color * 0.6;
	ALPHA = smoothstep(0.0, 0.12, life) * (1.0 - smoothstep(0.78, 1.0, life));
}
