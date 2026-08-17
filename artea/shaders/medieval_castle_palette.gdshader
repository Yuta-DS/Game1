shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D source_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 source_tint : source_color = vec4(1.0);

void fragment() {
	vec4 texel = texture(source_texture, UV) * source_tint;
	vec3 source = texel.rgb;
	float high = max(source.r, max(source.g, source.b));
	float low = min(source.r, min(source.g, source.b));
	float saturation = high - low;
	float value = dot(source, vec3(0.299, 0.587, 0.114));
	float masonry = 0.0;

	vec3 medieval_colour;
	if (value < 0.105) {
		// Atlas outlines and deep recesses become near-black wrought iron.
		medieval_colour = vec3(0.055, 0.064, 0.066);
	} else if (source.r > source.g * 1.16 && source.r > source.b * 1.18) {
		// The reference castle's vivid red roofs become weathered blue slate.
		medieval_colour = vec3(0.12, 0.155, 0.175);
	} else if (source.b > source.r * 1.08 || (source.g > source.r * 1.12 && source.b > source.r * 0.82)) {
		// Blue/cyan painted walls become warm, irregular limestone.
		medieval_colour = vec3(0.44, 0.415, 0.36);
		masonry = 1.0;
	} else if (source.r > source.b * 1.15 && source.g > source.b * 1.08 && saturation > 0.10) {
		// Gold and orange mechanical parts become oak and aged bronze.
		medieval_colour = vec3(0.29, 0.19, 0.105);
	} else if (source.g > source.r * 1.08 && source.g > source.b * 1.04) {
		medieval_colour = vec3(0.21, 0.27, 0.17);
	} else {
		medieval_colour = vec3(0.49, 0.47, 0.42);
	}

	float shade = mix(0.62, 1.18, smoothstep(0.05, 0.95, value));
	vec2 brick_uv = UV * vec2(34.0, 46.0);
	brick_uv.x += step(0.5, fract(brick_uv.y * 0.5)) * 0.5;
	vec2 brick_cell = fract(brick_uv);
	float vertical_joint = 1.0 - smoothstep(0.035, 0.095, min(brick_cell.x, 1.0 - brick_cell.x));
	float horizontal_joint = 1.0 - smoothstep(0.035, 0.095, min(brick_cell.y, 1.0 - brick_cell.y));
	float mortar = max(vertical_joint, horizontal_joint) * masonry;
	ALBEDO = medieval_colour * shade * mix(1.0, 0.72, mortar);
	ROUGHNESS = 0.88;
	METALLIC = value < 0.105 ? 0.36 : 0.03;
}
