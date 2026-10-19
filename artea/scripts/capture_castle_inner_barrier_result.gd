extends SceneTree

## Focused proof render for the corrected tower-side stair/parapet joint.

const OUTPUT := "res://artifacts/castle_stairs_station/14_inner_barrier_finished_edge.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	# Build the production stair generator in an isolated proof world. This uses
	# the exact game geometry and materials while avoiding unrelated terrain,
	# village scatter, audio and UI work that makes a one-angle render very slow.
	var world := Node3D.new()
	root.add_child(world)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9bc9e8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dcebf2")
	environment.ambient_light_energy = 0.8
	environment_node.environment = environment
	world.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff4dc")
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.shadow_enabled = true
	world.add_child(sun)
	# Invoke only the production stair builder. Keeping the generator outside the
	# active tree after the call avoids its full-world obstruction sweeps and
	# bridge/crown construction; a temporary host supplies its terrain fallback.
	var builder_host := Node3D.new()
	world.add_child(builder_host)
	var stair_generator := Node3D.new()
	stair_generator.set_script(load("res://scripts/hub_castle_stairs.gd"))
	builder_host.add_child(stair_generator)
	stair_generator.call("_build_stair", world, Vector2(-1.4, 27.41),
		35.5, 67.73)
	builder_host.remove_child(stair_generator)
	stair_generator.free()
	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.05
	camera.far = 4000.0
	world.add_child(camera)
	camera.global_position = Vector3(-1.4, 78.0, 44.0)
	camera.look_at(Vector3(-1.4, 67.8, 27.41), Vector3.UP)
	camera.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/castle_stairs_station")
	var error := root.get_texture().get_image().save_png(OUTPUT)
	if error != OK:
		push_error("CASTLE_INNER_BARRIER_CAPTURE: %s" % error_string(error))
		quit(error)
		return
	print("CASTLE_INNER_BARRIER_CAPTURE: PASS — wrote %s" % OUTPUT)
	quit()
