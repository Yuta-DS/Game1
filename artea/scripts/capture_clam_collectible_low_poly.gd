extends SceneTree

const CLAM_SCENE := preload("res://scenes/items/clam_collectible.tscn")
const OUTPUT := "res://artifacts/clam_collectible_low_poly.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(960, 720)
	root.msaa_3d = Viewport.MSAA_4X
	var stage := Node3D.new()
	root.add_child(stage)
	var clam := CLAM_SCENE.instantiate() as Area3D
	stage.add_child(clam)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(15, 15)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("e9dcc2")
	floor_material.roughness = 0.9
	floor_mesh.material = floor_material
	floor.mesh = floor_mesh
	floor.position.y = -1.05
	stage.add_child(floor)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9ebbc8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dce7e2")
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color("ffe4bc")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(6.8, 4.3, 7.4)
	camera.fov = 48
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.35, 0), Vector3.UP)
	camera.make_current()
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT) == OK)
	print("CLAM_COLLECTIBLE_CAPTURE: PASS — %s" % OUTPUT)
	stage.queue_free()
	await process_frame
	quit()
