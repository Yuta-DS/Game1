extends SceneTree
# Heart Melody island polish: the island clears the Heart kingdom floor, one
# lake joins every island, entering opens no menu, sound is heard from the
# player, the fox carries the basket instead of its sword, bridges stand proud
# of the land they rest on, and the standalone camera swings behind the player.
#   godot --headless --path artea --script res://scripts/test_heart_island_polish.gd
var failures: Array[String] = []

func _init() -> void: _run.call_deferred()

func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func _run() -> void:
	create_timer(240).timeout.connect(func(): push_error("Heart island polish test timed out"); quit(1))
	check(change_scene_to_file("res://scenes/art_gallery_3d_inprogress.tscn") == OK, "load overworld")
	for i in 4: await process_frame
	for i in 4: await physics_frame
	var gallery = current_scene
	var connection = gallery.find_child("StoryCrownRailway", true, false).get_node("HeartMelodyConnection")
	var island = connection.island
	island.test_mode = true
	var player: CharacterBody3D = gallery.get_node("Player3D")

	# With a mouse, the keys never turn the view: not A or D, even reversing
	# from one to the other, and not S.
	var follow_camera = gallery.get_node("Camera3D")
	var yaw_start: float = follow_camera._yaw
	for action in ["move_left", "move_right", "move_left", "move_backward"]:
		Input.action_press(action)
		for i in 120: await physics_frame
		Input.action_release(action)
	check(is_zero_approx(angle_difference(follow_camera._yaw, yaw_start)), "desktop movement keys leave the camera alone")

	# Nothing but the island and its lake lies under the whole basin.
	var space: PhysicsDirectSpaceState3D = gallery.get_world_3d().direct_space_state
	var over_floor := 0
	for x in range(-95, 495, 15):
		for z in range(-60, 66, 15):
			var p: Vector3 = island.to_global(Vector3(x, 0, z))
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30, p + Vector3.DOWN * 200))
			if hit and not connection.is_ancestor_of(hit.collider): over_floor += 1
	check(over_floor == 0, "island and lake clear the kingdom floor (%d points over it)" % over_floor)
	var lake: Node3D = island.get_node("IslandOne/ConnectingLake")
	check(lake != null and lake.is_visible_in_tree(), "one lake joins the islands")

	# Walk-in activation: no welcome menu, ears move to the player.
	player.global_position = island.to_global(Vector3(-60, 1.2, 12))
	for i in 10: await physics_frame
	island._process(0.016)
	check(island.embedded_active, "entering activates Heart Melody")
	check(not island.modal_open, "entering does not pop up the welcome menu")
	check(island.listener.is_current(), "positional sound is heard from the player")
	check(island.listener.global_position.distance_to(player.global_position + Vector3.UP * 1.6) < 0.05, "listener sits at the player, not the camera")
	await process_frame
	var skeleton := player.get_node("FoxVisuals/Fox/IdleDemo/Skeleton3D") as Skeleton3D
	var sword := skeleton.get_node("Sword") as Node3D
	var basket: Node3D = island.musical_garden.basket
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Sword_2")).origin
	check(not sword.visible, "sword is put away in Heart Melody")
	check(basket.visible and basket.global_position.distance_to(hand) < 1.0, "basket is carried in the fox's hand")

	# Bridges rest a few centimetres above the banks they overlap.
	var land_top: float = island.to_global(Vector3(266, 0, 8)).y
	var deck := island.river.decks[0].get_child(0) as MeshInstance3D
	var top := (deck.global_transform * deck.get_aabb()).end.y
	check(top > land_top + 0.02, "first chime deck stands above the Bell Grove bank")

	# Falling into the lake between islands: Milo scoops the player out and
	# carries them back to land, rather than a teleport.
	var rescue = root.get_node("MiloCompanionManager").active_fall_rescue
	var rescues_before: int = rescue.get_rescue_count() if is_instance_valid(rescue) else 0
	player.global_position = island.to_global(Vector3(200, 2, 52))
	player.velocity = Vector3.ZERO
	var rescued := false
	var landed := false
	for i in 600:
		await physics_frame
		if is_instance_valid(rescue) and rescue.is_rescuing(): rescued = true
		if rescued and not rescue.is_rescuing() and player.is_on_floor() and island.player_local_position().y > -0.5:
			landed = true
			break
	check(rescued, "Milo rescues a player who falls into the lake")
	check(landed, "the rescue sets the player down on solid ground")

	# Leaving hands back the sword and the camera's ears.
	player.global_position = connection.to_global(connection.walk_points[connection.walk_points.size() / 2]) + Vector3.UP
	for i in 5: await physics_frame
	island._process(0.016)
	await process_frame
	check(not island.embedded_active, "walking out deactivates Heart Melody")
	check(sword.visible, "sword returns outside Heart Melody")
	check(not island.listener.is_current(), "outside, sound is heard from the camera again")

	# The standalone garden camera, like the overworld one, is steered only by
	# the mouse on a PC: running back towards it leaves the view alone.
	var world = load("res://scenes/heart_melody/heart_melody_world.tscn").instantiate()
	world.test_mode = true
	world.progress.path = "user://heart_island_polish_test.json"
	change_scene_to_node(world)
	for i in 4: await process_frame
	var camera = world.camera
	check(camera.has_method("movement_yaw"), "garden camera publishes a movement frame")
	var yaw_before: float = camera.yaw
	Input.action_press("move_backward")
	for i in 150: await physics_frame
	var frame_yaw: float = camera.movement_yaw()
	Input.action_release("move_backward")
	check(absf(angle_difference(camera.yaw, yaw_before)) < 0.01, "desktop: S does not turn the garden camera")
	check(absf(angle_difference(frame_yaw, yaw_before)) < 0.05, "movement keeps its frame while S is held")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://heart_island_polish_test.json" + suffix))

	print("HEART ISLAND POLISH: all checks passed" if failures.is_empty() else "HEART ISLAND POLISH FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)
