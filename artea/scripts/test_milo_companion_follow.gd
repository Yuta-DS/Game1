extends SceneTree

const MILO_SCENE := preload("res://scenes/milo_animations.tscn")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("  FAIL: %s" % message)


func _run() -> void:
	var world := Node3D.new()
	world.name = "CompanionFollowTestWorld"
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "NewPlayer"
	player.add_to_group("player")
	player.position = Vector3.ZERO
	world.add_child(player)

	var milo := MILO_SCENE.instantiate() as CharacterBody3D
	milo.position = Vector3(-12.0, 0.0, 0.0)
	milo.set("gravity_enabled", false)
	world.add_child(milo)
	await process_frame
	milo.call("set_companion_player", player, false)

	_check(milo.collision_layer == 0,
		"Milo is non-blocking and cannot become a combat target")
	_check(milo.collision_mask == 1,
		"Milo still resolves solid world geometry")
	_check(str(milo.call("get_companion_state_name")) == "IDLE_NEAR_PLAYER",
		"companion adoption starts in the calm nearby state")

	# Record a corner in the player's route. Milo must retain the first point
	# instead of cutting directly to the newest position.
	player.position = Vector3(0.0, 0.0, 6.0)
	milo.call("_sample_player_breadcrumb", true)
	var breadcrumbs: Array = milo.get("_breadcrumbs")
	_check(breadcrumbs.size() >= 2 and (breadcrumbs[0] as Vector3).distance_to(Vector3.ZERO) < 0.01,
		"player breadcrumbs retain the safe route order")

	await physics_frame
	var first_step_speed := Vector2(milo.velocity.x, milo.velocity.z).length()
	await physics_frame
	var second_step_speed := Vector2(milo.velocity.x, milo.velocity.z).length()
	_check(str(milo.call("get_companion_state_name")) == "CATCHING_UP",
		"a distant Milo enters the catch-up state (got %s at %.2fm)" % [
			str(milo.call("get_companion_state_name")),
			milo.global_position.distance_to(player.global_position)])
	var locomotion_player := milo.find_child("AnimationPlayer", true, false) \
		as AnimationPlayer
	_check(locomotion_player != null and locomotion_player.current_animation == "Cane_Walk",
		"a distant Milo keeps the supported cane gait instead of switching to a human sprint")
	_check(first_step_speed > 0.01 and first_step_speed < float(milo.get("catch_up_speed")) * 0.4,
		"Milo eases into movement instead of jumping to full running speed")
	_check(second_step_speed > first_step_speed,
		"Milo accelerates progressively across physics frames")
	var start_distance := milo.global_position.distance_to(player.global_position)
	for _frame in 720:
		await physics_frame
	var followed_distance := milo.global_position.distance_to(player.global_position)
	_check(followed_distance < start_distance - 5.0,
		"Milo physically follows the player's breadcrumb trail")
	_check(followed_distance <= float(milo.get("follow_start_distance")) + 0.45,
		"Milo catches up to companion range (%.2fm)" % followed_distance)
	_check(str(milo.call("get_companion_state_name")) == "IDLE_NEAR_PLAYER",
		"Milo stops instead of crowding the player (got %s)" % str(
			milo.call("get_companion_state_name")))
	_check(followed_distance >= float(milo.get("follow_stop_distance")) - 0.2,
		"Milo preserves visible personal space instead of overlapping the player (%.2fm)" \
		% followed_distance)
	_check(bool(milo.get("first_wave")), "Milo still greets the player on arrival")
	milo.call("_process", 5.1)
	_check(str(milo.call("get_companion_state_name")) == "IDLE_NEAR_PLAYER" \
			and locomotion_player.current_animation == "Idle_3",
		"the completed arrival greeting does not restart every five seconds")

	# Stopping also eases out instead of zeroing the body velocity in one frame.
	milo.velocity = Vector3(1.5, 0.0, 0.0)
	milo.set("companion_state", 2) # CompanionState.FOLLOWING
	milo.set("_follow_active", false)
	milo.set("_previous_player_position", player.global_position)
	await physics_frame
	var eased_stop_speed := Vector2(milo.velocity.x, milo.velocity.z).length()
	_check(eased_stop_speed > 0.01 and eased_stop_speed < 1.5,
		"Milo eases out of movement instead of snapping to a stop")
	for _frame in 30:
		await physics_frame
	_check(Vector2(milo.velocity.x, milo.velocity.z).length() < 0.01,
		"Milo settles fully after the short deceleration")

	# Castle height is not a teleport. A breadcrumb directly above Milo must stay
	# in the route, and ordinary multi-level traversal cannot pop Milo upstairs.
	var castle_side_start := milo.global_position
	var elevated_breadcrumb := castle_side_start + Vector3(0.0, 4.0, 0.0)
	_check(not bool(milo.call("_has_reached_breadcrumb", elevated_breadcrumb)),
		"castle-side breadcrumbs are not reached merely because X/Z match")
	player.position += Vector3(4.0, 6.0, 0.0)
	await physics_frame
	_check(milo.global_position.distance_to(castle_side_start) < 1.0,
		"normal castle height changes do not instantly relocate Milo")

	# A genuine large one-frame player teleport still uses bounded recovery so
	# scene portals cannot strand Milo kilometres away.
	player.position = Vector3(40.0, 8.0, -12.0)
	await physics_frame
	var repaired_distance := milo.global_position.distance_to(player.global_position)
	_check(repaired_distance < 4.0,
		"Milo safely reappears near the player after a teleport")
	_check(repaired_distance >= float(milo.get("follow_stop_distance")) - 0.2,
		"teleport recovery places Milo beside the player rather than inside their silhouette")
	_check(milo.velocity.length() < 0.01,
		"safe repositioning clears stale movement velocity")

	var shore_wait_position := milo.global_position
	player.set_meta("sailing_boat", true)
	player.position += Vector3(35, 0, 0)
	for frame in 12:
		await physics_frame
	_check(milo.global_position.distance_to(shore_wait_position) < 0.01,
		"Milo waits ashore rather than following the sailing player over water")
	player.remove_meta("sailing_boat")
	await physics_frame
	_check(milo.global_position.distance_to(player.global_position) < 4.0,
		"safe disembarking resumes the companion's normal catch-up")

	_check(ProjectSettings.has_setting("autoload/MiloCompanionManager"),
		"the scene-lifecycle companion manager is registered as an autoload")
	var manager := root.get_node_or_null("MiloCompanionManager")
	_check(manager != null, "the companion manager is alive at runtime")
	if manager != null:
		_check(manager.call("_find_3d_player", world) == player,
			"the manager adopts lowercase player-group controllers")
		player.remove_from_group("player")
		player.add_to_group("Player")
		_check(manager.call("_find_3d_player", world) == player,
			"the manager adopts uppercase Player-group controllers")

	world.queue_free()
	await process_frame

	# Prove scene lifecycle behavior, not merely the manager's lookup helper.
	var gallery_like_world := Node3D.new()
	gallery_like_world.name = "GalleryLikeWorld"
	root.add_child(gallery_like_world)
	var floating_world_marker := Node3D.new()
	floating_world_marker.name = "ArtCastleFloatingWorld"
	gallery_like_world.add_child(floating_world_marker)
	var gallery_player := CharacterBody3D.new()
	gallery_player.name = "Player3D"
	gallery_player.add_to_group("Player")
	gallery_like_world.add_child(gallery_player)
	var fox_visuals := Node3D.new()
	fox_visuals.name = "FoxVisuals"
	gallery_player.add_child(fox_visuals)
	var fox := Node3D.new()
	fox.name = "Fox"
	fox_visuals.add_child(fox)
	var fox_mesh := MeshInstance3D.new()
	fox_mesh.name = "FoxSizeReference"
	var fox_box := BoxMesh.new()
	fox_box.size = Vector3(1.0, 3.25, 1.0)
	fox_mesh.mesh = fox_box
	fox.add_child(fox_mesh)
	current_scene = gallery_like_world
	if manager != null:
		manager.call("refresh_companion")
	await process_frame
	await process_frame
	if manager != null:
		var spawned := manager.call("get_active_milo") as CharacterBody3D
		_check(spawned != null and gallery_like_world.is_ancestor_of(spawned),
			"a 3D scene without an authored Milo receives the companion")
		_check(spawned != null and spawned.get("player") == gallery_player,
			"the scene-spawned companion adopts that scene's player")
		var fox_height := float(spawned.get_meta("matched_fox_visual_height_m", 0.0)) \
			if spawned != null else 0.0
		var milo_height := float(spawned.get_meta("milo_native_visual_height_m", 0.0)) \
			* spawned.scale.y if spawned != null else 0.0
		var calibrated_ratio := milo_height / fox_height if fox_height > 0.001 else 0.0
		_check(spawned != null and absf(calibrated_ratio - 0.88) < 0.001 \
				and str(spawned.get_meta("scene_scale_profile", "")) \
					== "art_galaxy_fox_perceived_height_match",
			"Galaxy Milo uses the fox idle-pose height calibration")

	gallery_like_world.queue_free()
	await process_frame
	var activity_2d := Control.new()
	activity_2d.name = "TwoDimensionalActivity"
	root.add_child(activity_2d)
	current_scene = activity_2d
	if manager != null:
		manager.call("refresh_companion")
	await process_frame
	await process_frame
	_check(activity_2d.find_child("WonderfulCounsellorMilo", true, false) == null,
		"2D activities do not receive an unusable 3D walking body")
	activity_2d.queue_free()
	await process_frame
	if _failures > 0:
		push_error("MILO_COMPANION_FOLLOW_TEST: %d failure(s)" % _failures)
		quit(1)
		return
	print("MILO_COMPANION_FOLLOW_TEST: PASS — eased acceleration and stopping, breadcrumb following, catch-up, non-blocking body, teleport recovery, and scene manager")
	quit()
