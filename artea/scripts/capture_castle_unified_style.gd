extends SceneTree

const SHOTS := [
	["01_full_castle_route", Vector3(63, 106, 104), Vector3(-25, 73, 27.41)],
	["02_spiral_and_rooftop", Vector3(20, 76, 48), Vector3(-1.4, 59, 27.41)],
	["03_rooftop_bridge_court", Vector3(9, 79, 39), Vector3(-13, 69, 27.41)],
	["04_royal_entrance", Vector3(-21, 80, 39), Vector3(-36, 78, 27.41)],
	["05_door_and_reference_tower", Vector3(-22, 87, 42), Vector3(-41, 85, 27.41)],
	["06_stair_underside", Vector3(14, 50, 39), Vector3(-1.4, 49, 27.41)],
	["07_ground_arrival", Vector3(13, 31.5, 15), Vector3(5.1, 27.2, 24.4)],
	["08_soffit_from_below", Vector3(8, 44, 33), Vector3(-1.4, 51, 27.41)],
]

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.set_physics_process(false)
	player.global_position = Vector3(-30.6, 69.18, 27.41)
	for frame in 100:
		await process_frame
		await physics_frame
	for layer: CanvasLayer in hub.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	var underside_audit := "--underside-audit" in OS.get_cmdline_user_args()
	if underside_audit:
		var stair := hub.get_node("CastleStairs/CastleStair")
		for label: String in ["AscentRoadbed", "OuterStoneParapet", "InnerStoneParapet", "InnerSafetyPlinth"]:
			var part := stair.get_node(label) as MeshInstance3D
			var material := StandardMaterial3D.new()
			material.albedo_color = {"AscentRoadbed": Color.RED, "OuterStoneParapet": Color.BLUE,
				"InnerStoneParapet": Color.YELLOW, "InnerSafetyPlinth": Color.GREEN}[label]
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			part.material_override = material
	var camera := Camera3D.new()
	camera.fov = 58
	camera.near = 0.05
	camera.far = 2000
	hub.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts/castle_unified_style")
	for shot in SHOTS:
		if underside_audit and shot[0] != "08_soffit_from_below":
			continue
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://artifacts/castle_unified_style/%s.png" % ("audit_soffit_parts" if underside_audit else shot[0])
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("REFERENCE_STYLE_CAPTURE: " + error_string(error))
			quit(1)
			return
		print("REFERENCE_STYLE_CAPTURE: " + path)
	quit(0)
