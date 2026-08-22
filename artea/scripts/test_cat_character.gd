extends SceneTree

const CatScene := preload("res://scenes/characters/cat_gardener.tscn")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("CAT_CHARACTER_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var cat := CatScene.instantiate() as CharacterBody3D
	root.add_child(cat)
	await process_frame
	var skin := cat.get_node_or_null("Model")
	if skin == null or not skin.has_method("is_cat_gardener_skin"):
		_fail("Cat is not using the cat gardener villager skin")
		return
	var meshes := cat.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() < 35:
		_fail("Cat lost the part-by-part villager construction: %d meshes" % meshes.size())
		return
	for part in ["Head", "CatEarOuter_L", "CatEarInner_L", "GardenerApron",
			"ApronPocket", "Kerchief", "CatTail", "Boot_L"]:
		if cat.find_child(part, true, false) == null:
			_fail("required Cat part is missing: %s" % part)
			return
	var skeleton := cat.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or skeleton.get_bone_count() < 35:
		_fail("Cat's villager animation skeleton is missing")
		return
	var player := cat.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		_fail("Cat's AnimationPlayer is missing")
		return
	for clip in ["Idle", "Walk", "Run", "Wave_One_Hand"]:
		if not player.has_animation(clip):
			_fail("Cat animation alias is missing: %s" % clip)
			return
	print("CAT_CHARACTER_TEST: PASS — cat gardener villager mesh, rig, scene and animations")
	quit()
