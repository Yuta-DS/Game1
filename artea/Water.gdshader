shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_opaque;

uniform float time_speed = 0.35;
uniform float surface_speed = 0.025;
uniform float spin = 0.08;
uniform float brightness = 0.82;
uniform float color_intensity = 0.35;
uniform float horizontal_frequency = 2.0;
uniform float vertical_frequency = 2.0;
uniform float size = 3.0;
uniform float banding_bias = 0.66;
uniform sampler2D wave_texture : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;
uniform float wave_height = 0.45;
uniform float texture_height = 0.12;
uniform vec4 color1 : source_color = vec4(0.38, 0.76, 0.84, 1.0);
uniform vec4 color2 : source_color = vec4(0.10, 0.48, 0.66, 1.0);
uniform vec4 color3 : source_color = vec4(0.025, 0.25, 0.43, 1.0);
uniform vec4 color4 : source_color = vec4(0.015, 0.12, 0.24, 1.0);

varying vec3 world_position;
varying float crest_signal;

void vertex() {
	vec2 point = VERTEX.xz;
	float time = TIME * time_speed;
	float wave_a = sin(point.x * 0.034 + point.y * 0.018 + time * 0.72);
	float wave_b = sin(point.x * -0.021 + point.y * 0.047 - time * 0.53);
	float wave_c = sin((point.x + point.y) * 0.073 + time * 0.31);
	vec2 noise_uv = UV * vec2(horizontal_frequency, vertical_frequency)
		+ vec2(time * surface_speed, -time * surface_speed * 0.63);
	float fine_noise = textureLod(noise_texture, noise_uv, 0.0).r * 2.0 - 1.0;
	crest_signal = wave_a * 0.48 + wave_b * 0.31 + wave_c * 0.14 + fine_noise * 0.07;
	VERTEX.y += crest_signal * wave_height + fine_noise * texture_height;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 tangent_x = dFdx(world_position);
	vec3 tangent_y = dFdy(world_position);
	vec3 water_normal = normalize(cross(tangent_y, tangent_x));
	if (water_normal.y < 0.0) {
		water_normal *= -1.0;
	}
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.2);
	float broad_variation = sin(world_position.x * 0.018 + world_position.z * 0.013 + TIME * 0.12) * 0.5 + 0.5;
	vec3 deep = mix(color4.rgb, color3.rgb, broad_variation * 0.38);
	vec3 shallow = mix(color2.rgb, color1.rgb, 0.32 + crest_signal * 0.12);
	vec3 sky_reflection = vec3(0.48, 0.72, 0.86);
	vec3 water = mix(deep, shallow, 0.28 + fresnel * 0.42);
	water = mix(water, sky_reflection, fresnel * 0.46);
	float crest = smoothstep(0.58, 0.94, crest_signal);
	water = mix(water, vec3(0.78, 0.91, 0.92), crest * 0.16);
	float micro_ripple = sin(world_position.x * 0.31 + TIME * 0.42)
		* sin(world_position.z * 0.27 - TIME * 0.31) * 0.5 + 0.5;
	water = mix(water, vec3(0.62, 0.80, 0.86), micro_ripple * 0.025);
	float camera_distance = distance(CAMERA_POSITION_WORLD, world_position);
	float aerial_haze = smoothstep(210.0, 470.0, camera_distance);
	water = mix(water, vec3(0.70, 0.84, 0.91), aerial_haze * 0.82);
	ALBEDO = water * brightness;
	ROUGHNESS = mix(0.34, 0.12, fresnel);
	METALLIC = 0.0;
	ALPHA = 1.0;
}
