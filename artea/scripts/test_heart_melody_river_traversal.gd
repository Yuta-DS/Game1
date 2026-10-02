extends SceneTree

const Preview := preload("res://scenes/heart_melody/heart_garden_preview.tscn")
const River := preload("res://scripts/heart_melody/heart_melody_river_region.gd")
var player: CharacterBody3D
var camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Preview.instantiate()
	var world = scene.get_node("HeartMelodyWorld")
	world.persist_progress = false
	root.add_child(scene)
	player = scene.get_node("Player3D")
	camera = scene.get_node("Camera3D")
	await physics_frame
	_complete_feeling_garden(world.state)
	await create_timer(1.2).timeout
	assert(not world._bridge_blocker.visible)
	player.position = Vector3(285, 5, 0)
	player.speed = 28.0
	var targets := [Vector3(305, 3, 0), Vector3(335, 3, 0), Vector3(365, 3, 0),
		Vector3(392, 3, 0), River.DEW_GROVE + Vector3(0, 0, 7), Vector3(392, 3, 0),
		River.ORGAN + Vector3(0, 0, 9), River.SUN_GROVE + Vector3(0, 0, 7),
		River.ORGAN + Vector3(0, 0, 9), Vector3(475, 3, 0),
		River.HARP + Vector3(0, 0, 9), River.BELL_GROVE + Vector3(0, 0, 7),
		River.BELLS + Vector3(0, 0, -13), River.HARP + Vector3(0, 0, 9),
		Vector3(475, 3, 0), River.ORGAN + Vector3(0, 0, 9), Vector3(392, 3, 0),
		Vector3(365, 3, 0), Vector3(335, 3, 0), Vector3(305, 3, 0)]
	for target in targets:
		if not await _walk(target):
			push_error("RIVER_TRAVERSAL blocked toward %s at %s" % [target, player.position])
			quit(1)
			return
	world.deactivate()
	scene.queue_free()
	await process_frame
	print("PASS: production player crosses the bridge and reaches every River Voice landmark in both directions")
	quit()


func _complete_feeling_garden(state) -> void:
	state.grant_story_fruit("echo_berry", 3, "river.traversal.echo")
	for index in 3: state.plant(index, "sound")
	for note in state.PHRASE: state.enter_note(note)
	state.confirm_phrase()
	for wave in state.WAVES:
		for enemy_id in wave: state.record_defeat(enemy_id)
		state.finish_wave(wave)


func _walk(target: Vector3) -> bool:
	for frame in 600:
		var offset := target - player.position
		offset.y = 0
		if offset.length() < 3.8:
			_release()
			player.velocity.x = 0
			player.velocity.z = 0
			return true
		player.speed = 7.0 if offset.length() < 8.0 else 28.0
		var direction := offset.normalized()
		var right := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
		var forward := Vector3(-camera.global_basis.z.x, 0, -camera.global_basis.z.z).normalized()
		var x := direction.dot(right)
		var z := direction.dot(forward)
		_release()
		Input.action_press("move_right", maxf(x, 0))
		Input.action_press("move_left", maxf(-x, 0))
		Input.action_press("move_forward", maxf(z, 0))
		Input.action_press("move_backward", maxf(-z, 0))
		await physics_frame
	_release()
	return false


func _release() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_backward"]:
		Input.action_release(action)
