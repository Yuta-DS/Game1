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
	await physics_frame
	_check(str(milo.call("get_companion_state_name")) == "CATCHING_UP",
		"a distant Milo enters the catch-up state (got %s at %.2fm)" % [
			str(milo.call("get_companion_state_name")),
			milo.global_position.distance_to(player.global_position)])
	var locomotion_player := milo.find_child("AnimationPlayer", true, false) \
		as AnimationPlayer
	_check(locomotion_player != null and locomotion_player.current_animation == "Run",
		"a distant Milo uses the authored running cycle while catching up")
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
	_check(milo.velocity.length() < 0.01,
		"safe repositioning clears stale movement velocity")

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
	var gallery_player := CharacterBody3D.new()
	gallery_player.name = "Player3D"
	gallery_player.add_to_group("Player")
	gallery_like_world.add_child(gallery_player)
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
	print("MILO_COMPANION_FOLLOW_TEST: PASS — breadcrumb following, catch-up, stop distance, non-blocking body, teleport recovery, and scene manager")
	quit()
