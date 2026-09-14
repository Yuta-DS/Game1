extends SceneTree
const STORE := "user://test_memory_style_family.json"
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if FileAccess.file_exists(STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = STORE
	world.get_node("QuestController").enabled = false
	root.add_child(world)
	for frame in 8:
		await process_frame
	var seen := {}
	for object in world.get_quest_objects():
		var kind := int(object.definition.object_kind)
		if object.save_id in ["world_one.checkpoint.landing", "world_one.path_projector"]:
			var apron: AABB = object.global_transform * AABB(Vector3(-1.4,.2,-.8),Vector3(2.8,2.8,2.8))
			for mesh in world.find_children("*","MeshInstance3D",true,false):
				if not mesh.is_visible_in_tree() or object.is_ancestor_of(mesh): continue
				var bounds: AABB = mesh.global_transform * mesh.get_aabb()
				# Joined island-wide art needs triangle-level inspection, not this small-prop test.
				if bounds.size.length() < 80:
					assert(not apron.intersects(bounds), "Station apron intersects " + str(mesh.get_path()))
		if kind == 3 or seen.has(kind):
			continue
		seen[kind] = true
		var model := object.get_node("VisualRoot/BlenderModel") as Node3D
		assert(model.get_meta("memory_style_family",false))
		assert(object.get_meta("preserve_authored_nodes",false))
		assert(model.find_children("*","MeshInstance3D",true,false).size() <= 7)
		assert(not object.prompt.text.contains("\n"))
		assert(object.prompt.font_size == 24)
		assert(is_equal_approx(object.prompt.position.y-object.status.position.y,.18))
		if kind not in [4,5,8]:
			assert(model.get_node("ActionCaption").text != "")
		assert(not object._find_blender_part("Status0").visible)
		var collisions := object.find_children("*","CollisionShape3D",true,false).size()
		assert(collisions > 0)
		object.interaction_enabled = true
		match kind:
			0: object.interact(&"place_spark")
			1: object.interact(&"scan")
			2: object.interact(&"turn")
			4: object.interact(&"place_evidence")
			5: object.interact(&"true")
			6: object.interact(&"help")
			7:
				object.interact(&"dodge")
				object.interact(&"strike")
			8: object.interact(&"hold")
			9: object.interact(&"answer_a", "outward")
			10: object.interact(&"save")
			11: object.interact(&"toggle")
		assert(object.find_children("*","CollisionShape3D",true,false).size() == collisions)
		if kind in [0,1,2,4,5,6,8,11]:
			assert(object._find_blender_part("Status0").visible)
		if kind == 0:
			assert(object._find_blender_part("Charge0").visible)
			assert(not object._find_blender_part("Charge1").visible)
		if kind in [5,6,7,8,9,10,11]:
			assert(object._find_blender_part("Status1") == null)
		if kind == 6:
			var arrow = object.visual_root.get_node("HintArrow")
			assert(arrow.visible and arrow.modulate.a == 1.0 and arrow.transparency == 0.0)
			assert(arrow.position.y > object.prompt.position.y)
		if kind == 8:
			var rain = object.visual_root.get_node("GentleRain")
			assert(rain.visible and rain.emitting)
		if kind == 11:
			for marker in object.visual_root.get_node("RouteDots").get_children():
				if marker is GeometryInstance3D: assert(marker.transparency == 0.0)
		if kind == 4:
			assert(object._find_blender_part("Status2") == null)
			var closed_y := object._find_blender_part("Mechanism").position.y
			object.interact(&"place_evidence")
			assert(is_equal_approx(object._find_blender_part("Mechanism").position.y,closed_y+1.6))
		var saved := object.current_state.duplicate(true)
		object.configure(object.definition,object.save_id,STORE)
		assert(JSON.parse_string(JSON.stringify(object.current_state)) == JSON.parse_string(JSON.stringify(saved)), "State reload mismatch: %s / %s" % [object.current_state,saved])
		for geometry in object.get_node("VisualRoot").find_children("*","GeometryInstance3D",true,false):
			if not object.get_node("VisualRoot/BlenderModel").is_ancestor_of(geometry):
				if geometry.name in ["PathBeam", "HintArrow", "SafeArrow", "GentleRain"] or geometry.get_parent().name == "RouteDots":
					continue
				assert(not geometry.visible)
		if "--capture" in OS.get_cmdline_user_args():
			if not await _capture(world,object):
				quit(1)
				return
	assert(seen.size()==11)
	world.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	print("MEMORY_STYLE_FAMILY: PASS — 11 types, compact textured models, live state, gate motion, retained collisions and reload")
	quit()

func _capture(world: Node3D, object: QuestObjectBase) -> bool:
	root.size=Vector2i(1280,720)
	root.msaa_3d=Viewport.MSAA_4X
	if root.get_node_or_null("WorldEnvironment")==null:
		var containing=load("res://scenes/art_castle_floating_world.tscn").instantiate()
		for name in ["WorldEnvironment","Sun","FillLight"]:
			var light=containing.get_node(name)
			containing.remove_child(light)
			light.owner=null
			root.add_child(light)
		containing.free()
	var camera:=Camera3D.new()
	camera.fov=55
	world.add_child(camera)
	var gate:=object.definition.object_kind==QuestObjectDefinition.ObjectKind.LOGIC_GATE_ARCH
	camera.global_position=object.to_global(Vector3(.65,2.1 if gate else 1.7,5.8 if gate else 3.4))
	camera.look_at(object.to_global(Vector3(0,1.7 if gate else .95,0)))
	camera.make_current()
	await create_timer(1).timeout
	if camera.environment == null or not is_equal_approx(camera.environment.tonemap_exposure,.82):
		push_error("Station lighting mismatch: " + object.save_id)
		return false
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute("res://artifacts/memory_style_family")
	assert(root.get_texture().get_image().save_png("res://artifacts/memory_style_family/%02d.png" % int(object.definition.object_kind))==OK)
	camera.queue_free()
	await process_frame
	return true
