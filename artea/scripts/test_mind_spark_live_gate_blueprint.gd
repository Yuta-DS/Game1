extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("MIND_SPARK_LIVE_GATE_BLUEPRINT: %s" % message)
	quit(1)


func _run() -> void:
	var gallery_scene := load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene
	if gallery_scene == null:
		_fail("gallery scene could not load")
		return
	var gallery := gallery_scene.instantiate()
	root.add_child(gallery)
	for _frame in 10:
		await process_frame
	await physics_frame
	var floating_world := gallery.get_node_or_null("ArtCastleFloatingWorld") as Node3D
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	if floating_world == null or player == null:
		_fail("live floating world or production player is missing")
		return
	var world := floating_world.get_node_or_null("MindSparkWorldOne") as MindSparkWorldOne
	var source := floating_world.get_node_or_null("MindSparkWorldGate") as MindSparkWorldGate
	if world == null or source == null:
		_fail("six-island World One or its Art Castle source gate is missing")
		return
	if not world.force_standalone_blueprint \
			or world.get_meta("foundation_mode") != "standalone_preview" \
			or world.position != Vector3(-2200, 0, 1640):
		_fail("live World One is not using the nearby collision-safe full blueprint")
		return
	var expected_arrival := world.position + world.get_player_arrival_local()
	if source.destination_world_local.distance_to(expected_arrival) > 0.01:
		_fail("source gate destination does not match the supported arrival marker")
		return
	if not source.use_target_world_arrival:
		_fail("source gate does not resolve the supported arrival after deferred loading")
		return
	var geometry := world.get_node("WorldOneGeometry") as Node3D
	if geometry.find_children("WalkableZoneFloorCollision", "StaticBody3D", true, false).size() != 6:
		_fail("live blueprint does not have six collision-backed island floors")
		return
	if geometry.get_node_or_null("MainStoryCircuitRoute") == null:
		_fail("required 01-to-06 story route is missing")
		return
	var station := geometry.get_node("OptionalCompletedWorldStationSpur") as Node3D
	if station.visible or bool(station.get_meta("blocks_story_route")):
		_fail("optional station is visible early or blocks the story route")
		return

	player.velocity = Vector3(12, 3, -7)
	if not source.teleport_player(player):
		_fail("source gate rejected the production player")
		return
	if player.global_position.distance_to(floating_world.to_global(expected_arrival)) > 0.05 \
			or not player.velocity.is_zero_approx():
		_fail("source gate did not land safely at Zone 01 and clear velocity")
		return
	var ray := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP * 8, player.global_position + Vector3.DOWN * 20)
	ray.collision_mask = 1
	if floating_world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		_fail("Zone 01 arrival has no physical floor")
		return

	var safe_return := floating_world.to_global(Vector3(-650, 7, 1575))
	var entry_return := geometry.get_node("01WorldGateLanding/EntryWorldGate") as MindSparkWorldGate
	var island_one_arch := geometry.get_node(
		"01WorldGateLanding/CelestialWorldGateArrival/GateArchitectureKit/03_ThresholdStructureKit/WorldGateCelestialArch") as Node3D
	if Vector2(island_one_arch.position.x, island_one_arch.position.z).distance_to(
			Vector2(entry_return.position.x, entry_return.position.z)) > 0.01 \
			or absf(wrapf(island_one_arch.rotation.y - entry_return.rotation.y,
				-PI, PI)) > 0.001:
		_fail("Island One return arch is not aligned with its working portal")
		return
	var island_three_arch := geometry.get_node(
		"06OldestTreeSanctuary/ReturnWorldGate") as Node3D
	if island_three_arch.get_meta("design_source", "") != \
			island_one_arch.get_meta("design_source", "") \
			or island_three_arch.find_children("IvoryCurvedVoussoir_*", "MeshInstance3D",
				false, false).size() != 18 \
			or island_three_arch.find_children("GiltCurvedReveal_*", "MeshInstance3D",
				false, false).size() != 18:
		_fail("Island 3 return portal does not reuse the Island 1 teleport arch")
		return
	if island_three_arch.find_children("*", "StaticBody3D",
			false, false).size() < 2:
		_fail("the shared return arch has no solid supporting piers")
		return
	if not entry_return.teleport_player(player) \
			or player.global_position.distance_to(safe_return) > 0.05:
		_fail("Zone 01 abort gate does not return to the safe forecourt landing")
		return
	if player.global_position.distance_to(source.global_position) <= 7.0:
		_fail("return landing remains inside the source gate trigger")
		return

	var final_return := geometry.get_node(
		"06OldestTreeSanctuary/ReturnToArtCastleWorldGate") as MindSparkWorldGate
	if absf(wrapf(final_return.rotation.y - island_three_arch.rotation.y, -PI, PI)) > 0.001 \
			or island_three_arch.position.distance_to(
				final_return.position - Vector3.UP) > 0.01:
		_fail("Island 3 arch does not frame its live teleport")
		return
	if not final_return.gate_enabled \
			or str(final_return.get_meta("destination_landmark", "")) != "Mind Spark Train Station" \
			or not bool(final_return.get_meta("always_available_return", false)):
		_fail("Island 3 does not provide an always-available Mind Spark station return")
		return
	player.velocity = Vector3(-4, 2, 8)
	if not final_return.teleport_player(player) \
			or player.global_position.distance_to(safe_return) > 0.05 \
			or not player.velocity.is_zero_approx():
		_fail("Island 3 station portal does not return safely")
		return
	world.set_return_gate_enabled(true)
	world.set_station_spur_available(true)
	if not station.visible:
		_fail("completion did not reveal the optional Zone 05 station spur")
		return
	print("MIND_SPARK_LIVE_GATE_BLUEPRINT: PASS — source, abort, Island 3 station return, floors, route, and station policy verified")
	gallery.queue_free()
	await process_frame
	await process_frame
	quit()
