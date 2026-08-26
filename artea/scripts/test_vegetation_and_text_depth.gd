extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("VEGETATION_TEXT_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var hub_scene := load("res://scenes/New_Hub_World.tscn") as PackedScene
	if hub_scene == null:
		_fail("hub scene must load")
		return
	var hub := hub_scene.instantiate()
	var grass := hub.get_node_or_null("Environment/Grass")
	var trees := hub.get_node_or_null("Environment/Objects")
	if grass == null or trees == null:
		_fail("hub must retain authored grass and tree scatter roots")
		return
	var bush_item = grass.get_node_or_null("ScatterItemBush")
	if bush_item == null or int(bush_item.proportion) != 0:
		_fail("the grass distribution must not hide thousands of full tree scenes")
		return
	var grass_shape_node := grass.get_node_or_null("ScatterShape") as Node3D
	if grass_shape_node == null or grass_shape_node.get("shape") == null:
		_fail("grass must retain a complete authored coverage shape")
		return
	var grass_shape = grass_shape_node.get("shape")
	var grass_shape_transform := (grass as Node3D).transform * grass_shape_node.transform
	var grass_height := grass_shape_transform.origin.y
	var coverage_points := {
		"west grove": Vector3(-120.0, grass_height, -100.0),
		"Mind Spark": Vector3(110.0, grass_height, -80.0),
		"Creator's Light": Vector3(40.0, grass_height, 65.0),
		"Heart Melody": Vector3(90.0, grass_height, 75.0),
		"central lawn": Vector3(0.0, grass_height, 0.0),
		"north shoreline": Vector3(0.0, grass_height, -175.0),
		"south landscape": Vector3(0.0, grass_height, 140.0),
		"east landscape": Vector3(165.0, grass_height, 20.0),
		"west landscape": Vector3(-180.0, grass_height, 0.0),
	}
	for area_name in coverage_points:
		if not grass_shape.is_point_inside(
				coverage_points[area_name], grass_shape_transform):
			_fail("grass coverage does not reach the %s ground" % area_name)
			return
	var grass_stack = grass.get("modifier_stack")
	if grass_stack == null or grass_stack.stack.is_empty() \
			or int(grass_stack.stack[0].amount) < 24000:
		_fail("desktop grass density is below the performance-tested island coverage")
		return
	for modifier in grass_stack.stack:
		var modifier_script = modifier.get_script() if modifier != null else null
		if modifier_script != null and modifier_script.resource_path.ends_with("relax.gd") \
				and int(modifier.iterations) != 0:
			_fail("dense grass must not run the quadratic relax pass during hub load")
			return
	for item in trees.get_children():
		if not ("path" in item and "source_scale_multiplier" in item):
			continue
		if String(item.path).contains("/tree_") and float(item.source_scale_multiplier) > 1.4:
			_fail("tree scatter item %s is oversized enough to engulf the camera" % item.name)
			return
	var tree_stack = trees.get("modifier_stack")
	if tree_stack == null:
		_fail("trees must retain terrain placement modifiers")
		return
	for modifier in tree_stack.stack:
		var modifier_script = modifier.get_script() if modifier != null else null
		if modifier_script != null and modifier_script.resource_path.ends_with("randomize_transforms.gd"):
			if not is_zero_approx(modifier.rotation.x) or not is_zero_approx(modifier.rotation.z):
				_fail("tree randomization may rotate around Y, but trunks must stay upright")
				return
	for item_name in ["ScatterItemGrassA", "ScatterItemGrassB"]:
		var item = grass.get_node_or_null(item_name)
		if item == null or item.override_material is not ShaderMaterial:
			_fail("%s must use the wind-and-player-interaction grass shader" % item_name)
			return
		var blade_scale := float(item.source_scale_multiplier)
		if blade_scale < 0.25 or blade_scale > 0.4:
			_fail("%s must remain short without disappearing into the ground" % item_name)
			return
		if not String(item.path).ends_with("grass_clump_3d.tscn"):
			_fail("%s must scatter real low-poly 3D blade clumps" % item_name)
			return
	var rainbow_names := ["Red", "Orange", "Yellow", "Green", "Blue", "Indigo", "Violet"]
	var flower_proportion := 0
	var petal_colors: Dictionary = {}
	for color_name in rainbow_names:
		var flower_item = grass.get_node_or_null("ScatterItemFlower%s" % color_name)
		var expected_path := "res://scenes/vegetation/wildflower_%s_3d.tscn" % \
			String(color_name).to_lower()
		if flower_item == null or String(flower_item.path) != expected_path:
			_fail("the lawn must scatter the %s 3D rainbow flower" % color_name)
			return
		flower_proportion += int(flower_item.proportion)
		var color_scene := load(expected_path) as PackedScene
		if color_scene == null:
			_fail("the %s flower scene must load" % color_name)
			return
		var color_flower := color_scene.instantiate()
		var north_petal := color_flower.get_node_or_null("PetalNorth") as MeshInstance3D
		if north_petal == null or north_petal.material_override == null:
			_fail("the %s flower must have modeled colored petals" % color_name)
			return
		petal_colors[north_petal.material_override.albedo_color] = true
		color_flower.free()
	if flower_proportion < 84 or petal_colors.size() != 7:
		_fail("the lawn must contain all seven distinct rainbow flower colors")
		return
	var grass_model := load("res://scenes/vegetation/grass_clump_3d.tscn") as PackedScene
	var flower_model := load("res://scenes/vegetation/wildflower_3d.tscn") as PackedScene
	if grass_model == null or flower_model == null:
		_fail("3D vegetation source scenes must load")
		return
	var grass_geometry := grass_model.instantiate()
	var flower_geometry := flower_model.instantiate()
	if grass_geometry.find_children("*", "MeshInstance3D", true, false).size() < 7:
		_fail("grass clumps must contain multiple solid blade meshes")
		return
	if flower_geometry.find_children("*", "MeshInstance3D", true, false).size() < 9:
		_fail("wildflowers must contain modeled stems, leaves, petals, and centres")
		return
	grass_geometry.free()
	flower_geometry.free()
	if hub.get_node_or_null("GrassInteraction") == null:
		_fail("hub needs a live player-to-grass flattening controller")
		return
	hub.free()

	for scene_path in [
		"res://scenes/narrative_package.tscn",
		"res://scenes/characters/milo_guide.tscn",
		"res://scenes/characters/town_villager.tscn",
		"res://scenes/characters/elder_cat_mayor.tscn",
		"res://scenes/mind_spark/world_gate.tscn",
		"res://scenes/mind_spark/mind_spark_perspective.tscn",
	]:
		var packed := load(scene_path) as PackedScene
		if packed == null:
			_fail("text-bearing scene failed to load: %s" % scene_path)
			return
		var instance := packed.instantiate()
		var labels: Array[Node] = []
		if instance is Label3D:
			labels.append(instance)
		labels.append_array(instance.find_children("*", "Label3D", true, false))
		for label in labels:
			if (label as Label3D).no_depth_test:
				_fail("%s still draws through walls in %s" % [label.name, scene_path])
				return
		instance.free()

	print("VEGETATION_TEXT_TEST: PASS — correctly scaled trees, interactive grass, and depth-tested world labels")
	quit()
