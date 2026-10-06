extends SceneTree
## Independent physics proof against the rendered gold-frame triangles.

const MASK := 1 << 28
const Clearance := preload("res://scripts/train_light_frame_clearance.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)

func _run() -> void:
	var test_faces := PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP,
		Vector3(20, 0, 0), Vector3(20, 0, 0), Vector3(20, 0, 0)])
	_check(is_equal_approx(Clearance.distance_to_frame(Vector3(.2, .2, .3), test_faces), .3),
		"Degenerate sphere-pole triangles cannot erase the nearest frame measurement")
	var world := Node3D.new()
	root.add_child(world)
	var railway := Node3D.new()
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	for i in 4:
		await process_frame
	railway.set_process(false)
	var train := railway.get_node("RainbowGalaxyTrain") as Node3D
	var frame := train.get_node("DriverFrontWindscreen") as Node3D
	var decor := train.find_child("GoldenChristmasExpressDecor", true, false)
	var body := StaticBody3D.new()
	body.collision_layer = MASK
	body.collision_mask = 0
	for part: MeshInstance3D in frame.find_children("*", "MeshInstance3D", true, false):
		if part.get_active_material(0).resource_name != "WindscreenChampagneGold":
			continue
		var collision := CollisionShape3D.new()
		collision.shape = part.mesh.create_trimesh_shape()
		collision.shape.backface_collision = true
		body.add_child(collision)
		collision.transform = train.global_transform.affine_inverse() * part.global_transform
	world.add_child(body)
	body.global_transform = train.global_transform
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var old_collisions := 0
	var moved := 0
	var checked_balls := 0
	var minimum_gap := INF
	for ball: MeshInstance3D in decor.find_children("*", "MeshInstance3D", false, false):
		if not ball.mesh is SphereMesh or not ball.has_meta("original_pendant_position"):
			continue
		checked_balls += 1
		var radius := (ball.mesh as SphereMesh).radius
		var original: Vector3 = ball.get_meta("original_pendant_position")
		var offset: Vector3 = ball.get_meta("roof_pendant_offset")
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.collision_mask = MASK
		query.transform = Transform3D(Basis.IDENTITY, train.to_global(original))
		var collided := not space.intersect_shape(query, 1).is_empty()
		old_collisions += int(collided)
		query.transform.origin = ball.global_position
		sphere.radius = radius + .09
		_check(space.intersect_shape(query, 1).is_empty(), "Every globe clears the gold frame by at least 9 cm")
		var low := .001
		var high := 2.0
		for step in 13:
			sphere.radius = (low + high) * .5
			if space.intersect_shape(query, 1).is_empty():
				low = sphere.radius
			else:
				high = sphere.radius
		minimum_gap = minf(minimum_gap, low - radius)
		if not offset.is_zero_approx():
			moved += 1
			_check(collided, "Only intersecting pendants move")
			_check(offset.x * original.x > 0 and offset.y == 0 and offset.z == 0, "Move offending lights outboard only")
		else:
			_check(ball.position.is_equal_approx(original), "Unaffected light positions stay unchanged")
		for label in [String(ball.name) + "_GoldCap", String(ball.name).replace("RoofBall_", "RoofBallHanger_"),
				String(ball.name) + "_FrameClearanceArm"]:
			var part := decor.get_node_or_null(label) as MeshInstance3D
			if part == null:
				continue
			var fixture_query := PhysicsShapeQueryParameters3D.new()
			fixture_query.shape = part.mesh.create_convex_shape()
			fixture_query.transform = part.global_transform
			fixture_query.collision_mask = MASK
			fixture_query.margin = .035
			_check(space.intersect_shape(fixture_query, 1).is_empty(), label + " also clears the frame")
	_check(checked_balls == 23, "Check all driver side and rear globes")
	_check(old_collisions == 2 and moved == 2, "Reproduce and fix exactly the two overlapping corner globes")
	var left := decor.get_node("RoofBall_00_L_01") as Node3D
	var right := decor.get_node("RoofBall_00_R_01") as Node3D
	_check(Vector3(-left.position.x, left.position.y, left.position.z).distance_to(right.position) < .001,
		"Corrected pendants remain symmetric")
	print("TRAIN_LIGHT_FRAME_CLEARANCE: %s checks=%d old_collisions=%d moved=%d min_gap=%.4fm" % [
		"PASS" if failures.is_empty() else "FAIL", checks, old_collisions, moved, minimum_gap])
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
