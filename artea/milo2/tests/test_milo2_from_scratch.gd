extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_test_source_isolation()
	_test_generated_assets()
	_test_character_scene()
	_test_original_milo_unchanged()
	if failures.is_empty():
		print("MILO2_FROM_SCRATCH_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("MILO2_FROM_SCRATCH_TEST: FAIL (%d)" % failures.size())
		quit(1)


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _test_source_isolation() -> void:
	var generator := _read("res://milo2/blender/build_milo2_from_scratch.py")
	_expect(generator.contains("read_factory_settings(use_empty=True)"), "generator must begin from a blank Blender scene")
	_expect(generator.contains("def unify_character_mesh"), "generator must consolidate the character into one mesh")
	_expect(generator.contains("TRIANGULATE"), "generator must triangulate the final surface")
	_expect(generator.contains("MODEL_OBJECTS[:] = [RIG, unified]"), "export list must contain only the rig and unified character mesh")
	_expect(not generator.contains("M2_Cuff_"), "Milo 2 arms must use the continuous sleeve loft, not a separate cuff volume")
	_expect(generator.contains("M2_Sleeve_Shoulder_Piping_Outer_"), "Milo 2 sleeves must retain their fitted shoulder piping")
	_expect(generator.contains("def sleeve_front_point"), "Milo 2 sleeve decoration must conform to the curved sleeve surface")
	_expect(generator.contains("M2_Sleeve_Diamond_Knot_"), "Milo 2 sleeves must retain their compact heraldic knot")
	_expect(generator.contains("M2_Sleeve_Cuff_Piping_Upper_"), "Milo 2 sleeves must retain their fitted double wrist border")
	_expect(generator.contains("def moustache_leaf"), "Milo 2 moustache must use the sculpted reference-leaf construction")
	_expect(generator.contains("M2_Moustache_Ridge_Lower_"), "Milo 2 moustache must retain its layered fur ridges")
	for forbidden in ["milo_exact_target_parts", "milo_villager_skin", "open_mainfile", "milo_animations.gd"]:
		_expect(not generator.contains(forbidden), "generator contains forbidden Milo 1 dependency: %s" % forbidden)
	var controller := _read("res://milo2/godot/milo2_controller.gd")
	_expect(not controller.contains("milo_animations.gd"), "Milo 2 controller must not inherit Milo 1")


func _test_generated_assets() -> void:
	_expect(FileAccess.file_exists("res://milo2/assets/milo2_from_scratch.blend"), "independent .blend is missing")
	_expect(FileAccess.file_exists("res://milo2/assets/milo2_from_scratch.glb"), "independent .glb is missing")
	_expect(FileAccess.file_exists("res://milo2/artifacts/milo2_reference_render.png"), "reference render is missing")
	var model := load("res://milo2/assets/milo2_from_scratch.glb") as PackedScene
	_expect(model != null, "independent GLB did not import as a Godot scene")
	if model == null:
		return
	var imported := model.instantiate()
	root.add_child(imported)
	var skeleton := _find_type(imported, "Skeleton3D") as Skeleton3D
	_expect(skeleton != null, "imported GLB has no skeleton")
	if skeleton != null:
		_expect(skeleton.get_bone_count() == 41, "imported GLB must contain exactly 41 authored bones")
	var player := _find_type(imported, "AnimationPlayer") as AnimationPlayer
	_expect(player != null, "imported GLB has no AnimationPlayer")
	if player != null:
		for clip in [&"Milo2_Idle", &"Milo2_Walk", &"Milo2_Wave"]:
			_expect(player.has_animation(clip), "imported GLB is missing animation: %s" % clip)
	_expect(_count_type(imported, "MeshInstance3D") == 1, "Milo 2 must import as one unified skinned mesh")
	imported.queue_free()


func _test_character_scene() -> void:
	var packed := load("res://milo2/godot/milo2_character.tscn") as PackedScene
	_expect(packed != null, "Milo 2 character scene failed to load")
	if packed == null:
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	_expect(instance.get_meta("milo_generation", 0) == 2, "Milo 2 generation marker is missing")
	_expect(instance.has_method("get_milo_generation"), "Milo 2 independent controller is missing")
	_expect(instance.get_node_or_null("Milo2Skin") != null, "Milo 2 skin is missing")
	instance.queue_free()


func _test_original_milo_unchanged() -> void:
	var original_scene := _read("res://scenes/milo_animations.tscn")
	_expect(original_scene.contains("res://scripts/milo_animations.gd"), "original Milo no longer references its original controller")
	_expect(not original_scene.contains("milo_1_controller.gd"), "original Milo was wrapped by replacement code")
	var original_skin := _read("res://scenes/characters/milo_scholar.tscn")
	_expect(original_skin.contains("res://scenes/characters/milo_villager_skin.tscn"), "original Milo skin was replaced")


func _find_type(node: Node, class_name_to_find: String) -> Node:
	if node.is_class(class_name_to_find):
		return node
	for child in node.get_children():
		var found := _find_type(child, class_name_to_find)
		if found != null:
			return found
	return null


func _count_type(node: Node, class_name_to_count: String) -> int:
	var count := 1 if node.is_class(class_name_to_count) else 0
	for child in node.get_children():
		count += _count_type(child, class_name_to_count)
	return count
