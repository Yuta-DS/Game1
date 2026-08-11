# Visual proof for the Crown of Life short story. Uses scratch journey state
# and disables LensPersistence, then drives the same capture/place API as play.
extends SceneTree

const STORY := "res://scenes/viewfinder/crown_of_life_story.tscn"
const OUT_DIR := "res://artifacts"
const TEST_SAVE := "res://.godot/capture_crown_story.json"
const TEST_SETTINGS := "res://.godot/capture_crown_story_settings.cfg"

var _story: Node3D
var _js: Node


func _initialize() -> void:
	_js = root.get_node_or_null("JourneyState")
	_js.save_path = TEST_SAVE
	_js.clear_journey()

	_story = (load(STORY) as PackedScene).instantiate()
	_story.persist_lens_placements = false
	_story.settings_path = TEST_SETTINGS
	root.add_child(_story)
	current_scene = _story
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _settle()

	var player := _story.get_node("StoryPlayer") as CharacterBody3D
	var camera := player.get_node("StoryCamera") as Camera3D

	# Presentation proof: a wide overview showing the whole connected journey
	# (all four islands, three chasms, and the distant castle) in one frame.
	camera.position = Vector3(0.0, 0.0, 0.0)
	camera.global_position = Vector3(-26.0, 34.0, -30.0)
	camera.look_at(Vector3(0.0, 2.0, 20.0), Vector3.UP)
	await _settle()
	_shoot("crown_story_00_world_overview.png")

	camera.global_position = Vector3(10.0, 6.5, -35.0)
	camera.look_at(Vector3(0.0, 1.8, -18.0), Vector3.UP)
	await _settle()
	_shoot("crown_story_01_prologue.png")

	await _complete_chapter("mind_spark", 2)

	# Evidence for the pause/settings production-UX pass: opens the pause
	# menu and the audio/accessibility settings panel mid-journey.
	camera.global_position = Vector3(7.0, 3.6, -6.0)
	camera.look_at(Vector3(0.0, 1.5, 0.0), Vector3.UP)
	await _settle()
	_story.call("_toggle_pause")
	_story.call("_open_settings")
	await _settle()
	_shoot("crown_story_03_pause_settings.png")
	_story.call("_close_all_panels")
	await _settle()

	await _complete_chapter("heart_melody", 4)
	await _complete_chapter("creators_light", 5)

	# Frame from well clear of the player-attached crown (it sits at the
	# player's head) so the finale hero elements read without clipping through
	# its geometry — the same wide-camera approach that works for shot 08.
	player.global_position = Vector3(6.0, 2.0, 28.0)
	player.rotation.y = PI
	camera.position = Vector3.ZERO
	camera.global_position = Vector3(14.0, 11.0, 22.0)
	camera.look_at(Vector3(0.0, 9.0, 34.0), Vector3.UP)
	await _settle()
	_shoot("crown_story_06_finale.png")
	var finale_layer := _story.get("_finale_layer") as CanvasLayer
	if finale_layer != null:
		finale_layer.visible = false

	# Presentation proof: the distant Artéa castle as a clear destination,
	# framed from the approach so its trim/windows/doorway/battlements read.
	camera.global_position = Vector3(-10.0, 6.5, 26.0)
	camera.look_at(Vector3(0.0, 3.0, 38.0), Vector3.UP)
	await _settle()
	_shoot("crown_story_07_castle_destination.png")

	# Presentation proof: a hero composition of crown/star/train together,
	# framed wider than the gameplay finale shot above so nothing clips.
	var gameplay_fov := camera.fov
	camera.fov = 82.0
	camera.global_position = Vector3(10.0, 9.0, 26.0)
	camera.look_at(Vector3(0.0, 7.5, 38.0), Vector3.UP)
	await _settle()
	_shoot("crown_story_08_finale_hero.png")
	camera.fov = gameplay_fov
	if finale_layer != null:
		finale_layer.visible = true

	_js.clear_journey()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("capture_crown_story: wrote visual proof to %s" % OUT_DIR)
	quit()


func _complete_chapter(chapter_id: String, capture_index: int) -> void:
	var lens := _story.find_child("ViewfinderLens", true, false)
	var camera := _story.find_child("StoryCamera", true, false) as Camera3D
	var zone := _story.get_node("Zone_%s" % chapter_id)
	var source := zone.get_node("Source_%s" % chapter_id) as Node3D
	var gap := zone.get_node("Gap_%s" % chapter_id) as Area3D
	var player := _story.get_node("StoryPlayer") as CharacterBody3D
	player.global_position = source.global_position + Vector3(0.0, 0.0, 2.0)
	await physics_frame
	if chapter_id == "heart_melody":
		for i in 6:
			_story.call("_perform_current_interaction")
	elif chapter_id == "creators_light":
		_story.call("_perform_current_interaction", 1)
	else:
		_story.call("_perform_current_interaction")
	camera.global_position = source.global_position + Vector3(4.8, 2.8, -4.5)
	camera.look_at(source.global_position, Vector3.UP)
	await _settle()
	_shoot("crown_story_%02d_%s.png" % [capture_index, chapter_id])
	var captured := false
	# The presentation cameras are deliberately detached from the player for
	# beauty shots. Re-establish and settle the gameplay framing explicitly;
	# Forward Mobile can otherwise expose a one-frame stale frustum transform.
	for attempt in 3:
		camera.global_position = source.global_position + Vector3(
			0.0, 0.0, 3.0 - float(attempt) * 0.35)
		camera.look_at(source.global_position, Vector3.UP)
		for i in 3:
			await physics_frame
		await process_frame
		captured = lens.capture()
		if captured:
			break
	if not captured:
		push_error("capture_crown_story: could not capture %s" % chapter_id)
		quit(1)
		return
	camera.global_position = gap.global_position + Vector3(0.0, 0.0, 3.0)
	camera.look_at(gap.global_position, Vector3.UP)
	await physics_frame
	await physics_frame
	var placed: bool = lens.place()
	if not placed:
		for i in 4:
			await physics_frame
		camera.look_at(gap.global_position, Vector3.UP)
		placed = lens.place()
	if not placed:
		push_error("capture_crown_story: could not place %s" % chapter_id)
		quit(1)
		return
	for i in 5:
		await physics_frame


func _settle() -> void:
	for i in 8:
		await process_frame


func _shoot(filename: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		push_error("capture_crown_story: no framebuffer for %s" % filename)
		return
	var path := "%s/%s" % [OUT_DIR, filename]
	image.save_png(path)
	print("  wrote %s" % path)
