extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func shot(scene: Node, label: String, eye: Vector3, target: Vector3) -> void:
	var player := scene.get_node_or_null("Player3D") as CharacterBody3D
	if player != null:
		player.set_physics_process(false)
		player.global_position = target + Vector3.UP * 2
	for layer in scene.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var camera := Camera3D.new()
	camera.far = 12000
	camera.near = 0.1
	camera.fov = 65
	scene.add_child(camera)
	camera.global_position = eye
	camera.look_at(target)
	camera.make_current()
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/arrival_repairs/%s.png" % label
	root.get_texture().get_image().save_png(path)
	print("ARRIVAL CAPTURE ", path)
	camera.queue_free()

func run() -> void:
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute("res://artifacts/arrival_repairs")
	OS.set_environment("ARTEA_FORCE_WEB_LOD", "1")
	OS.set_environment("ARTEA_USE_BAKED_TREE", "1")
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	current_scene = gallery
	for frame in 30:
		await process_frame
	var world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var fountain := world.to_global(Vector3(1787.4, 0.22, 7943.7))
	await shot(gallery, "01_musical_fountain", fountain + Vector3(72, 28, -105), fountain + Vector3.UP * 25)
	var landing := world.to_global(Vector3(1722.4, 0.20, 7838.7))
	await shot(gallery, "02_heart_paving", landing + Vector3(12, 10, -12), landing + Vector3(-12, 0, 14))
	if "--heart-only" in OS.get_cmdline_user_args():
		print("ARRIVAL CAPTURE: PASS")
		quit()
		return
	current_scene = null
	gallery.queue_free()
	for frame in 3:
		await process_frame
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	current_scene = hub
	for frame in 80:
		await process_frame
		await physics_frame
	var entry := hub.get_node("CastleStairs/CastleStair/GroundedCastleEntry")
	var middle: Vector3 = (entry.get_meta("surface_start") + entry.get_meta("surface_end")) * 0.5
	await shot(hub, "03_ground_stair", middle + Vector3(6, 4, -5), middle + Vector3.UP)
	print("ARRIVAL CAPTURE: PASS")
	quit()
