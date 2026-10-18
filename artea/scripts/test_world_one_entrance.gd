extends SceneTree

# World One entrance (Mind Spark district) and its West lookout: the finished
# ceremonial gate court and a railed bridge the player can walk across.

const WALK_SPEED := 10.0


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("WORLD_ONE_ENTRANCE_TEST: %s" % message)
	quit(1)


func _settle(player: CharacterBody3D, position: Vector3) -> void:
	player.global_position = position
	player.velocity = Vector3.ZERO
	for _frame in 120:
		player.velocity.y -= 28.0 / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			return


func _walk(player: CharacterBody3D, target: Vector3, frames: int) -> void:
	for _frame in frames:
		var delta := target - player.global_position
		delta.y = 0.0
		if delta.length() < 0.5:
			return
		var was_on_floor := player.is_on_floor()
		var before := player.global_position
		player.velocity.x = delta.normalized().x * WALK_SPEED
		player.velocity.z = delta.normalized().z * WALK_SPEED
		player.velocity.y -= 28.0 / 60.0
		var intended := player.velocity
		player.move_and_slide()
		if player.has_method("_try_step_up"):
			player.call("_try_step_up", was_on_floor, before, intended, 1.0 / 60.0)
		await physics_frame


## The node a downward ray from `top` lands on, or null.
func _hit_below(space: PhysicsDirectSpaceState3D, top: Vector3) -> Node:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 40.0))
	return hit.collider as Node if not hit.is_empty() else null


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 6:
		await physics_frame
	var world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var player := gallery.get_node("Player3D") as CharacterBody3D
	var district := world.get_node("MindSparkDistrict") as Node3D
	var lookout := world.get_node("WestObservatory") as Node3D
	var space := world.get_world_3d().direct_space_state
	player.set_physics_process(false)

	if not district.find_children("RuinWall*", "", true, false).is_empty() \
			or not district.find_children("OpenArch*", "", true, false).is_empty():
		_fail("the wall with the pink rings is still there")
		return
	var forecourt := district.get_node_or_null("MindSparkCeremonialForecourt") as Node3D
	var cradle := district.get_node_or_null(
		"MindSparkCeremonialForecourt/CelestialGatehouse/WorldGatePortalCradle") as Node3D
	if forecourt == null or cradle == null \
			or not bool(cradle.get_meta("opening_collision_free", false)):
		_fail("the finished Mind gate court or clear portal opening is missing")
		return
	var mind_bridge := world.get_node("MindBridge") as Node3D
	if str(mind_bridge.get_meta("visual_style", "")) != "mind_spark_ivory_processional_bridge_v3" \
			or mind_bridge.find_children("MindBridgeCyanRail*", "MeshInstance3D", false, false).size() != 4:
		_fail("the Mind Bridge is missing its finished ivory deck and cyan rails")
		return

	if lookout.get_node_or_null("CompassRing") != null:
		_fail("the gold ring is still on the lookout")
		return
	var tower := lookout.get_node("ObservatoryTower") as Node3D
	var dome_hit := _hit_below(space, tower.global_position + Vector3.UP * 20.0)
	if dome_hit == null or dome_hit.name != "DomeCollision":
		_fail("the observatory dome has no collision")
		return
	if not (lookout.get_node("WalkableDeck") as MeshInstance3D).material_override is ShaderMaterial:
		_fail("the lookout floor has no texture")
		return

	# Walk from the district over the railed bridge onto the lookout island.
	var bridge := world.get_node("WestObservatoryBridge") as Node3D
	if bridge.get_node_or_null("GuardGlassLeft") == null:
		_fail("the lookout bridge has no railing")
		return
	var start: Vector3 = bridge.get_meta("connection_start")
	var finish: Vector3 = bridge.get_meta("connection_finish")
	var along := (finish - start).normalized()
	await _settle(player, world.to_global(start - along * 20.0 + Vector3.UP * 3.0))
	var goal := world.to_global(finish + along * 12.0)
	await _walk(player, goal, 2000)
	var gap := Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length()
	if gap > 1.0 or player.global_position.y < world.to_global(finish).y - 0.5:
		_fail("could not walk across the lookout bridge: stopped %.1f m short at %s"
			% [gap, world.to_local(player.global_position)])
		return

	print("WORLD_ONE_ENTRANCE_TEST: PASS (finished gate court and walkable West lookout)")
	quit(0)
