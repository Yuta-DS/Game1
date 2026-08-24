shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// The user-selected village surface: pale worn stones with grass already
// growing through its irregular joints. World-space UVs keep it continuous
// across the full terrain-fitted center mesh.
uniform sampler2D ground_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_size : hint_range(4.0, 30.0) = 12.0;
uniform vec3 surface_tint : source_color = vec3(0.92, 0.94, 0.90);

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
	vec2 ground_uv = world_xz / tile_size;
	vec3 selected_surface = texture(ground_texture, ground_uv).rgb;
	float broad_wear = 0.94 + hash21(floor(world_xz * 0.18)) * 0.08;
	ALBEDO = selected_surface * surface_tint * broad_wear;
	ROUGHNESS = 0.96;
}
