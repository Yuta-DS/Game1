extends SceneTree

const MiloScene := preload("res://scenes/characters/milo_scholar.tscn")
const MiloNPCScene := preload("res://scenes/milo_animations.tscn")
const HubPlayerScene := preload("res://scenes/entities/NewPlayer.tscn")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("MILO_CHARACTER_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var milo := MiloScene.instantiate() as Node3D
	root.add_child(milo)
	await process_frame
	var meshes := milo.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 1:
		_fail("Milo must be one unified low-poly mesh, found %d mesh nodes" % meshes.size())
		return
	var shared_cast_skin := milo.get_node_or_null("Model")
	if shared_cast_skin == null or not shared_cast_skin.has_method("is_villager_lowpoly_skin"):
		_fail("Milo is no longer the unified smooth villager-style asset")
		return
	var unified_mesh := meshes[0] as MeshInstance3D
	var vertex_count := 0
	for surface_index in unified_mesh.mesh.get_surface_count():
		vertex_count += unified_mesh.mesh.surface_get_array_len(surface_index)
	# Godot duplicates boundary vertices across the 19 material surfaces. The
	# authored Blender mesh is 4.5k vertices; the imported surface total remains
	# comfortably below the market-NPC quality ceiling.
	if vertex_count < 1500 or vertex_count > 7500:
		_fail("Milo polygon density is outside the low-poly NPC target: %d vertices" % vertex_count)
		return
	if unified_mesh.mesh.get_surface_count() < 10:
		_fail("Milo's suit and face material separation is missing")
		return
	var skeletons := milo.find_children("*", "Skeleton3D", true, false)
	var skeleton := skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	if skeleton == null or skeleton.get_bone_count() < 35:
		_fail("Milo's full-body villager animation skeleton is missing")
		return
	var animation_players := milo.find_children("*", "AnimationPlayer", true, false)
	var animations := animation_players[0] as AnimationPlayer if not animation_players.is_empty() else null
	if animations == null:
		_fail("AnimationPlayer is missing")
		return
	for clip in ["Idle", "Idle_3", "Wave_One_Hand", "Walk", "Walking", "Run", "Running"]:
		if not animations.has_animation(clip):
			_fail("required %s animation is missing" % clip)
			return
	var npc := MiloNPCScene.instantiate() as Node3D
	if not npc is CharacterBody3D:
		_fail("Milo is not a walking town NPC CharacterBody3D")
		return
	var npc_cast_skin := npc.get_node_or_null("Model")
	if npc_cast_skin == null or not npc_cast_skin.has_method("is_villager_lowpoly_skin"):
		_fail("interactive Milo NPC does not use the shared villager cast asset")
		return
	if npc.get_node_or_null("Area3D/CollisionShape3D") == null:
		_fail("interactive Milo NPC lost its interaction area")
		return
	var name_label := npc.get_node_or_null("MayorMiloName") as Label3D
	if name_label == null or name_label.text != "Mayor Milo":
		_fail("visible Mayor Milo name marker is missing")
		return
	if not is_equal_approx(npc.scale.x, 1.0):
		_fail("reusable Cat Mayor Milo scene must stay at native villager scale")
		return
	if float(npc.get("walk_speed")) <= 0.0 or float(npc.get("wander_radius")) > 3.0:
		_fail("Milo's greeting route can carry him out of the spawn camera")
		return
	var dummy_player := CharacterBody3D.new()
	dummy_player.name = "NewPlayer"
	root.add_child(dummy_player)
	root.add_child(npc)
	await process_frame
	var walk_start := npc.position
	npc.set("_pause_timer", 0.0)
	for _frame in 12:
		await physics_frame
	var horizontal_distance := Vector2(npc.position.x - walk_start.x,
		npc.position.z - walk_start.z).length()
	if horizontal_distance < 0.08:
		_fail("Milo did not physically walk when his town route started")
		return
	npc.queue_free()
	dummy_player.queue_free()
	await process_frame

	var hub_player := HubPlayerScene.instantiate() as CharacterBody3D
	root.add_child(hub_player)
	await process_frame
	if hub_player.find_child("ProfessorTie", true, false) != null:
		_fail("live hub player was incorrectly replaced by Milo")
		return
	if hub_player.get_node_or_null("RogueSkin/AnimationPlayer") == null:
		_fail("existing fox player locomotion visuals are missing")
		return

	var hub_text := FileAccess.get_file_as_string("res://scenes/New_Hub_World.tscn")
	if not hub_text.contains("Milo_Animations2") or not hub_text.contains("res://scenes/milo_animations.tscn"):
		_fail("production Milo NPC is not placed in the live hub")
		return
	if not hub_text.contains("OriginalCatStatue") \
			or not hub_text.contains("res://meshy ai/Milo_Animations.glb"):
		_fail("the original cat statue is missing beside the Artéa sign")
		return
	if not hub_text.contains("Transform3D(-0.1736482, 0, -0.9848078, 0, 1, 0, 0.9848078, 0, -0.1736482, 104.8, 21, -7.25)"):
		_fail("live hub Mayor Milo must stand beside the Artéa sign at native 1x scale")
		return

	print("MILO_CHARACTER_TEST: PASS — approved Cat Mayor silhouette on shared villager rig, exact 1x hub scale, animations, sign placement, interaction, player unchanged")
	quit()
