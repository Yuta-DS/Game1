extends SceneTree

const BaseScene := preload("res://scenes/mind_spark/quest_objects/quest_object_base.tscn")
const Catalog := preload("res://scripts/mind_spark/quest_objects/quest_object_catalog.gd")
const Store := preload("res://scripts/mind_spark/quest_objects/quest_object_state_store.gd")

const TEST_STORE := "user://test_mind_spark_quest_objects.json"
const TEST_IDENTITY := "user://test_mind_spark_identity.json"
const AUTHORED_MODEL_DIR := "res://scenes/mind_spark/quest_objects/models/"
const MIN_VISIBLE_MESHES := 10


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Store.new(TEST_STORE).clear()
	var tracker := root.get_node_or_null("PlayerIdentityTracker")
	assert(tracker != null, "identity tracker is an autoload")
	tracker.save_path = TEST_IDENTITY
	tracker.clear_evidence()
	var silhouette_signatures: Dictionary = {}
	var foley_profiles: Dictionary = {}

	for index in 12:
		var definition := Catalog.definition_at(index)
		assert(definition != null, "object resource %02d loads" % (index + 1))
		var object: QuestObjectBase = await _spawn(index, "shape.%02d" % index)
		assert(object.has_node("InteractionArea/CollisionShape3D"), "shared Area3D interaction exists")
		assert(object.has_node("Prompt") and object.has_node("AnimationPlayer"), "shared prompt and optional animation exist")
		assert(not object.save_id.is_empty(), "every object has a save id")
		var model_path := str(object.get_meta("authored_model_path", ""))
		assert(model_path.begins_with(AUTHORED_MODEL_DIR) and model_path.ends_with("_model.tscn"),
			"%s references a dedicated checked-in model scene" % definition.display_name)
		assert(ResourceLoader.exists(model_path),
			"%s loads a checked-in authored 3D model scene" % definition.display_name)
		assert(load(model_path) is PackedScene, "%s model asset is a PackedScene" % definition.display_name)
		assert(not bool(object.get_meta("runtime_procedural_visuals", true)),
			"%s does not construct its visible model procedurally at runtime" % definition.display_name)
		_assert_blender_model(object)
		_assert_authored_surface_texture(object)
		_assert_real_model_geometry(object)
		_assert_specialized_children(index, object)
		object.call("_play_tone")
		var feedback_stream := object.feedback_sound.stream as AudioStreamWAV
		assert(feedback_stream != null and feedback_stream.mix_rate == 48000 and not feedback_stream.stereo,
			"%s uses 48 kHz mono positional Foley" % definition.display_name)
		var foley_event := String(feedback_stream.get_meta("foley_event", ""))
		assert(not foley_event.is_empty(), "%s identifies its physical sound profile" % definition.display_name)
		foley_profiles[foley_event] = true
		var signature := _silhouette_signature(object)
		silhouette_signatures[signature] = int(silhouette_signatures.get(signature, 0)) + 1
		if index == 6:
			assert(not object.hint_timer.is_stopped(), "only the Focus Bell arms the 45-second help timer")
		else:
			assert(object.hint_timer.is_stopped(), "%s does not emit unrelated timed hints" % definition.display_name)
		object.queue_free()
		await process_frame
	assert(silhouette_signatures.size() >= 10,
		"the twelve authored assets have distinguishable mesh-count and bounding-box silhouettes")
	assert(foley_profiles.size() == 12, "all twelve quest-object kinds have distinct Foley profiles")

	await _test_socket_persistence_and_save_order()
	await _test_scanner_lens_and_sequences()
	await _test_gate_bridge_and_support()
	await _test_boss_sanctuary_identity_checkpoint()
	Store.new(TEST_STORE).clear()
	tracker.clear_evidence()
	if FileAccess.file_exists(TEST_IDENTITY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_IDENTITY))
	print("Mind Spark quest objects: all checks passed")
	quit()


func _assert_specialized_children(index: int, object: QuestObjectBase) -> void:
	var required_paths := {
		0: ["VisualRoot/SparkReceiverBowl", "VisualRoot/SocketCrown", "VisualRoot/CentralSpark", "VisualRoot/SparkBeam", "VisualRoot/Pip1", "VisualRoot/Pip2", "VisualRoot/Pip3"],
		1: ["VisualRoot/ScannerFrame", "VisualRoot/ScannerGlass", "VisualRoot/ScannerCrystal", "VisualRoot/FactButton", "VisualRoot/FearButton"],
		2: ["VisualRoot/LensBody", "VisualRoot/LensBody/LensCrystal", "VisualRoot/PathBeam"],
		3: ["VisualRoot/ConstellationFrame", "VisualRoot/ConstellationSlate", "VisualRoot/Socket1", "VisualRoot/Socket2", "VisualRoot/Socket3", "VisualRoot/MemoryLink1", "VisualRoot/MemoryLink2"],
		4: ["VisualRoot/LogicPillar", "VisualRoot/LogicLintel", "VisualRoot/GateCrownCrystal", "VisualRoot/EvidenceSocket1", "VisualRoot/EvidenceSocket2", "VisualRoot/Door", "VisualRoot/PathBeam"],
		5: ["VisualRoot/BridgeTile/CollisionShape3D", "VisualRoot/BridgeTile/CircuitTile", "VisualRoot/TileCircuitRing", "VisualRoot/CompletionCrystal"],
		6: ["VisualRoot/BellShrine", "VisualRoot/FocusBell", "VisualRoot/BellRim", "VisualRoot/HintArrow", "HintTimer"],
		7: ["VisualRoot/AnchorBody", "VisualRoot/AnchorBody/CrystalSpine", "VisualRoot/AnchorBody/Hurtbox", "VisualRoot/SafeArrow"],
		8: ["VisualRoot/RainBasin", "VisualRoot/RainBasinRim", "VisualRoot/StormCloud", "VisualRoot/CalmHeart", "VisualRoot/GentleRain"],
		9: ["VisualRoot/ReflectionSurface", "VisualRoot/MirrorFrame"],
		10: ["VisualRoot/ServerConsole", "VisualRoot/ServerRootTrunk", "VisualRoot/LivingRootBranch", "VisualRoot/MenuButton0", "VisualRoot/MenuButton1", "VisualRoot/MenuButton2"],
		11: ["VisualRoot/RouteProjector", "VisualRoot/RouteDots", "VisualRoot/RouteDots/Goal"],
	}
	for path in required_paths[index]:
		assert(object.has_node(path), "%s includes functional child %s" % [object.definition.display_name, path])
	assert(object.prompt.text.contains("0/") or index in [6, 9, 10, 11],
		"%s shows visible progress or an explicit optional/service state" % object.definition.display_name)


func _assert_real_model_geometry(object: QuestObjectBase) -> void:
	var visual_root := object.get_node("VisualRoot") as Node3D
	var meshes := visual_root.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() >= MIN_VISIBLE_MESHES,
		"%s is a composed 3D asset with at least %d visible mesh parts" % [object.definition.display_name, MIN_VISIBLE_MESHES])
	assert(visual_root.find_children("*", "Sprite3D", true, false).is_empty(),
		"%s does not use a generated flat-image/Sprite3D stand-in" % object.definition.display_name)
	for mesh_node in meshes:
		var mesh_instance := mesh_node as MeshInstance3D
		assert(mesh_instance.mesh != null, "%s contains no empty mesh placeholders" % object.definition.display_name)


func _assert_blender_model(object: QuestObjectBase) -> void:
	var blender_path := str(object.get_meta("blender_model_path", ""))
	assert(blender_path.begins_with("res://assets3D/mind_spark/quest_objects/glb/")
		and blender_path.ends_with(".glb"),
		"%s uses its dedicated Blender GLB" % object.definition.display_name)
	assert(ResourceLoader.exists(blender_path) and load(blender_path) is PackedScene,
		"%s Blender GLB imports as a Godot PackedScene" % object.definition.display_name)
	assert(bool(object.get_meta("blender_rendering", false)),
		"%s visible runtime geometry comes from Blender" % object.definition.display_name)
	var blender_model := object.get_node_or_null("VisualRoot/BlenderModel") as Node3D
	assert(blender_model != null, "%s instances its Blender model" % object.definition.display_name)
	var lod0_nodes := blender_model.find_children("LOD0*", "Node3D", true, false)
	var lod1_nodes := blender_model.find_children("LOD1*", "Node3D", true, false)
	var lod2_nodes := blender_model.find_children("LOD2*", "Node3D", true, false)
	var lod0 := lod0_nodes[0] as Node3D if not lod0_nodes.is_empty() else null
	var lod1 := lod1_nodes[0] as Node3D if not lod1_nodes.is_empty() else null
	var lod2 := lod2_nodes[0] as Node3D if not lod2_nodes.is_empty() else null
	assert(lod0 != null and lod0.visible, "%s displays Blender LOD0" % object.definition.display_name)
	assert(lod1 != null and not lod1.visible and lod2 != null and not lod2.visible,
		"%s keeps lower Blender LODs available but hidden" % object.definition.display_name)
	var visible_mesh_count := 0
	for mesh_node in lod0.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.visible and not mesh_instance.name.begins_with("UCX_"):
			visible_mesh_count += 1
		if mesh_instance.name.begins_with("UCX_"):
			assert(not mesh_instance.visible, "%s collision proxy is never rendered" % object.definition.display_name)
	assert(visible_mesh_count >= 10,
		"%s has composed visible Blender geometry" % object.definition.display_name)


func _assert_authored_surface_texture(object: QuestObjectBase) -> void:
	var texture_path := str(object.get_meta("authored_texture_path", ""))
	assert(texture_path.begins_with("res://assets/textures/mind_spark/quest_objects/")
		and texture_path.ends_with("_albedo_v1.png"),
		"%s has its own authored albedo texture" % object.definition.display_name)
	assert(FileAccess.file_exists(texture_path),
		"%s authored texture exists in the project" % object.definition.display_name)
	var target_path := str(object.get_meta("authored_texture_target", ""))
	var target := object.get_node_or_null("VisualRoot/" + target_path)
	assert(target != null, "%s has a dedicated readable texture target" % object.definition.display_name)
	var textured_meshes: Array[MeshInstance3D] = []
	if target is MeshInstance3D:
		textured_meshes.append(target as MeshInstance3D)
	for child in target.find_children("*", "MeshInstance3D", true, false):
		textured_meshes.append(child as MeshInstance3D)
	assert(not textured_meshes.is_empty(), "%s texture target contains real 3D geometry" % object.definition.display_name)
	for mesh_instance in textured_meshes:
		var material := mesh_instance.material_override as StandardMaterial3D
		assert(material != null and material.albedo_texture != null,
			"%s texture is applied to its in-engine 3D surface" % object.definition.display_name)


func _silhouette_signature(object: QuestObjectBase) -> String:
	var visual_root := object.get_node("VisualRoot") as Node3D
	var bounds := AABB()
	var has_bounds := false
	var meshes := visual_root.find_children("*", "MeshInstance3D", true, false)
	for mesh_node in meshes:
		var mesh_instance := mesh_node as MeshInstance3D
		if not mesh_instance.visible or mesh_instance.mesh == null:
			continue
		var relative_transform := visual_root.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds := relative_transform * mesh_instance.get_aabb()
		bounds = bounds.merge(mesh_bounds) if has_bounds else mesh_bounds
		has_bounds = true
	assert(has_bounds, "%s has measurable 3D bounds" % object.definition.display_name)
	var snapped_size := Vector3(
		snappedf(bounds.size.x, 0.1),
		snappedf(bounds.size.y, 0.1),
		snappedf(bounds.size.z, 0.1))
	return "%d:%s" % [meshes.size(), snapped_size]


func _spawn(index: int, id: String) -> QuestObjectBase:
	var object := BaseScene.instantiate()
	object.definition = Catalog.definition_at(index)
	object.save_id = id
	object.state_store_path = TEST_STORE
	root.add_child(object)
	await process_frame
	return object


func _assert_textured_socket_ball(socket: QuestObjectBase, node_name: String) -> void:
	var ball := socket.get_node("VisualRoot/%s" % node_name) as MeshInstance3D
	assert(ball.has_meta("torch_spark_textured_ball"), "%s uses a textured socket-ball material" % node_name)
	var material := ball.material_override as StandardMaterial3D
	assert(material != null, "%s has a StandardMaterial3D override" % node_name)
	assert(material.albedo_texture != null, "%s has a base-color texture" % node_name)
	assert(material.normal_texture != null, "%s has a normal texture" % node_name)
	assert(material.roughness_texture != null, "%s has a roughness texture" % node_name)


func _test_socket_persistence_and_save_order() -> void:
	var socket: QuestObjectBase = await _spawn(0, "socket")
	assert(socket.definition.display_name == "Torch Spark Socket")
	assert(socket.definition.action_prompt == "PLACE ONE FOUND SPARK")
	assert(socket.prompt.text.contains("0/3"), "empty socket visibly reports 0/3")
	assert(not socket.get_node("VisualRoot/CentralSpark").visible, "empty socket has no floating Spark")
	assert(not socket.get_node("VisualRoot/SparkHalo").visible,
		"empty socket removes the legacy circle in favor of the segmented technology receptacle")
	assert(not socket.get_node("VisualRoot/ObjectGlow").visible,
		"detailed PBR textures are not washed out by the legacy flood light")
	# The generic socket now uses the catalog GLB; the world has its own
	# memory-style instrument. Check the catalog's authored state meshes.
	var inactive := socket._find_blender_part("CentralSpark_Inactive")
	var active := socket._find_blender_part("CentralSpark_Active")
	var completed := socket._find_blender_part("CentralSpark")
	var beam := socket._find_blender_part("SparkBeam")
	assert(inactive != null and active != null and completed != null and beam != null)
	assert(inactive.visible and not active.visible and not completed.visible and not beam.visible,
		"0/3 shows the unpowered catalog socket")
	var saved_before_signal := {"value": false}
	var opened_task := {"id": ""}
	socket.completed.connect(func(id: String, _result: Dictionary) -> void:
		saved_before_signal["value"] = bool(Store.new(TEST_STORE).load_object(id).get("completed", false)))
	socket.linked_task_opened.connect(func(_id: String, task_id: String) -> void: opened_task["id"] = task_id)
	socket.set_meta("available_sparks", 0)
	assert(socket.interact()["reason"] == "find_thought_spark_first", "socket accepts only a found Spark")
	socket.set_meta("available_sparks", 1)
	assert(socket.interact()["progress"] == 1)
	assert(socket.prompt.text.contains("1/3") and active.visible and not inactive.visible and not completed.visible,
		"1/3 activates the socket without showing completion")
	assert(socket.get_node("VisualRoot/CentralSpark").visible, "placed Spark becomes a visible crystal and beam")
	assert(socket.interact()["reason"] == "find_thought_spark_first", "one found Spark cannot be placed twice")
	socket.set_meta("available_sparks", 2)
	assert(socket.interact()["progress"] == 2)
	assert(socket.prompt.text.contains("2/3") and active.visible and not completed.visible,
		"2/3 keeps the completion reward locked")
	socket.set_meta("available_sparks", 3)
	var done: Dictionary = socket.interact()
	assert(done["completed"] and saved_before_signal["value"], "completion is saved before the signal opens a gate")
	assert(opened_task["id"] == "open_logic_gate" and completed.visible and beam.visible and not active.visible,
		"3/3 reveals the completed crystal and beam and opens the linked task")
	socket.queue_free()
	await process_frame
	var restored: QuestObjectBase = await _spawn(0, "socket")
	assert(restored.current_state["completed"] and restored.interact()["reason"] == "already_complete",
		"socket restores 3/3 without duplicating completion")
	restored.queue_free()
	await process_frame


func _test_scanner_lens_and_sequences() -> void:
	var scanner: QuestObjectBase = await _spawn(1, "scanner")
	assert(scanner.interact()["reason"] == "choose_fact_or_fear")
	assert(scanner.interact(&"fear")["completed"] and scanner.current_state["result"]["evidence"] == "fear")
	scanner.queue_free()
	await process_frame

	var lens: QuestObjectBase = await _spawn(2, "lens")
	assert(not lens.interact()["completed"])
	assert(not lens.interact()["completed"])
	assert(lens.interact()["completed"] and lens.get_node("VisualRoot/PathBeam").visible,
		"third fixed angle reveals the path beam")
	lens.queue_free()
	await process_frame

	var board: QuestObjectBase = await _spawn(3, "board")
	assert(board.interact(&"node", "choose")["reason"] == "wrong_link_reset")
	assert(board.current_state["progress"] == 0, "wrong link gently clears with no penalty")
	assert(board.interact()["progress"] == 1)
	assert(board.interact()["progress"] == 2)
	assert(board.interact()["completed"])
	board.queue_free()
	await process_frame


func _test_gate_bridge_and_support() -> void:
	var gate: QuestObjectBase = await _spawn(4, "gate")
	assert(not gate.interact()["completed"])
	assert(gate.interact()["completed"])
	assert(gate.get_node("VisualRoot/Door").position.y > 2.0 and gate.get_node("VisualRoot/PathBeam").visible,
		"gate visual opens: door=%s beam=%s" % [gate.get_node("VisualRoot/Door").position,
			gate.get_node("VisualRoot/PathBeam").visible])
	gate.queue_free()
	await process_frame

	var bridge: QuestObjectBase = await _spawn(5, "bridge")
	assert(bridge.get_node("VisualRoot/BridgeTile/CollisionShape3D").disabled)
	assert(not bridge.get_node("VisualRoot/CompletionCrystal").visible)
	bridge.interact(&"true")
	assert(not bridge.get_node("VisualRoot/BridgeTile/CollisionShape3D").disabled and
		bridge.get_node("VisualRoot/CompletionCrystal").visible, "truth tile becomes solid and gains its crystal")
	bridge.queue_free()
	await process_frame

	var bell: QuestObjectBase = await _spawn(6, "bell")
	assert(bell.interact(&"help")["reason"] == "hint_on")
	assert(not bell.current_state["completed"], "hint never solves the puzzle")
	assert(bell.interact(&"toggle")["reason"] == "hint_off")
	bell.queue_free()
	await process_frame

	var projector: QuestObjectBase = await _spawn(11, "projector")
	assert(projector.interact()["reason"] == "route_on")
	assert(projector.get_node("VisualRoot/RouteDots").visible)
	assert(projector.interact()["reason"] == "route_off")
	projector.queue_free()
	await process_frame


func _test_boss_sanctuary_identity_checkpoint() -> void:
	var anchor: QuestObjectBase = await _spawn(7, "anchor")
	assert(anchor.interact()["reason"] == "vulnerable")
	assert(anchor.interact(&"strike")["completed"])
	anchor.queue_free()
	await process_frame

	var basin: QuestObjectBase = await _spawn(8, "basin")
	assert(basin.get_node("VisualRoot/StormCloud").visible and not basin.get_node("VisualRoot/CalmHeart").visible)
	assert(basin.interact(&"hold")["completed"])
	assert(basin.current_state["result"]["weather"] == "gentle_rain" and
		not basin.get_node("VisualRoot/StormCloud").visible and basin.get_node("VisualRoot/CalmHeart").visible,
		"basin visibly changes from storm clouds to the calm-heart rain state")
	basin.queue_free()
	await process_frame

	var mirror: QuestObjectBase = await _spawn(9, "mirror")
	assert(mirror.interact(&"private")["reason"] == "skipped")
	var tracker := root.get_node("PlayerIdentityTracker")
	assert(tracker.evidence.is_empty(), "private reflection writes no identity axis")
	assert(mirror.interact(&"answer_a", "outward")["completed"])
	assert(tracker.has_evidence("mind_spark.reflection.after_quest"), "first short answer is saved privately")
	var replay := mirror.interact(&"answer_b", "inward")
	assert(replay["reason"] == "first_answer_kept" and
		tracker.evidence["mind_spark.reflection.after_quest"]["choice"] == "outward" and
		mirror.current_state["result"]["choice"] == "outward",
		"replay explicitly keeps the first private answer in both stores")
	mirror.queue_free()
	await process_frame

	var checkpoint: QuestObjectBase = await _spawn(10, "checkpoint")
	var actions: Array[String] = []
	checkpoint.checkpoint_action_requested.connect(func(action: String): actions.append(action))
	assert(checkpoint.interact()["reason"] == "menu_open")
	assert(checkpoint.interact(&"save")["reason"] == "save")
	assert(checkpoint.interact(&"heal")["reason"] == "heal")
	assert(checkpoint.interact(&"task")["reason"] == "task")
	assert(actions == ["save", "heal", "task"], "checkpoint exposes all three safe-pause actions")
	checkpoint.queue_free()
	await process_frame
