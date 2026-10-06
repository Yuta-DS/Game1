extends SceneTree

const FollowCameraScript := preload("res://scripts/CameraFollow.gd")
const SpringCameraScene := preload("res://scenes/Camera/camera_controller.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player := Node3D.new()
	player.name = "Player"
	root.add_child(player)
	var follow_camera := Camera3D.new()
	follow_camera.name = "ProductionFollowCamera"
	follow_camera.set_script(FollowCameraScript)
	follow_camera.set("player_path", NodePath("../Player"))
	root.add_child(follow_camera)
	assert(not bool(follow_camera.get("_pointer_capture_ready")),
		"the production camera cannot reuse the start-screen click for pointer lock")
	assert(not bool(follow_camera.call("try_capture_pointer")),
		"pointer capture is rejected while the scene transition is active")

	var spring_camera := SpringCameraScene.instantiate() as SpringArm3D
	player.add_child(spring_camera)
	assert(not bool(spring_camera.get("_pointer_capture_ready")),
		"the player camera also ignores the transition click")
	assert(not bool(spring_camera.call("try_capture_pointer")),
		"the player camera cannot request pointer lock before it is armed")

	await process_frame
	assert(bool(follow_camera.get("_pointer_capture_ready"))
		and bool(spring_camera.get("_pointer_capture_ready")),
		"both camera paths arm click-to-look after the transition finishes")
	assert(bool(follow_camera.call("try_capture_pointer"))
		and bool(spring_camera.call("try_capture_pointer")),
		"a later gameplay click still enables normal mouse-look")
	var follow_source := FileAccess.get_file_as_string("res://scripts/CameraFollow.gd")
	var spring_source := FileAccess.get_file_as_string(
		"res://scenes/Camera/camera_controller.gd")
	assert(follow_source.contains('if OS.has_feature("web"):'),
		"the follow camera must avoid pointer lock in Web exports")
	assert(spring_source.contains('if OS.has_feature("web"):'),
		"the spring camera must avoid pointer lock in Web exports")
	assert(follow_source.contains("_web_orbit_dragging")
		and spring_source.contains("_web_orbit_dragging"),
		"both Web camera paths must provide drag-to-orbit controls")

	print("CAMERA_POINTER_CAPTURE_TRANSITION: PASS — scene-swap click ignored, gameplay click armed")
	player.queue_free()
	follow_camera.queue_free()
	await process_frame
	quit(0)
