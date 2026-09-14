extends SceneTree

const Preview := preload("res://scenes/heart_melody/heart_garden_preview.tscn")
const Layout := preload("res://scripts/heart_melody/heart_garden_layout.gd")
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
	assert(is_equal_approx(player.speed, 10.0), "Heart Melody keeps the approved normal speed")
	player.speed = 40.0 # Accelerate only this automated traversal after checking runtime speed.
	var targets: Array[Vector3] = [Vector3(-88,2,0)]
	for point in Layout.ROUTE:
		targets.append(point)
	for index in range(Layout.ROUTE.size() - 1, -1, -1):
		targets.append(Layout.ROUTE[index])
	for target in targets:
		if not await _walk(target):
			push_error("HEART_TRAVERSAL: blocked walking to %s at %s"%[target,player.position])
			quit(1)
			return
	for id in world.controls:
		if id == "help": continue
		var anchor: Marker3D = world.controls[id].anchor
		var shape := CapsuleShape3D.new()
		shape.radius = 0.45
		shape.height = 1.0
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = anchor.global_position+Vector3(0,1.35,0)
		query.collision_mask = 1
		query.exclude = [player.get_rid()]
		assert(world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"clear standing capsule: "+id)
	world.deactivate()
	scene.queue_free()
	await process_frame
	print("HEART_TRAVERSAL: PASS — continuous keyboard-driven route and clear control aprons")
	quit()

func _walk(target: Vector3) -> bool:
	for frame in 900:
		var offset := target-player.position
		offset.y = 0
		# Slow the automation near each waypoint so its accelerated test speed does
		# not orbit around a small target while the production speed remains 10 m/s.
		player.speed = 5.0 if offset.length() < 10.0 else 40.0
		if offset.length() < 4.4:
			_release()
			player.velocity.x = 0.0
			player.velocity.z = 0.0
			player.speed = 40.0
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
	print("TRAVERSAL_TIMEOUT velocity=", player.velocity, " camera_x=", camera.global_basis.x,
		" camera_z=", camera.global_basis.z, " input_enabled=", player.input_enabled,
		" on_floor=", player.is_on_floor())
	for collision_index in player.get_slide_collision_count():
		var collision := player.get_slide_collision(collision_index)
		print("  COLLIDER ", collision.get_collider().get_path(), " normal=", collision.get_normal())
	return false

func _release() -> void:
	for action in ["move_left","move_right","move_forward","move_backward"]:
		Input.action_release(action)
