extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var scene: Node = (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var camera := root.get_viewport().get_camera_3d()
	var player := scene.get_node("Player3D") as CharacterBody3D
	for _i in 90:
		await physics_frame
	Input.action_press("move_right")
	for _i in 40:
		await physics_frame
		Input.action_press("move_right")
	var ly := camera.global_rotation.y
	var lp := player.global_position
	var lc := camera.global_position
	for _i in 40:
		await physics_frame
		Input.action_press("move_right")
		var p := player.global_position
		var c := camera.global_position
		print("yaw %+.5f  pstep %s  pv %s floor=%s  cstep %s" % [angle_difference(ly, camera.global_rotation.y), (p - lp).snappedf(0.001), player.velocity.snappedf(0.01), player.is_on_floor(), (c - lc).snappedf(0.001)])
		ly = camera.global_rotation.y; lp = p; lc = c
	quit()
