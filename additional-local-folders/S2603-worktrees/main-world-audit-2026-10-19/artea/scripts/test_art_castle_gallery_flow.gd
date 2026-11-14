# End-to-end contract for the Art Castle doorway and Art Explore handoff.
extends SceneTree


func _fail(message: String) -> void:
	push_error("ART_CASTLE_GALLERY_TEST: %s" % message)
	quit(1)


func _run() -> void:
	# Reproduce the imported castle transform without loading terrain, scatter,
	# inventory and the local LLM. This is the exact relationship used by the
	# real hub's sibling castle and Art_Gallery nodes.
	var hub := Node3D.new()
	root.add_child(hub)
	var castle := Node3D.new()
	castle.name = "building_castle_red2"
	castle.transform = Transform3D(
		Basis(Vector3(-4.37114e-07, 0.0, -10.0), Vector3(0.0, 10.0, 0.0),
			Vector3(10.0, 0.0, -4.37114e-07)),
		Vector3(-51.4, 74.49, 27.4105))
	hub.add_child(castle)
	var portal := Area3D.new()
	portal.name = "Art_Gallery"
	portal.set_script(load("res://scripts/teleport_Art_Gallery.gd"))
	var authored_collision := CollisionShape3D.new()
	authored_collision.name = "CollisionShape3D"
	authored_collision.shape = BoxShape3D.new()
	portal.add_child(authored_collision)
	hub.add_child(portal)
	await process_frame
	if str(portal.get("TARGET_SCENE_PATH")) != "res://scenes/art_gallery_3d_inprogress.tscn":
		_fail("castle door bypasses the Art Gallery")
		return
	if not ResourceLoader.exists(str(portal.get("TARGET_SCENE_PATH"))):
		_fail("Art Explore destination scene is missing")
		return

	# The imported castle doorway is at (-39.8, 78.33, 27.41). The trigger
	# must follow that raised threshold, rather than its legacy ground position.
	var expected_door := Vector3(-39.8, 78.33, 27.41)
	if portal.global_position.distance_to(expected_door) > 0.35:
		_fail("Art Explore trigger is not at the raised castle door: %s"
			% portal.global_position)
		return
	var collision := portal.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null or not (collision.shape is BoxShape3D) or collision.disabled:
		_fail("Art Explore doorway has no enabled box trigger")
		return
	var size := (collision.shape as BoxShape3D).size
	if size.x < 2.0 or size.y < 3.0 or size.z < 2.0:
		_fail("Art Explore trigger is too small for the player: %s" % size)
		return

	var marker := portal.get_node_or_null("ArtExploreMarker") as Label3D
	if marker == null or not marker.visible or not marker.text.contains("ART EXPLORE"):
		_fail("the castle door has no visible Art Explore marker")
		return
	if portal.get_node_or_null("GalleryDoorRig") == null:
		_fail("the castle door has no visible portal architecture")
		return

	# Validate the gallery side without taking a network dependency. Placeholder
	# artwork is loaded synchronously and must become a walkable local 3D world.
	hub.free()
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 5:
		await process_frame
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	if player == null:
		_fail("Art Explore gallery has no player")
		return
	var manager := gallery.get_node_or_null("GalleryManager")
	if manager == null:
		_fail("gallery artwork manager is missing")
		return
	for frame_index in 12:
		var frame_name := "Frame_%02d" % (frame_index + 1)
		var frame := gallery.get_node_or_null(frame_name) as Sprite3D
		if frame == null or frame.texture == null or not frame.visible:
			_fail("%s has no visible gallery artwork" % frame_name)
			return
		if gallery.get_node_or_null("%s/InteractionArea" % frame_name) == null:
			_fail("%s cannot be entered by the player" % frame_name)
			return
		var surround := frame.get_node_or_null("ArtworkSurround")
		if surround == null or surround.get_child_count() < 12:
			_fail("%s has no fitted picture surround" % frame_name)
			return
		if gallery.get_node_or_null("Frame_Asset%02d" % (frame_index + 1)) != null:
			_fail("%s still has the oversized legacy gold frame" % frame_name)
			return
		var trigger := frame.get_node_or_null("InteractionArea/CollisionShape3D") as CollisionShape3D
		if trigger == null or not trigger.shape is BoxShape3D:
			_fail("%s has no picture interaction volume" % frame_name)
			return
		var bottom := trigger.to_global(Vector3(0, -(trigger.shape as BoxShape3D).size.y * 0.5, 0)).y
		if bottom > player.global_position.y:
			_fail("%s interaction volume is above the player" % frame_name)
			return
	gallery.call("_on_interaction_area_body_entered", player, "Frame_01")
	if not bool(gallery.get("player_near_artwork")):
		_fail("gallery artwork interaction does not recognise the player")
		return
	var artwork_path := str(manager.call("prepare_frame_for_world", "Frame_01")) \
		if manager != null else ""
	if artwork_path.is_empty() or not FileAccess.file_exists(artwork_path):
		_fail("gallery artwork cannot be prepared for Art Explore")
		return
	# Keep the exact prepared source stable when the real handler resolves this
	# frame again; otherwise placeholder textures are exported under a new
	# timestamp and correctly begin a separate world build.
	manager.set("frame_to_artwork", {"Frame_01": artwork_path})
	var state := root.get_node_or_null("CreationWorldState")
	if state == null:
		_fail("CreationWorldState is missing, so Art Explore cannot open")
		return
	if not ResourceLoader.exists("res://scenes/creation_world.tscn"):
		_fail("interactive artwork world scene is missing")
		return

	# Exercise the player's real Space handler all the way through its world
	# preparation and scene change, without prebuilding a manifest.
	current_scene = gallery
	Input.action_press("jump")
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	gallery.call("_input", space)
	if not bool(gallery.get("_world_opening")) or bool(player.get("input_enabled")):
		_fail("Space did not lock movement while opening the artwork")
		return
	var camera := gallery.get_node("Camera3D")
	if str(camera.get("_mode")) != "follow":
		_fail("Space also switched the camera into inspect mode")
		return
	await process_frame
	await process_frame
	var world := current_scene
	if world == null or world.scene_file_path != "res://scenes/creation_world.tscn":
		var current := "nothing" if world == null else "%s (%s), status: %s" % [
			world.name, world.scene_file_path, gallery.get_node("CanvasLayer/RatingPanel/RatingLabel").text]
		_fail("pressing Enter at gallery artwork did not open the 3D world; current scene is %s"
			% current)
		return
	if world.find_child("CreationWorldPlayer", true, false) == null:
		_fail("interactive artwork world did not create a walking player")
		return
	var artwork_player := world.find_child("CreationWorldPlayer", true, false)
	# Main may clear held actions during the scene transition. A release lock
	# is only needed when Space remains held in the new scene.
	if Input.is_action_pressed("jump") and not bool(artwork_player.get("_jump_requires_release")):
		_fail("held Space can make the new artwork player jump on arrival")
		return
	Input.action_release("jump")
	for _frame in 3:
		await physics_frame
	if bool(artwork_player.get("_jump_requires_release")):
		_fail("artwork jump did not reset after releasing Space (pressed=%s)" %
			str(Input.is_action_pressed("jump")))
		return
	var exit_button := world.find_child("ExitArtworkButton", true, false) as Button
	if exit_button == null:
		_fail("interactive artwork world has no Exit Artwork button")
		return
	var interactive_found := false
	for actor in world.find_children("*", "StaticBody3D", true, false):
		if bool(actor.get_meta("artwork_interactive", false)):
			interactive_found = true
			break
	if not interactive_found:
		_fail("interactive artwork world contains no responsive 3D artwork objects")
		return
	exit_button.pressed.emit()
	var return_deadline := Time.get_ticks_msec() + 30000
	while (current_scene == null or current_scene.scene_file_path !=
			"res://scenes/art_gallery_3d_inprogress.tscn") \
			and Time.get_ticks_msec() < return_deadline:
		await process_frame
	if current_scene == null or current_scene.scene_file_path != \
			"res://scenes/art_gallery_3d_inprogress.tscn":
		_fail("Exit Artwork button did not return to the gallery")
		return

	print("ART_CASTLE_GALLERY_TEST: PASS — fitted frames, Space entry, held-key protection, Exit Artwork button and gallery return")
	quit()


func _init() -> void:
	call_deferred("_run")
