# Self-check that the Lens of Seeing is wired into the real hub world.
#   godot --headless --path artea --script res://scripts/test_hub_lens.gd
#
# Loads New_Hub_World.tscn itself, because the thing being tested is exactly
# the part a standalone harness cannot cover: does the lens find the real
# player, and does it tag real props without touching the systems that must
# never be cut.
extends SceneTree

const HUB := "res://scenes/New_Hub_World.tscn"
const FrustumCutterScript := preload("res://scripts/viewfinder/frustum_cutter.gd")

var _hub: Node3D


func _initialize() -> void:
	# The lens is gated on the journey having started (UNLOCK_STAGE), so force
	# the stage up before the hub builds.
	#
	# Set here rather than relying on whatever the developer's own journey.json
	# happens to contain: with a freshly cleared journey the stage is 0 and the
	# lens would correctly not appear, making this suite fail for a reason that
	# has nothing to do with the wiring it exists to check. The autoload has
	# already run load_journey() by now, so this write is not overwritten.
	var js := root.get_node_or_null("JourneyState")
	assert(js != null, "JourneyState autoload is present")
	js.stage = maxi(int(js.stage), 1)

	var packed := load(HUB) as PackedScene
	assert(packed != null, "the hub scene loads")
	_hub = packed.instantiate()
	root.add_child(_hub)

	# The hub systems each await a frame in _ready() before building, and
	# hub_lens attaches the controller after its own await. Two frames was
	# enough most runs and not all of them — a flaky suite is worse than a
	# slow one, so wait until the controller actually exists.
	for i in 30:
		await process_frame
		if _hub.find_child("LensController", true, false) != null:
			break
	await physics_frame

	_test_lens_is_present()
	_test_attached_to_the_player_camera()
	_test_tagging_is_opt_in()
	_test_village_buildings_are_cuttable()
	_test_the_castle_is_never_cuttable()
	_test_uncuttable_systems_are_untouched()

	print("hub lens: all checks passed")
	quit()


func _test_lens_is_present() -> void:
	var hub_lens := _hub.get_node_or_null("HubLens")
	assert(hub_lens != null,
		"the hub scene carries a HubLens node, so the mechanic is reachable "
		+ "in the real game rather than only in the demo room")


func _test_attached_to_the_player_camera() -> void:
	var controller := _hub.find_child("LensController", true, false)
	assert(controller != null, "the lens controller was attached to the player")

	# Parented to the camera, not the player body: a held seeing has to follow
	# where the player LOOKS, not just where they stand.
	var parent := controller.get_parent()
	assert(parent is Camera3D,
		"the controller hangs off the player's camera, got %s" % parent.get_class())

	assert(controller.camera == parent, "the controller uses that same camera")

	var lens := controller.find_child("ViewfinderLens", false, false)
	assert(lens != null, "the lens itself exists in the hub")
	assert(lens.capture_point == controller,
		"the controller is the capture point, so placement stays exact")


func _test_tagging_is_opt_in() -> void:
	var hub_lens := _hub.get_node_or_null("HubLens")
	assert(hub_lens.tagged_count() > 0,
		"tagging found real props — a silent match of nothing would leave the "
		+ "mechanic with nothing to cut and still look wired up")

	# Everything tagged must actually be cuttable geometry.
	for path in hub_lens.CUTTABLE_ROOTS:
		var branch := _hub.get_node_or_null(path)
		if branch == null:
			continue
		for child in branch.get_children():
			var body = hub_lens._find_body(child)
			if body == null:
				continue
			if body.collision_layer & FrustumCutterScript.CUTTABLE_MASK == 0:
				continue
			var mesh_instance = FrustumCutterScript._find_mesh_instance(child)
			assert(mesh_instance != null and mesh_instance.mesh != null,
				"a tagged prop has real mesh geometry to cut")
			# Tagging must ADD the layer, not replace it: these rocks are world
			# collision the player already walks into.
			assert(body.collision_layer != FrustumCutterScript.CUTTABLE_MASK,
				"tagging preserves the prop's original collision layer, so the "
				+ "player does not fall through the mountains")


func _test_village_buildings_are_cuttable() -> void:
	var hub_lens := _hub.get_node_or_null("HubLens")
	var mask := FrustumCutterScript.CUTTABLE_MASK

	# The buildings are where the player actually spends time. Tagging only the
	# distant mountains left the lens with nothing to frame anywhere they walk.
	var tagged_buildings := 0
	for child in _hub.get_children():
		if not String(child.name).begins_with("building_"):
			continue
		var body = hub_lens._find_body(child)
		if body != null and body.collision_layer & mask != 0:
			tagged_buildings += 1

	assert(tagged_buildings >= 8,
		"the village buildings are cuttable, got %d" % tagged_buildings)


func _test_the_castle_is_never_cuttable() -> void:
	# The hub castle anchors the entire Castle Universe: the citadel, the crown,
	# the entrance, the Gallery door trigger and the skyrail station all attach
	# to it or measure from it. Cutting it would take the finale down.
	var castle := _hub.get_node_or_null("building_castle_red2")
	assert(castle != null, "the hub castle is present")

	var hub_lens := _hub.get_node_or_null("HubLens")
	var body = hub_lens._find_body(castle)
	assert(body != null, "the castle has a body")
	assert(body.collision_layer & FrustumCutterScript.CUTTABLE_MASK == 0,
		"the castle is never cuttable — the Crown of Life finale hangs off it")

	# And the exclusion is deliberate, not an accident of its poly count.
	assert("building_castle_red2" in hub_lens.NEVER_CUTTABLE,
		"the castle is excluded by name, not merely by being over budget")


func _test_uncuttable_systems_are_untouched() -> void:
	# Terrain3D is a streamed clipmap and ProtonScatter output is MultiMesh —
	# neither has a per-instance mesh to cut, and slicing them fights the
	# addons (ViewFinder.txt 6.8). Neither may ever carry the Cuttable layer.
	var mask := FrustumCutterScript.CUTTABLE_MASK
	var offenders: Array[String] = []
	_collect_offenders(_hub, mask, offenders)
	assert(offenders.is_empty(),
		"terrain and scattered/multimesh geometry are never cuttable, found: %s"
		% ", ".join(offenders))


func _collect_offenders(node: Node, mask: int, offenders: Array[String]) -> void:
	var class_name_str := node.get_class()
	var is_forbidden := class_name_str.begins_with("Terrain3D") \
		or node is MultiMeshInstance3D \
		or String(node.name).begins_with("ProtonScatter")

	if is_forbidden:
		var body = _nearest_body(node)
		if body != null and body.collision_layer & mask != 0:
			offenders.append(String(node.name))

	for child in node.get_children():
		_collect_offenders(child, mask, offenders)


static func _nearest_body(node: Node) -> CollisionObject3D:
	var current := node
	while current != null:
		if current is CollisionObject3D:
			return current
		current = current.get_parent()
	return null
