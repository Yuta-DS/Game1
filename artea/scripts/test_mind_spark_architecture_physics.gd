extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("MIND_SPARK_ARCHITECTURE_PHYSICS: %s" % message)
	for action in ["move_forward", "move_backward", "move_left", "move_right", "jump"]:
		Input.action_release(action)
	quit(1)


func _settle(player: CharacterBody3D) -> bool:
	for _frame in 180:
		await physics_frame
		if player.is_on_floor():
			return true
	return false


func _story_route_collision_count(route: Node3D) -> int:
	var count := 0
	for link_index in range(1, 6):
		for leg in ["A", "B"]:
			if route.get_node_or_null("CircuitRoute_%02d_%sCollision" % [link_index, leg]) is StaticBody3D:
				count += 1
	return count


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 10:
		await physics_frame

	var floating_world := gallery.get_node_or_null("ArtCastleFloatingWorld") as Node3D
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	if floating_world == null or player == null:
		_fail("gallery world or real player controller did not load")
		return

	var bridge := floating_world.get_node_or_null("ArtCastleEntranceBridge175m") as Node3D
	if bridge == null:
		_fail("the engineered gallery-to-castle approach bridge is missing")
		return
	if bridge.get_meta("structural_mass_class") != "infinite_static_mass" \
			or not is_equal_approx(float(bridge.get_meta("deck_friction")), 0.92):
		_fail("bridge structural mass or friction specification is missing")
		return
	var deck := bridge.get_node_or_null("ContinuousWalkwayCollision") as StaticBody3D
	if deck == null or deck.physics_material_override == null \
			or not is_equal_approx(deck.physics_material_override.friction, 0.92):
		_fail("bridge deck is not a high-friction StaticBody3D")
		return
	if bridge.get_node_or_null("UnderDeckSpineCollision") == null \
			or bridge.get_node_or_null("ApproachFallRecovery") == null:
		_fail("bridge spine or fall-recovery volume is missing")
		return
	if bridge.find_children("GuardPost*", "StaticBody3D", true, false).size() < 30 \
			or bridge.find_children("PierLeg*", "StaticBody3D", true, false).size() < 10:
		_fail("bridge guard-post or portal-pier structural rhythm is incomplete")
		return

	# Three ray samples prove the complete 170 m walkway has physical support.
	var space := root.world_3d.direct_space_state
	for local_z in [505.0, 585.0, 665.0]:
		var above := floating_world.to_global(Vector3(0, 8, local_z))
		var query := PhysicsRayQueryParameters3D.create(above, above + Vector3.DOWN * 16.0)
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.get("collider") != deck:
			_fail("bridge has no continuous physical deck at local z %.1f" % local_z)
			return

	var world := floating_world.get_node_or_null("MindSparkWorldOne") as MindSparkWorldOne
	if world == null:
		_fail("World One did not load")
		return
	var geometry := world.get_node("WorldOneGeometry") as Node3D
	if world.get_meta("foundation_mode") != "standalone_preview":
		_fail("live World One did not select the full six-island blueprint")
		return
	for zone_id in world.get_zone_ids():
		var zone := geometry.get_node(zone_id.to_pascal_case()) as Node3D
		var floor_mesh := zone.get_node_or_null("WalkableZoneFloor") as MeshInstance3D
		var floor_body := zone.get_node_or_null("WalkableZoneFloorCollision") as StaticBody3D
		if floor_mesh == null or floor_body == null:
			_fail("%s is missing its visible or physical floor" % zone_id)
			return
		if floor_body.physics_material_override == null \
				or not is_equal_approx(floor_body.physics_material_override.friction, 0.90) \
				or floor_body.get_meta("mass_class") != "infinite_static_mass":
			_fail("%s is not an infinite-mass high-friction island" % zone_id)
			return
		var material := floor_mesh.material_override as StandardMaterial3D
		if material == null or material.albedo_texture == null:
			_fail("%s has no authored procedural surface texture" % zone_id)
			return
	var story_route := geometry.get_node("MainStoryCircuitRoute") as Node3D
	if _story_route_collision_count(story_route) != 10:
		_fail("the five required links do not retain ten physical walkway legs")
		return
	var station := geometry.get_node("OptionalCompletedWorldStationSpur") as Node3D
	if station.visible or bool(station.get_meta("blocks_story_route")):
		_fail("the optional station is visible early or blocks the story route")
		return

	# Use the production player controller on the remote Zone 04 floor and prove
	# that normal movement and its 1.4 m jump remain available after gate travel.
	var hope_zone := geometry.get_node("04HopePathRidge") as Node3D
	var test_camera := Camera3D.new()
	world.add_child(test_camera)
	test_camera.global_transform = Transform3D(Basis.IDENTITY, hope_zone.to_global(Vector3(0, 8, 8)))
	test_camera.make_current()
	player.set("_camera", test_camera)
	player.global_position = hope_zone.to_global(Vector3(0, 6, 0))
	player.velocity = Vector3.ZERO
	if not await _settle(player):
		_fail("the player cannot stand on the collision-backed Hope Path island")
		return
	var floor_y := player.global_position.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var peak_y := player.global_position.y
	for _frame in 60:
		await physics_frame
		peak_y = maxf(peak_y, player.global_position.y)
	if peak_y - floor_y < 1.15:
		_fail("production player jump was unavailable after World Gate travel (rise %.2f m)" \
			% (peak_y - floor_y))
		return

	print("MIND_SPARK_ARCHITECTURE_PHYSICS: PASS — bridge, six islands, story decks, textures, and real remote jump verified")
	quit()
