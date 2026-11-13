extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene) \
		.instantiate() as Node3D
	root.add_child(gallery)
	current_scene = gallery
	for _frame in 8:
		await physics_frame
	var world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var gate := world.get_node("HeartMelodyWorldGate") as MindSparkWorldGate
	var heart := world.get_node("HeartMelodyWorld") as Node3D
	assert(world.find_children("HeartMelodyWorldGate*", "MindSparkWorldGate",
		false, false).size() == 1, "Heart Melody must have one unambiguous gate")
	assert(gate.target_kingdom_id.is_empty(), "visible gate must use its local Heart world")
	assert(gate.target_world_path == NodePath("../HeartMelodyWorld"))
	assert(gate.destination_world_local.is_equal_approx(
		heart.position + HeartGardenWorld.ARRIVAL))
	var player := gallery.get_node("Player3D") as CharacterBody3D
	gate.set_gate_enabled(true)
	assert(gate.teleport_player(player), "visible Heart gate must teleport")
	assert(player.global_position.distance_to(
		world.to_global(heart.position + HeartGardenWorld.ARRIVAL)) < 0.1)
	assert(bool(heart.get("built")), "Heart world must build on first travel")
	print("HEART_WORLD_GATE_IN_GALLERY: PASS — one gate teleports to the built Heart island")
	quit()
