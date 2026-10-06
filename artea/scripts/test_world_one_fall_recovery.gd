extends SceneTree

const GALLERY_SCENE := "res://scenes/art_gallery_3d_inprogress.tscn"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gallery := (load(GALLERY_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(gallery)
	for _frame in 10:
		await process_frame
	var floating_world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var world_one := floating_world.get_node("MindSparkWorldOne") as MindSparkWorldOne
	var player := gallery.get_node("Player3D") as CharacterBody3D
	floating_world.set_process(false)
	world_one.set_process(false)
	player.set_physics_process(false)

	for zone_index in [0, 2, 4]:
		var zone_info: Dictionary = MindSparkWorldOne.ZONES[zone_index]
		var zone_local := world_one.get_zone_position(str(zone_info.id))
		var supported := world_one.to_global(zone_local + Vector3.UP * 7.0)
		player.global_position = supported
		world_one.call("_process", .016)
		var fall_position := supported
		fall_position.y = -130.0
		player.global_position = fall_position
		player.velocity = Vector3(4.0, -30.0, 2.0)
		floating_world.call("_process", .016)
		assert(player.global_position.distance_to(supported) < .05,
			"falling from physical island %d returns to its supported World One district" \
			% int(zone_info.super_island))
		assert(player.velocity.is_zero_approx(),
			"World One fall recovery clears unsafe momentum")

	# The shallower perimeter volumes must use the same World One checkpoint;
	# they fire before the shared -120 m failsafe during normal play.
	var island_three := MindSparkWorldOne.ZONES[4]
	var island_three_local := world_one.get_zone_position(str(island_three.id))
	var island_three_safe := world_one.to_global(island_three_local + Vector3.UP * 7.0)
	player.global_position = island_three_safe
	world_one.call("_process", .016)
	player.global_position.y = -50.0
	world_one.call("_on_recovery_body_entered", player)
	assert(player.global_position.distance_to(island_three_safe) < .05,
		"the Island Three perimeter recovery volume stays inside World One")

	print("WORLD_ONE_FALL_RECOVERY: PASS — all three islands retain their local recovery spawn")
	gallery.queue_free()
	await process_frame
	quit(0)
