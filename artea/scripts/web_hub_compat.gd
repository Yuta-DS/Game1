extends Node3D


func _ready() -> void:
	if OS.get_name() != "Web":
		return
	_configure_web_sky()


func _configure_web_sky() -> void:
	var world_environment := get_node_or_null("Environment/DayNite/WorldEnvironment") as WorldEnvironment
	if not world_environment or not world_environment.environment or not world_environment.environment.sky:
		return
	var sky_material := world_environment.environment.sky.sky_material as ShaderMaterial
	if not sky_material or not sky_material.shader:
		return

	# WebGL's Compatibility renderer does not reliably reproduce the sky
	# half-resolution pass. Compile the same shader without that pass and blend
	# its clouds directly, keeping the material and all animated uniforms intact.
	var shader_source := sky_material.shader.code
	shader_source = shader_source.replace("render_mode use_half_res_pass;", "")
	var half_res_block := """\t// clouds
\tif (AT_HALF_RES_PASS) {
\t\tvec3 clouds_direction = vec3(EYEDIR.xz / clamp(EYEDIR.y, 0.0, 1.0), 1.0);
\t\tvec2 clouds = EYEDIR.y > 0.0 ? cloud_ray_march(clouds_direction, LIGHT0_DIRECTION) : vec2(0.0);

\t\tCOLOR.rgb = mix(bottom_color, clouds_light_color, exp(-clouds.y * clouds_shadow_intensity));
\t\tALPHA = (1.0 - exp(-clouds.x * horizon_mask * bottom_mask * 10.0));

\t}else{
\t\tCOLOR.rgb = mix(sky_color, HALF_RES_COLOR.rgb, HALF_RES_COLOR.a);
\t}
"""
	var full_res_block := """\t// clouds (full-resolution Web/GL Compatibility path)
\tvec3 clouds_direction = vec3(EYEDIR.xz / clamp(EYEDIR.y, 0.0, 1.0), 1.0);
\tvec2 clouds = EYEDIR.y > 0.0 ? cloud_ray_march(clouds_direction, LIGHT0_DIRECTION) : vec2(0.0);
\tvec3 cloud_color = mix(bottom_color, clouds_light_color, exp(-clouds.y * clouds_shadow_intensity));
\tfloat cloud_alpha = 1.0 - exp(-clouds.x * horizon_mask * bottom_mask * 10.0);
\tCOLOR.rgb = mix(sky_color, cloud_color, cloud_alpha);
\tALPHA = 1.0;
"""
	if not shader_source.contains(half_res_block):
		push_warning("Web sky compatibility patch did not match the source shader.")
		return
	shader_source = shader_source.replace(half_res_block, full_res_block)
	var web_shader := Shader.new()
	web_shader.code = shader_source
	sky_material.shader = web_shader
