// Rune circle — where Artéa's magic and science meet in one mark.
//
// Read as a spell circle from a distance and as an etched circuit board up
// close: concentric rings (magic) crossed by radial traces with square
// solder pads (science). Projected flat on the ground under portals.
//
// Driven by `awake` (0..1) from hub_magitech.gd, same as the crystals.
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never;

uniform float awake : hint_range(0.0, 1.0) = 0.0;

uniform vec3 glow_color : source_color = vec3(0.45, 0.85, 1.0);
uniform vec3 accent_color : source_color = vec3(1.0, 0.82, 0.45);

uniform float brightness : hint_range(0.0, 6.0) = 2.2;
uniform float spin_speed : hint_range(-4.0, 4.0) = 0.25;

// How many radial traces run out from the centre.
uniform float trace_count : hint_range(3.0, 48.0) = 16.0;
uniform float ring_count : hint_range(1.0, 12.0) = 4.0;

uniform float line_sharpness : hint_range(1.0, 200.0) = 60.0;


// Thin bright line wherever `v` crosses a whole number.
float etched_line(float v, float sharpness) {
	float d = abs(fract(v) - 0.5) * 2.0;
	return pow(d, sharpness);
}


void fragment() {
	// UV to polar, centred.
	vec2 p = UV - vec2(0.5);
	float radius = length(p) * 2.0;

	// Outside the disc, draw nothing at all.
	if (radius > 1.0) {
		ALPHA = 0.0;
		EMISSION = vec3(0.0);
		ALBEDO = vec3(0.0);
	} else {
		float angle = atan(p.y, p.x);

		// Magic: concentric rings, slowly breathing outward.
		float rings = etched_line(radius * ring_count - TIME * 0.15, line_sharpness);

		// Science: radial traces, counter-rotating like a mechanism.
		float spin = TIME * spin_speed;
		float traces = etched_line(
			(angle + spin) / TAU * trace_count, line_sharpness);
		// Traces stop short of the centre, like real board routing.
		traces *= smoothstep(0.18, 0.30, radius);

		// Solder pads where the outermost ring meets each trace.
		float pad_ring = smoothstep(0.06, 0.0, abs(radius - 0.82));
		float pads = pad_ring * step(0.72,
			etched_line((angle + spin) / TAU * trace_count, 6.0));

		float figure = clamp(rings + traces, 0.0, 1.0);

		// Fade out at the rim so the disc has no hard cut edge.
		float edge = smoothstep(1.0, 0.86, radius);

		vec3 colour = mix(glow_color, accent_color, pads);
		float strength = clamp(figure + pads * 1.4, 0.0, 2.0) * edge * awake;

		EMISSION = colour * strength * brightness;
		ALBEDO = vec3(0.0);
		ALPHA = strength;
	}
}
