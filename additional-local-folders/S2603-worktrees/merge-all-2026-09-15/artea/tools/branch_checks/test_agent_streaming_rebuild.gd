extends SceneTree

# External audit test: not part of the remote branch's authored baseline.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var distant := Node3D.new()
	distant.position.x = 2000.0
	world.add_child(distant)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	distant.add_child(mesh)
	var retired := MeshInstance3D.new()
	retired.mesh = BoxMesh.new()
	retired.visible = false
	world.add_child(retired)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	distant.add_child(body)
	var eye := Node3D.new()
	root.add_child(eye)
	var director = load("res://scripts/world_streaming_director.gd").new()
	director.world_root = world
	director.player = eye
	world.add_child(director)
	director.set_process(false)
	director.call("_build_cells")
	director.call("_apply", true)
	var hidden_at_distance := not distant.visible
	director.call("rebuild")
	eye.position.x = 2000.0
	director.call("_apply", true)
	var restored_on_approach := distant.visible
	var preserves_authored_hidden := not retired.visible
	var preserves_collision := not shape.disabled and body.collision_layer == 1
	print("STREAMING_REBUILD: hidden_at_distance=%s restored_on_approach=%s cells=%d" %
		[hidden_at_distance, restored_on_approach, director.call("get_cell_count")])
	world.free()
	eye.free()
	if not hidden_at_distance or not restored_on_approach or not preserves_authored_hidden or not preserves_collision:
		push_error("Streaming rebuild lost a previously culled cell; approaching it must restore visibility")
		quit(1)
	else:
		print("STREAMING_REBUILD: PASS")
		quit(0)
