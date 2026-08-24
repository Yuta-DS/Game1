shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec3 stone_warm : source_color = vec3(0.61, 0.58, 0.50);
uniform vec3 stone_light : source_color = vec3(0.82, 0.80, 0.72);
uniform vec3 stone_cool : source_color = vec3(0.47, 0.49, 0.47);
uniform vec3 soil_color : source_color = vec3(0.16, 0.14, 0.10);
uniform vec3 moss_color : source_color = vec3(0.19, 0.34, 0.10);
uniform float joint_width : hint_range(0.02, 0.20) = 0.09;

varying vec2 world_xz;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 local = world_xz - vec2(90.0, -30.0);
	// Uneven running courses read like hand-laid medieval setts rather than a
	// modern machine-perfect herringbone floor.
	float course_hint = floor(local.y / 0.88);
	float course_width = 1.32 + hash21(vec2(course_hint, 11.0)) * 0.82;
	float warped_y = local.y + sin(local.x * 0.21 + course_hint * 1.7) * 0.065;
	vec2 paver_uv = vec2(local.x / course_width, warped_y / 0.88);
	float row = floor(paver_uv.y);
	paver_uv.x += mod(row, 2.0) * 0.5 + (hash21(vec2(row, 3.0)) - 0.5) * 0.32;
	vec2 paver_id = floor(paver_uv);
	vec2 within = fract(paver_uv);

	// Every stone gets different margins and rounded/chipped corners. This
	// breaks the machine-made grid and matches old, hand-dressed pale blocks.
	float left_joint = joint_width * (0.55 + hash21(paver_id + vec2(2.0, 7.0)) * 0.95);
	float right_joint = joint_width * (0.55 + hash21(paver_id + vec2(11.0, 3.0)) * 0.95);
	float bottom_joint = joint_width * (0.45 + hash21(paver_id + vec2(5.0, 17.0)) * 0.8);
	float top_joint = joint_width * (0.45 + hash21(paver_id + vec2(19.0, 5.0)) * 0.8);
	vec2 center_shift = vec2(left_joint - right_joint, bottom_joint - top_joint) * 0.5;
	vec2 half_size = vec2(
		0.5 - (left_joint + right_joint) * 0.5,
		0.5 - (bottom_joint + top_joint) * 0.5);
	float corner_radius = 0.035 + hash21(paver_id + vec2(23.0, 31.0)) * 0.07;
	vec2 q = abs((within - vec2(0.5)) - center_shift) - half_size + corner_radius;
	float stone_sdf = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	vec2 chip_cell = floor(within * vec2(13.0, 9.0));
	float chips = (hash21(chip_cell + paver_id * 17.0) - 0.5) * 0.026;
	float stone_mask = 1.0 - smoothstep(-0.018, 0.018, stone_sdf + chips);
	float variation = hash21(paver_id);
	vec3 paver = mix(stone_warm, stone_light, variation);
	paver = mix(paver, stone_cool, smoothstep(0.82, 0.98,
		hash21(paver_id + vec2(13.0, 29.0))) * 0.7);
	paver *= 0.91 + 0.13 * hash21(paver_id + vec2(17.0, 9.0));
	float limestone_streak = sin(world_xz.x * 5.3 + world_xz.y * 0.45
		+ hash21(paver_id) * 6.28) * 0.5 + 0.5;
	paver *= 0.94 + limestone_streak * 0.08;

	// A darker soldier-course frame gives the square a deliberately designed
	// edge without making it feel like a modern tiled floor.
	float edge_distance = min(36.0 - abs(local.x), 60.0 - abs(local.y));
	float border = 1.0 - smoothstep(0.7, 2.0, edge_distance);
	paver = mix(paver, stone_cool * 0.82, border * 0.7);
	float moss_noise = hash21(chip_cell + paver_id * 5.0 + vec2(41.0, 7.0));
	float moss = (1.0 - stone_mask) * smoothstep(0.42, 0.78, moss_noise);
	vec3 joints = mix(soil_color, moss_color, moss * 0.92);
	ALBEDO = mix(joints, paver, stone_mask);
	ROUGHNESS = mix(1.0, 0.93, stone_mask);
}
