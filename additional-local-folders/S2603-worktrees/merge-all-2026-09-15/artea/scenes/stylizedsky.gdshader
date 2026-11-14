shader_type sky;

group_uniforms clouds;
uniform sampler2D cloud_shape_sampler : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cloud_noise_sampler : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cloud_curves;
uniform int clouds_samples : hint_range(8, 32, 8) = 16;
uniform int shadow_sample : hint_range(1, 4, 1) = 2;
uniform float clouds_density : hint_range(0.0, 1.0, 0.01) = 0.46;
uniform float clouds_scale : hint_range(0.5, 1.5, 0.1) = 1.0;
uniform float clouds_smoothness : hint_range(0.01, 0.1, 0.01) = 0.05;
uniform vec3 clouds_light_color : source_color = vec3(0.95, 0.97, 0.98);
uniform float clouds_shadow_intensity : hint_range(0.1, 10.0, 0.1) = 1.4;

group_uniforms high_clouds;
uniform sampler2D high_clouds_sampler : filter_linear_mipmap, repeat_enable;
uniform float high_clouds_density : hint_range(0.0, 1.0, 0.05) = 0.12;

group_uniforms sky;
uniform vec3 top_color : source_color = vec3(0.16, 0.43, 0.72);
uniform vec3 bottom_color : source_color = vec3(0.70, 0.85, 0.94);
uniform vec3 sun_scatter : source_color = vec3(1.0, 0.72, 0.42);

group_uniforms astro;
uniform vec3 astro_tint : source_color = vec3(1.0);
uniform sampler2D astro_sampler : repeat_disable, filter_linear_mipmap;
uniform float astro_scale : hint_range(0.1, 10.0, 0.1) = 5.0;
uniform float astro_intensity : hint_range(1.0, 3.0, 0.1) = 1.0;

group_uniforms stars;
uniform float stars_intensity : hint_range(0.0, 5.0, 0.1) = 0.0;

group_uniforms shooting_stars;
uniform float shooting_stars_intensity : hint_range(0.0, 10.0, 0.1) = 0.0;
uniform sampler2D shooting_star_sampler : filter_linear, repeat_disable;
uniform vec3 shooting_star_tint : source_color = vec3(0.72, 0.82, 1.0);

float hash31(vec3 point) {
	return fract(sin(dot(point, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float height = clamp(direction.y, -1.0, 1.0);
	float night = smoothstep(0.8, 3.2, stars_intensity);
	float daylight = 1.0 - night;
	float horizon = 1.0 - smoothstep(0.0, 0.62, max(height, 0.0));
	vec3 sky_color = mix(bottom_color, top_color, smoothstep(-0.08, 0.88, height));
	vec3 haze = mix(vec3(0.48, 0.58, 0.70), vec3(0.80, 0.89, 0.95), daylight);
	sky_color = mix(sky_color, haze, horizon * 0.42);

	float longitude = atan(direction.z, direction.x) / (2.0 * PI) + 0.5;
	float latitude = asin(height) / PI + 0.5;
	// Integer longitude tiling keeps both ends of the equirectangular map
	// identical, preventing a vertical cloud seam behind the player.
	vec2 cloud_uv = vec2(longitude * 2.0, latitude * 3.0);
	cloud_uv += vec2(TIME * 0.00045, TIME * 0.00012);
	float broad = texture(cloud_shape_sampler, cloud_uv * clouds_scale).r;
	float detail = texture(cloud_noise_sampler, cloud_uv * 3.0 - vec2(TIME * 0.00022, 0.0)).r;
	float cloud_field = broad * 0.78 + detail * 0.22;
	float cloud_threshold = mix(0.72, 0.48, clouds_density);
	float cloud_mask = smoothstep(cloud_threshold - clouds_smoothness,
		cloud_threshold + clouds_smoothness, cloud_field);
	cloud_mask *= smoothstep(0.015, 0.18, height) * (1.0 - smoothstep(0.78, 0.98, height));
	vec3 cloud_shadow = mix(clouds_light_color * 0.72, clouds_light_color,
		clamp(height * 1.7 + 0.35, 0.0, 1.0));
	cloud_shadow = mix(cloud_shadow * 0.48, cloud_shadow,
		1.0 / max(clouds_shadow_intensity, 1.0));
	sky_color = mix(sky_color, cloud_shadow, cloud_mask * mix(0.52, 0.82, daylight));

	float sun_alignment = dot(direction, normalize(LIGHT0_DIRECTION));
	float sun_disc = smoothstep(0.99915, 0.99972, sun_alignment) * daylight;
	float sun_glow = pow(max(sun_alignment, 0.0), 96.0) * daylight;
	sky_color += sun_scatter * (sun_disc * 1.15 + sun_glow * 0.18);

	float star_seed = hash31(floor(direction * 420.0));
	float star = smoothstep(0.9965, 1.0, star_seed) * night;
	sky_color += vec3(0.72, 0.82, 1.0) * star * min(stars_intensity, 2.2);
	float moon_alignment = dot(direction, -normalize(LIGHT0_DIRECTION));
	float moon_disc = smoothstep(0.9987, 0.99945, moon_alignment) * night;
	float moon_glow = pow(max(moon_alignment, 0.0), 120.0) * night;
	sky_color += astro_tint * (moon_disc * 0.78 + moon_glow * 0.08);

	COLOR = max(sky_color, vec3(0.0));
}
