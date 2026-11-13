shader_type spatial;

// Crown Line station surfaces, patterned in world space so any box or ramp
// tiles evenly whatever its size: 0 = running-bond pavers, 1 = riveted metal
// panels, 2 = tactile warning dots at the platform edge.

uniform int pattern = 0;
uniform vec3 base_color : source_color = vec3(0.85, 0.83, 0.88);
uniform vec3 alt_color : source_color = vec3(0.75, 0.73, 0.80);
uniform vec3 line_color : source_color = vec3(0.45, 0.42, 0.50);
uniform float tile_size = 1.2;
uniform vec3 glow_color : source_color = vec3(0.0);
uniform float glow_strength = 0.0;
uniform float roughness_value = 0.8;
uniform float metallic_value = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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

// 1 inside a line of half-width w around 0 (d in cell units), anti-aliased.
float line(float d, float w) {
	float aa = fwidth(d) + 1e-4;
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv = n.y > max(n.x, n.z) ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	vec3 color = base_color;
	float rough = roughness_value;
	float glow = 0.0;

	if (pattern == 0) {
		// Pavers twice as long as wide, every other row offset by half.
		vec2 cell_uv = uv / vec2(tile_size * 2.0, tile_size);
		float row = floor(cell_uv.y);
		cell_uv.x += mod(row, 2.0) * 0.5;
		vec2 cell = floor(cell_uv);
		vec2 f = fract(cell_uv) - 0.5;
		// Far away (many pavers per pixel) the joints and per-paver shading
		// would alias into moire rings, so fade to their average colour.
		float near = 1.0 - smoothstep(0.08, 0.35, length(fwidth(cell_uv)));
		color = mix(base_color, alt_color, mix(0.5, hash(cell), near));
		color *= 0.94 + 0.12 * mix(0.5, noise(uv * 3.0), near);
		float grout = max(line(0.5 - abs(f.x), 0.012), line(0.5 - abs(f.y), 0.03));
		color = mix(color, line_color, mix(0.12, grout * 0.85, near));
	} else if (pattern == 1) {
		// Square panels with dark seams, four rivets and a brushed grain.
		vec2 cell_uv = uv / tile_size;
		vec2 f = fract(cell_uv) - 0.5;
		color *= 0.92 + 0.10 * noise(vec2(uv.x * 0.6, uv.y * 14.0));
		color = mix(color, alt_color, hash(floor(cell_uv)) * 0.35);
		float seam = max(line(0.5 - abs(f.x), 0.02), line(0.5 - abs(f.y), 0.02));
		color = mix(color, line_color, seam);
		vec2 rivet = abs(f) - vec2(0.40);
		float rivets = 1.0 - smoothstep(0.03, 0.045, length(rivet));
		color = mix(color, alt_color * 1.4, rivets);
		glow = seam;
	} else {
		// Tactile dots on a warning yellow band.
		vec2 cell_uv = uv / 0.3;
		vec2 f = fract(cell_uv) - 0.5;
		float dot_mask = 1.0 - smoothstep(0.22, 0.27, length(f));
		color = mix(base_color, alt_color, dot_mask);
		color *= 0.95 + 0.08 * noise(uv * 5.0);
	}

	ALBEDO = color;
	ROUGHNESS = rough;
	// Low specular: matte paving shouldn't mirror the bright sky.
	SPECULAR = pattern == 1 ? 0.4 : 0.15;
	METALLIC = metallic_value;
	EMISSION = glow_color * glow_strength * (pattern == 1 ? glow : 1.0);
}
