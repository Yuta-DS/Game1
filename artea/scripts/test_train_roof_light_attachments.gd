extends SceneTree
## Physics-triangle contact proof, independent of the runtime profile sampler.

var failed := false
const MASK := 1 << 29

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var railway := Node3D.new()
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	# Let the station's initial train placement settle before freezing this
	# geometry-only fixture. Otherwise the train moves away from its proxy.
	for i in 4:
		await process_frame
	railway.set_process(false)
	var train := railway.get_node("RainbowGalaxyTrain") as Node3D
	var decor := train.find_child("GoldenChristmasExpressDecor", true, false) as Node3D
	var faces := preload("res://scripts/train_roof_light_profile.gd").purple_faces(train)
	_check(faces.size() > 100, "the proxy contains the actual rendered purple beam triangles")
	var body := StaticBody3D.new()
	body.collision_layer = MASK
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	body.global_transform = train.global_transform
	await physics_frame
	await physics_frame
	_check(body.global_transform.is_equal_approx(train.global_transform), "beam proxy aligns with the rendered train")
	var legacy_query := PhysicsRayQueryParameters3D.create(train.to_global(Vector3(4.26, 6.8, -19.82)),
		train.to_global(Vector3(4.26, 8.3, -19.82)), MASK)
	_check(world.get_world_3d().direct_space_state.intersect_ray(legacy_query).is_empty(),
		"negative control: the former straight-row position is outside the tapered beam")
	var checked := 0
	var max_gap := 0.0
	var contacts := {}
	for mount: Node3D in decor.get_children():
		var label := String(mount.name)
		if not (label.begins_with("RoofFrameMount_00_") or label.begins_with("EngineRearRoofFrameMount_")):
			continue
		var mesh := (mount as MeshInstance3D).mesh as CylinderMesh
		var bottom := mount.position - Vector3.UP * mesh.height * 0.5
		var top := mount.position + Vector3.UP * mesh.height * 0.5
		var query := PhysicsRayQueryParameters3D.create(train.to_global(bottom - Vector3.UP * 0.2),
			train.to_global(top + Vector3.UP), MASK)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		_check(not hit.is_empty(), label + " has a real purple beam overhead")
		if hit.is_empty():
			continue
		var contact := train.to_local(hit.position)
		var gap := absf(top.y - contact.y - 0.008)
		max_gap = maxf(max_gap, gap)
		_check(gap < 0.003, label + " seats into the beam, without an air gap")
		contacts[label] = contact
		if label.begins_with("RoofFrameMount_00_"):
			var side := signf(contact.x)
			var edge_query := PhysicsRayQueryParameters3D.create(
				train.to_global(Vector3(side * 6.0, contact.y + 0.15, contact.z)),
				train.to_global(Vector3(0.0, contact.y + 0.15, contact.z)), MASK)
			var edge_hit := world.get_world_3d().direct_space_state.intersect_ray(edge_query)
			_check(not edge_hit.is_empty(), "the beam has a physical outer edge beside the socket")
			if not edge_hit.is_empty():
				var inset := absf(train.to_local(edge_hit.position).x) - absf(contact.x)
				_check(inset > 0.08 and inset < 0.16, "socket sits at the edge, not inside the cab")
		var ball_name := label.replace("RoofFrameMount_", "RoofBall_")
		var hanger_name := label.replace("RoofFrameMount_", "RoofBallHanger_")
		var socket_name := label.replace("RoofFrameMount_", "RoofEdgeSocket_")
		var ball := decor.get_node(ball_name) as MeshInstance3D
		var cap := decor.get_node(ball_name + "_GoldCap") as MeshInstance3D
		var hanger := decor.get_node(hanger_name) as MeshInstance3D
		var socket := decor.get_node(socket_name) as MeshInstance3D
		var offset: Vector3 = ball.get_meta("roof_pendant_offset", Vector3.ZERO)
		_check(Vector2(ball.position.x, ball.position.z).distance_to(Vector2(contact.x + offset.x, contact.z)) < 0.001,
			label + " suspends its ball below its connected hanger")
		_check(offset.y == 0 and offset.z == 0 and offset.x * contact.x >= 0 and offset.length() <= .801,
			"clearance offsets point outboard without changing roof contacts or pendant height")
		_check(absf(hanger.position.y + (hanger.mesh as CylinderMesh).height * 0.5 - bottom.y) < 0.001,
			label + " has a connected stem")
		if not offset.is_zero_approx():
			var arm := decor.get_node(ball_name + "_FrameClearanceArm") as MeshInstance3D
			var half_arm := arm.basis.y * (arm.mesh as CylinderMesh).height * .5
			_check((arm.position - half_arm).distance_to(bottom) < .001 \
				and (arm.position + half_arm).distance_to(bottom + offset) < .001,
				"outboard arm connects the original roof mount to the moved hanger")
		_check(socket.position.distance_to(contact) < 0.003, label + " has a flush gold edge socket")
		_check(cap.position.y - (cap.mesh as CylinderMesh).height * 0.5
			<= ball.position.y + (ball.mesh as SphereMesh).radius,
			label + " has no gap between cap and light ball")
		_check(absf(ball.position.y - (bottom.y - 0.40)) < 0.001, "consistent ornament drop")
		checked += 1
	_check(checked == 23, "all 18 side and 5 rear balls attach to the purple roof")
	if checked == 23:
		for i in 9:
			var left: Vector3 = contacts["RoofFrameMount_00_L_%02d" % i]
			var right: Vector3 = contacts["RoofFrameMount_00_R_%02d" % i]
			_check(Vector3(-left.x, left.y, left.z).distance_to(right) < 0.003,
				"side lights follow the roof symmetrically")
		_check((contacts["RoofFrameMount_00_R_08"] as Vector3).x
			- (contacts["RoofFrameMount_00_R_00"] as Vector3).x > 0.50,
			"the light row follows the tapered roof instead of floating in a straight row")
	# Parentage is also checked after a train move/turn, not just at the origin.
	var old_transform := train.global_transform
	train.position += Vector3(12, 3, -9)
	train.rotation.y += 0.4
	for label: String in contacts:
		var mount := decor.get_node(label) as MeshInstance3D
		var top := mount.to_global(Vector3.UP * (mount.mesh as CylinderMesh).height * 0.5)
		_check(top.distance_to(train.to_global(contacts[label] + Vector3.UP * 0.008)) < 0.003,
			"roof attachments travel and turn with the train")
	train.global_transform = old_transform
	print("TRAIN_ROOF_LIGHT_ATTACHMENTS: %s — %d/23 beam contacts, max error %.6fm" % [
		"FAIL" if failed else "PASS", checked, max_gap])
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("TRAIN_ROOF_LIGHT_ATTACHMENTS: " + message)
