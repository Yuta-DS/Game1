extends SceneTree

# Arrival-island bounce pads launch the real gallery player, bounce again on
# the way back down, and the Latona fountain carries three prize sockets.


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("ARRIVAL_BOUNCE_PAD_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 6:
		await physics_frame
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	var island := gallery.get_node_or_null("ArtCastleFloatingWorld/ArrivalIsland") as Node3D
	if player == null or island == null:
		_fail("gallery player or arrival island did not load")
		return

	var pads := island.find_children("BouncePad*", "Area3D", false, false)
	if pads.size() != 30:
		_fail("expected 30 arrival bounce pads, found %d" % pads.size())
		return

	# Drop the player onto a promenade-side pad and watch two bounces.
	var pad := pads[0] as Area3D
	player.global_position = pad.global_position + Vector3(0.0, 4.0, 0.0)
	player.velocity = Vector3.ZERO
	var peak := -INF
	var launches := 0
	var rising := false
	for _frame in 360:
		await physics_frame
		peak = maxf(peak, player.global_position.y - pad.global_position.y)
		if player.velocity.y > 10.0 and not rising:
			launches += 1
		rising = player.velocity.y > 0.0
	if peak < 8.0:
		_fail("pad did not throw the player high: peak %.2f m" % peak)
		return
	if launches < 2:
		_fail("player did not bounce again on landing (launches=%d)" % launches)
		return

	# Holding jump on landing throws the player noticeably higher.
	player.global_position = pad.global_position + Vector3(0.0, 4.0, 0.0)
	player.velocity = Vector3.ZERO
	Input.action_press("jump")
	var boosted_peak := -INF
	for _frame in 240:
		await physics_frame
		boosted_peak = maxf(boosted_peak, player.global_position.y - pad.global_position.y)
	Input.action_release("jump")
	if boosted_peak < peak + 8.0:
		_fail("holding jump did not boost the bounce: %.1f m vs %.1f m" % [boosted_peak, peak])
		return

	var fountain := island.get_node_or_null("LatonaFountain") as Node3D
	if fountain == null:
		_fail("Latona fountain is missing")
		return
	if island.find_children("*PortalFrame", "", false, false).size() != 0:
		_fail("old gold portal frame still stands where the fountain goes")
		return
	if fountain.find_children("PrizeSocket*", "Marker3D", false, false).size() != 3:
		_fail("fountain does not have three prize sockets")
		return
	if island.get_parent().get_node_or_null("SouthObservatory") != null:
		_fail("south observatory tower still stands on the arrival island")
		return

	# The basin rim must be jumpable and the water must not be a floor.
	var cap := fountain.get_node("Tier0Cap") as MeshInstance3D
	var rim_height := cap.get_aabb().end.y
	var jump_height := float(player.get("jump_height"))
	if rim_height >= jump_height:
		_fail("basin rim %.2f m is taller than the %.2f m jump" % [rim_height, jump_height])
		return
	var water := fountain.get_node("Tier0Water") as MeshInstance3D
	var splash := fountain.get_node("SplashBurst") as GPUParticles3D
	player.global_position = fountain.global_position + Vector3(24.0, 3.0, 0.0)
	player.velocity = Vector3.ZERO
	var splashed := false
	for _frame in 120:
		await physics_frame
		splashed = splashed or splash.emitting
	if not splashed:
		_fail("dropping into the basin did not splash")
		return
	# The capsule is centred on the player origin, so feet sit half its height lower.
	var capsule := (player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	var feet_y := player.global_position.y - capsule.height * 0.5
	if not player.is_on_floor() or feet_y >= water.global_position.y - 0.3:
		_fail("player stands on the water instead of wading: feet y=%.2f water y=%.2f"
			% [feet_y, water.global_position.y])
		return

	# Every fountain layer is solid: tier walls/caps, frogs, statue, plinths.
	var space := player.get_world_3d().direct_space_state
	var probes := {
		"tier 1 cap": [Vector3(0.0, 0.0, 17.2), 5.3],
		"tier 2 cap": [Vector3(0.0, 0.0, 11.2), 9.3],
		"tier 3 cap": [Vector3(-6.2, 0.0, 0.0), 12.8],
		"basin frog": [Vector3(29.2, 0.0, 0.0), 1.7],
		"statue": [Vector3(0.0, 0.0, 0.2), 22.9],
		"prize plinth": [Vector3(0.0, 0.0, -8.7), 9.8],
	}
	for label in probes:
		var at: Vector3 = fountain.global_position + probes[label][0]
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			at + Vector3.UP * 40.0, at + Vector3.DOWN * 5.0))
		var expected: float = fountain.global_position.y + probes[label][1]
		if hit.is_empty() or absf(hit.position.y - expected) > 0.6:
			_fail("%s has no collision at %.1f m (hit %s)" % [label, expected,
				hit.position.y if not hit.is_empty() else "nothing"])
			return

	# Mind Spark route dots lie on the arrival floor and stay out of the fountain.
	var world := island.get_parent() as Node3D
	for dot in world.get_node("WalkRouteToMindSparkWorldGate").find_children("MindRoute_*", "MeshInstance3D", false, false):
		var local := world.to_local((dot as Node3D).global_position)
		if local.z < 682.0 or local.z > 970.0:
			continue
		if local.y > 0.3:
			_fail("route dot %s floats %.2f m above the arrival floor" % [dot.name, local.y])
			return
		if Vector2(local.x, local.z - 760.0).length() < 30.0:
			_fail("route dot %s sits inside the fountain" % dot.name)
			return

	# Arrival cypresses stand on the floor, and trunks and crowns are solid.
	var trees := island.find_children("SkyCypress*", "Node3D", false, false)
	if trees.size() < 14:
		_fail("expected at least 14 arrival cypresses, found %d" % trees.size())
		return
	for tree in trees:
		var base := (tree as Node3D).global_position
		if absf(world.to_local(base).y) > 0.05:
			_fail("%s floats %.2f m off the floor" % [tree.name, world.to_local(base).y])
			return
		var trunk_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			base + Vector3(12.0, 2.0, 0.0), base + Vector3(0.0, 2.0, 0.0)))
		var crown_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			base + Vector3(0.0, 60.0, 0.0), base + Vector3(0.0, 21.0, 0.0)))
		if trunk_hit.is_empty() or crown_hit.is_empty():
			_fail("%s is missing trunk or crown collision" % tree.name)
			return

	# Walk from the gallery carpet onto the bridge without jumping.
	player.global_position = Vector3(0.0, 1.5, 8.0)
	player.velocity = Vector3.ZERO
	for _frame in 30:
		await physics_frame
	var forward := player.call("get_camera_relative_move_direction", Vector2(0.0, -1.0)) as Vector3
	var action := "move_forward" if forward.z > 0.5 else "move_backward"
	Input.action_press(action)
	for _frame in 180:
		await physics_frame
	Input.action_release(action)
	if player.global_position.z < 35.0 or player.global_position.y < 1.4:
		_fail("player could not walk from the carpet onto the bridge: stopped at %s"
			% player.global_position)
		return

	print("ARRIVAL_BOUNCE_PAD_TEST: PASS (peak %.1f m, boosted %.1f m, %d launches, splash)"
		% [peak, boosted_peak, launches])
	quit(0)
