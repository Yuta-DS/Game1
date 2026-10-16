extends SceneTree

class CameraFrameProbe extends Node:
	signal camera_updated
	func _process(_delta: float) -> void:
		camera_updated.emit()

const DriverView := preload("res://scripts/train_driver_view.gd")
const Windscreen := preload("res://scripts/train_front_windscreen.gd")
var failed := false
var camera: Camera3D
var train: Node3D
var capture := false
var capture_gear_motion := false
var probe: CameraFrameProbe

func _initialize() -> void:
	capture = "--capture-driver-view" in OS.get_cmdline_user_args()
	capture_gear_motion = capture and "--capture-gear-motion" in OS.get_cmdline_user_args()
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1440, 900)
	var world := Node3D.new()
	world.name = "ArtCastleFloatingWorld"
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	var visuals := Node3D.new()
	visuals.name = "FoxVisuals"
	player.add_child(visuals)
	var fox := load("res://assets3D/characters/fox.glb").instantiate() as Node3D
	fox.name = "Fox"
	fox.scale = Vector3.ONE * 3.0
	fox.position.y = -0.980317
	visuals.add_child(fox)
	world.add_child(player)
	var railway := Node3D.new()
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	railway.set_process_unhandled_input(false)
	player.set_process_unhandled_input(false)
	camera = Camera3D.new()
	# A non-default scene FOV makes accidental hard-coded restoration visible.
	camera.fov = 72.0
	camera.set_script(load("res://scripts/CameraFollow.gd"))
	camera.set("player_path", NodePath("../Player3D"))
	camera.set("capture_mouse", false)
	world.add_child(camera)
	camera.set_process_input(false)
	probe = CameraFrameProbe.new()
	probe.process_priority = 101
	world.add_child(probe)
	var original_mask := camera.cull_mask
	var original_fov := camera.fov
	for i in 5:
		await _frame()
	train = railway.get_node("RainbowGalaxyTrain")
	var detailed := train.get_node("BlenderCrownLineTrain")
	_check_windscreen(detailed)
	_check(int(detailed.get_meta("removed_driver_control_wheel_triangles", 0)) > 1000,
		"remove the measured navigation wheel, spokes and grips")
	var visible_train_parts := 0
	var wheel_triangles := 0
	var console := train.get_node("DriverWorkingControls")
	for mesh: MeshInstance3D in train.find_children("*", "MeshInstance3D", true, false):
		if not mesh.visible or mesh.mesh == null or console.is_ancestor_of(mesh):
			continue
		if mesh.layers & camera.cull_mask != 0:
			visible_train_parts += 1
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(surface)
			var material_name := material.resource_name.to_lower() if material != null else ""
			var wheel_material := bool(railway.call("_is_botanical_roof_material", material_name)) \
				or material_name.contains("cab_control_rubber") or material_name.contains("seat_navy")
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
				if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for i in vertices.size():
					indices.append(i)
			if wheel_material:
				wheel_triangles += DriverView.find_control_wheel_triangles(mesh, train, vertices, indices).size()
			if String(mesh.name) == "CrownLineRuntimeTexturedSurface" \
					and (material_name.contains("warm_ivory") or material_name.contains("crown_accentgold") \
					or material_name.contains("cab_clear_cyan_glass")):
				var transform := train.global_transform.affine_inverse() * mesh.global_transform
				for group in preload("res://scripts/train_cab_sightline.gd").components(arrays, transform):
					_check(not Windscreen.is_legacy_component(group.bounds, material_name),
						"no old arch or overlapping front-glass components remain")
	_check(visible_train_parts > 50, "the intact cab and engine remain renderable")
	_check(wheel_triangles == 0, "no control-wheel triangles remain in any view")
	player.global_position = railway.call("get_driver_interaction_position")
	_check(railway.call("board_as_driver"), "driver boards through R interaction")
	_check(camera.call("get_view_mode") == "third", "boarding still starts in third person")
	_key(KEY_3)
	await _frame()
	_check(camera.call("get_view_mode") == "first", "3 selects first person")
	_check(train.get_node("FPSGearHousings").is_visible_in_tree(), "driver first person shows fitted gear housings")
	_check(is_equal_approx(camera.fov, 95.0), "first person uses the wider 95-degree FOV")
	_key(KEY_3)
	_check(is_equal_approx(camera.fov, 95.0), "repeated first-person selection does not change FOV")
	_check(camera.cull_mask == original_mask, "first person does not hide the cab or engine")
	_check(not visuals.visible, "the player's head cannot obstruct first person")
	_check((console.get_node("ThrottleHandle/Grip") as GeometryInstance3D).layers & camera.cull_mask != 0,
		"working levers remain available when looking down")
	var rig := fox.find_child("Skeleton3D", true, false) as Skeleton3D
	var seated_eye := train.to_local(camera.global_position)
	_check(seated_eye.distance_to(Vector3(0, 4.73, -15.665)) < 0.02,
		"the lens is between the measured fox eyes, not above the boiler")
	_check(camera.global_position.distance_to(_measured_eye(rig)) < 0.001,
		"first-person entry matches the character's posed eye point")
	_check((player.call("get_first_person_eye_position", Vector3.UP * 100.0) as Vector3)
		.distance_to(_measured_eye(rig)) < 0.001,
		"a configured fallback cannot lift the camera away from a valid eye socket")
	var head := rig.find_bone("Bone.001")
	var saved_head_position := rig.get_bone_pose_position(head)
	var original_eye := camera.global_position
	rig.set_bone_pose_position(head, saved_head_position + Vector3(0, 0.1, 0))
	camera.call("_process", 0.0)
	_check(camera.global_position.distance_to(_measured_eye(rig)) < 0.001 \
		and camera.global_position.distance_to(original_eye) > 0.25,
		"the lens follows an actual head-pose change, not a fixed seat offset")
	rig.set_bone_pose_position(head, saved_head_position)
	camera.call("_process", 0.0)
	var saved_scale := fox.scale
	fox.scale *= 1.1
	camera.call("_process", 0.0)
	_check(camera.global_position.distance_to(_measured_eye(rig)) < 0.001 \
		and camera.global_position.distance_to(original_eye) > 0.10,
		"the eye point follows character scale")
	fox.scale = saved_scale
	camera.call("_process", 0.0)
	var sightline := preload("res://scripts/train_sightline_test_probe.gd").build(train, world)
	await physics_frame
	await physics_frame
	await _frame()
	var blocked_rays := 0
	var low_instrument := preload("res://scripts/train_sightline_test_probe.gd").trace(camera, Vector2(0.5, 0.95))
	_check(not low_instrument.is_empty(), "a little of the real control stand remains visible at the bottom")
	for row in 41:
		for column in 61:
			var uv := Vector2(0.32 + column * 0.006, 0.31 + row * 0.004125)
			var hit := preload("res://scripts/train_sightline_test_probe.gd").trace(camera, uv)
			if not hit.is_empty():
				blocked_rays += 1
				if blocked_rays <= 8:
					print("SIGHTLINE_BLOCKER ", hit)
	print("CAB_SIGHTLINE clear=%d/2501" % (2501 - blocked_rays))
	_check(blocked_rays == 0, "the central forward road window is free of opaque train geometry")
	sightline.free()
	if capture:
		_setup_lighting(world)
	await _save("train_driver_clear_cab_view")
	var start := train.global_position
	var worst_eye_error := 0.0
	var worst_forward_error := 0.0
	if capture_gear_motion:
		_check(DirAccess.make_dir_recursive_absolute("res://artifacts/train_fps_open_gear_frames") == OK,
			"create FPS gear-motion capture directory")
	for i in 330:
		railway.call("drive_manual", 1.0, 1.0 / 60.0)
		await _frame()
		worst_eye_error = maxf(worst_eye_error, camera.global_position.distance_to(
			_measured_eye(rig)))
		worst_forward_error = maxf(worst_forward_error,
			rad_to_deg((-camera.global_basis.z).angle_to(
				train.global_basis * (Basis.from_euler(Vector3(deg_to_rad(-4.0), 0, 0)) * Vector3.FORWARD))))
		if capture_gear_motion and i < 240 and i % 5 == 0:
			await _save("train_fps_open_gear_frames/frame_%03d" % (i / 5))
	_check(start.distance_to(train.global_position) > 10.0, "real driving moves the camera down the route")
	_check(worst_eye_error < 0.001, "first-person eye follows the actual character pose while driving")
	_check(worst_forward_error < 0.1, "the forward view tracks curves without yaw drift")
	await _save("train_driver_clear_cab_moving")
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(90, 0)
	camera.call("_input", mouse)
	await _frame()
	var look_offset: float = angle_difference(train.global_rotation.y, camera.get("_yaw"))
	_check(absf(look_offset) > 0.4, "mouse free look still works aboard")
	for i in 12:
		railway.call("drive_manual", 1.0, 1.0 / 60.0)
		await _frame()
	_check(absf(angle_difference(look_offset,
		angle_difference(train.global_rotation.y, camera.get("_yaw")))) < 0.01,
		"mouse look offset is preserved through train turns")
	_key(KEY_4)
	await _frame() # the post-camera visual selector applies on the next frame
	_check(is_equal_approx(camera.fov, original_fov), "4 restores the scene's third-person FOV")
	_check(camera.cull_mask == original_mask and visuals.visible, "4 restores train and character rendering")
	await _save("train_driver_clear_cab_exterior")
	_check(not train.get_node("FPSGearHousings").visible, "third person leaves the original transmission exposed")
	_key(KEY_3)
	# Real safe-station exit path, not just a direct camera reset.
	var guard := 0
	while int(railway.call("get_drive_segment")) >= 0 and guard < 3000:
		railway.call("drive_manual", -1.0, 1.0 / 60.0)
		await _frame()
		guard += 1
	_check(railway.call("request_disembark"), "driver can exit at the station")
	_check(camera.cull_mask == original_mask and not camera.call("is_ride_view_active"),
		"exit restores the render mask while preserving walking first person")
	_check(is_equal_approx(camera.fov, 95.0), "walking first person retains the wider FOV after leaving the train")
	await _frame()
	_check(camera.global_position.distance_to(_measured_eye(rig)) < 0.001,
		"on-foot first person follows the same character eye socket")
	_check(not train.get_node("FPSGearHousings").visible, "real disembarking removes FPS-only housings")
	camera.call("begin_ride_view", 14.0)
	_key(KEY_3)
	_check(camera.cull_mask == original_mask, "passenger first person does not inherit driver hiding")
	await _frame()
	_check(camera.global_position.distance_to(_measured_eye(rig)) < 0.001,
		"passenger camera also uses the character's eye point")
	camera.call("end_ride_view")
	camera.call("enter_inspect", train)
	_check(is_equal_approx(camera.fov, original_fov), "artwork inspection keeps its original framing")
	camera.call("exit_inspect")
	_check(is_equal_approx(camera.fov, 95.0), "leaving inspection restores wide first person")
	_key(KEY_4)
	_check(is_equal_approx(camera.fov, original_fov), "repeated view cycles do not accumulate FOV changes")
	print("CHARACTER_EYE_VIEW visible_train_parts=%d wheel_triangles=%d eye_error=%.5fm forward_error=%.4fdeg seated_eye=%s" % [
		visible_train_parts, wheel_triangles, worst_eye_error, worst_forward_error, seated_eye])
	if not failed:
		print("TRAIN_DRIVER_VIEW: PASS — actual character-eye perspective, intact cab, wheel removed, moving eye, curves, free look, FOV/third-person/inspection/exit restoration")
	quit(1 if failed else 0)

func _frame() -> void:
	# Sample after the priority-100 camera, rather than SceneTree.process_frame
	# (which fires before all Node._process callbacks).
	await probe.camera_updated

func _measured_eye(rig: Skeleton3D) -> Vector3:
	var head := rig.find_bone("Bone.001")
	var eye_in_head := rig.get_bone_global_rest(head).affine_inverse() * Vector3(0, 0.84, 0.205)
	return rig.to_global(rig.get_bone_global_pose(head) * eye_in_head)

func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	camera.call("_input", event)

func _check_windscreen(detailed: Node3D) -> void:
	_check(int(detailed.get_meta("replaced_front_window_pieces", 0)) >= 14,
		"replace the complete segmented arch and old front pane")
	var assembly := train.get_node_or_null("DriverFrontWindscreen") as Node3D
	_check(assembly != null, "the fitted windscreen is installed")
	if assembly == null:
		return
	var frame := assembly.get_node("ContinuousGoldFrame") as MeshInstance3D
	var bounds := frame.mesh.get_aabb()
	_check(bounds.size.x > 8.5 and bounds.size.x < 9.08,
		"the panoramic frame fits inside the measured purple roof width")
	_check(bounds.size.z > 0.65, "the screen is swept back rather than a flat picture frame")
	_check(bounds.end.y <= 7.45 and bounds.end.y > 7.40,
		"the curved header stays below the roof without intersecting its skin")
	for label in ["RoofMountLeft", "RoofMountRight"]:
		var mount := assembly.get_node(label) as MeshInstance3D
		var mount_box: AABB = mount.transform * mount.mesh.get_aabb()
		_check(mount_box.position.y < 7.35 and mount_box.end.y >= 7.48,
			"the upper brackets connect the header to the roof")
	_check(Windscreen.FRAME_WIDTH < 0.15, "the frame is slim rather than chunky")
	var frame_arrays := frame.mesh.surface_get_arrays(0)
	var frame_normals: PackedVector3Array = frame_arrays[Mesh.ARRAY_NORMAL]
	_check(frame_normals[0].z < -0.97, "the sloped front trim faces outward")
	var pane := assembly.get_node("SingleClearPane") as MeshInstance3D
	var material := pane.material_override as StandardMaterial3D
	_check(pane.mesh.get_surface_count() == 1 and material.albedo_color.a <= 0.05
		and material.cull_mode == BaseMaterial3D.CULL_DISABLED,
		"one clear double-sided pane without stacked transparent faces")
	var pane_vertices: PackedVector3Array = pane.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex in pane_vertices:
		_check(vertex.distance_to(Windscreen.surface_point(Vector2(vertex.x, vertex.y))) < 0.0001
			and Geometry2D.is_point_in_polygon(Vector2(vertex.x, vertex.y), Windscreen.outline(0)),
			"glass stays entirely inside the frame and above the lower cab wall")
	for label in ["LowerMountLeft", "LowerMountRight"]:
		var post := assembly.get_node(label) as MeshInstance3D
		var post_box: AABB = post.transform * post.mesh.get_aabb()
		_check(post_box.position.y < Windscreen.BOTTOM and post_box.end.y > Windscreen.BOTTOM + 0.5,
			"the lower frame joins its body mounts without floating ends")
	for label in ["ParkedWiperArmLeft", "ParkedWiperArmRight", "ParkedWiperBladeLeft", "ParkedWiperBladeRight"]:
		var wiper := assembly.get_node(label) as MeshInstance3D
		var wiper_box: AABB = wiper.transform * wiper.mesh.get_aabb()
		_check(wiper_box.end.y < 3.60, "parked wipers stay below the forward road view")
	var lower_width := 0.0
	var upper_width := 0.0
	for point in Windscreen.outline(0):
		if point.y < 4.5:
			lower_width = maxf(lower_width, absf(point.x))
		if point.y > 6.5:
			upper_width = maxf(upper_width, absf(point.x))
	_check(lower_width > upper_width + 0.1, "the shoulders taper naturally toward the roof")
	print("FRONT_WINDSCREEN: swept panoramic pane, tapered trim, recessed seal, parked wipers, attached mounts")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("TRAIN_DRIVER_VIEW: " + message)

func _setup_lighting(world: Node3D) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("203c59")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	world.add_child(sun)

func _save(label: String) -> void:
	if not capture:
		return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://artifacts/" + label + ".png") == OK,
		"save screenshot " + label)
