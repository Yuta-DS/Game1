extends SceneTree

const OUT_DIR := "res://artifacts/mind_spark_character_reference"
const TARGET_HEIGHT := 3.2
const SHOTS := [
	{"name": "front", "angle": 0.0},
	{"name": "three_quarter", "angle": 45.0},
	{"name": "side", "angle": 90.0},
	{"name": "back", "angle": 180.0},
]
const MODELS := [
	{"name": "player_fox", "path": "res://assets3D/characters/fox.glb"},
	{"name": "milo_cat", "path": "res://meshy ai/Milo_Animations.glb"},
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	print("CHARACTER_REFERENCE: start")
	root.size = Vector2i(1024, 1024)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var stage := Node3D.new()
	stage.name = "CharacterReferenceStage"
	root.add_child(stage)
	current_scene = stage

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("d8eef4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dff7ff")
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	stage.add_child(environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	key.light_color = Color("fff2d7")
	key.light_energy = 1.45
	key.shadow_enabled = true
	stage.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, 145.0, 0.0)
	fill.light_color = Color("8dd9ff")
	fill.light_energy = 0.65
	stage.add_child(fill)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("edf8fb")
	material.roughness = 0.9
	plane.material = material
	floor_mesh.mesh = plane
	stage.add_child(floor_mesh)

	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.near = 0.05
	camera.far = 100.0
	stage.add_child(camera)
	camera.make_current()

	for spec in MODELS:
		print("CHARACTER_REFERENCE: loading %s" % spec["name"])
		var model := (load(spec["path"]) as PackedScene).instantiate()
		stage.add_child(model)
		if spec["name"] == "milo_cat":
			# The authored hub uses a large scene transform. Match that intended
			# scale before framing; scaling the imported 0.007-unit bounds directly
			# can push the skinned mesh outside the useful camera range.
			model.scale = Vector3.ONE * 2.0
		for _frame in 3:
			await process_frame
		if spec["name"] == "milo_cat":
			var animation_player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if animation_player != null:
				print("CHARACTER_REFERENCE: Milo animations %s" % [animation_player.get_animation_list()])
				for animation_name in animation_player.get_animation_list():
					if str(animation_name).to_lower().contains("idle"):
						animation_player.play(animation_name)
						animation_player.seek(0.2, true)
						break
			for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
				var mi := mesh_node as MeshInstance3D
				print("CHARACTER_REFERENCE: Milo mesh %s transform=%s aabb=%s" % [mi.get_path(), mi.global_transform, mi.get_aabb()])

		print("CHARACTER_REFERENCE: finding bounds %s" % spec["name"])
		var bounds := _combined_bounds(model)
		if bounds.size.y <= 0.001:
			push_error("CHARACTER_REFERENCE: empty bounds for %s" % spec["name"])
			quit(1)
			return
		var uniform_scale := TARGET_HEIGHT / bounds.size.y
		print("CHARACTER_REFERENCE: initial bounds %s %s" % [spec["name"], bounds])
		var model_centre := bounds.get_center()
		if spec["name"] == "player_fox":
			model.scale = Vector3.ONE * uniform_scale
			for _frame in 2:
				await process_frame
			bounds = _combined_bounds(model)
			model.global_position += Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
			for _frame in 2:
				await process_frame
			bounds = _combined_bounds(model)
			model_centre = bounds.get_center()
		var target := Vector3(model_centre.x, model_centre.y, model_centre.z)
		var radius := maxf(bounds.size.y * 2.05, bounds.size.x * 2.2)
		if spec["name"] == "milo_cat":
			# Render close to the native imported scale. The hub enlarges this
			# model at scene level, but its skeleton is authored in a 0.014 m box.
			radius = 0.035
			camera.near = 0.0001
		else:
			camera.near = 0.05

		for shot in SHOTS:
			var angle := deg_to_rad(float(shot["angle"]))
			camera.global_position = target + Vector3(sin(angle) * radius, bounds.size.y * 0.08, -cos(angle) * radius)
			camera.look_at(target, Vector3.UP)
			for _frame in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var path := "%s/%s_%s.png" % [OUT_DIR, spec["name"], shot["name"]]
			var error := root.get_texture().get_image().save_png(path)
			if error != OK:
				push_error("CHARACTER_REFERENCE: failed %s (%s)" % [path, error_string(error)])
				quit(error)
				return
			print("CHARACTER_REFERENCE: wrote %s" % path)

		model.queue_free()
		for _frame in 3:
			await process_frame

	print("CHARACTER_REFERENCE: PASS")
	quit()


func _combined_bounds(root_node: Node3D) -> AABB:
	var found := false
	var bounds := AABB()
	for node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var item_bounds: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		if found:
			bounds = bounds.merge(item_bounds)
		else:
			bounds = item_bounds
			found = true
	return bounds
