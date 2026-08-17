extends SceneTree

const OUTPUT_PATH := "res://artifacts/mind_spark_world_one_render/04_functional_object_sheet.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1200, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("030817")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8aa8d8")
	environment.ambient_light_energy = 0.46
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)
	_add_light(stage, Vector3(-52, -32, 0), Color("fff0d2"), 0.82)
	_add_light(stage, Vector3(-25, 148, 0), Color("5ad9ff"), 0.42)

	var sheet := (load("res://scenes/mind_spark/quest_objects/quest_object_sheet.tscn") as PackedScene).instantiate()
	stage.add_child(sheet)
	var index := 0
	for child in sheet.get_children():
		if child is QuestObjectBase:
			child.persist_state = false
			child.scale = Vector3.ONE * 0.92
			_stage_representative_state(index, child)
			for interface_node_name in ["Prompt", "Status", "Icon"]:
				var interface_node := child.get_node(interface_node_name) as Label3D
				interface_node.modulate.a = 0.0
				interface_node.outline_modulate.a = 0.0
			for internal_label in child.get_node("VisualRoot").find_children("*", "Label3D", true, false):
				(internal_label as Label3D).visible = false
			_add_number(stage, child.position, index + 1)
			_add_cell(stage, child.position, index)
			index += 1
	for capture_label in stage.find_children("*", "Label3D", true, false):
		(capture_label as Label3D).visible = capture_label.name.begins_with("ObjectNumber")

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.0
	camera.position = Vector3(0, 12.8, 17.2)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.76, 0), Vector3.UP)
	camera.make_current()
	for _frame in 10:
		await process_frame
	var error := root.get_texture().get_image().save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Quest object model capture failed: %s" % error_string(error))
		quit(1)
		return
	print("MIND_SPARK_QUEST_OBJECT_MODEL_RENDER: PASS • %s" % OUTPUT_PATH)
	quit()


func _add_light(parent: Node3D, rotation: Vector3, color: Color, energy: float) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = rotation
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = false
	parent.add_child(light)


func _stage_representative_state(index: int, object: QuestObjectBase) -> void:
	match index:
		0: object.interact(); object.interact()
		1: object.interact(); object.interact(&"fact")
		2: object.interact(); object.interact()
		3: object.interact(&"connect", 0); object.interact(&"connect", 1)
		4: object.interact()
		5: object.interact(&"true")
		6: object.interact(&"help")
		7: object.interact(&"dodge"); object.interact(&"strike")
		8: object.interact(&"hold")
		9: object.interact(&"choose", "growing")
		10: object.interact(&"save")
		11: object.interact(&"toggle")


func _add_number(parent: Node3D, object_position: Vector3, number: int) -> void:
	var label := Label3D.new()
	label.name = "ObjectNumber%02d" % number
	label.text = "%02d" % number
	label.font_size = 64
	label.outline_size = 12
	label.modulate = Color("42f3ff")
	label.position = object_position + Vector3(-1.35, 0.22, -1.34)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)


func _add_cell(parent: Node3D, center: Vector3, index: int) -> void:
	var cell := Node3D.new()
	cell.position = Vector3(center.x, -0.16, center.z)
	parent.add_child(cell)
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
