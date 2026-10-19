shader_type spatial;

// World One entrance forecourt (Mind Spark district): the 9x9 checkerboard,
// now cut crystal and gold-inlaid marble. Crystal tiles carry a glowing
// thought-spark sigil over a faint neural lattice; marble tiles a gold inset
// and a four-point star. Model space XZ of the district deck (centred on it).

uniform float tile_spacing = 27.0;
uniform float tile_size = 25.2;
uniform float grid_size = 9.0;
uniform float island_radius = 175.0;
uniform vec3 crystal : source_color = vec3(0.32, 0.88, 0.96);
uniform vec3 crystal_deep : source_color = vec3(0.10, 0.42, 0.62);
uniform vec3 marble : source_color = vec3(0.94, 0.93, 0.96);
uniform vec3 marble_vein : source_color = vec3(0.80, 0.78, 0.88);
uniform vec3 gold : source_color = vec3(0.95, 0.77, 0.37);
uniform vec3 joint : source_color = vec3(0.16, 0.20, 0.34);
uniform vec3 spark : source_color = vec3(0.75, 0.98, 1.0);
uniform vec3 border : source_color = vec3(0.36, 0.29, 0.56);

varying vec3 model_pos;
varying float up_facing;

void vertex() {
	model_pos = VERTEX;
	up_facing = NORMAL.y;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 1 on a line of half-width w at distance d, anti-aliased.
float line(float d, float w) {
	float aa = fwidth(d);
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

// Distance to the nearest edge of a hexagonal lattice of cell size s.
float hex_edge(vec2 p, float s) {
	p /= s;
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	return (0.5 - max(dot(q, normalize(r)), q.x)) * s;
}

void fragment() {
	vec3 color = marble;
	vec3 glow = vec3(0.0);

	if (up_facing > 0.5) {
		vec2 p = model_pos.xz;
		float r = length(p);
		vec2 cell = floor(p / tile_spacing + 0.5);
		vec2 local = p - cell * tile_spacing;
		float half_grid = (grid_size - 1.0) * 0.5;
		bool in_grid = abs(cell.x) <= half_grid && abs(cell.y) <= half_grid;
		float half_tile = tile_size * 0.5;
		float edge = half_tile - max(abs(local.x), abs(local.y));

		// Marble everywhere first: soft veining.
		float v = noise(p * 0.09) * 0.6 + noise(p * 0.23) * 0.4;
		color = mix(marble, marble_vein, smoothstep(0.03, 0.0, abs(v - 0.5)) * 0.6);

		if (in_grid) {
			if (edge < 0.0) {
				// Joint between tiles, with a fine cyan thread down the middle.
				color = joint;
				float thread = line(min(abs(abs(local.x) - tile_spacing * 0.5),
					abs(abs(local.y) - tile_spacing * 0.5)), 0.12);
				color = mix(color, crystal, thread);
				glow += crystal * thread * 0.8;
			} else if (mod(cell.x + cell.y, 2.0) < 0.5) {
				// Crystal tile: deep at the rim, bright at the heart, bevelled.
				float centre = length(local) / half_tile;
				color = mix(crystal, crystal_deep, smoothstep(0.1, 1.1, centre));
				color = mix(color, spark, (1.0 - smoothstep(0.0, 0.9, edge)) * 0.55);
				float lattice = line(hex_edge(local + cell * 3.1, 3.2), 0.06);
				color = mix(color, spark, lattice * 0.35);
				// The thought-spark sigil: a ring, four rays and a core.
				float pulse = 0.6 + 0.4 * sin(TIME * 1.4 + hash(cell) * 6.2831);
				float ring = line(length(local) - 6.0, 0.22);
				float rays = max(line(local.x, 0.16) * step(abs(local.y), 9.5),
					line(local.y, 0.16) * step(abs(local.x), 9.5)) * step(3.0, length(local));
				float core = 1.0 - smoothstep(1.2, 1.6, length(local));
				float sigil = max(max(ring, rays * 0.8), core);
				color = mix(color, spark, sigil);
				glow += spark * sigil * pulse * 1.1 + crystal * lattice * 0.25;
			} else {
				// Marble tile: gold inset frame, corner studs and a four-point star.
				float inset = line(edge - 1.6, 0.14);
				vec2 corner = abs(local) - vec2(half_tile - 3.2);
				float studs = 1.0 - smoothstep(0.5, 0.7, length(corner));
				vec2 a = abs(local);
				float star = step(a.x * a.y, 2.2) * step(a.x + a.y, 7.5);
				color = mix(color, gold, max(max(inset, studs), star * 0.9));
				glow += gold * (inset + studs + star) * 0.18;
			}
		} else {
			// Beyond the board: a gold ring and the violet island rim.
			float ring = line(r - (island_radius - 14.0), 0.35);
			color = mix(color, gold, ring);
			glow += gold * ring * 0.3;
			color = mix(color, border, smoothstep(island_radius - 9.0, island_radius - 8.5, r));
		}
	}

	ALBEDO = color;
	ROUGHNESS = 0.45;
	EMISSION = glow;
}
