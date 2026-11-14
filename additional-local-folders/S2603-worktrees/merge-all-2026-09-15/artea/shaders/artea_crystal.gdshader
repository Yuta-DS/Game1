// Crystal — the "magic" half of Artéa's magic-meets-science look.
//
// A faceted shard that is dark and inert while the journey is asleep, and
// glows and breathes as the player progresses. Driven by `awake` (0..1),
// which hub_magitech.gd tweens from the JourneyState stage.
//
// Deliberately cheap: no screen texture, no refraction pass. This sits in an
// open world with a lot of foliage already on screen.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// 0 = dormant (dark, still), 1 = fully awake (bright, pulsing).
uniform float awake : hint_range(0.0, 1.0) = 0.0;

uniform vec3 core_color : source_color = vec3(0.55, 0.35, 1.0);
uniform vec3 rim_color : source_color = vec3(0.45, 0.85, 1.0);

// Dormant crystals are not black — they read as cold stone, not as missing
// geometry. This is the colour they sit at when awake = 0.
uniform vec3 dormant_color : source_color = vec3(0.16, 0.17, 0.24);

uniform float glow_strength : hint_range(0.0, 8.0) = 3.0;
uniform float pulse_speed : hint_range(0.0, 6.0) = 1.6;
uniform float pulse_depth : hint_range(0.0, 1.0) = 0.35;

// Bands of light running up the shard — the "energy is flowing" read.
uniform float band_scale : hint_range(0.0, 40.0) = 9.0;
uniform float band_speed : hint_range(0.0, 6.0) = 0.9;
uniform float band_strength : hint_range(0.0, 1.0) = 0.45;

uniform float fresnel_power : hint_range(0.5, 8.0) = 2.6;

varying vec3 local_pos;


void vertex() {
	local_pos = VERTEX;
}


void fragment() {
	// Fresnel: edges catch the light, so facets read even against bright sky.
	float fresnel = pow(
		1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0),
		fresnel_power);

	// Slow breath, plus light banding travelling up the shard.
	float pulse = 1.0 - pulse_depth
		+ pulse_depth * (0.5 + 0.5 * sin(TIME * pulse_speed));
	float bands = 0.5 + 0.5 * sin(local_pos.y * band_scale - TIME * band_speed);

	vec3 lit = mix(core_color, rim_color, fresnel);
	lit += rim_color * bands * band_strength;

	// Everything above only matters once the crystal is awake.
	ALBEDO = mix(dormant_color, lit, awake);
	EMISSION = lit * glow_strength * pulse * awake;

	ROUGHNESS = mix(0.55, 0.12, awake);
	METALLIC = 0.15;
	SPECULAR = 0.6;

	// Dormant crystal is near-opaque stone; awake it becomes glassy.
	ALPHA = mix(0.94, 0.72, awake);
}
