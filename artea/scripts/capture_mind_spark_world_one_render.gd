extends SceneTree

const OUTPUT_DIR := "res://artifacts/mind_spark_world_one_render"
const SHOTS := [
	{"name": "01_six_zone_birdseye", "eye": Vector3(0, 2400, 60), "look": Vector3(0, 35, 60), "orthographic": true, "size": 1450.0},
	{"name": "02_living_network_to_constellation", "eye": Vector3(-1040, 250, -690), "look": Vector3(-470, 24, -80), "orthographic": false, "fov": 58.0},
	{"name": "03_storm_to_oldest_tree", "eye": Vector3(240, 300, 770), "look": Vector3(760, 62, -110), "orthographic": false, "fov": 56.0},
	{"name": "05_warden_and_sanctuary", "eye": Vector3(250, 220, 520), "look": Vector3(760, 66, -160), "orthographic": false, "fov": 49.0},
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	print("MIND_SPARK_WORLD_ONE_RENDER: start")
	root.size = Vector2i(1200, 675)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var stage := Node3D.new()
	stage.name = "MindSparkWorldOneRenderStage"
	root.add_child(stage)
	current_scene = stage
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://capture_mind_spark_world_one.json"
	stage.add_child(world)
	world.set_world_state("waking")
	# The cartographic blueprint shows the completed-world station branch. This
	# affects capture visibility only; runtime construction still starts hidden
	# and non-colliding until the story unlocks it.
	world.set_station_spur_available(true)
	# Billboard text is verified in gameplay tests; hiding it here keeps the
	# cartographic overview focused on geometry and avoids rasterizing dozens of
	# large dynamic font atlases in one frame.
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	print("MIND_SPARK_WORLD_ONE_RENDER: world attached")
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071126")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("88a8d8")
	environment.ambient_light_energy = 0.58
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = false
	environment_node.environment = environment
	stage.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54, -34, 0)
	sun.light_color = Color("fff1d0")
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-26, 142, 0)
	fill.light_color = Color("55ccec")
	fill.light_energy = 0.42
	stage.add_child(fill)
	print("MIND_SPARK_WORLD_ONE_RENDER: lighting attached")
	var camera := Camera3D.new()
	camera.near = 0.5
	camera.far = 7000
	stage.add_child(camera)
	camera.make_current()
	for _frame in 8:
		await process_frame
		print("MIND_SPARK_WORLD_ONE_RENDER: warmup %d" % _frame)
	for shot in SHOTS:
		print("MIND_SPARK_WORLD_ONE_RENDER: framing %s" % shot.name)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL if bool(shot.orthographic) else Camera3D.PROJECTION_PERSPECTIVE
		if bool(shot.orthographic):
			camera.size = float(shot.size)
		else:
			camera.fov = float(shot.fov)
		camera.position = shot.eye
		camera.look_at(shot.look, Vector3(0, 0, -1) if bool(shot.orthographic) else Vector3.UP)
		for _frame in 4:
			await process_frame
			print("MIND_SPARK_WORLD_ONE_RENDER: %s settle %d" % [shot.name, _frame])
		var path := "%s/%s.png" % [OUTPUT_DIR, shot.name]
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Mind Spark World One render failed: %s" % error_string(error))
			quit(1)
			return
		print("MIND_SPARK_WORLD_ONE_RENDER: wrote %s" % path)
	world.visible = false
	var sheet := (load("res://scenes/mind_spark/quest_objects/quest_object_sheet.tscn") as PackedScene).instantiate()
	for child in sheet.get_children():
		if child is QuestObjectBase:
			child.persist_state = false
			child.scale = Vector3.ONE * 1.22
			child.get_node("Prompt").visible = false
			child.get_node("Status").visible = false
			child.get_node("Icon").visible = false
	stage.add_child(sheet)
	await process_frame
	var sheet_index := 0
	for child in sheet.get_children():
		if child is QuestObjectBase:
			_stage_representative_state(sheet_index, child)
			var number := Label3D.new()
			number.text = "%02d" % (sheet_index + 1)
			number.font_size = 64
			number.outline_size = 12
			number.modulate = Color("42f3ff")
			number.position = Vector3(-1.08, 2.08, -0.30)
			number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			child.add_child(number)
			_add_sheet_cell(stage, child.position, sheet_index)
			sheet_index += 1
	var sheet_floor := MeshInstance3D.new()
	var sheet_floor_mesh := BoxMesh.new()
	sheet_floor_mesh.size = Vector3(10.4, 0.16, 13.6)
	sheet_floor.mesh = sheet_floor_mesh
	sheet_floor.position.y = -0.28
	var sheet_floor_material := StandardMaterial3D.new()
	sheet_floor_material.albedo_color = Color("050b18")
	sheet_floor_material.metallic = 0.2
	sheet_floor_material.roughness = 0.82
	sheet_floor.material_override = sheet_floor_material
	stage.add_child(sheet_floor)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.7
	camera.position = Vector3(0, 11.8, 15.8)
	camera.look_at(Vector3(0, 0.76, 0), Vector3.UP)
	for _frame in 6:
		await process_frame
	var sheet_path := "%s/04_functional_object_sheet.png" % OUTPUT_DIR
	var sheet_error := root.get_texture().get_image().save_png(sheet_path)
	if sheet_error != OK:
		push_error("Mind Spark object sheet render failed: %s" % error_string(sheet_error))
		quit(1)
		return
	print("MIND_SPARK_WORLD_ONE_RENDER: wrote %s" % sheet_path)
	print("MIND_SPARK_WORLD_ONE_RENDER: PASS")
	quit()


func _stage_representative_state(index: int, object: QuestObjectBase) -> void:
	# Each cell shows the interaction state that best communicates its purpose.
	# These calls are capture-only and persistence is disabled above.
	match index:
		0:
			object.interact()
			object.interact()
		1:
			object.interact()
		2:
			object.interact()
			object.interact()
			object.interact()
		3:
			object.interact()
			object.interact()
		4:
			object.interact()
		5:
			object.interact(&"true")
		6:
			object.interact(&"help")
		7:
			object.interact()
		10:
			object.interact()
		11:
			object.interact()


func _add_sheet_cell(stage: Node3D, center: Vector3, index: int) -> void:
	var cell := Node3D.new()
	cell.name = "ObjectCell%02d" % (index + 1)
	cell.position = Vector3(center.x, -0.16, center.z)
	stage.add_child(cell)
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(3.02, 0.10, 3.02)
	plate.mesh = plate_mesh
	var plate_material := StandardMaterial3D.new()
	plate_material.albedo_color = Color("081327") if index % 2 == 0 else Color("0a162b")
	plate_material.metallic = 0.28
	plate_material.roughness = 0.76
	plate.material_override = plate_material
	cell.add_child(plate)
	var border_material := StandardMaterial3D.new()
	border_material.albedo_color = Color("17dff2")
	border_material.emission_enabled = true
	border_material.emission = Color("08b9d8")
	border_material.emission_energy_multiplier = 1.25
	for border_data in [
		{"position": Vector3(0, 0.08, -1.50), "size": Vector3(3.04, 0.035, 0.035)},
		{"position": Vector3(0, 0.08, 1.50), "size": Vector3(3.04, 0.035, 0.035)},
		{"position": Vector3(-1.50, 0.08, 0), "size": Vector3(0.035, 0.035, 3.04)},
		{"position": Vector3(1.50, 0.08, 0), "size": Vector3(0.035, 0.035, 3.04)},
	]:
		var border := MeshInstance3D.new()
		var border_mesh := BoxMesh.new()
		border_mesh.size = border_data.size
		border.mesh = border_mesh
		border.position = border_data.position
		border.material_override = border_material
		cell.add_child(border)
