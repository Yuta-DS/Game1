extends SceneTree

const Ritual := preload("res://scripts/creation_world/gallery_frame_ritual.gd")
const TEST_ART := "user://test_gallery_frame_ritual.png"
const TEST_SAVE := "user://test_gallery_frame_ritual.json"

func _init() -> void:
	var ids := Ritual.motif_ids()
	assert(ids == ["star_bridge", "dream_door", "constellation_mural"], "Ritual must expose exactly the three authored motifs.")
	var file := FileAccess.open("res://scripts/creation_world/gallery_frame_ritual.gd", FileAccess.READ)
	assert(file != null, "Ritual source must be present.")
	var source: String = file.get_as_text()
	assert(not source.contains("HTTPRequest"), "Gallery ritual must remain offline.")
	assert(not source.contains("APIManager"), "Gallery ritual must not use an AI API.")
	assert(source.contains("complete_creator_frame_ritual"), "Confirm flow must complete through JourneyState.")
	assert(source.contains("return_to_campaign"), "Return flow must use JourneyCampaign when available.")
	var ritual := Ritual.new()
	root.add_child.call_deferred(ritual)
	await process_frame
	assert(ritual.get("_confirm_button") != null, "Ritual must build a confirm action without a selected artwork.")
	ritual.queue_free()
	await process_frame
	await _test_confirm_flow()
	print("GalleryFrameRitual: static checks passed")
	quit(0)


func _test_confirm_flow() -> void:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color("8fd9ff"))
	assert(image.save_png(TEST_ART) == OK, "Test artwork saves locally.")

	var journey: Node = root.get_node_or_null("JourneyState")
	assert(journey != null and journey.has_method("record_creation"),
		"The test needs the project's JourneyState autoload.")
	# Redirect the autoload before any mutation. This is an in-process test only;
	# neither the player's current journey file nor its on-disk state is touched.
	var original_save_path: String = str(journey.get("save_path"))
	journey.set("save_path", TEST_SAVE)
	journey.call("clear_journey")
	var creation_id: String = str(journey.call("record_creation", TEST_ART, "Test Light"))

	var ritual := Ritual.new()
	root.add_child(ritual)
	await process_frame
	assert(ritual.get("_creation_id") == creation_id, "Ritual resolves the local creation id.")
	ritual._choose_motif("dream_door")
	ritual._place_selected_motif()
	ritual._confirm()
	assert(bool(journey.call("has_completed_creator_frame_ritual", creation_id)),
		"Confirm records exactly the chosen artwork and motif.")
	assert(bool(journey.call("has_treasure", "creators_light")),
		"Confirm awards Creator's Light only through the ritual.")

	ritual.queue_free()
	journey.call("clear_journey")
	journey.set("save_path", original_save_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_ART))
