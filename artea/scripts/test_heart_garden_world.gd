extends SceneTree

const Preview := preload("res://scenes/heart_melody/heart_garden_preview.tscn")
const World := preload("res://scripts/heart_melody/heart_garden_world.gd")
const Enemy := preload("res://scripts/heart_melody/heart_garden_enemy.gd")
var scene: Node3D
var world: World
var player: CharacterBody3D

func _init() -> void:
	call_deferred("_run")

func _press(text: String) -> void:
	for child in world.panel_content.get_children():
		if child is Button and child.text == text:
			child.pressed.emit()
			return
	push_error("Missing button: "+text)
	quit(1)

func _run() -> void:
	scene = Preview.instantiate()
	world = scene.get_node("HeartMelodyWorld")
	world.persist_progress = false
	world.save_path = "user://heart_world_test_unused.json"
	root.add_child(scene)
	player = scene.get_node("Player3D")
	await process_frame
	await physics_frame
	for i in 3:
		var anchor: Marker3D = world.controls["planter_%d"%i].anchor
		player.global_position = anchor.global_position+Vector3.UP
		assert(world.nearest_control(player.global_position) == "planter_%d"%i)
		world.open_control("planter_%d"%i)
		_press("Choose a sound instead")
		_press("Cancel")
		assert(world.state.planted_count() == i,"cancel creates no seed")
		world.open_control("planter_%d"%i)
		_press("Hope")
		_press("Plant this seed")
		assert(world.state.planted_count() == i+1)
	world.open_control("phrase")
	_press("Play Leaf")
	_press("Play Droplet")
	_press("Play Sun")
	_press("Confirm phrase")
	assert(not world.state.data.rhythm_solved)
	_press("Undo last note")
	_press("Undo last note")
	_press("Play Sun")
	_press("Play Droplet")
	_press("Confirm phrase")
	assert(world.state.data.rhythm_solved)
	world._close_panel()
	for wave in 2:
		player.global_position = Vector3(54,1,8)
		world.open_control("encounter")
		_press("Enter the clearing")
		assert(world._encounter != null)
		await physics_frame
		var enemies: Array = world._encounter.get_children()
		for enemy in enemies:
			var enemy_id: String = enemy.enemy_id
			# Set a long recovery window, then exercise the actual player's sword volume.
			enemy.phase = Enemy.Phase.RECOVERY
			enemy.remaining = 60.0
			enemy.global_position = Vector3(54,0,0)
			player.global_position = Vector3(54,1,-2.5)
			player.get_node("FoxVisuals").rotation.y = 0
			for hit in 2:
				player.call("_finish_attack")
				player.call("_start_attack")
				for frame in 5: await physics_frame
			assert(world.state.data.xp_receipts.has(enemy_id),"real sword hits release the shell")
			await process_frame
		await process_frame
		assert(world.state.current_wave() == wave+1)
	assert(world.state.complete() and world.state.xp() == 119)
	if world._bridge_opening:
		assert(world._bridge_blocker.visible,"crossing stays blocked until growth finishes")
		await create_timer(1.2).timeout
	assert(world._bridge.visible and not world._bridge_blocker.visible)
	player.global_position = Vector3(12,-25,15)
	await process_frame
	assert(player.global_position.y > 0 and world.state.complete(),"fall recovery preserves completion")
	world.deactivate()
	scene.queue_free()
	await process_frame
	print("HEART_GARDEN_WORLD: PASS — real UI planting/revision, sword contacts, two waves, restoration and fall recovery")
	quit()
