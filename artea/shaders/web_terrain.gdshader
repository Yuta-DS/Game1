shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 world_position;

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	fraction = fraction * fraction * (3.0 - 2.0 * fraction);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, fraction.x), mix(c, d, fraction.x), fraction.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The baked mesh stores Terrain3D's painted surface blend in COLOR. Add
	// small and broad world-space variation so the eight-metre grid does not
	// read as one flat average colour, without recreating Terrain3D's oversized
	// WebGL uniform block.
	float broad = value_noise(world_position.xz * 0.022);
	float detail = value_noise(world_position.xz * 0.16 + vec2(17.3, -9.1));
	float slope = clamp(1.0 - dot(normalize(NORMAL), vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	vec3 base = COLOR.rgb * mix(0.84, 1.12, broad) * mix(0.94, 1.06, detail);
	base = mix(base, base * vec3(0.78, 0.76, 0.72), slope * 0.52);
	ALBEDO = base;
	ROUGHNESS = mix(0.96, 0.82, slope);
	SPECULAR = 0.18;
}
