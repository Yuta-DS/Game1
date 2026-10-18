shader_type spatial;

// Painted stone follows the same world-space circle on the deck and rock mantle.
// The finish is visual only; their existing collision surfaces remain walkable.
uniform vec2 island_center = vec2(0.0, 2290.0);
uniform float island_radius = 175.0;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 colour = vec3(0.31, 0.32, 0.38);
	if (world_normal.y > 0.8) {
		vec2 offset = world_position.xz - island_center;
		float radius = length(offset) / island_radius;
		float angle = atan(offset.y, offset.x);
		float aa = max(fwidth(radius), 0.001);
		float sector = floor((angle + 3.14159265) * 12.0 / 6.2831853);
		float alternating = mod(sector, 2.0);
		colour = mix(vec3(0.70, 0.65, 0.70), vec3(0.75, 0.70, 0.72), alternating);
		// Twelve broad, quiet stone courses echo the conservatory's petal plan.
		float course = fract(radius * 12.0);
		float radial_joint = 1.0 - smoothstep(0.0, aa + 0.002,
			min(course, 1.0 - course));
		colour = mix(colour, vec3(0.58, 0.54, 0.61), radial_joint * 0.16);
		// Five inlaid staff lines run through the outer garden promenade.
		for (int line = 0; line < 5; line++) {
			float staff_radius = 0.73 + float(line) * 0.043;
			float staff = 1.0 - smoothstep(0.003, 0.003 + aa,
				abs(radius - staff_radius));
			colour = mix(colour, vec3(0.92, 0.80, 0.71), staff * 0.65);
		}
		float inner_border = 1.0 - smoothstep(0.006, 0.006 + aa,
			abs(radius - 0.695));
		float outer_border = 1.0 - smoothstep(0.006, 0.006 + aa,
			abs(radius - 0.958));
		colour = mix(colour, vec3(0.49, 0.72, 0.72),
			max(inner_border, outer_border) * 0.72);
		// A darker stone lip anchors the railing at the actual island edge.
		float lip = smoothstep(0.968, 0.982, radius);
		colour = mix(colour, vec3(0.39, 0.44, 0.52), lip);
	}
	ALBEDO = OUTPUT_IS_SRGB ? colour : pow((colour + vec3(0.055)) / 1.055,
		vec3(2.4));
	ROUGHNESS = 0.91;
}
