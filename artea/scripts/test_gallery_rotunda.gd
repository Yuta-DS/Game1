extends SceneTree
## The oval sky-roof gallery: the doorway is open from the bridge, the floor
## carries the player in, the walls enclose the hall, the roof stays behind the
## entrance façade, and every canvas hangs on the wall facing into the room.

const Rotunda := preload("res://scripts/gallery_rotunda.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("GALLERY_ROTUNDA_TEST: FAIL — " + message)
	print("GALLERY_ROTUNDA_TEST: FAIL — " + message)
	quit(1)


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3,
		exclude: Array[RID]) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	return space.intersect_ray(query)


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 5:
		await physics_frame
	var rotunda := gallery.get_node_or_null("GalleryRotunda") as Node3D
	if rotunda == null or rotunda.get_node_or_null("RotundaCollision") == null:
		_fail("the rotunda or its collision was not built")
		return
	var player := gallery.get_node("Player3D") as CharacterBody3D
	var space := (gallery as Node3D).get_world_3d().direct_space_state
	var skip: Array[RID] = [player.get_rid()]

	# Walk-in route: from the bridge, through the door, to the bench.
	for z in [19.5, 16.0, 10.0, 0.0, -10.0]:
		var hit := _ray(space, Vector3(0, 5, z), Vector3(0, -2, z), skip)
		# The bridge's threshold slope rises from the floor 8 m inside the doorway.
		if hit.is_empty() or (hit.position as Vector3).y < Rotunda.FLOOR_TOP - 0.05 \
				or (hit.position as Vector3).y > 0.6:
			_fail("no walkable floor at z=%.1f on the entrance route" % z)
			return
	for x in [-5.0, 0.0, 5.0]:
		if not _ray(space, Vector3(x, 1.5, 26.0), Vector3(x, 1.5, -12.0), skip).is_empty():
			_fail("the doorway is blocked at x=%.1f" % x)
			return

	# The walls enclose the hall all the way round (bar the doorway).
	var centre := Rotunda.CENTRE + Vector3(0, 3.0, 0)
	for i in 36:
		var t := TAU * float(i) / 36.0
		var outward := Vector3(cos(t), 0, sin(t))
		if outward.z > 0.9:
			continue
		if _ray(space, centre + outward * 12.0, centre + outward * 90.0, skip).is_empty():
			_fail("a player could walk out through the wall at angle %d°" % (i * 10))
			return

	# The glass roof never reaches past the entrance façade over the bridge.
	for mesh_name in ["SkyRoofGlass", "GoldTrim"]:
		var mesh := rotunda.get_node_or_null(mesh_name) as MeshInstance3D
		if mesh == null:
			_fail("%s mesh is missing" % mesh_name)
			return
	var roof := (rotunda.get_node("SkyRoofGlass") as MeshInstance3D).get_aabb()
	if roof.end.z > Rotunda.ENTRANCE_FRONT_Z:
		_fail("the sky roof pokes out in front of the entrance (z=%.2f)" % roof.end.z)
		return

	# Every canvas hangs inside the hall, close to the wall, facing inward.
	for index in 12:
		var frame := gallery.get_node("Frame_%02d" % (index + 1)) as Node3D
		var p := frame.global_position - Rotunda.CENTRE
		var e := sqrt(pow(p.x / Rotunda.RADIUS_X, 2) + pow(p.z / Rotunda.RADIUS_Z, 2))
		if e > 1.0 or e < 0.97:
			_fail("%s is not hung on the oval wall (e=%.3f)" % [frame.name, e])
			return
		var inward := -Vector3(p.x / pow(Rotunda.RADIUS_X, 2), 0, p.z / pow(Rotunda.RADIUS_Z, 2)).normalized()
		if frame.global_basis.z.normalized().dot(inward) < 0.95:
			_fail("%s does not face into the room" % frame.name)
			return

	print("GALLERY_ROTUNDA_TEST: PASS — open doorway, walkable floor, enclosed oval, roof behind façade, canvases hung facing in")
	quit()
