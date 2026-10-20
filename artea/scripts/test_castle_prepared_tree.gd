extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(ResourceLoader.exists("res://generated/castle_tree.scn"),
		"Run tools/bake_castle_tree.gd before the prepared-tree regression")
	OS.set_environment("ARTEA_USE_BAKED_TREE", "1")
	var world = load("res://scripts/art_castle_floating_world.gd").new()
	var host := Node3D.new()
	root.add_child(host)
	var center := Vector3(13, 7, 19)
	world._build_life_tree(host, center)
	var tree := host.get_node("TreeOfImagination")
	assert(tree.position.is_equal_approx(center + Vector3(0, -0.24, 0)))
	assert(tree.find_children("ArteaTreeOfLifeModel", "Node3D", true, false).size() == 1,
		"Prepared imported children must appear exactly once")
	assert(not tree.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"Prepared tree keeps its walkable collisions")
	assert(world._tree_christmas_melody.playing and world._tree_christmas_bells.playing,
		"Prepared tree reconnects both ambient audio sources")
	var crystal := tree.find_child("HeartCrystalSpin", true, false) as Node3D
	assert(crystal != null and crystal.has_meta("castle_spin_seconds"))
	var before := crystal.rotation.y
	await create_timer(0.15).timeout
	assert(not is_equal_approx(crystal.rotation.y, before),
		"Prepared heart crystal must animate rather than freeze")
	host.queue_free()
	world.free()
	await process_frame
	print("CASTLE PREPARED TREE: PASS")
	quit()
