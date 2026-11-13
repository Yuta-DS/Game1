# Live regression for the exact failure reported by guest players:
# OFFLINE_GUEST_TOKEN -> loopback AI -> semantic Frame 09 -> explorable scene.
extends SceneTree

const TEST_STATE := "user://guest_frame09_pipeline_test.json"
const ART_PATH := "res://assets/ArtGallery/placeholders/painting_9.jpeg"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var api = root.get_node("APIManager")
	var global = root.get_node("Global")
	var state = root.get_node("CreationWorldState")
	api.auth_token = ""
	global.auth_token = "OFFLINE_GUEST_TOKEN"
	state.save_path = TEST_STATE
	state.worlds.clear()
	state.current_artwork_path = ""
	state.prepare_artwork(ART_PATH, "Frame 09")

	var guide_result := {"done": false, "ok": false, "response": {}}
	state.request_creative_guide(
		"Identify every visible subject so each can become a separate 3D object.",
		func(ok: bool, response: Dictionary) -> void:
			guide_result["ok"] = ok
			guide_result["response"] = response
			guide_result["done"] = true
			print("guest guide response: ", response)
	)
	await _wait_until(func() -> bool: return bool(guide_result["done"]), 90.0)
	assert(bool(guide_result["done"]) and bool(guide_result["ok"]), "guest creative guide request completes")
	var guide_response: Dictionary = guide_result["response"]
	assert(str(guide_response.get("ai_source", "")) in ["primary", "backup", "cache"],
		"guest request reaches the real local AI route without HTTP 422")

	var world_result := {"done": false, "ok": false, "response": {}}
	state.request_world(
		"Reconstruct every visible subject as a separate interactive 3D object in a walkable mini-world.",
		func(ok: bool, response: Dictionary) -> void:
			world_result["ok"] = ok
			world_result["response"] = response
			world_result["done"] = true
			print("guest world response source: ", response.get("ai_source", response.get("error", "unknown")))
	)
	await _wait_until(func() -> bool: return bool(world_result["done"]), 90.0)
	assert(bool(world_result["done"]) and bool(world_result["ok"]), "guest semantic world request completes")
	var world_response: Dictionary = world_result["response"]
	assert(bool(world_response.get("semantic_ready", false)),
		"only a validated semantic world is allowed through")
	assert(state.current_manifest().get("objects", []).size() >= 6,
		"Frame 09 contains several independently placed subjects")

	var world := (load("res://scenes/creation_world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var generation_deadline := Time.get_ticks_msec() + 20000
	while not world.call("world_generation_idle") and Time.get_ticks_msec() < generation_deadline:
		await process_frame
	assert(world.call("world_generation_idle"), "the live runtime generation queue completes")
	assert(world.find_child("ArtistFox", true, false) != null,
		"the explorable scene loads its real player model")
	assert(_has_artwork_kind(world, "boat"),
		"a painted boat becomes an independent world actor")
	assert(_has_artwork_kind(world, "tree"),
		"a painted tree becomes an independent world actor")
	world.queue_free()
	await process_frame
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
	print("guest Frame 09 pipeline: all checks passed")
	quit(0)


func _wait_until(condition: Callable, timeout_seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame


func _has_artwork_kind(world: Node, kind: String) -> bool:
	for node in world.find_children("*", "StaticBody3D", true, false):
		if str(node.get_meta("artwork_kind", "")) == kind:
			return true
	return false
