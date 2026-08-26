extends SceneTree

const BeeGarden := preload("res://scripts/hub_bee_garden.gd")


func _init() -> void:
	var scene_text := FileAccess.get_file_as_string("res://scenes/New_Hub_World.tscn")
	if not "amount = 260" in scene_text or not "tree_scatter_path" in scene_text:
		_fail("hub trees or tree-mounted bee homes are not configured")
		return

	var garden := BeeGarden.new()
	garden.call("_build_shared_materials")
	garden.call("_build_batched_bees")
	if garden.bee_count != garden.ORIGINAL_BEE_COUNT * garden.POPULATION_MULTIPLIER:
		_fail("bee population is not exactly 18 times the original swarm")
		return
	var batched := garden.get_node_or_null("BatchedBees") as MultiMeshInstance3D
	if batched == null or batched.multimesh.instance_count != 252:
		_fail("252 bees must share one Web-safe MultiMesh")
		return

	var flower_points: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(4, 0, 0),
		Vector3(8, 0, 3),
	]
	garden.set("_flower_points", flower_points)
	garden.call("_seed_flight_paths")
	var bees: Array = garden.get("_bees")
	var size_classes := {}
	for bee_data in bees:
		size_classes[bee_data["size_class"]] = true
		if bee_data["source"] == bee_data["target"]:
			_fail("a bee must have a different destination flower")
			return
	if size_classes.size() != 3 or garden.BASE_SCALE != 0.45:
		_fail("small, medium, and large bee classes must remain distinct")
		return
	for size_variant in garden.SIZE_VARIANTS:
		var final_scale: float = garden.BASE_SCALE * float(size_variant)
		if final_scale < 0.40 or final_scale > 0.50:
			_fail("every bee size must be 50 to 60 percent smaller")
			return

	var before_progress: float = bees[0]["progress"]
	garden.call("_process", 0.5)
	var moved_bees: Array = garden.get("_bees")
	if float(moved_bees[0]["progress"]) <= before_progress:
		_fail("batched bee did not travel toward another flower")
		return

	var tree_points: Array[Vector3] = [Vector3.ZERO, Vector3(3, 0, 0)]
	garden.call("_place_bee_homes", tree_points)
	var homes := garden.get_node_or_null("BeeHomes")
	if homes == null or homes.get_child_count() != 2 \
			or not homes.get_child(0).is_in_group("hub_bee_homes"):
		_fail("bee homes were not mounted at available tree positions")
		return

	print("HUB_BEE_GARDEN_TEST: PASS — 252 batched bees, three 50–60 percent smaller sizes, flower travel, and tree homes")
	quit(0)


func _fail(message: String) -> void:
	push_error("HUB_BEE_GARDEN_TEST: FAIL — %s" % message)
	quit(1)
