extends SceneTree

const Preview := preload("res://scenes/heart_melody/heart_garden_preview.tscn")
var player: CharacterBody3D
var camera: Camera3D

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := Preview.instantiate()
	var world = scene.get_node("HeartMelodyWorld")
	world.persist_progress = false
	world.save_path = "user://heart_traversal_unused.json"
	root.add_child(scene)
	player = scene.get_node("Player3D")
	camera = scene.get_node("Camera3D")
	await physics_frame
	await physics_frame
	for target in [Vector3(-46,0,-18.5),Vector3(-24,0,-24.5),Vector3(-6,0,-12.5),
		Vector3(-6,0,12),Vector3(12,0,18),Vector3(35,0,3),Vector3(54,0,0),
		Vector3(12,0,18),Vector3(-42,0,19),Vector3(-70,0,0)]:
		if not await _walk(target):
			push_error("HEART_TRAVERSAL: blocked walking to %s at %s"%[target,player.position])
			quit(1)
			return
	for id in world.controls:
		if id == "help": continue
		var anchor: Marker3D = world.controls[id].anchor
		var shape := CapsuleShape3D.new()
		shape.radius = 0.5
		shape.height = 2.0
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = anchor.global_position+Vector3(0,1.05,0)
		query.collision_mask = 1
		query.exclude = [player.get_rid()]
		assert(world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"clear standing capsule: "+id)
	world.deactivate()
	scene.queue_free()
	await process_frame
	print("HEART_TRAVERSAL: PASS — continuous keyboard-driven route and clear control aprons")
	quit()

func _walk(target: Vector3) -> bool:
	for frame in 1200:
		var offset := target-player.position
		offset.y = 0
		if offset.length() < 0.8:
			_release()
			return true
		var direction := offset.normalized()
		var right := Vector3(camera.global_basis.x.x,0,camera.global_basis.x.z).normalized()
		var forward := Vector3(-camera.global_basis.z.x,0,-camera.global_basis.z.z).normalized()
		var x := direction.dot(right)
		var z := direction.dot(forward)
		_release()
		Input.action_press("move_right",maxf(x,0))
		Input.action_press("move_left",maxf(-x,0))
		Input.action_press("move_forward",maxf(z,0))
		Input.action_press("move_backward",maxf(-z,0))
		await physics_frame
	_release()
	return false

func _release() -> void:
	for action in ["move_left","move_right","move_forward","move_backward"]:
		Input.action_release(action)
