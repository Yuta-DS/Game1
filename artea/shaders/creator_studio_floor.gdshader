shader_type spatial;

// Creator's Light island floor: staggered oak planks with a gold inlay on the
// raised studio platform, a mown lawn on the rest of the island for the
// flower garden. Model space XZ; the platform and the island deck are both
// centred on the district, so one material covers both without a seam.

uniform vec2 platform_half = vec2(90.0, 82.0);
uniform float island_radius = 195.0;
uniform float plank_length = 7.0;
uniform float plank_width = 1.6;
uniform vec3 oak : source_color = vec3(0.60, 0.40, 0.25);
uniform vec3 oak_alt : source_color = vec3(0.48, 0.31, 0.19);
uniform vec3 seam : source_color = vec3(0.26, 0.17, 0.11);
uniform vec3 gold : source_color = vec3(0.95, 0.77, 0.37);
uniform vec3 grass : source_color = vec3(0.36, 0.62, 0.30);
uniform vec3 grass_dark : source_color = vec3(0.22, 0.45, 0.22);
uniform vec3 grass_light : source_color = vec3(0.55, 0.76, 0.36);
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

vec3 planks(vec2 p) {
	float row = floor(p.y / plank_width);
	float run = p.x / plank_length + hash(vec2(row, 3.1));
	float id = hash(vec2(row, floor(run)));
	vec3 color = mix(oak, oak_alt, id);
	// Grain runs along the plank.
	color *= 0.9 + 0.18 * noise(vec2(p.x * 0.5, p.y * 8.0) + id * 40.0);
	float seams = max(line(fract(p.y / plank_width + 0.5) - 0.5, 0.025),
		line(fract(run + 0.5) - 0.5, 0.004));
	return mix(color, seam, seams * 0.8);
}

vec3 lawn(vec2 p) {
	// Broad patches of darker and sunlit grass...
	float patches = noise(p * 0.035) * 0.6 + noise(p * 0.11) * 0.4;
	vec3 color = mix(grass_dark, grass, smoothstep(0.25, 0.65, patches));
	color = mix(color, grass_light, smoothstep(0.62, 0.9, patches) * 0.6);
	// ...then fine tufts, faded out with distance before they shimmer.
	vec2 tuft_uv = p * vec2(2.2, 0.9);
	float tufts = noise(tuft_uv) * 0.6 + noise(tuft_uv * 2.7) * 0.4;
	float near = 1.0 - smoothstep(0.3, 1.2, fwidth(tuft_uv.x));
	color *= 1.0 + (tufts - 0.5) * 0.28 * near;
	return color;
}

void fragment() {
	vec2 p = model_pos.xz;
	vec2 edge = platform_half - abs(p);
	float to_edge = min(edge.x, edge.y);
	bool on_platform = to_edge > -0.01;
	vec3 color = on_platform ? oak_alt * 0.7 : grass_dark * 0.8;
	vec3 glow_color = vec3(0.0);

	if (up_facing > 0.5) {
		if (on_platform) {
			color = planks(p);
			// Gold inlay band 4 m in from the platform edge.
			float band = line(to_edge - 4.0, 0.35);
			color = mix(color, gold, band);
			glow_color += gold * band * 0.25;
		} else {
			color = lawn(p);
			// Violet band at the island rim, like the other islands.
			color = mix(color, border, smoothstep(island_radius - 12.0, island_radius - 11.5, length(p)));
		}
	}

	ALBEDO = color;
	ROUGHNESS = on_platform ? 0.55 : 0.9;
	EMISSION = glow_color;
}
