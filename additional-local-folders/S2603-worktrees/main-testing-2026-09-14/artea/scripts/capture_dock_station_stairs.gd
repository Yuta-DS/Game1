extends SceneTree

## Renders the Crown Line dock station and its arrival stairs — the navy flight
## with gold rail posts and the cyan CrystalEnergyConduit down the middle, built
## by art_castle_story_railway.gd::_build_dock_arrival_stairs().

const RAILWAY := preload("res://scripts/art_castle_story_railway.gd")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var host := Node3D.new()
	root.add_child(host)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.09, 0.07, 0.16)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.74, 0.86)
	environment.ambient_light_energy = 1.15
	env.environment = environment
	host.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.25
	host.add_child(sun)

	var railway := Node3D.new()
	railway.set_script(RAILWAY)
	host.add_child(railway)
	for _i in 90:
		await process_frame
		await physics_frame

	# Find the dock station's stair group wherever the railway placed it.
	var ramps: Array = []
	for node in host.find_children("AccessRamp", "Node3D", true, false):
		ramps.append(node as Node3D)
	if ramps.is_empty():
		push_error("DOCK_STAIRS: no AccessRamp found — railway did not build the dock")
		quit(1)
		return
	print("DOCK_STAIRS: found %d access ramp(s)" % ramps.size())

	var camera := Camera3D.new()
	camera.fov = 60.0
	camera.near = 0.05
	camera.far = 4000.0
	host.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts/dock_stairs")

	for ramp_index in ramps.size():
		var ramp: Node3D = ramps[ramp_index]
		var first := ramp.get_node_or_null("DockStep_01") as MeshInstance3D
		var last := ramp.get_node_or_null("DockStep_%02d" % RAILWAY.STAIR_STEP_COUNT) as MeshInstance3D
		if first == null or last == null:
			print("DOCK_STAIRS: ramp %d has no dock steps, skipping" % ramp_index)
			continue
		var foot: Vector3 = first.global_position
		var head: Vector3 = last.global_position
		var middle: Vector3 = foot.lerp(head, 0.5)
		print("DOCK_STAIRS: ramp %d foot=%s head=%s" % [ramp_index, foot, head])

		# Eye-height views matching how the screenshots were taken, plus a side
		# elevation that exposes the junction at each end of the flight.
		var shots := {
			"01_from_foot": [foot + Vector3(-16.0, 3.2, 0.0), head],
			"02_from_head": [head + Vector3(14.0, 3.4, 0.0), foot],
			"03_side": [middle + Vector3(0.0, 7.0, 26.0), middle],
			"04_top_junction": [head + Vector3(-9.0, 6.5, 12.0), head],
			"05_foot_junction": [foot + Vector3(-11.0, 5.0, 13.0), foot],
		}
		for label in shots:
			var eye: Vector3 = shots[label][0]
			var target: Vector3 = shots[label][1]
			camera.global_position = eye
			camera.look_at(target, Vector3.UP)
			for _i in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			var path := "res://artifacts/dock_stairs/ramp%d_%s.png" % [ramp_index, label]
			var error := root.get_texture().get_image().save_png(path)
			if error != OK:
				push_error("DOCK_STAIRS: failed %s (%s)" % [path, error_string(error)])
				quit(error)
				return
			print("DOCK_STAIRS: wrote %s" % path)

	print("DOCK_STAIRS: PASS")
	quit()
