shader_type spatial;

uniform vec4 hedge_color : source_color = vec4(0.31, 0.51, 0.24, 1.0);
varying vec3 garden_position;

void vertex() {
	garden_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float leaf_grain(vec3 cell) {
	vec3 p = fract(cell * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	float leaves = leaf_grain(floor(garden_position * 5.0));
	float clusters = leaf_grain(floor(garden_position * 1.4));
	ALBEDO = hedge_color.rgb * (0.78 + 0.26 * leaves + 0.10 * clusters);
	ROUGHNESS = 0.95;
}
