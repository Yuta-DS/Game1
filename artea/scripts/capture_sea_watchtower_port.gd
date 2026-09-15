extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1440, 900)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(hub)
	for frame in 120:
		await process_frame
	var lettering := hub.get_node("Port").find_child("SeafoodShopLettering", true, false) as MeshInstance3D
	if lettering == null or not str(lettering.get_meta("extras", {}).get("lettering_style", "")).contains("hand-painted") or lettering.get_meta("extras", {}).get("front_direction", "") != "village":
		push_error("Latest painted sign is not imported; refusing a stale screenshot")
		quit(1)
		return
	for layer in hub.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var title := hub.get_node("Port").find_child("HarbourTitle", true, false) as MeshInstance3D
	var accent := hub.get_node("Port").find_child("HarbourTitleAccent", true, false) as MeshInstance3D
	var title_data: Dictionary = title.get_meta("extras", {}) if title != null else {}
	if title == null or accent == null or title_data.get("lettering_revision", 0) != 3 \
			or title_data.get("lettering_source", "") != "res://assets/Fonts/NewFont-Artea.otf":
		push_error("Milo-style Artéa lettering is not imported; refusing a stale screenshot")
		quit(1)
		return
	var camera := Camera3D.new()
	camera.far = 1000
	camera.fov = 60
	hub.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts/coastal_style")
	for shot in [
		["watchtower_coast_overview", Vector3(65, 55, 216), Vector3(20, 1, 159)],
		["watchtower_port", Vector3(60, 20, 218), Vector3(25, 2, 175)],
		["watchtower_connected_detail", Vector3(41, 16, 219), Vector3(25, 3, 190)],
		["harbour_boat_refined", Vector3(43, 7, 207), Vector3(32, 2.8, 197)],
		["harbour_village_frontage", Vector3(41, 12, 158), Vector3(32, 3, 178)],
		["harbour_smooth_shore_access", Vector3(44, 8, 160), Vector3(34, 1.8, 173)],
		["harbour_milo_style_sign", Vector3(41, 6.8, 164), Vector3(38, 5.4, 175.2)],
		["harbour_clean_lettering_detail", Vector3(38.8, 6.5, 168.4), Vector3(38, 5.8, 175)],
		["seafood_painted_sign_in_game", Vector3(22, 6.4, 166), Vector3(26.525, 4.35, 174.7585)]
	]:
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		for frame in 16:
			await process_frame
		await RenderingServer.frame_post_draw
		var saved := root.get_texture().get_image().save_png("res://artifacts/coastal_style/%s.png" % shot[0])
		if saved != OK:
			push_error("Screenshot could not be saved: %s" % shot[0])
			quit(1)
			return
	print("WATCHTOWER_PORT_CAPTURE: PASS")
	quit()
