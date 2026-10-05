extends SceneTree

const OUTPUT := "res://artifacts/mind_station_reference_style"

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1440, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var world := Node3D.new()
	world.name = "ArtCastleFloatingWorld"
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	world.add_child(player)
	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	for _frame in 8:
		await process_frame
	player.visible = false
	for layer in world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	var station := railway.get_node("StoryStations/Station_02_mind") as Node3D
	var stairs := station.get_node("MindSparkIslandConnectionStair") as Node3D
	var foot := (stairs.get_node("IslandGroundStep_01") as MeshInstance3D).global_position
	var top := (stairs.get_node("IslandGroundStep_72") as MeshInstance3D).global_position
	var climb := top - foot
	var forward := Vector3(climb.x, 0.0, climb.z).normalized()
	var side := Vector3.UP.cross(forward).normalized()

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("14213f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8dcff")
	env.ambient_light_energy = 0.72
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_color = Color("fff1cd")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.near = 0.2
	camera.far = 5000.0
	world.add_child(camera)
	camera.make_current()

	camera.fov = 57.0
	camera.global_position = foot - forward * 28.0 + side * 32.0 + Vector3.UP * 22.0
	camera.look_at(foot.lerp(station.global_position + Vector3.UP * 5.0, 0.58), Vector3.UP)
	await _save("01_island_approach")

	camera.fov = 53.0
	camera.global_position = foot.lerp(top, 0.50) + side * 82.0 + Vector3.UP * 34.0
	camera.look_at(station.global_position + Vector3.UP * 3.0, Vector3.UP)
	await _save("02_rainbow_stair_and_station")

	camera.fov = 62.0
	camera.global_position = top + side * 35.0 + forward * 18.0 + Vector3.UP * 12.0
	camera.look_at(station.global_position + Vector3.UP * 7.0, Vector3.UP)
	await _save("03_station_platform")
	print("MIND_STATION_REFERENCE_STYLE_CAPTURE: PASS")
	quit()

func _save(file_name: String) -> void:
	for _frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUTPUT, file_name]
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("MIND_STATION_REFERENCE_STYLE_CAPTURE: wrote %s" % path)
