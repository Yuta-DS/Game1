shader_type spatial;

// Creator's Light island floor: glazed kitchen-style tiles (cream alternating
// with the studio paints) and a gold inlay on the raised studio platform,
// paint-flecked terrazzo on the rest of the island.
// Model space XZ; the platform and the island deck are both centred on the
// district, so one material covers both without a seam.

uniform vec2 platform_half = vec2(90.0, 82.0);
uniform float island_radius = 195.0;
uniform float tile_size = 4.0;
uniform float chip_size = 1.4;
uniform vec3 cream : source_color = vec3(0.86, 0.82, 0.74);
uniform vec3 grout : source_color = vec3(0.55, 0.52, 0.50);
uniform vec3 platform_side : source_color = vec3(0.55, 0.44, 0.62);
uniform vec3 gold : source_color = vec3(0.95, 0.77, 0.37);
uniform vec3 terrazzo : source_color = vec3(0.95, 0.92, 0.87);
uniform vec3 border : source_color = vec3(0.36, 0.29, 0.56);

// The six studio paints, one per easel.
const vec3 PAINT[6] = vec3[6](
	vec3(0.89, 0.33, 0.38), vec3(0.96, 0.62, 0.25), vec3(0.98, 0.84, 0.36),
	vec3(0.38, 0.72, 0.49), vec3(0.31, 0.56, 0.88), vec3(0.62, 0.43, 0.86));

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

vec3 tiles(vec2 p) {
	vec2 g = p / tile_size;
	vec2 cell = floor(g);
	// Checkerboard: cream tiles between tiles in a random studio paint,
	// deepened a little so they hold their colour in the bright island light.
	bool coloured = mod(cell.x + cell.y, 2.0) > 0.5;
	vec3 glaze = coloured
		? mix(PAINT[min(int(hash(cell + 11.0) * 6.0), 5)], vec3(0.0), 0.12)
		: cream;
	// Each tile fired a touch differently, brighter towards its middle.
	vec2 centred = fract(g) - 0.5;
	glaze *= (0.95 + 0.06 * hash(cell + 3.0)) * (1.0 - 0.2 * dot(centred, centred));
	float joints = max(line(fract(g.x + 0.5) - 0.5, 0.025), line(fract(g.y + 0.5) - 0.5, 0.025));
	return mix(glaze, grout, joints);
}

vec3 flecked_terrazzo(vec2 p) {
	vec3 color = terrazzo * (0.95 + 0.08 * noise(p * 0.3));
	vec2 g = p / chip_size;
	vec2 cell = floor(g);
	vec2 offset = (hash2(cell) - 0.5) * 0.6;
	float h = hash(cell + 17.0);
	float chip = 1.0 - smoothstep(0.12, 0.17, length(fract(g) - 0.5 - offset));
	// Fade the chips out with distance before they shimmer.
	chip *= 1.0 - smoothstep(0.25, 0.6, fwidth(g.x));
	vec3 paint = PAINT[min(int(hash(cell + 5.0) * 6.0), 5)];
	return mix(color, paint, chip * step(0.55, h) * 0.85);
}

void fragment() {
	vec2 p = model_pos.xz;
	vec2 edge = platform_half - abs(p);
	float to_edge = min(edge.x, edge.y);
	bool on_platform = to_edge > -0.01;
	vec3 color = on_platform ? platform_side : terrazzo * 0.75;
	vec3 glow_color = vec3(0.0);

	if (up_facing > 0.5) {
		if (on_platform) {
			color = tiles(p);
			// Gold inlay band 4 m in from the platform edge.
			float band = line(to_edge - 4.0, 0.35);
			color = mix(color, gold, band);
			glow_color += gold * band * 0.25;
		} else {
			color = flecked_terrazzo(p);
			// Violet band at the island rim, like the other islands.
			color = mix(color, border, smoothstep(island_radius - 12.0, island_radius - 11.5, length(p)));
		}
	}

	ALBEDO = color;
	// Glazed tiles catch the light; terrazzo stays matte.
	ROUGHNESS = on_platform ? 0.45 : 0.7;
	EMISSION = glow_color;
}
