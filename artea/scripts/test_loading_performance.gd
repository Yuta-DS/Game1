extends SceneTree

const Warmup := preload("res://scripts/shader_warmup.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Use the real construction helpers: sharing geometry must not share a
	# transform or change a differently sized collision surface.
	var railway = load("res://scripts/art_castle_story_railway.gd").new()
	var host := Node3D.new()
	var material := StandardMaterial3D.new()
	railway._add_box(host, "First", Vector3.ZERO, Vector3(2, 3, 4), material, true)
	railway._add_box(host, "Repeated", Vector3(10, 0, 0), Vector3(2, 3, 4), material, true)
	railway._add_box(host, "Different", Vector3.ZERO, Vector3(5, 3, 4), material, true)
	assert(host.get_node("First").mesh == host.get_node("Repeated").mesh,
		"Repeated railway fittings share one vertex buffer")
	assert(host.get_node("First").mesh != host.get_node("Different").mesh,
		"Different geometry must not reuse the wrong dimensions")
	assert(host.get_node("Repeated").position == Vector3(10, 0, 0))
	assert(host.get_node("DifferentCollision/CollisionShape3D").shape.size == Vector3(5, 3, 4),
		"Mesh sharing preserves individual collisions")
	host.free()
	railway.free()
	Engine.remove_meta(Warmup.CACHE_META)
	var first := StandardMaterial3D.new()
	var same_program := StandardMaterial3D.new()
	same_program.albedo_color = Color.RED
	var other_program := StandardMaterial3D.new()
	other_program.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var materials: Array[Material] = [first, other_program]
	Warmup.remember_warmed(materials, 1)
	var revisited: Array[Material] = [same_program, other_program]
	var pending := Warmup.unwarmed(revisited)
	assert(pending.size() == 1 and pending[0] == other_program,
		"Re-entry reuses warmed programs but still compiles unseen variants")
	var shader_a := Shader.new()
	shader_a.code = "shader_type spatial; void fragment() { ALBEDO = vec3(1.0); }"
	var shader_b := Shader.new()
	shader_b.code = shader_a.code
	var material_a := ShaderMaterial.new()
	material_a.shader = shader_a
	var material_b := ShaderMaterial.new()
	material_b.shader = shader_b
	Warmup.remember_warmed([material_a], 1)
	assert(Warmup.unwarmed([material_b]).is_empty(), "Reloaded identical shader sources reuse warmup")
	shader_b.code = "shader_type spatial; render_mode unshaded; void fragment() { ALBEDO = vec3(1.0); }"
	assert(Warmup.unwarmed([material_b]).size() == 1, "Modified shader programs must warm again")
	# Distant streaming cells start hidden. Their ordinary and instanced
	# materials must still be prepared before the first camera turn.
	var district := Node3D.new()
	district.hide()
	var mesh := BoxMesh.new()
	mesh.material = other_program
	var distant := MeshInstance3D.new()
	distant.mesh = mesh
	district.add_child(distant)
	var instances := MultiMeshInstance3D.new()
	instances.multimesh = MultiMesh.new()
	instances.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	instances.multimesh.mesh = mesh
	instances.material_override = material_b
	district.add_child(instances)
	var hidden_materials := Warmup.collect(district)
	assert(hidden_materials.has(other_program) and hidden_materials.has(material_b),
		"Hidden and instanced world materials are included in loading warmup")
	var rig := Warmup.build_rig(hidden_materials)
	assert(Warmup.warm_node_count(rig) == hidden_materials.size() * 2,
		"Prepare both ordinary and instanced shader variants")
	rig.free()
	district.free()
	var loader = load("res://scenes/loading_scene.tscn").instantiate()
	loader._main_viewport = root
	loader._previous_disable_3d = false
	loader._restore_3d = true
	root.disable_3d = true
	loader._restore_world_rendering()
	assert(not root.disable_3d, "Cancelling a load restores the main viewport")
	loader._previous_disable_3d = true
	loader._restore_3d = true
	loader._restore_world_rendering()
	assert(root.disable_3d, "Restore respects a viewport that was already 2D-only")
	root.disable_3d = false
	loader.free()
	Engine.remove_meta(Warmup.CACHE_META)
	print("LOADING PERFORMANCE: PASS")
	quit()
