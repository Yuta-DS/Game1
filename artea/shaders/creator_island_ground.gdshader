shader_type spatial;

// One finish for the studio floor and the entire circular Creator island.
// World-space courses keep the pattern aligned across their different meshes.
uniform vec2 island_center = vec2(600.0, 1640.0);
uniform vec2 paving_origin = vec2(450.0, 1520.0);
uniform float island_radius = 195.0;
uniform bool lookout_finish = false;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 colour = vec3(0.48, 0.38, 0.32);
	if (world_normal.y > 0.8) {
		vec2 size = vec2(37.5, 40.0);
		vec2 block = (world_position.xz - paving_origin) / size;
		vec2 cell = floor(block);
		vec2 edge = min(fract(block), 1.0 - fract(block)) * size;
		float aa = max(length(fwidth(world_position.xz)), 0.025);
		float joint = 1.0 - smoothstep(0.30, 0.30 + aa, min(edge.x, edge.y));
		float inset = 1.0 - smoothstep(0.38, 0.38 + aa,
			abs(min(edge.x, edge.y) - 1.35));
		float accent = mod(cell.x + cell.y, 3.0);
		colour = mix(vec3(0.83, 0.73, 0.58),
			vec3(0.91, 0.82, 0.68), step(1.0, accent));
		colour = mix(colour, vec3(0.96, 0.89, 0.76), inset * 0.54);
		colour = mix(colour, vec3(0.58, 0.47, 0.37), joint * 0.8);
		float radius = length(world_position.xz - island_center) / island_radius;
		float border = smoothstep(0.905, 0.916, radius)
			* (1.0 - smoothstep(0.936, 0.948, radius));
		colour = mix(colour, vec3(0.78, 0.59, 0.30),
			border * (lookout_finish ? 0.0 : 0.9));
		float lip = smoothstep(0.969, 0.984, radius);
		colour = mix(colour, vec3(0.67, 0.53, 0.39), lip * 0.75);
		// Small enamel markers pick out selected intersections without adding mass.
		vec2 tile_center = abs(fract(block) - 0.5) * size;
		float marker = 1.0 - smoothstep(1.7, 1.7 + aa,
			max(tile_center.x, tile_center.y));
		float chosen = 1.0 - step(0.5, mod(cell.x + cell.y * 2.0, 7.0));
		colour = mix(colour, vec3(0.30, 0.75, 0.77), marker * chosen * 0.76);
	}
	// StandardMaterial uses sRGB colours. Match it in both Web/Compatibility
	// and native linear renderers.
	ALBEDO = OUTPUT_IS_SRGB ? colour : pow((colour + vec3(0.055)) / 1.055,
		vec3(2.4));
	ROUGHNESS = 0.92;
}
