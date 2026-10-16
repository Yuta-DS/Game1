extends SceneTree

const OUTPUT := "res://artifacts/milo_galaxy_size/01_milo_matches_fox.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1440, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	current_scene = gallery
	var manager := root.get_node_or_null("MiloCompanionManager")
	manager.call("refresh_companion")
	for _frame in 10:
		await process_frame
	var player := gallery.get_node("Player3D") as CharacterBody3D
	var milo := manager.call("get_active_milo") as CharacterBody3D
	player.set_process(false)
	player.set_physics_process(false)
	milo.set_process(false)
	milo.set_physics_process(false)
	var idle_clips: Array[String] = ["Idle"]
	player.call("_play_character_clip", idle_clips, 0.0)
	var fox_animation := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if fox_animation != null:
		fox_animation.seek(0.0, true)
	# Stand both characters on the same Galaxy surface and at the same depth so
	# the screenshot is a direct height comparison without perspective bias.
	var stage_at := player.global_position
	player.global_position = stage_at + Vector3(-2.2, 0.0, 0.0)
	milo.global_position = stage_at + Vector3(2.2, 0.0, 0.0)
	player.rotation.y = PI
	milo.rotation.y = PI
	var existing_camera := gallery.get_node_or_null("Camera3D") as Camera3D
	if existing_camera != null:
		existing_camera.current = false
	var camera := Camera3D.new()
	camera.fov = 42.0
	camera.position = stage_at + Vector3(0.0, 2.25, 11.5)
	gallery.add_child(camera)
	camera.look_at(stage_at + Vector3(0.0, 1.9, 0.0), Vector3.UP)
	camera.make_current()
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT) == OK)
	print("MILO_GALAXY_FOX_SIZE_CAPTURE: PASS — %s" % OUTPUT)
	quit()
