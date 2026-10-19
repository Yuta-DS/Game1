extends SceneTree

const PrototypeSkin := preload("res://scenes/characters/milo_prototype_reference_skin.tscn")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("MILO_PROTOTYPE_REFERENCE_TEST: %s" % message)
	quit(1)


func _run() -> void:
	for required_path in [
			"res://assets3D/characters/milo_2_pictured.glb",
			"res://assets3D/characters/milo_2_pictured.blend",
			"res://tools/blender/build_milo_prototype_reference.py",
			"res://scenes/characters/milo_villager_skin.tscn"]:
		if not FileAccess.file_exists(required_path):
			_fail("missing separate prototype/fallback asset: %s" % required_path)
			return

	var skin := PrototypeSkin.instantiate() as Node3D
	root.add_child(skin)
	await process_frame
	if str(skin.get_meta("milo_visual_variant", "")) \
			!= "pictured_prototype_reference":
		_fail("the new scene does not identify the pictured prototype variant")
		return
	if str(skin.get_meta("fallback_scene", "")) \
			!= "res://scenes/characters/milo_villager_skin.tscn":
		_fail("the original Milo fallback was not preserved")
		return

	var meshes := skin.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() < 100:
		_fail("prototype lost its part-based construction: %d meshes" % meshes.size())
		return
	for required_part in ["Head", "PrototypeEyeWhite_L", "PrototypeEyeWhite_R",
			"Pupil_L", "Pupil_R", "PrototypeMoustache_L",
			"PrototypeMoustache_R", "PrototypeBrow_L", "PrototypeBrow_R",
			"PrototypeMuzzleBridge", "PrototypeTail", "Paw_L", "Paw_R", "CoatBody",
			"Waistcoat", "PrototypeCoatBelt", "PrototypeBeltBuckle",
			"MayorCaneShaft", "MayorCaneHook"]:
		if skin.find_child(required_part, true, false) == null:
			_fail("pictured prototype part is missing: %s" % required_part)
			return
	for removed_part in ["FaceMask_L", "FaceMask_R", "IrisInner_L", "IrisInner_R",
			"EyeCatchlight_L", "EyeCatchlight_R", "MoustachePad_L", "MoustachePad_R",
			"BrowFrame_L", "BrowFrame_R", "ForeheadMark", "MouthSocket"]:
		if skin.find_child(removed_part, true, false) != null:
			_fail("legacy face layer still conflicts with the clean prototype: %s" \
				% removed_part)
			return

	var head := skin.find_child("Head", true, false) as MeshInstance3D
	var coat := skin.find_child("CoatBody", true, false) as MeshInstance3D
	if head.get_aabb().size.x <= coat.get_aabb().size.x:
		_fail("Milo lost the prototype's head-dominant chubby silhouette")
		return
	for pupil_name in ["Pupil_L", "Pupil_R"]:
		var pupil := skin.find_child(pupil_name, true, false) as MeshInstance3D
		var pupil_size := pupil.get_aabb().size
		if pupil_size.y < pupil_size.x * 1.30:
			_fail("%s is no longer a vertical black prototype eye" % pupil_name)
			return

	var material_names := {}
	for mesh_value in meshes:
		var mesh_instance := mesh_value as MeshInstance3D
		for surface_index in mesh_instance.mesh.get_surface_count():
			var value := mesh_instance.mesh.surface_get_material(surface_index)
			if value != null:
				material_names[value.resource_name] = true
	for required_material in ["Prototype Warm Ivory Fur", "Prototype Soft Black Eye",
			"Prototype Moustache Ivory", "Prototype Dark Teal Coat",
			"Prototype Burgundy Waistcoat", "Prototype Luxury Gold",
			"Prototype Belt Leather"]:
		if not material_names.has(required_material):
			_fail("prototype material is missing: %s" % required_material)
			return

	var skeleton := skin.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or skeleton.get_bone_count() != 41:
		_fail("the shared 41-bone Milo rig contract was not preserved")
		return
	var animation_player := skin.find_child("AnimationPlayer", true, false) \
		as AnimationPlayer
	if animation_player == null or not animation_player.has_animation("Milo_Walking") \
			or not animation_player.has_animation("Cane_Walk") \
			or not animation_player.has_animation("Idle_3"):
		_fail("the prototype did not preserve Milo's walk/cane/idle animation library")
		return

	var scholar_source := FileAccess.get_file_as_string(
		"res://scenes/characters/milo_2_scholar.tscn")
	if not scholar_source.contains("milo_prototype_reference_skin.tscn"):
		_fail("the separate Milo 2 wrapper is not using the pictured prototype scene")
		return

	skin.queue_free()
	await process_frame
	print("MILO_PROTOTYPE_REFERENCE_TEST: PASS — pictured visual variant, clean face, luxury suit, separate fallback, 41-bone rig and animation library")
	quit()
