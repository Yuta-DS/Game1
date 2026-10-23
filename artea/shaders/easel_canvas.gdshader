shader_type spatial;

// Easel canvas: blank primed linen until the player paints at that easel,
// then their drawing on the front face, fitted inside the canvas at its own
// proportions. Model space XY of the canvas box; the front looks along -Z.

uniform vec2 half_size = vec2(19.0, 22.5);
uniform vec3 linen : source_color = vec3(0.97, 0.95, 0.90);
uniform sampler2D art : source_color, filter_linear;
uniform bool has_art = false;
uniform float art_aspect = 1.0;

varying vec3 model_pos;
varying float front_facing;

void vertex() {
	model_pos = VERTEX;
	front_facing = -NORMAL.z;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = model_pos.xy / half_size;
	vec3 color = linen * (0.97 + 0.03 * hash(floor(model_pos.xy * 3.0)));
	if (front_facing > 0.5) {
		if (has_art) {
			float canvas_aspect = half_size.x / half_size.y;
			vec2 fit = art_aspect > canvas_aspect
				? vec2(1.0, canvas_aspect / art_aspect) : vec2(art_aspect / canvas_aspect, 1.0);
			vec2 a = uv / fit;
			if (abs(a.x) <= 1.0 && abs(a.y) <= 1.0) {
				// Seen from the front, model +X is the viewer's left.
				color = texture(art, vec2(0.5 - a.x * 0.5, 0.5 - a.y * 0.5)).rgb;
			}
		}
	} else {
		color *= 0.86;
	}
	ALBEDO = color;
	ROUGHNESS = 0.9;
}
