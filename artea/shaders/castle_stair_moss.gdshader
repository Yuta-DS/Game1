shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

// A colour-only pass on the existing mesh. No vertex displacement, extra
// surface height, screen textures, particles or Web-incompatible dependencies.
uniform vec3 moss_dark : source_color = vec3(0.19, 0.27, 0.13);
uniform vec3 moss_light : source_color = vec3(0.40, 0.48, 0.25);
uniform float remaining_fraction : hint_range(0.0, 1.0) = 0.4;
varying vec3 stone_position;
varying vec3 stone_normal;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float moss_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i+vec3(1,0,0)), f.x),
		mix(hash3(i+vec3(0,1,0)), hash3(i+vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(i+vec3(0,0,1)), hash3(i+vec3(1,0,1)), f.x),
		mix(hash3(i+vec3(0,1,1)), hash3(i+vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	stone_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	stone_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = stone_position;
	// Warped, overlapping colonies rather than large rounded camouflage blobs.
	// The three-dimensional field wraps across corners and curved stair walls.
	vec3 warp = vec3(moss_noise(p * 0.76 + vec3(18.4, 7.2, 41.0)),
		moss_noise(p * 0.76 + vec3(63.1, 9.8, 4.2)),
		moss_noise(p * 0.76 + vec3(3.7, 51.2, 26.0))) - vec3(0.5);
	vec3 colony_position = p * vec3(1.8, 1.05, 1.8) + warp * 1.3
		+ vec3(37.8, 91.2, 16.4);
	float colonies = moss_noise(colony_position) * 0.55
		+ moss_noise(colony_position * 2.3) * 0.30
		+ moss_noise(colony_position * 5.1) * 0.15;
	// Fine vertical fronds break up each colony's edge into tapered trails.
	// No time input: moss stays attached to the stone instead of crawling.
	float fronds = moss_noise(p * vec3(8.0, 1.8, 8.0) + warp * 2.2);
	vec3 tuft_position = vec3(p.x * 0.8 + p.z * 0.6,
		p.y + p.x * 0.23, p.z * 0.8 - p.x * 0.6) * 15.0 + warp;
	float tufts = moss_noise(tuft_position) * 0.68
		+ moss_noise(tuft_position * 2.17 + vec3(6.8, 11.2, 3.9)) * 0.32;
	float growth = colonies + (fronds - 0.5) * 0.20 + (tufts - 0.5) * 0.07;
	float threshold = 0.50 + (0.5 - remaining_fraction) * 0.43;
	float edge_width = max(0.024, fwidth(growth) * 0.75);
	float coverage = smoothstep(threshold - edge_width, threshold + edge_width, growth);
	if (remaining_fraction >= 0.999) {
		coverage = 1.0;
	} else if (remaining_fraction <= 0.001) {
		coverage = 0.0;
	}
	// Olive tips and darker cushions give the fine growth depth without adding
	// floating geometry. Fade subpixel fibres out to avoid distant shimmering.
	float detail_fade = 1.0 - smoothstep(0.35, 1.1, length(fwidth(p * 38.0)));
	float velvet = mix(0.5, moss_noise(p * 38.0), detail_fade);
	float colour = clamp(0.22 + smoothstep(0.28, 0.72, tufts) * 0.40 + velvet * 0.20
		+ (1.0 - coverage) * 0.10, 0.0, 1.0);
	// Tiny cushions catch the light. This perturbs only the shading normal,
	// never the actual wall surface, silhouette or collision geometry.
	float cushion_height = (tufts * 0.005 + velvet * detail_fade * 0.001) * coverage;
	vec3 view_dx = dFdx(VERTEX);
	vec3 view_dy = dFdy(VERTEX);
	vec3 base_normal = normalize(NORMAL);
	vec3 gradient_x = cross(view_dy, base_normal);
	vec3 gradient_y = cross(base_normal, view_dx);
	float determinant = dot(view_dx, gradient_x);
	vec3 height_gradient = sign(determinant) * (dFdx(cushion_height) * gradient_x
		+ dFdy(cushion_height) * gradient_y);
	NORMAL = normalize(max(abs(determinant), 0.000001) * base_normal - height_gradient);
	// Stair treads are not selected at all. This additionally leaves the upper
	// faces of selected coping/plinth meshes clear, and keeps soffits readable.
	float wall_face = 1.0 - smoothstep(0.38, 0.72, abs(normalize(stone_normal).y));
	ALBEDO = mix(moss_dark, moss_light, colour);
	ROUGHNESS = 0.98;
	SPECULAR = 0.12;
	ALPHA = coverage * wall_face * 0.96;
}
