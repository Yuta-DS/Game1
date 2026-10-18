extends SceneTree

# Tree of Imagination court: quieter music, no purple ring, flower beds are
# bounce pads, no slate plinth or black cat, a solid trunk/floor, and a spiral stair up
# the hollow trunk the real player capsule can climb.

const HUB := Vector3(0.0, 0.0, 1640.0)
const WALK_SPEED := 10.0


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("TREE_COURT_FEEDBACK_TEST: %s" % message)
	quit(1)


func _settle(player: CharacterBody3D, position: Vector3) -> bool:
	player.global_position = position
	player.velocity = Vector3.ZERO
	for _frame in 240:
		player.velocity.y -= 28.0 / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			return true
	return false


## Walks toward `target` (a Callable giving the next horizontal goal) for up to
## `frames`, the way test_tree_of_life_asset.gd drives the real capsule.
func _walk(player: CharacterBody3D, target: Callable, frames: int) -> void:
	for _frame in frames:
		var delta: Vector3 = target.call() - player.global_position
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


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 6:
		await physics_frame
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	var world := gallery.get_node_or_null("ArtCastleFloatingWorld") as Node3D
	var island := world.get_node_or_null("CentralSanctuary") as Node3D if world else null
	if player == null or island == null:
		_fail("gallery player or tree island did not load")
		return
	player.set_physics_process(false)
	var tree := island.get_node("TreeOfImagination") as Node3D
	var at := func(local: Vector3) -> Vector3: return island.to_global(HUB + local)

	if island.get_node_or_null("OuterGardenRing") != null:
		_fail("purple outer ring is still there")
		return
	if not island.find_children("OpenArch", "Node3D", true, false).is_empty():
		_fail("gray rectangular arches with pink rings still surround the Tree of Life")
		return
	if island.find_children("BouncePad*", "Area3D", false, false).size() != 72:
		_fail("expected the 72 court flower beds to be bounce pads")
		return
	if not island.find_children("FlowerGarden*", "MeshInstance3D", false, false).is_empty():
		_fail("flower-bed blobs still stand beside the pads")
		return
	for plinth_name in ["FoundationArchitecture", "Foundation_001"]:
		var plinth := tree.find_child(plinth_name, true, false) as Node3D
		if plinth == null or plinth.is_visible_in_tree():
			_fail("dark %s around the roots is still drawn" % plinth_name)
			return
	if island.get_node_or_null("InnerGardenRing") != null:
		_fail("cyan ring is still there")
		return
	var rod := world.find_child("PortalGold", true, false) as Node3D
	if rod == null or rod.is_visible_in_tree():
		_fail("gold rod still stands at the end of the bridge")
		return
	var manifold := tree.find_child("RootManifold", true, false) as MeshInstance3D
	var manifold_top := (manifold.global_transform * manifold.get_aabb()).end.y
	if manifold_top > at.call(Vector3(0, 0.8 + 0.1, 0)).y:
		_fail("cyan ring at the stair foot still stands proud of the floor")
		return
	if not (island.get_node("WalkableDeck") as MeshInstance3D).material_override is ShaderMaterial:
		_fail("island floor has no texture")
		return

	var melody := tree.get_node("ChristmasTreeMelody3D") as AudioStreamPlayer3D
	player.global_position = melody.global_position
	world.call("_update_tree_christmas_ambience", 40.0)
	if melody.volume_db > -15.0:
		_fail("tree music still too loud up close: %.1f dB" % melody.volume_db)
		return

	# Floor: the court, the hollow and the outer garden all hold the player.
	for spot in [Vector3(0, 0, 20), Vector3(-25, 0, 0), Vector3(90, 0, 0), Vector3(0, 0, -100),
			Vector3(-180, 0, 30)]:
		if not await _settle(player, at.call(spot + Vector3(0, 6, 0))) \
				or player.global_position.y < at.call(spot).y - 0.5:
			_fail("no floor under %s (player at %s)" % [spot, player.global_position])
			return

	# Trunk: walking at the back and the side of the tree stops at the bark.
	for start in [Vector3(0, 0, 95), Vector3(95, 0, 0), Vector3(-70, 0, -70)]:
		await _settle(player, at.call(start + Vector3(0, 3, 0)))
		await _walk(player, func() -> Vector3: return at.call(Vector3.ZERO), 600)
		var reached := island.to_local(player.global_position) - HUB
		if Vector2(reached.x, reached.z).length() < 30.0:
			_fail("walked from %s through the trunk to %s" % [start, reached])
			return

	# The court's edge is a ramp: walk up it from the deck, between two pads.
	var gap_angle := TAU * 0.5 / 72.0
	var outward := Vector3(cos(gap_angle), 0, sin(gap_angle))
	await _settle(player, at.call(outward * 112.5 + Vector3(0, 2, 0)))
	await _walk(player, func() -> Vector3: return at.call(outward * 100.0), 300)
	var on_court := island.to_local(player.global_position) - HUB
	if Vector2(on_court.x, on_court.z).length() > 101.0:
		_fail("court edge is still a wall: stopped at %s" % on_court)
		return

	# Roots on the floor are solid: a ray dropped onto each flare's highest
	# face lands on the trunk collision.
	var space := tree.get_world_3d().direct_space_state
	for flare in tree.find_children("ReferenceRootFlare_*", "MeshInstance3D", true, false):
		var root_mesh := flare as MeshInstance3D
		var root_faces := root_mesh.mesh.get_faces()
		var top := Vector3(0, -INF, 0)
		for index in range(0, root_faces.size(), 3):
			var centre := root_mesh.global_transform * ((root_faces[index] + root_faces[index + 1]
				+ root_faces[index + 2]) / 3.0)
			if centre.y > top.y:
				top = centre
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			top + Vector3.UP * 5.0, top + Vector3.DOWN * 2.0))
		if hit.is_empty() or (hit.collider as Node).name != "TrunkCollision":
			_fail("%s has no collision" % root_mesh.name)
			return

	# The former statue and its collider must leave the approach open.
	if island.get_node_or_null("BlackCatGuide") != null \
			or island.find_child("CatCollision", true, false) != null:
		_fail("black cat or its collision still stands beside the Tree of Life")
		return

	# In through the doorway to the foot of the stair, then round and up.
	await _settle(player, at.call(Vector3(0, 3, -98)))
	await _walk(player, func() -> Vector3: return at.call(Vector3(0, 0, -20)), 900)
	var inside := island.to_local(player.global_position) - HUB
	if Vector2(inside.x, inside.z).length() > 22.0:
		_fail("doorway blocked: stopped at %s" % inside)
		return
	await _walk(player, func() -> Vector3: return at.call(Vector3(0, 0, -11)), 120)
	var floor_y := player.global_position.y
	var climb := func() -> Vector3:
		var local: Vector3 = island.to_local(player.global_position) - HUB
		var angle := atan2(local.z, local.x) + 0.35
		return at.call(Vector3(cos(angle) * 11.0, 0.0, sin(angle) * 11.0))
	var climbed := 0.0
	for _chunk in 40:
		await _walk(player, climb, 40)
		climbed = player.global_position.y - floor_y
		if climbed > 33.0:
			break
	if climbed < 33.0:
		_fail("spiral stair stopped the player %.1f m up at %s" % [climbed,
			island.to_local(player.global_position) - HUB])
		return

	# On the lookout floor, the glass wall keeps the player off the bark.
	await _walk(player, climb, 40)
	var off_stair := island.to_local(player.global_position) - HUB
	var outward_dir := Vector3(off_stair.x, 0, off_stair.z).normalized()
	await _walk(player, func() -> Vector3: return at.call(outward_dir * 40.0), 300)
	var lookout := island.to_local(player.global_position) - HUB
	if Vector2(lookout.x, lookout.z).length() > 24.0 or player.global_position.y - floor_y < 33.0:
		_fail("lookout floor or glass wall failed: player at %s" % lookout)
		return

	print("TREE_COURT_FEEDBACK_TEST: PASS (climbed %.1f m, music %.1f dB)"
		% [climbed, melody.volume_db])
	quit(0)
