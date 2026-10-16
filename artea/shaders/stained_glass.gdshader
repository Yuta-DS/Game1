// Procedural stained glass for the Hub castle's windows (castle_redesign.gd).
//
// Drawn in the panel's own metres rather than from a texture, so the lead
// lines stay crisp at any distance and nothing has to ship in the pack.
// Unshaded: the glass reads as lit from inside, day or night.
//
// shape 0 - lancet: diamond quarries of jewel colours under a pointed head.
//   The head is triangular, matching the straight beams of the lancet frames,
//   or a semicircle (round_head) for the castle's own arched windows.
// shape 1 - rose: a round window of rings and petals around a gold boss.
// shape 2 - column: quarries wrapped round a cylinder (the spiral stair tower),
//   laid out from the mesh's own angle and height so they stay square on a
//   tapering shaft. panel_size.x is the perimeter; `wrap_cells` quarries fit
//   exactly once round, so the pattern closes with no seam.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform int shape = 0;
uniform vec2 panel_size = vec2(2.64, 5.95);
// Lancet only: height of the arch's springing line above the sill.
uniform float shoulder = 3.05;
uniform bool round_head = false;
uniform float quarry = 0.62;
uniform int wrap_cells = 0;
uniform float lead_width = 0.045;
uniform float brightness = 1.0;
uniform float seed = 0.0;

varying vec3 object_position;

const vec3 LEAD = vec3(0.07, 0.06, 0.08);
const vec3 JEWELS[6] = vec3[6](
	vec3(0.78, 0.10, 0.18),  // ruby
	vec3(0.12, 0.30, 0.82),  // sapphire
	vec3(0.10, 0.55, 0.32),  // emerald
	vec3(0.95, 0.68, 0.16),  // amber
	vec3(0.48, 0.20, 0.70),  // amethyst
	vec3(0.92, 0.48, 0.62)   // rose
);

float hash(vec2 p) {
	return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	object_position = VERTEX;
}

// 1 on a lead line, 0 in the glass, anti-aliased with the screen derivative.
float lead(float distance_to_line) {
	float aa = fwidth(distance_to_line);
	return 1.0 - smoothstep(lead_width - aa, lead_width + aa, distance_to_line);
}

void fragment() {
	// Metres from the panel's bottom centre (lancet) or its centre (rose).
	vec2 p = vec2((UV.x - 0.5) * panel_size.x, (1.0 - UV.y) * panel_size.y);
	if (shape == 2) {
		float around = atan(object_position.z, object_position.x) / TAU + 0.5;
		p = vec2(around * panel_size.x, object_position.y);
	}
	vec3 colour;
	float line;

	if (shape == 0 || shape == 2) {
		// Diamond quarries: a grid rotated 45 degrees.
		vec2 q = vec2(p.x + p.y, p.y - p.x) / quarry;
		vec2 cell = floor(q);
		vec2 f = fract(q);
		// Going once round the column shifts the cell by (n, -n); keying on
		// what that shift leaves unchanged gives the same colour either side.
		vec2 key = wrap_cells > 0
			? vec2(cell.x + cell.y, mod(cell.x - cell.y, 2.0 * float(wrap_cells)))
			: cell;
		colour = JEWELS[int(hash(key) * 6.0) % 6];
		// Lighter centre to each pane, like hand-blown glass.
		colour *= 0.82 + 0.3 * (1.0 - length(f - 0.5));
		line = lead(min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * quarry * 0.7071);
		if (shape == 0) {
			float half_width = panel_size.x * 0.5;
			float slope = (panel_size.y - shoulder) / half_width;
			float head = round_head
				? shoulder + sqrt(max(half_width * half_width - p.x * p.x, 0.0))
				: shoulder + (half_width - abs(p.x)) * slope;
			if (p.y > head) {
				discard;
			}
			// Edge lead round the whole panel.
			float to_head = round_head
				? half_width - length(vec2(p.x, max(p.y - shoulder, 0.0)))
				: (head - p.y) / slope;
			float edge = min(half_width - abs(p.x), min(p.y, to_head));
			line = max(line, lead(edge * 0.5));
		}
	} else {
		vec2 c = p - vec2(0.0, panel_size.y * 0.5);
		float radius = min(panel_size.x, panel_size.y) * 0.5;
		float r = length(c) / radius;
		if (r > 1.0) {
			discard;
		}
		float turns = (atan(c.y, c.x) + PI) / TAU;
		float ring = r < 0.2 ? 0.0 : (r < 0.55 ? 1.0 : (r < 0.85 ? 2.0 : 3.0));
		float petals = ring == 1.0 ? 8.0 : (ring == 2.0 ? 16.0 : 32.0);
		float sector = floor(turns * petals);
		colour = ring == 0.0 ? JEWELS[3]
			: JEWELS[int(ring * 2.0 + mod(sector, 2.0) + hash(vec2(ring, 0.0)) * 3.0) % 6];
		colour *= 0.8 + 0.25 * (1.0 - fract(r * 4.0));
		// Spokes between sectors, and rings between bands.
		float spoke = ring == 0.0 ? 1.0
			: abs(fract(turns * petals + 0.5) - 0.5) / petals * TAU * length(c);
		float band = min(min(abs(r - 0.2), abs(r - 0.55)), min(abs(r - 0.85), 1.0 - r)) * radius;
		line = max(lead(spoke), lead(band));
	}
	ALBEDO = mix(colour * brightness, LEAD, line);
}
