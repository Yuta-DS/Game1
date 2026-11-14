# Self-check for the Crown of Life short story.
#   godot --headless --path artea --script res://scripts/test_crown_story.gd
#
# Uses a scratch save path throughout, so this can never overwrite or erase a
# real player's journey.json (same rule as test_lens_journey.gd).
extends SceneTree

const STORY_SCENE := "res://scenes/viewfinder/crown_of_life_story.tscn"
const HUB_SCENE := "res://scenes/New_Hub_World.tscn"
const FrustumCutterScript := preload("res://scripts/viewfinder/frustum_cutter.gd")

const TEST_SAVE := "res://.godot/test_crown_story.json"
const TEST_SETTINGS := "res://.godot/test_crown_story_settings.cfg"

var _story: Node3D
var _js: Node


func _initialize() -> void:
	_js = root.get_node_or_null("JourneyState")
	assert(_js != null, "JourneyState autoload is present")
	_js.save_path = TEST_SAVE
	_js.clear_journey()

	_test_scene_and_portal_paths_exist()

	var packed := load(STORY_SCENE) as PackedScene
	assert(packed != null, "the story scene loads")
	_story = packed.instantiate()
	# A test must never replay or overwrite the player's real Lens placements.
	# Set this before add_child(), because the controller is built in _ready().
	_story.persist_lens_placements = false
	_story.settings_path = TEST_SETTINGS
	root.add_child(_story)
	# place() reparents placed geometry into get_tree().current_scene — a real
	# scene launch sets this automatically, but a script-driven SceneTree does
	# not, so a placement would silently land nowhere and never reach the gap.
	current_scene = _story

	for i in 10:
		await process_frame

	_test_first_person_player_and_one_lens()
	_test_three_named_chapter_zones()
	_test_hud_objective_and_progress_present()
	_test_pause_menu_and_settings_panel()
	await _test_fall_recovery_respawns_at_checkpoint()
	await _test_completing_chapters_in_order_records_optional_story_evidence()
	_test_faith_and_universal_text_preserves_optional_evidence()
	await _test_optional_story_does_not_create_the_canonical_finale()
	_test_optional_story_keeps_return_without_finale_actions()
	_test_return_action_points_to_hub()

	_cleanup()
	print("crown story: all checks passed")
	quit()


func _test_scene_and_portal_paths_exist() -> void:
	assert(ResourceLoader.exists(STORY_SCENE), "the story scene path exists")
	assert(ResourceLoader.exists("res://scripts/viewfinder/crown_of_life_story.gd"),
		"the story implementation script exists")
	assert(ResourceLoader.exists("res://scripts/viewfinder/crown_story_portal.gd"),
		"the hub portal script exists")
	assert(ResourceLoader.exists(HUB_SCENE), "the hub scene the portal targets exists")

	var hub_source := FileAccess.get_file_as_string("res://scenes/New_Hub_World.tscn")
	assert(hub_source.contains("crown_story_portal.gd"),
		"the hub scene wires in the Crown of Life portal")


func _test_first_person_player_and_one_lens() -> void:
	var player := _story.get_node_or_null("StoryPlayer")
	assert(player is CharacterBody3D,
		"the story creates exactly one first-person CharacterBody3D player")

	var camera := player.find_child("StoryCamera", true, false)
	assert(camera is Camera3D, "the player has a camera")

	var controllers := _story.find_children("LensController", "Node3D", true, false)
	assert(controllers.size() == 1,
		"exactly one Lens controller exists, got %d" % controllers.size())
	assert(controllers[0].get_parent() == camera,
		"the lens rides on the player's camera, matching the existing hub convention")

	var lenses := _story.find_children("ViewfinderLens", "Node3D", true, false)
	assert(lenses.size() == 1, "reuses the existing Lens stack — no second cutter")


func _test_three_named_chapter_zones() -> void:
	assert(_story.find_children("StoryIsland*", "StaticBody3D", true, false).size() == 4,
		"four floor islands leave three real chasms")
	assert(_story.get_node_or_null("MiloGuide") != null,
		"Milo appears in the prologue as an in-world guide")
	var ids := ["mind_spark", "heart_melody", "creators_light"]
	for chapter_id in ids:
		var zone := _story.get_node_or_null("Zone_%s" % chapter_id)
		assert(zone != null, "zone %s exists" % chapter_id)

		var source := zone.get_node_or_null("Source_%s" % chapter_id)
		assert(source != null, "zone %s has a Cuttable source" % chapter_id)
		assert(source.collision_layer == 0,
			"zone %s source waits for its distinct discovery before becoming Cuttable" % chapter_id)
		assert(str(source.get_meta("interaction_kind")) == chapter_id,
			"zone %s identifies its own interaction kind" % chapter_id)

		var gap := zone.get_node_or_null("Gap_%s" % chapter_id)
		assert(gap is Area3D, "zone %s has a fragment goal area" % chapter_id)
		assert(gap.collision_mask & FrustumCutterScript.CUTTABLE_MASK != 0,
			"zone %s goal area listens for Cuttable fragment bodies" % chapter_id)

		var gate := zone.get_node_or_null("Gate_%s" % chapter_id)
		assert(gate is StaticBody3D and gate.collision_layer == 1,
			"zone %s starts with a solid anti-bypass gate" % chapter_id)
		assert(zone.get_node_or_null("GuardianAvatar_%s" % chapter_id) != null,
			"zone %s has an in-world guardian avatar" % chapter_id)


# Drives the lens directly (capture -> reposition -> place), the same public
# API the player uses via input, so no synthetic mouse events are needed.
func _complete_chapter(index: int, chapter_id: String) -> void:
	var lens := _story.find_children("ViewfinderLens", "Node3D", true, false)[0]
	var controller := _story.find_children("LensController", "Node3D", true, false)[0]
	var camera: Camera3D = controller.camera
	var zone := _story.get_node_or_null("Zone_%s" % chapter_id)
	var source := zone.get_node_or_null("Source_%s" % chapter_id)
	var gap := zone.get_node_or_null("Gap_%s" % chapter_id)
	var player := _story.get_node("StoryPlayer") as CharacterBody3D
	player.global_position = source.global_position + Vector3(0.0, 0.0, 2.0)
	await physics_frame

	# Complete the chapter-specific discovery before the common Lens step.
	if chapter_id == "heart_melody":
		for i in 6:
			_story.call("_perform_current_interaction")
	elif chapter_id == "creators_light":
		_story.call("_perform_current_interaction", 1)
	else:
		_story.call("_perform_current_interaction")
	assert(source.collision_layer & FrustumCutterScript.CUTTABLE_MASK != 0,
		"chapter %s: its distinct discovery activates the Lens source" % chapter_id)

	# Look at the source from just in front of it and capture.
	camera.global_position = source.global_position + Vector3(0.0, 0.0, 3.0)
	camera.look_at(source.global_position, Vector3.UP)
	await physics_frame
	await physics_frame
	var captured: bool = lens.capture()
	assert(captured, "chapter %s: capture succeeded" % chapter_id)

	# Move to the gap and place — the held seeing travels with the capture
	# point (the camera), so placing here drops it into the goal area.
	camera.global_position = gap.global_position + Vector3(0.0, 0.0, 3.0)
	camera.look_at(gap.global_position, Vector3.UP)
	await physics_frame
	await physics_frame
	var placed: bool = lens.place()
	assert(placed, "chapter %s: place succeeded" % chapter_id)

	# Broadphase overlap updates happen on physics ticks, not idle ticks.
	for i in 5:
		await physics_frame


func _test_completing_chapters_in_order_records_optional_story_evidence() -> void:
	assert(not _js.has_story_chapter("mind_spark"), "not complete before playing")

	await _complete_chapter(0, "mind_spark")
	assert(_js.has_story_chapter("mind_spark"), "mind_spark chapter recorded")
	assert(not _js.has_treasure("star_of_wisdom"),
		"optional Lens replay does not award the canonical Star of Wisdom")
	assert((_story.get_node("Zone_mind_spark/Gate_mind_spark") as StaticBody3D).collision_layer == 0,
		"a valid Mind Spark placement opens its physical gate")

	await _complete_chapter(1, "heart_melody")
	assert(_js.has_story_chapter("heart_melody"), "heart_melody chapter recorded")
	assert(not _js.has_treasure("harmony_jewel"),
		"optional Lens replay does not award the canonical Harmony Jewel")

	await _complete_chapter(2, "creators_light")
	assert(_js.has_story_chapter("creators_light"), "creators_light chapter recorded")
	assert(not _js.has_treasure("creators_light"),
		"optional Lens replay does not award canonical Creator's Light")

	assert(_js.story_chapters_complete(), "all three chapters recorded")
	assert(not _js.has_all_treasures(),
		"optional story evidence cannot complete the canonical treasure set")
	assert(_js.bridgings_count() == 3,
		"each successful Lens placement records one truthful bridging event")

	# No mini-game data was fabricated to earn these — the story's own act of
	# placing a seeing is the evidence, same standard as record_bridging().
	assert(_js.thoughts.is_empty(), "the story does not fabricate thought entries")
	assert(_js.emotions.is_empty(), "the story does not fabricate emotion entries")
	assert(_js.creations.is_empty(), "the story does not fabricate creation entries")


func _test_faith_and_universal_text_preserves_optional_evidence() -> void:
	var CrownStoryScript := preload("res://scripts/viewfinder/crown_of_life_story.gd")
	for chapter in CrownStoryScript.CHAPTERS:
		assert(chapter["guardian"].has("faith") and chapter["guardian"].has("universal"),
			"chapter %s has both guardian registers" % chapter["id"])
		assert(chapter["line_before"]["faith"] != chapter["line_before"]["universal"],
			"chapter %s: the two registers use different naming" % chapter["id"])
		assert(chapter["line_after"]["faith"] != chapter["line_after"]["universal"],
			"chapter %s: the closing line also differs by register" % chapter["id"])

	# Audience mode changes only naming; optional story evidence cannot change
	# into a canonical kingdom reward in either register.
	_js.set_audience_mode("universal")
	assert(_js.story_chapters_complete() and not _js.has_all_treasures(),
		"switching audience mode preserves replay evidence without rewards")
	_js.set_audience_mode("faith")


func _test_optional_story_does_not_create_the_canonical_finale() -> void:
	# The Lens story is an optional replay, so its third chapter cannot create
	# the Crown finale without the three canonical mini-game treasures.
	for i in 6:
		await process_frame

	var player := _story.get_node_or_null("StoryPlayer")
	var crown := player.get_node_or_null("CrownOfLife")
	var star := _story.get_node_or_null("IdentityStar")
	var train := _story.get_node_or_null("RainbowGalaxyTrain")
	var message := _story.find_child("StoryMessage", true, false) as Label

	assert(crown == null, "optional Lens replay does not create the Crown")
	assert(star == null, "optional Lens replay does not create an Identity Star")
	assert(train == null, "optional Lens replay does not create the celebration train")
	assert(message != null and message.text.contains("Lens path complete"),
		"optional Lens replay ends with a return-to-Castle message, not a canonical finale")
	assert(_js.stage != 4, "optional Lens replay cannot advance to Crown stage")


func _test_return_action_points_to_hub() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/viewfinder/crown_of_life_story.gd")
	assert(source.contains(HUB_SCENE),
		"the Return to Castle action targets New_Hub_World.tscn")


func _test_hud_objective_and_progress_present() -> void:
	var objective := _story.find_child("ObjectiveText", true, false) as Label
	var progress := _story.find_child("ProgressText", true, false) as Label
	assert(objective != null, "an objective label exists")
	assert(progress != null, "a progress label exists")
	assert(objective.text.contains("Mind Spark"),
		"the objective names the first unstarted chapter, got '%s'" % objective.text)
	assert(progress.text.contains("0") and progress.text.contains("3"),
		"the progress label shows 0 of 3 treasures before any chapter, got '%s'" % progress.text)


# Exercises pause open/close, the settings sub-panel, and that toggling an
# accessibility setting actually changes observable HUD state (subtitles),
# not just an internal flag — a settings screen that doesn't affect anything
# would still pass a flag-only assertion.
func _test_pause_menu_and_settings_panel() -> void:
	var pause_layer := _story.get_node_or_null("PauseLayer") as CanvasLayer
	assert(pause_layer != null, "a pause layer exists")
	assert(not pause_layer.visible, "paused is not visible at start")

	_story.call("_toggle_pause")
	assert(pause_layer.visible, "_toggle_pause opens the pause menu")

	_story.call("_open_settings")
	var settings_layer := _story.get("_settings_panel") as CanvasLayer
	assert(settings_layer.visible, "opening settings shows the settings panel")
	assert(not pause_layer.visible, "opening settings hides the pause menu underneath")

	var guardian := _story.find_child("StoryMessage", true, false) as Label
	var before_text := guardian.text
	assert(before_text != "", "subtitles are on and showing text by default")

	var subtitles_check := settings_layer.get_child(1).get_node("SubtitlesCheck") as CheckButton
	subtitles_check.button_pressed = false
	subtitles_check.toggled.emit(false)
	assert(guardian.text == "", "turning subtitles off hides the caption text")
	assert(not guardian.visible, "turning subtitles off hides the caption label")

	subtitles_check.button_pressed = true
	subtitles_check.toggled.emit(true)
	assert(guardian.text == before_text,
		"turning subtitles back on restores the last guardian line")

	var large_text_check := settings_layer.get_child(1).get_node("LargeTextCheck") as CheckButton
	var size_before := guardian.get_theme_font_size("font_size")
	large_text_check.button_pressed = true
	large_text_check.toggled.emit(true)
	assert(guardian.get_theme_font_size("font_size") > size_before,
		"large text increases the guardian caption font size")
	large_text_check.button_pressed = false
	large_text_check.toggled.emit(false)
	assert(guardian.get_theme_font_size("font_size") == size_before,
		"large text off restores the original caption font size")

	_story.call("_close_all_panels")
	assert(not pause_layer.visible and not settings_layer.visible,
		"closing panels hides both pause and settings")
	# Input.mouse_mode is not meaningfully observable under --headless (no
	# window/display), so the mouse-capture side effect of closing panels is
	# exercised by code inspection instead of a runtime assertion here.


# Falling below the world respawns the player at their last checkpoint
# instead of leaving them stuck in the void — the completion standard's
# "fall recovery" requirement.
func _test_fall_recovery_respawns_at_checkpoint() -> void:
	var player := _story.get_node("StoryPlayer") as CharacterBody3D
	var checkpoint: Vector3 = _story.get("_checkpoint")
	player.global_position = checkpoint + Vector3(0.0, -50.0, 0.0)
	for i in 3:
		await physics_frame
	var respawned: Vector3 = player.global_position
	assert(respawned.y > -12.0,
		"falling below the world respawns the player above the fall threshold, got y=%.2f" % respawned.y)
	assert(respawned.distance_to(checkpoint) < 5.0,
		"the player respawns near the last checkpoint")


func _test_optional_story_keeps_return_without_finale_actions() -> void:
	# The replay still gives the player a safe way back to the Castle, but it
	# cannot expose canonical-finale actions before the three real kingdoms.
	var buttons := _story.find_children("*", "Button", true, false)
	var labels: Array[String] = []
	for button in buttons:
		labels.append((button as Button).text)
	assert(labels.has("Return to Castle"), "the optional story keeps a Return to Castle action")
	assert(not labels.has("Replay Journey") and not labels.has("Credits"),
		"optional story does not expose canonical finale actions")


func _cleanup() -> void:
	if _story != null and is_instance_valid(_story):
		_story.queue_free()
	if _js != null:
		_js.clear_journey()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
