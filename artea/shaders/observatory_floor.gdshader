shader_type spatial;

// Lookout island floor: an astrolabe laid in the stone. Gold rings and twelve
// sector ticks, alternate lavender sectors, an eight-point compass rose under
// the observatory and a scatter of glowing stars in the outer band.
// Model space XZ of the island deck (centred on it).

uniform float island_radius = 70.0;
uniform vec3 stone : source_color = vec3(0.93, 0.91, 0.95);
uniform vec3 sector : source_color = vec3(0.85, 0.80, 0.94);
uniform vec3 gold : source_color = vec3(0.95, 0.77, 0.37);
uniform vec3 night : source_color = vec3(0.14, 0.15, 0.32);
uniform vec3 star : source_color = vec3(0.70, 0.96, 1.0);
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

float line(float d, float w) {
	float aa = fwidth(d);
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

void fragment() {
	vec3 color = stone;
	vec3 glow = vec3(0.0);

	if (up_facing > 0.5) {
		vec2 p = model_pos.xz;
		float r = length(p);
		float ang = atan(p.y, p.x);
		float turn = ang / 6.2831 + 0.5;

		// Twelve sectors in the outer band, alternate ones tinted.
		float band = step(36.0, r) * step(r, 58.0);
		color = mix(color, sector, band * step(0.5, mod(floor(turn * 12.0), 2.0)));
		// A night-sky ring sprinkled with stars.
		float sky = step(46.0, r) * step(r, 56.0);
		color = mix(color, night, sky * 0.85);
		vec2 star_cell = floor(p / 1.6);
		vec2 star_pos = (star_cell + 0.5 + (vec2(hash(star_cell), hash(star_cell + 7.0)) - 0.5) * 0.7) * 1.6;
		float twinkle = 0.6 + 0.4 * sin(TIME * 2.0 + hash(star_cell) * 6.2831);
		float stars = (1.0 - smoothstep(0.08, 0.2, length(p - star_pos)))
			* step(0.78, hash(star_cell + 3.0)) * sky;
		color = mix(color, star, stars);
		glow += star * stars * twinkle * 1.4;

		// Gold rings and sector ticks.
		float rings = max(max(line(r - 18.0, 0.25), line(r - 36.0, 0.3)),
			max(line(r - 46.0, 0.25), max(line(r - 56.0, 0.25), line(r - 58.0, 0.35))));
		float ticks = line((fract(turn * 12.0 + 0.5) - 0.5) * 6.2831 * r / 12.0, 0.18)
			* step(36.0, r) * step(r, 46.0);
		float minor = line((fract(turn * 72.0 + 0.5) - 0.5) * 6.2831 * r / 72.0, 0.08)
			* step(56.0, r) * step(r, 58.0);
		// Eight-point compass rose, long points on the cardinals.
		float point_len = mix(30.0, 20.0, step(0.5, mod(floor(turn * 8.0 + 0.5), 2.0)));
		float spoke = abs(fract(turn * 8.0 + 0.5) - 0.5) * 6.2831 / 8.0;
		float rose = step(r * spoke, 2.6 * (1.0 - r / point_len)) * step(r, point_len);
		color = mix(color, gold, max(max(rings, ticks), max(minor, rose * 0.85)));
		glow += gold * (rings + ticks + rose * 0.5) * 0.2;

		color = mix(color, border, smoothstep(island_radius - 7.0, island_radius - 6.5, r));
	}

	ALBEDO = color;
	ROUGHNESS = 0.5;
	EMISSION = glow;
}
