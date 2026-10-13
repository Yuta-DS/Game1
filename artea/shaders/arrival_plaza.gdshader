shader_type spatial;

// Arrival-island plaza: a Versailles-style circular parterre centred on the
// Latona fountain. Pattern is in the deck's model space (XZ), so it follows
// the island wherever the floating world is placed.

uniform vec2 plaza_center = vec2(0.0, -60.0);   // fountain, relative to deck centre
uniform float island_radius = 155.0;
uniform float paver_size = 8.0;
uniform vec3 marble : source_color = vec3(0.925, 0.905, 0.94);
uniform vec3 marble_alt : source_color = vec3(0.95, 0.89, 0.93);
uniform vec3 vein : source_color = vec3(0.78, 0.74, 0.86);
uniform vec3 joint : source_color = vec3(0.70, 0.66, 0.76);
uniform vec3 petal : source_color = vec3(0.86, 0.74, 0.92);
uniform vec3 gold : source_color = vec3(0.95, 0.77, 0.37);
uniform vec3 cyan : source_color = vec3(0.40, 0.90, 0.94);
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

void fragment() {
	vec3 color = marble;
	float glow = 0.0;
	vec3 glow_color = vec3(0.0);

	if (up_facing > 0.5) {
		vec2 p = model_pos.xz;
		vec2 q = p - plaza_center;
		float r = length(q);
		float ang = atan(q.y, q.x);
		float edge = length(p);

		// Polar pavers: rings of curved slabs, each ring split into
		// near-square pieces, alternating tint like laid stone.
		float ring = floor(r / paver_size);
		float pieces = max(6.0, floor(6.2831 * (ring + 0.5)));
		float slot = (ang / 6.2831 + 0.5) * pieces + ring * 0.5;
		color = mod(ring + floor(slot), 2.0) < 1.0 ? marble : marble_alt;

		// Soft marble veining.
		float v = noise(p * 0.08) * 0.6 + noise(p * 0.21) * 0.4;
		color = mix(color, vein, smoothstep(0.02, 0.0, abs(v - 0.5)) * 0.55);

		// Eight-petal rose between the inner and outer gold rings.
		float petal_edge = 38.0 + 54.0 * pow(abs(cos(ang * 4.0)), 2.5);
		if (r > 38.0 && r < petal_edge) {
			color = mix(color, petal, 0.55);
		}
		float petal_line = line(r - petal_edge, 0.25) * step(38.0, r) * step(r, 96.0);

		// Paver joints (suppressed under inlays drawn below).
		float joints = max(line(fract(r / paver_size + 0.5) - 0.5, 0.012),
			line(fract(slot) - 0.5, 0.012 * pieces / max(r, 1.0) * paver_size));
		color = mix(color, joint, joints * 0.6);

		// Gold inlay rings and sixteen rays.
		float rays = line(fract(ang / 6.2831 * 16.0 + 0.5) - 0.5, 0.004 * 100.0 / max(r, 1.0))
			* step(38.0, r) * step(r, 100.0);
		float gold_mask = max(max(line(r - 36.0, 0.45), line(r - 100.0, 0.45)),
			max(line(edge - (island_radius - 12.0), 0.4), max(petal_line, rays * 0.8)));
		color = mix(color, gold, gold_mask);
		glow += gold_mask * 0.35;
		glow_color += gold * gold_mask * 0.35;

		// Cyan route line through the plaza, matching the bridge inlay.
		float route = line(p.x, 0.22) * step(36.5, r) * step(edge, island_radius - 12.5);
		color = mix(color, cyan, route);
		glow_color += cyan * route * 0.9;

		// Deep violet border band at the island rim.
		float band = smoothstep(island_radius - 12.0, island_radius - 11.5, edge);
		color = mix(color, border, band);
	}

	ALBEDO = color;
	ROUGHNESS = 0.55;
	EMISSION = glow_color;
}
