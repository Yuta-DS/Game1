extends SceneTree

const PoppyScene := preload("res://scenes/characters/poppy_gardener.tscn")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("POPPY_CHARACTER_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var poppy := PoppyScene.instantiate() as CharacterBody3D
	root.add_child(poppy)
	await process_frame
	var skin := poppy.get_node_or_null("Model")
	if skin == null or not skin.has_method("is_rabbit_gardener_skin"):
		_fail("Poppy is not using the rabbit gardener villager skin")
		return
	var meshes := poppy.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() < 35:
		_fail("Poppy lost the part-by-part villager construction: %d meshes" % meshes.size())
		return
	for part in ["Head", "RabbitEarOuter_L", "RabbitEarInner_L", "GardenerApron",
			"ApronPocket", "Kerchief", "RabbitTail", "Boot_L"]:
		if poppy.find_child(part, true, false) == null:
			_fail("required Poppy part is missing: %s" % part)
			return
	var skeleton := poppy.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or skeleton.get_bone_count() < 35:
		_fail("Poppy's villager animation skeleton is missing")
		return
	var player := poppy.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		_fail("Poppy's AnimationPlayer is missing")
		return
	for clip in ["Idle", "Walk", "Run", "Wave_One_Hand"]:
		if not player.has_animation(clip):
			_fail("Poppy animation alias is missing: %s" % clip)
			return
	print("POPPY_CHARACTER_TEST: PASS — rabbit gardener villager mesh, rig, scene and animations")
	quit()
