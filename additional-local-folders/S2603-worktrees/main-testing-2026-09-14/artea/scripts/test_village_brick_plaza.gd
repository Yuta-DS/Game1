extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("VILLAGE_BRICK_PLAZA_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var packed := load("res://scenes/New_Hub_World.tscn") as PackedScene
	if packed == null:
		_fail("hub scene must load")
		return
	var hub := packed.instantiate()
	root.add_child(hub)
	for _frame in 8:
		await process_frame
	var plaza := hub.get_node_or_null("VillageBrickPlaza")
	var brick_ground := hub.get_node_or_null("VillageBrickPlaza/BrickGround") as MeshInstance3D
	if plaza == null or brick_ground == null or brick_ground.mesh == null:
		_fail("village center must build a terrain-fitted brick ground")
		return
	if brick_ground.mesh.get_surface_count() != 1 \
			or brick_ground.mesh.surface_get_array_len(0) < 15000:
		_fail("brick plaza must cover the broad village-center footprint")
		return
	var material := brick_ground.material_override as ShaderMaterial
	if material == null or material.shader == null \
			or material.shader.resource_path != "res://shaders/village_brick_plaza.gdshader":
		_fail("village ground must use its continuous terrain-fitted surface shader")
		return
	var selected_texture := material.get_shader_parameter("ground_texture") as Texture2D
	if selected_texture == null or selected_texture.resource_path != \
			"res://textures/ground_tiles_13_1k/ground_tiles_13_baseColor_1k.png":
		_fail("the full village center must use the user-selected gray-green ground style")
		return
	var overgrowth := hub.get_node_or_null(
		"VillageBrickPlaza/GrassOvergrowth") as MultiMeshInstance3D
	if overgrowth == null or overgrowth.multimesh == null \
			or overgrowth.multimesh.instance_count < 1250:
		_fail("medieval brick joints must include sparse modeled grass overgrowth")
		return
	var bounds := brick_ground.mesh.get_aabb()
	if bounds.position.x > 55.0 or bounds.end.x < 125.0 \
			or bounds.position.z > -94.0 or bounds.end.z < 54.0:
		_fail("brick ground must cover the full church-to-market village center")
		return
	for scatter_name in ["Grass", "Objects"]:
		var exclusion = hub.get_node_or_null(
			"Environment/%s/VillagePlazaExclusion" % scatter_name)
		if exclusion == null or not bool(exclusion.negative) or exclusion.shape == null:
			_fail("%s scatter must be excluded from the brick plaza" % scatter_name)
			return
		if not exclusion.shape.is_point_inside(
				Vector3(90.0, 25.0, -20.0), exclusion.global_transform):
			_fail("%s exclusion must cover the village-center bricks" % scatter_name)
			return
	print("VILLAGE_BRICK_PLAZA_TEST: PASS — selected gray-green ground covers the full village center")
	quit()
