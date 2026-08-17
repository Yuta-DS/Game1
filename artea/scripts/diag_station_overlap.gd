extends SceneTree
## Audits every Crown Line dock station for geometry that intersects the access
## stairs, and for stations whose own footprints overlap each other.
const RAILWAY := preload("res://scripts/art_castle_story_railway.gd")

func _init() -> void: call_deferred("_run")

func _aabb(body: StaticBody3D) -> AABB:
	var cs := body.get_child(0) as CollisionShape3D
	if cs == null or not (cs.shape is BoxShape3D):
		return AABB()
	var size: Vector3 = (cs.shape as BoxShape3D).size
	var xf: Transform3D = body.global_transform * cs.transform
	var out := AABB(xf.origin, Vector3.ZERO)
	for sx in [-0.5, 0.5]:
		for sy in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				out = out.expand(xf * Vector3(size.x * sx, size.y * sy, size.z * sz))
	return out

func _run() -> void:
	var host := Node3D.new(); root.add_child(host)
	var r := Node3D.new(); r.set_script(RAILWAY); host.add_child(r)
	for _i in 80:
		await process_frame
		await physics_frame

	var ramps: Array = []
	for n in host.find_children("AccessRamp", "Node3D", true, false):
		ramps.append(n)
	print("stations found: %d" % ramps.size())

	var station_boxes: Array = []
	var issues := 0
	for i in ramps.size():
		var ramp := ramps[i] as Node3D
		var station := ramp.get_parent() as Node3D
		var title: String = str(RAILWAY.STATIONS[i]["title"]) if i < RAILWAY.STATIONS.size() else "?"
		var col := ramp.get_node_or_null("WalkableStairRampCollision") as StaticBody3D
		if col == null:
			print("[%s] MISSING stair collision" % title); issues += 1; continue
		var stair := _aabb(col)
		# Shrink slightly so shared touching faces are not reported as overlaps.
		var probe := stair.grow(-0.12)
		print("--- [%s] stair AABB pos=%s size=%s" % [title, stair.position, stair.size])

		# Any other solid body in this station that cuts into the stair volume.
		for body in station.find_children("*", "StaticBody3D", true, false):
			var b := body as StaticBody3D
			if b == col or b.get_parent() == ramp:
				continue
			var other := _aabb(b)
			if other.size == Vector3.ZERO:
				continue
			if probe.intersects(other):
				var inter := probe.intersection(other)
				# Ignore slivers: only report a real volumetric bite.
				if inter.size.x > 0.25 and inter.size.y > 0.25 and inter.size.z > 0.25:
					print("    OVERLAP: %-34s intersect=%s" % [b.name, inter.size])
					issues += 1
		station_boxes.append([title, _aabb(station.get_node_or_null("@StaticBody3D@1072") as StaticBody3D) if false else stair])

	# Station-to-station separation.
	print("--- station separation")
	for i in station_boxes.size():
		for j in range(i + 1, station_boxes.size()):
			var a: AABB = station_boxes[i][1]
			var b: AABB = station_boxes[j][1]
			var d: float = a.position.distance_to(b.position)
			var flag := "OK" if not a.intersects(b) else "OVERLAP"
			print("    %-14s <-> %-14s dist=%9.1f  %s" % [station_boxes[i][0], station_boxes[j][0], d, flag])
			if a.intersects(b): issues += 1

	print("ISSUES: %d" % issues)
	quit()
