extends SceneTree

const MiloNPCScene := preload("res://scenes/milo_animations.tscn")
const ArteaSignScene := preload("res://assets3D/house scenes/artéa_signpost.tscn")
const OUTPUT := "res://artifacts/milo_at_artea_sign.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("5f9fc6")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d9ecf5")
	environment.ambient_light_energy = 0.20
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	stage.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color("ffe3bd")
	sun.light_energy = 0.34
	sun.shadow_enabled = true
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 135, 0)
	fill.light_color = Color("78bde6")
	fill.light_energy = 0.10
	stage.add_child(fill)

	var floor_mesh := MeshInstance3D.new()
	var floor := PlaneMesh.new()
	floor.size = Vector2(18, 12)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("4f8249")
	floor_material.roughness = 0.92
	floor.material = floor_material
	floor_mesh.mesh = floor
	stage.add_child(floor_mesh)
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(18, 0.2, 12)
	floor_collision.position.y = -0.1
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	stage.add_child(floor_body)

	# Milo's existing controller expects the live player as a sibling. Keep a
	# distant stand-in so this capture exercises the real NPC wrapper safely.
	var player := CharacterBody3D.new()
	player.name = "NewPlayer"
	player.position = Vector3(0, 0, 20)
	stage.add_child(player)
	var journey_state := root.get_node_or_null("JourneyState")
	if journey_state != null:
		journey_state.stage = 0

	var milo := MiloNPCScene.instantiate() as Node3D
	milo.name = "Milo_Animations2"
	# The live hub adds a 2x parent transform; 0.75 inside the NPC scene gives
	# the same 1.5x visual scale used by the playable fox cast asset.
	milo.scale = Vector3.ONE * 1.5
	milo.position = Vector3(-1.8, 0, 0)
	stage.add_child(milo)
	# The production controller anchors to absolute hub coordinates in _ready().
	# Reset and freeze it for this isolated proof stage after _ready has run.
	await process_frame
	milo.set_process(false)
	milo.set_physics_process(false)
	milo.position = Vector3(-1.8, 0, 0)

	var signpost := ArteaSignScene.instantiate() as Node3D
	signpost.position = Vector3(3.1, 1.5, 0.6)
	signpost.scale = Vector3.ONE * 1.5
	signpost.rotation_degrees.y = 0
	stage.add_child(signpost)

	var camera := Camera3D.new()
	camera.position = Vector3(3.0, 3.2, 8.0)
	camera.fov = 30
	stage.add_child(camera)
	camera.look_at(Vector3(0.4, 1.45, 0))
	camera.make_current()

	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var error := root.get_texture().get_image().save_png(OUTPUT)
	if error != OK:
		push_error("MILO_SIGN_CAPTURE: failed: %s" % error_string(error))
		quit(error)
		return
	print("MILO_SIGN_CAPTURE: wrote %s" % OUTPUT)
	quit()
