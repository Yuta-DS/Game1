extends SceneTree


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://capture_root_stalker.json"
	world.get_node("QuestController").enabled = false
	root.add_child(world)
	var creature: MindSparkEnemyBase
	for enemy in world.get_enemies():
		if enemy.definition.enemy_kind == MindSparkEnemyDefinition.EnemyKind.ROOT_STALKER:
			creature = enemy
			break
	assert(creature != null)
	creature.reparent(root, true)
	creature.visible = true
	world.visible = false
	creature.name_label.visible = false
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(24, 24)
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.position = creature.global_position - Vector3.UP * 0.04
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("e8dfc5")
	floor.material_override = floor_material
	root.add_child(floor)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.3
	root.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 48
	camera.position = creature.global_position + Vector3(5, 4.5, 10)
	root.add_child(camera)
	camera.look_at(creature.global_position + Vector3.UP * 1.2)
	camera.make_current()
	await create_timer(1.4).timeout
	RenderingServer.force_draw(false)
	var output := "res://artifacts/root_stalker_gameplay.png"
	assert(root.get_texture().get_image().save_png(output) == OK)
	print("ROOT_STALKER_CAPTURE: ", ProjectSettings.globalize_path(output))
	quit()
