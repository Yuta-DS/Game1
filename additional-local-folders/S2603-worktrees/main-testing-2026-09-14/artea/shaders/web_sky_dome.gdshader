shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;

uniform vec3 zenith_color : source_color = vec3(0.10, 0.34, 0.64);
uniform vec3 upper_color : source_color = vec3(0.24, 0.56, 0.82);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.84, 0.91);
uniform vec3 lower_color : source_color = vec3(0.42, 0.59, 0.70);
uniform vec3 sun_color : source_color = vec3(1.0, 0.80, 0.50);
uniform vec3 cloud_color : source_color = vec3(0.91, 0.94, 0.96);
uniform vec3 sun_direction = vec3(-0.32, 0.58, -0.75);
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.38;
uniform float time_scale : hint_range(0.0, 0.05) = 0.0025;

varying vec3 dome_direction;

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

float cloud_noise(vec2 point) {
	float noise_value = value_noise(point) * 0.58;
	noise_value += value_noise(point * 2.03 + 13.7) * 0.28;
	noise_value += value_noise(point * 4.07 - 7.1) * 0.14;
	return noise_value;
}

void vertex() {
	// The dome follows the active camera. Preserving the local vertex direction
	// gives the fragment stage a stable spherical coordinate on every renderer.
	dome_direction = normalize(VERTEX);
}

void fragment() {
	vec3 direction = normalize(dome_direction);
	float height = clamp(direction.y, -1.0, 1.0);
	float above_horizon = smoothstep(-0.05, 0.72, height);
	vec3 sky = mix(horizon_color, upper_color, above_horizon);
	sky = mix(sky, zenith_color, smoothstep(0.56, 1.0, height));
	sky = mix(lower_color, sky, smoothstep(-0.42, 0.03, height));

	// Two low-cost noise octaves form broad moving cloud banks. This is a normal
	// spatial shader, not a Sky shader, so it remains inside WebGL2's limits.
	// Spherical coordinates avoid the old planar projection's denominator
	// singularity near the horizon, which stretched a few cloud texels into
	// vertical walls across the Web sky.
	float longitude = atan(direction.z, direction.x) / 6.2831853;
	float latitude = asin(height) / 3.1415927;
	vec2 cloud_uv = vec2(longitude * 3.2, latitude * 4.0);
	cloud_uv += vec2(TIME * time_scale, TIME * time_scale * 0.37);
	float cloud_field = cloud_noise(cloud_uv);
	float cloud_mask = smoothstep(0.62 + (1.0 - cloud_amount) * 0.18, 0.83, cloud_field);
	cloud_mask *= smoothstep(0.02, 0.32, height) * (1.0 - smoothstep(0.70, 0.98, height));
	sky = mix(sky, cloud_color, cloud_mask * 0.58);

	float sun_alignment = dot(direction, normalize(sun_direction));
	float sun_disc = smoothstep(0.9984, 0.99935, sun_alignment);
	float sun_glow = pow(max(sun_alignment, 0.0), 72.0) * 0.42;
	sky += sun_color * (sun_disc * 1.25 + sun_glow);

	ALBEDO = sky;
	ALPHA = 1.0;
}
