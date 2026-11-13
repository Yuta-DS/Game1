extends SceneTree

# World One entrance (Mind Spark district) and its West lookout: compact gate
# arch, bounce pads instead of pillows, solid coloured trees, a solid mini
# observatory, and railed bridges the real player capsule can walk across.

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
	if district.get_node_or_null("MINDSPARKPortalFrame") != null:
		_fail("the old 76 m portal frame is still there")
		return
	var arch := district.get_node_or_null("WorldOneGateArch") as Node3D
	if arch == null or arch.get_node("Lintel").position.y > 20.0:
		_fail("the compact gate arch is missing or too tall")
		return
	if not district.find_children("FlowerGarden*", "", true, false).is_empty() \
			or not world.get_node("MindBridge").find_children("FlowerGarden*", "", true, false).is_empty():
		_fail("pillows are still floating in the district or on the Mind Bridge")
		return
	if district.find_children("BouncePad*", "Area3D", false, false).size() < 20:
		_fail("the district needs its bounce pads")
		return
	var mind_bridge := world.get_node("MindBridge") as Node3D
	if mind_bridge.get_node_or_null("ReferenceTreeProcessionalBridge") == null \
			or not mind_bridge.find_children("BouncePad*", "", true, false).is_empty() \
			or not (mind_bridge.get_node("TreeCourtDeck") as MeshInstance3D).material_override is ShaderMaterial:
		_fail("the Mind Bridge is not the gold-railed processional style with the tree court deck")
		return

	var trees := district.find_children("SkyCypress*", "Node3D", false, false)
	if trees.size() < 6:
		_fail("expected the red, blue and green trees, found %d" % trees.size())
		return
	for tree in trees:
		var hit := _hit_below(space, (tree as Node3D).global_position + Vector3.UP * 35.0)
		if hit == null or not (tree as Node).is_ancestor_of(hit):
			_fail("%s has no collision" % tree.name)
			return

	if lookout.get_node_or_null("CompassRing") != null:
		_fail("the gold ring is still on the lookout")
		return
	var tower := lookout.get_node("MiniObservatory/ObservatoryTower") as Node3D
	var dome_hit := _hit_below(space, tower.global_position + Vector3.UP * 40.0)
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

	print("WORLD_ONE_ENTRANCE_TEST: PASS (%d trees, %d district pads)"
		% [trees.size(), district.find_children("BouncePad*", "Area3D", false, false).size()])
	quit(0)
