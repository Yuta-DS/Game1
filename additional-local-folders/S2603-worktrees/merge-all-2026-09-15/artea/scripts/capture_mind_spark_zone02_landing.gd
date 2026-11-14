extends SceneTree

## Local proof image for the repaired World One bridge-to-island handoff.

const OUTPUT_PATH := "res://artifacts/mind_spark_zone02_landing.png"
const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const PlayerScene := preload("res://scenes/player_3d.tscn")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	print("ZONE02_LANDING_CAPTURE: start")
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))

	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage

	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.force_standalone_blueprint = true
	stage.add_child(world)
	print("ZONE02_LANDING_CAPTURE: world attached")

	var route := world.get_node("WorldOneGeometry/MainStoryCircuitRoute") as Node3D
	var landing := route.get_node("CircuitRoute_01_B") as MeshInstance3D
	var landing_mesh := landing.mesh as BoxMesh
	var zone := world.to_global(world.get_zone_position("02_living_network_forest"))
	var end_a := landing.to_global(Vector3(0, landing_mesh.size.y * 0.5, -landing_mesh.size.z * 0.5))
	var end_b := landing.to_global(Vector3(0, landing_mesh.size.y * 0.5, landing_mesh.size.z * 0.5))
	var bridge_end := end_a if end_a.distance_to(zone) > end_b.distance_to(zone) else end_b
	var island_end := end_b if bridge_end == end_a else end_a
	var forward := (island_end - bridge_end).normalized()

	var player := PlayerScene.instantiate() as CharacterBody3D
	stage.add_child(player)
	player.set_physics_process(false)
	player.global_position = bridge_end + forward * 2.0 + Vector3.UP * 1.7
	player.look_at(player.global_position + forward, Vector3.UP)
	print("ZONE02_LANDING_CAPTURE: player positioned")

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071126")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9bb9e8")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_color = Color("fff1d0")
	sun.light_energy = 1.25
	stage.add_child(sun)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 48.0
	camera.near = 0.1
	camera.far = 5000.0
	stage.add_child(camera)
	var side := Vector3(-forward.z, 0.0, forward.x)
	camera.global_position = island_end + side * 100.0 + Vector3.UP * 9.0
	camera.look_at(island_end + Vector3.UP * 9.0, Vector3.UP)
	camera.make_current()
	print("ZONE02_LANDING_CAPTURE: camera ready")

	for canvas in stage.find_children("*", "CanvasLayer", true, false):
		(canvas as CanvasLayer).visible = false
	for _frame in 16:
		await process_frame
	print("ZONE02_LANDING_CAPTURE: frame settled")

	var error := root.get_texture().get_image().save_png(OUTPUT_PATH)
	if error != OK:
		push_error("ZONE02_LANDING_CAPTURE: %s" % error_string(error))
		quit(1)
		return
	print("ZONE02_LANDING_CAPTURE: PASS — wrote %s" % OUTPUT_PATH)
	quit()
