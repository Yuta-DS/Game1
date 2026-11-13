extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("GODOT_ENGINE_COVER_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var world := Node3D.new()
	world.name = "ArtCastleFloatingWorld"
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	world.add_child(player)
	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	for _frame in 3:
		await process_frame
	var cover := railway.get_node_or_null("RainbowGalaxyTrain/GodotEngineCover") as Node3D
	if cover == null:
		_fail("native cover was not attached to the playable train")
		return
	if String(cover.get_meta("shared_blueprint", "")) != \
			"res://assets3D/crown_line_train/crown_line_engine_cover_blueprint.json":
		_fail("Godot and Blender do not share the same cover blueprint")
		return
	var component_count := int(cover.get_meta("component_count", 0))
	if component_count < 700:
		_fail("cover was not decomposed into enough independently editable components")
		return
	if cover.find_children("UpperShellBand_*", "MeshInstance3D", true, false).size() != 24:
		_fail("upper shell is not split into 24 Godot-native bands")
		return
	if cover.find_children("Feather_*", "MeshInstance3D", true, false).size() != 480:
		_fail("micro feather skin does not contain the expected 480 pieces")
		return
	if cover.find_children("MacroLeafPanel_*", "MeshInstance3D", true, false).size() != 16:
		_fail("large screenshot-readable leaf layer is incomplete")
		return
	print("GODOT_ENGINE_COVER_TEST: PASS — shared blueprint, %d native components, playable train integration" % component_count)
	quit()
