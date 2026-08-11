# Developer visual check for the exact gallery artwork reported in the block-
# fallback bug. It loads the latest validated Frame 09 vision manifest from the
# local server cache and renders the same creation_world.tscn the player enters.
extends SceneTree

const ART_PATH := "res://assets/ArtGallery/placeholders/painting_9.jpeg"
const OUTPUT_PATH := "res://artifacts/frame09_semantic_world.png"
const HUD_OUTPUT_PATH := "res://artifacts/frame09_creation_hud.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var manifest := _latest_validated_manifest()
	print("FRAME09_CAPTURE: loaded manifest")
	assert(not manifest.is_empty(), "a validated Frame 09 server manifest is available")
	manifest["semantic_ready"] = true
	manifest["vision_source"] = "cache"
	var state = root.get_node("CreationWorldState")
	state.prepare_artwork(ART_PATH, "Frame 09")
	state._store_manifest(manifest)
	print("FRAME09_CAPTURE: stored manifest")
	assert(state.current_world_is_semantic(), "Frame 09 is approved as a semantic world")

	var world := (load("res://scenes/creation_world.tscn") as PackedScene).instantiate()
	print("FRAME09_CAPTURE: instantiated scene")
	root.add_child(world)
	print("FRAME09_CAPTURE: entered scene tree")
	current_scene = world
	for _frame in 90:
		await process_frame
	print("FRAME09_CAPTURE: scene settled")

	var semantic_count := 0
	var extrusion_count := 0
	for node in world.find_children("*", "StaticBody3D", true, false):
		if bool(node.get_meta("artwork_interactive", false)):
			semantic_count += 1
			if str(node.get_meta("reconstruction_mode", "")) == "artwork_extrusion":
				extrusion_count += 1
	print("FRAME09_CAPTURE: semantic=%d extrusions=%d" % [semantic_count, extrusion_count])
	assert(semantic_count >= 6, "the painting becomes several independent interactive objects")
	assert(extrusion_count == 0, "Frame 09 contains no generic painted block extrusions")

	# Optional presentation capture. This keeps the real player camera and HUD
	# visible so the same script can supervise the in-game composition without
	# changing the established semantic-world reference capture below.
	if "--hud" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		var hud_error := root.get_texture().get_image().save_png(HUD_OUTPUT_PATH)
		assert(hud_error == OK, "the creation-world HUD capture is written")
		print("FRAME09_CAPTURE: HUD PASS — presentation capture written")
		quit(0)
		return

	for node in world.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.fov = 64.0
	camera.far = 200.0
	world.add_child(camera)
	# Eye level on the sculpted terrain, not a top-down plan view. A world the
	# player walks through has to be judged from where the player stands.
	var eye := Vector3(-2.0, 0.0, 14.0)
	eye.y = world.call("terrain_height_at", eye.x, eye.z) + 2.6
	camera.global_position = eye
	camera.look_at(Vector3(2.0, world.call("terrain_height_at", 2.0, -4.0) + 1.2, -4.0), Vector3.UP)
	camera.make_current()
	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var error := root.get_texture().get_image().save_png(OUTPUT_PATH)
	assert(error == OK, "the semantic world capture is written")
	print("FRAME09_CAPTURE: PASS — %d semantic objects, no block fallback" % semantic_count)
	quit(0)


func _latest_validated_manifest() -> Dictionary:
	var cache_path := ProjectSettings.globalize_path("res://../server/ai_cache").simplify_path()
	var directory := DirAccess.open(cache_path)
	if directory == null:
		return {}
	var newest_time := 0
	var newest_manifest: Dictionary = {}
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.begins_with("world_") and file_name.ends_with(".json"):
			var path := cache_path.path_join(file_name)
			var file := FileAccess.open(path, FileAccess.READ)
			var record = JSON.parse_string(file.get_as_text()) if file != null else null
			if record is Dictionary and record.get("payload") is Dictionary:
				var candidate: Dictionary = record["payload"]
				if str(candidate.get("world_title", "")) == "Frame 09" \
						and int(candidate.get("schema_version", 0)) == 2 \
						and _subjects_have_bounds(candidate):
					var modified := FileAccess.get_modified_time(path)
					if modified >= newest_time:
						newest_time = modified
						newest_manifest = candidate.duplicate(true)
		file_name = directory.get_next()
	directory.list_dir_end()
	return newest_manifest


func _subjects_have_bounds(manifest: Dictionary) -> bool:
	var count := 0
	for collection_key in ["objects", "characters"]:
		for value in manifest.get(collection_key, []):
			if value is Dictionary and value.get("bounding_box") is Dictionary \
					and value.get("normalized_position") is Dictionary:
				count += 1
	return count >= 6
