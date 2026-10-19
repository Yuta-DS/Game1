shader_type spatial;

// Tree of Imagination island floor: organic flagstones crossed by the tree's
// growth rings and by glowing roots that run out from the trunk, pulsing
// outward. Model space XZ; the court and the island deck are both centred on
// the tree, so the pattern runs across them without a seam.

uniform float island_radius = 220.0;
uniform float trunk_radius = 40.0;
uniform float stone_size = 5.5;
uniform float ring_spacing = 9.0;
uniform vec3 stone : source_color = vec3(0.92, 0.89, 0.86);
uniform vec3 stone_alt : source_color = vec3(0.86, 0.84, 0.89);
uniform vec3 joint : source_color = vec3(0.62, 0.57, 0.60);
uniform vec3 growth_ring : source_color = vec3(0.78, 0.60, 0.42);
uniform vec3 gold : source_color = vec3(0.95, 0.77, 0.37);
uniform vec3 root_glow : source_color = vec3(0.30, 0.88, 1.0);
uniform vec3 blossom : source_color = vec3(0.74, 0.56, 0.94);
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

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
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

// Flagstones: x = distance to the nearest stone edge, y = the stone's random id.
vec2 flagstone(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec2 nearest_cell = vec2(0.0);
	vec2 nearest = vec2(8.0);
	float best = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) * 0.8 + 0.1 - f;
			float d = dot(r, r);
			if (d < best) {
				best = d;
				nearest = r;
				nearest_cell = g;
			}
		}
	}
	float edge = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = nearest_cell + vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) * 0.8 + 0.1 - f;
			if (dot(nearest - r, nearest - r) > 0.00001) {
				edge = min(edge, dot(0.5 * (nearest + r), normalize(r - nearest)));
			}
		}
	}
	return vec2(edge, hash(n + nearest_cell));
}

// Distance in metres to the nearest of `count` meandering roots.
float root_distance(vec2 p, float r, float ang, float count, float seed) {
	float t = ang / 6.2831 * count;
	float id = floor(t + 0.5);
	float wander = (noise(vec2(r * 0.035, id * 7.3 + seed)) - 0.5) * 14.0;
	return (fract(t + 0.5) - 0.5) * 6.2831 * r / count - wander;
}

void fragment() {
	vec3 color = stone;
	vec3 glow_color = vec3(0.0);

	if (up_facing > 0.5) {
		vec2 p = model_pos.xz;
		float r = length(p);
		float ang = atan(p.y, p.x);

		vec2 cell = flagstone(p / stone_size);
		color = mix(stone, stone_alt, cell.y);
		color *= 0.95 + 0.08 * noise(p * 0.7);
		// A scattering of blossom-stained stones.
		color = mix(color, blossom, step(0.93, cell.y) * 0.32);
		color = mix(color, joint, (1.0 - smoothstep(0.02, 0.06, cell.x)) * 0.7);

		// Growth rings, wobbling like real ones.
		float wobble = (noise(vec2(ang * 5.0, r * 0.02)) - 0.5) * 3.0;
		float rings = line(fract((r + wobble) / ring_spacing + 0.5) - 0.5, 0.014)
			* step(trunk_radius + 6.0, r) * step(r, island_radius - 16.0);
		color = mix(color, growth_ring, rings * 0.5);

		// Roots: twelve main ones from the trunk, twenty-four finer ones
		// further out. Gold edges, a cyan core that pulses away from the tree.
		float fade = 1.0 - smoothstep(island_radius - 45.0, island_radius - 18.0, r);
		float main_width = mix(1.1, 0.3, smoothstep(trunk_radius, island_radius - 20.0, r));
		float main_d = root_distance(p, r, ang, 12.0, 0.0);
		float fine_d = root_distance(p, r, ang + 0.13, 24.0, 41.0);
		float main_root = line(main_d, main_width) * step(trunk_radius - 4.0, r);
		float fine_root = line(fine_d, main_width * 0.45) * smoothstep(80.0, 95.0, r);
		float root_mask = max(main_root, fine_root) * fade;
		color = mix(color, gold, root_mask * 0.85);
		float core = max(line(main_d, main_width * 0.4) * step(trunk_radius - 4.0, r),
			line(fine_d, main_width * 0.18) * smoothstep(80.0, 95.0, r)) * fade;
		float pulse = 0.55 + 0.45 * sin(r * 0.09 - TIME * 1.6);
		color = mix(color, root_glow, core);
		glow_color += root_glow * core * pulse * 0.9 + gold * root_mask * 0.12;

		// Gold ring round the court edge and a violet band at the island rim.
		float court_line = line(r - 104.0, 0.35);
		color = mix(color, gold, court_line);
		glow_color += gold * court_line * 0.3;
		color = mix(color, border, smoothstep(island_radius - 12.0, island_radius - 11.5, r));
	}

	ALBEDO = color;
	ROUGHNESS = 0.6;
	EMISSION = glow_color;
}
