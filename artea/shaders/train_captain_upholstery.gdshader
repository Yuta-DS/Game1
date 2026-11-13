shader_type spatial;
render_mode specular_schlick_ggx;

uniform float upholstery_phase = 0.0;

vec3 rainbow_colour(float hue) {
	float band = fract(hue) * 7.0;
	float blend = smoothstep(0.0, 1.0, fract(band));
	vec3 coral = vec3(1.0, 0.32, 0.46);
	vec3 apricot = vec3(1.0, 0.58, 0.26);
	vec3 sunshine = vec3(1.0, 0.82, 0.30);
	vec3 mint = vec3(0.34, 0.90, 0.54);
	vec3 aqua = vec3(0.25, 0.82, 0.86);
	vec3 sky = vec3(0.38, 0.62, 1.0);
	vec3 orchid = vec3(0.78, 0.44, 1.0);
	if (band < 1.0) return mix(coral, apricot, blend);
	if (band < 2.0) return mix(apricot, sunshine, blend);
	if (band < 3.0) return mix(sunshine, mint, blend);
	if (band < 4.0) return mix(mint, aqua, blend);
	if (band < 5.0) return mix(aqua, sky, blend);
	if (band < 6.0) return mix(sky, orchid, blend);
	return mix(orchid, coral, blend);
}

void fragment() {
	// A complete seven-colour cycle crosses each pad, slowly flowing like silk.
	float hue = UV.x + 0.08 * sin(UV.y * 6.283185 + TIME * 0.18)
		+ TIME * 0.035 + upholstery_phase;
	vec3 colour = rainbow_colour(hue);
	// Fine diamond stitching, not deep grooves that interrupt the seat surface.
	vec2 quilt = vec2(UV.x + UV.y, UV.x - UV.y) * 6.0;
	vec2 seam_distance = abs(fract(quilt + 0.5) - 0.5);
	float seam = 1.0 - smoothstep(0.012, 0.040, min(seam_distance.x, seam_distance.y));
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = mix(colour * (1.0 - seam * 0.14), vec3(1.0, 0.87, 0.64), rim * 0.10);
	EMISSION = colour * 0.10;
	METALLIC = 0.05;
	SPECULAR = 0.55;
	ROUGHNESS = 0.38 + seam * 0.12;
}

