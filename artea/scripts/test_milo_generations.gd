extends SceneTree

const MILO_1 := preload("res://scenes/milo_1.tscn")
const MILO_2 := preload("res://milo2/godot/milo2_game_character.tscn")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("  FAIL: %s" % message)


func _run() -> void:
	var milo_1_source := FileAccess.get_file_as_string(
		"res://scenes/characters/milo_villager_skin.tscn")
	var milo_2_source := FileAccess.get_file_as_string(
		"res://milo2/godot/milo2_skin.tscn")
	var hub_source := FileAccess.get_file_as_string("res://scenes/New_Hub_World.tscn")
	_check(milo_1_source.contains("milo_exact_target_parts.glb"),
		"Milo 1 retains the original model asset")
	_check(not milo_1_source.contains("milo_2_pictured.glb"),
		"Milo 1 never redirects to the pictured model")
	_check(milo_2_source.contains("milo2_from_scratch.glb"),
		"Milo 2 owns its finalized independent model")
	_check(not milo_2_source.contains("milo_exact_target_parts.glb"),
		"Milo 2 does not silently instantiate Milo 1")
	_check(FileAccess.file_exists("res://assets3D/characters/milo_exact_target_parts.glb")
		and FileAccess.file_exists("res://milo2/assets/milo2_from_scratch.glb"),
		"both independent GLB assets exist")
	_check(hub_source.contains("res://milo2/godot/milo2_game_character.tscn"),
		"the live hub explicitly chooses Milo 2")

	var first := MILO_1.instantiate() as CharacterBody3D
	var second := MILO_2.instantiate() as CharacterBody3D
	root.add_child(first)
	root.add_child(second)
	await process_frame
	_check(first != null and int(first.get_meta("milo_generation", 0)) == 1,
		"Milo 1 retains its preserved generation marker")
	_check(second != null and int(second.call("get_milo_generation")) == 2,
		"Milo 2 has its own controller entry")
	_check(first.find_child("PrototypeMoustache_L", true, false) == null,
		"Milo 1 keeps its legacy face")
	_check(second.find_child("Milo2_Unified_Skinned_Character", true, false) != null,
		"Milo 2 contains the finalized unified character mesh")
	_check(first.find_child("PrototypeCoatBelt", true, false) == null,
		"Milo 1 keeps its original clothing construction")
	_check(second.get_meta("milo_visual_variant", "") == "independent_reference_build_gameplay",
		"Milo 2 uses the finalized gameplay visual variant")

	first.queue_free()
	second.queue_free()
	await process_frame
	if _failures > 0:
		push_error("MILO_GENERATIONS_TEST: %d failure(s)" % _failures)
		quit(1)
		return
	print("MILO_GENERATIONS_TEST: PASS — Milo 1 legacy and finalized Milo 2 are independent assets, scenes, controllers, and hub choices")
	quit()
