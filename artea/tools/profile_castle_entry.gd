extends SceneTree

const Warmup = preload("res://scripts/shader_warmup.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var started := Time.get_ticks_msec()
	var packed := load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene
	print("CASTLE PROFILE resources ", Time.get_ticks_msec() - started)
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	print("CASTLE PROFILE construction ", Time.get_ticks_msec() - started)
	for frame in 6:
		await process_frame
		print("CASTLE PROFILE frame ", frame, " ", Time.get_ticks_msec() - started)
	var materials := Warmup.collect(scene)
	print("CASTLE PROFILE variants ", materials.size(), " at ", Time.get_ticks_msec() - started)
	var world := scene.get_node("ArtCastleFloatingWorld")
	for builder in [world, world.get_node("StoryCrownRailway")]:
		var cache = builder.get("_mesh_cache")
		print("CASTLE PROFILE shared meshes ", builder.name, " boxes=", cache._boxes.size(),
			" cylinders=", cache._cylinders.size())
	for child in world.get_children():
		var count := child.find_children("*", "VisualInstance3D", true, false).size()
		if count > 100:
			print("CASTLE PROFILE nodes ", child.name, " ", count)
	quit()
