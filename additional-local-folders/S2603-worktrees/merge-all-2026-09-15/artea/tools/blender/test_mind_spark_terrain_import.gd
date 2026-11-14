extends SceneTree
## Run in a disposable Godot project containing this kit's manifest/parts/assemblies.

var errors: Array[String] = []
var checked := 0
var ray_checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://manifest.json"))
	var world := Node3D.new()
	root.add_child(world)
	for spec: Dictionary in manifest["assets"]:
		var path: String = "res://" + str(spec["glb"])
		var packed := load(path) as PackedScene
		if packed == null:
			errors.append("Cannot load " + path)
			continue
		var asset := packed.instantiate() as Node3D
		world.add_child(asset)
		var meshes: Array[Node] = asset.find_children("*", "MeshInstance3D", true, false)
		var shapes: Array[Node] = asset.find_children("*", "CollisionShape3D", true, false)
		if meshes.size() != int(spec["mesh_instances"]):
			errors.append("%s: visual mesh count expected %d, got %d" % [spec["id"],spec["mesh_instances"],meshes.size()])
		if shapes.size() != int(spec["collisions"]):
			errors.append("%s: collision count expected %d, got %d" % [spec["id"],spec["collisions"],shapes.size()])
		for node: MeshInstance3D in meshes:
			if str(node.name).begins_with("COL_"):
				errors.append(str(spec["id"]) + ": collision proxy remained visible")
			for surface in range(node.mesh.get_surface_count()):
				if node.mesh.surface_get_material(surface) == null:
					errors.append(str(spec["id"]) + ": missing imported material")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		if spec["id"] == "05_ramp_stair":
			for i in range(41):
				var forward := 0.03 + float(i) * 3.54 / 40.0
				_check_surface(space, 1.0, forward, forward / 12.0, "ramp")
			for i in range(11):
				_check_surface(space, 1.0, 3.61 + float(i) * 0.14, 0.3, "ramp landing")
		elif spec["id"] == "02_civic_deck":
			for x in range(-3,4):
				for y in range(-3,4):
					_check_surface(space, float(x), float(y), 0.0, "deck")
		elif spec["id"] == "04_bridge_foundation":
			_check_surface(space,0.0,0.0,0.0,"bridge landing")
		elif spec["id"] == "06_cliff_ledge":
			_check_surface(space,0.0,0.75,0.0,"ledge")
		checked += 1
		asset.free()
	var report := {"passed": errors.is_empty(),"assets_loaded": checked,"surface_ray_checks": ray_checks,
		"errors": errors,"scope":"isolated import and physics geometry; not live gameplay or deployment"}
	var output := FileAccess.open("res://godot_validation_report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  "))
	output.close()
	print("[MST GODOT] ",JSON.stringify(report))
	world.free()
	quit(0 if errors.is_empty() else 1)


func _check_surface(space: PhysicsDirectSpaceState3D, x: float, forward: float, expected: float, label: String) -> void:
	# Blender X,Y,Z converts to Godot X,Z,-Y.
	var query := PhysicsRayQueryParameters3D.create(Vector3(x,3.0,-forward),Vector3(x,-2.0,-forward))
	var hit := space.intersect_ray(query)
	ray_checks += 1
	if hit.is_empty():
		errors.append("%s: no surface at %.3f, %.3f" % [label,x,forward])
	elif absf(float(hit.position.y) - expected) > 0.015:
		errors.append("%s: surface height %.4f, expected %.4f" % [label,hit.position.y,expected])
