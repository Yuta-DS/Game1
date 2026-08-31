shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 shallow_color : source_color = vec3(0.18, 0.60, 0.70);
uniform vec3 deep_color : source_color = vec3(0.018, 0.18, 0.34);
uniform vec3 highlight_color : source_color = vec3(0.70, 0.86, 0.90);
uniform vec3 horizon_reflection : source_color = vec3(0.48, 0.70, 0.82);

varying vec3 world_position;
varying float wave_crest;

void vertex() {
	float wave_a = sin(VERTEX.x * 0.034 + VERTEX.z * 0.018 + TIME * 0.42);
	float wave_b = sin(VERTEX.x * -0.021 + VERTEX.z * 0.047 - TIME * 0.31);
	float ripple = sin((VERTEX.x + VERTEX.z) * 0.073 + TIME * 0.19);
	wave_crest = wave_a * 0.46 + wave_b * 0.34 + ripple * 0.20;
	VERTEX.y += wave_crest * 0.34;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float long_wave = sin(world_position.x * 0.018 + world_position.z * 0.013 + TIME * 0.12);
	float crossing = sin(world_position.x * -0.037 + world_position.z * 0.031 - TIME * 0.24);
	float surface = clamp(0.5 + long_wave * 0.18 + crossing * 0.12 + wave_crest * 0.16, 0.0, 1.0);
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	vec3 water = mix(deep_color, shallow_color, smoothstep(0.12, 0.92, surface) * 0.46);
	water = mix(water, horizon_reflection, fresnel * 0.42);
	float crest = smoothstep(0.78, 0.98, surface);
	water = mix(water, highlight_color, crest * 0.16);
	float camera_distance = distance(CAMERA_POSITION_WORLD, world_position);
	float aerial_haze = smoothstep(210.0, 470.0, camera_distance);
	ALBEDO = mix(water, vec3(0.70, 0.84, 0.91), aerial_haze * 0.82);
	ALPHA = 1.0;
}
