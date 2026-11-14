shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D surface_map : filter_nearest, repeat_disable;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D brick_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 world_position;

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	fraction = fraction * fraction * (3.0 - 2.0 * fraction);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, fraction.x), mix(c, d, fraction.x), fraction.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Terrain3D's 4096 m square is baked from -2048 to +2048 on X/Z. The compact
	// R8 surface map stores grass, sand, and paving as IDs 0..2 at the centre of
	// three broad value bands, so nearest sampling reconstructs the authored
	// surface without Terrain3D's WebGL-incompatible region uniform block.
	vec2 map_uv = clamp(world_position.xz / 4096.0 + vec2(0.5), vec2(0.0), vec2(1.0));
	float surface_id = floor(texture(surface_map, map_uv).r * 3.0);
	vec3 grass = texture(grass_albedo, world_position.xz * 0.1165).rgb;
	vec3 sand = texture(sand_albedo, world_position.xz * 0.1444).rgb;
	vec3 brick = texture(brick_albedo, world_position.xz * 0.1634).rgb;
	// Lift and gently saturate the meadow without pushing it into neon green.
	// The Web compatibility renderer otherwise makes the authored texture look
	// grey and washed out compared with the Godot editor's Forward+ lighting.
	float grass_luma = dot(grass, vec3(0.2126, 0.7152, 0.0722));
	grass = mix(vec3(grass_luma), grass, 1.05) * vec3(1.07, 1.11, 1.05);
	vec3 authored_surface = surface_id < 0.5 ? grass : (surface_id < 1.5 ? sand : brick);

	// Add restrained macro variation to break up repetition while retaining the
	// real meadow flowers, blades, sand grains, and paving detail.
	float broad = value_noise(world_position.xz * 0.022);
	float detail = value_noise(world_position.xz * 0.16 + vec2(17.3, -9.1));
	float slope = clamp(1.0 - dot(normalize(NORMAL), vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	vec3 base = authored_surface * mix(1.0, 1.1, broad) * mix(0.99, 1.03, detail);
	base = mix(base, base * vec3(0.78, 0.76, 0.72), slope * 0.52);
	ALBEDO = base;
	ROUGHNESS = mix(0.96, 0.82, slope);
	SPECULAR = 0.18;
}
