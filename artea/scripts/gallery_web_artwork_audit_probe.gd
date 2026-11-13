extends Node

## Opt-in browser check for Space entering an artwork and its visible exit.
## This node lives under /root so it survives both scene changes in the flow.

var gallery: Node3D
var errors: Array[String] = []


func configure(gallery_node: Node3D) -> void:
	gallery = gallery_node
	_run.call_deferred()


func _run() -> void:
	var report := {"ok": false, "errors": errors, "frames": 0,
		"chandeliers": 0,
		"space_entered": false, "exit_visible": false, "returned": false}
	for _frame in 4:
		await get_tree().process_frame
	if gallery == null or not is_instance_valid(gallery):
		errors.append("Art Castle gallery did not load")
		_finish(report)
		return
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	var manager := gallery.get_node_or_null("GalleryManager")
	if player == null or manager == null:
		errors.append("gallery player or artwork manager is missing")
		_finish(report)
		return
	for frame_index in 12:
		var frame_name := "Frame_%02d" % (frame_index + 1)
		var frame := gallery.get_node_or_null(frame_name) as Sprite3D
		if frame == null or frame.texture == null or not frame.visible \
				or gallery.get_node_or_null("%s/InteractionArea" % frame_name) == null:
			errors.append("artwork %s is missing or cannot be entered" % frame_name)
			_finish(report)
			return
		report.frames += 1
	gallery.call("_on_interaction_area_body_entered", player, "Frame_01")
	if not bool(gallery.get("player_near_artwork")):
		errors.append("gallery does not recognize nearby artwork")
		_finish(report)
		return
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	if not space.is_action_pressed("ui_accept"):
		errors.append("Space is not mapped to gallery interaction")
		_finish(report)
		return
	gallery.call("_input", space)
	for _frame in 900:
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == "res://scenes/creation_world.tscn":
			report.space_entered = true
			break
	if not bool(report.space_entered):
		errors.append("Space did not open the interactive artwork world")
		_finish(report)
		return
	var artwork_world := get_tree().current_scene
	if artwork_world.find_child("CreationWorldPlayer", true, false) == null:
		errors.append("interactive artwork world has no walking player")
		_finish(report)
		return
	var exit_button := artwork_world.find_child("GalleryButton", true, false) as Button
	if exit_button == null or not exit_button.is_visible_in_tree():
		errors.append("artwork world has no visible Gallery exit button")
		_finish(report)
		return
	report.exit_visible = true
	exit_button.pressed.emit()
	for _frame in 900:
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current != null \
				and current.scene_file_path == "res://scenes/art_gallery_3d_inprogress.tscn":
			report.returned = true
			break
	if not bool(report.returned):
		errors.append("Gallery exit button did not return to Art Castle gallery")
	else:
		var returned_gallery := get_tree().current_scene
		for gallery_node in returned_gallery.find_children(
				"*", "Node3D", true, false):
			if str(gallery_node.name).to_lower().contains("chandelier"):
				report.chandeliers += 1
		if int(report.chandeliers) != 0:
			errors.append("removed gallery chandeliers are present after artwork return")
		var returned_player := returned_gallery.get_node_or_null("Player3D") as CharacterBody3D
		var gallery_entry := returned_gallery.get_node_or_null("CastleGalleryEntry") as Marker3D
		if returned_player == null or gallery_entry == null \
				or returned_player.global_position.distance_to(gallery_entry.global_position) > 1.0:
			errors.append("Gallery exit returned to World One instead of the gallery hall")
	_finish(report)


func _finish(report: Dictionary) -> void:
	report.ok = errors.is_empty() and int(report.frames) == 12 \
		and int(report.chandeliers) == 0 \
		and bool(report.space_entered) and bool(report.exit_visible) \
		and bool(report.returned)
	if OS.has_feature("web") and bool(report.returned) \
			and "gallery_view=entrance" in str(JavaScriptBridge.eval(
				"window.location.search", true)):
		var returned_gallery := get_tree().current_scene as Node3D
		if returned_gallery != null:
			var camera := Camera3D.new()
			camera.name = "GalleryEntranceAuditCamera"
			returned_gallery.add_child(camera)
			camera.global_position = returned_gallery.to_global(Vector3(0.0, 12.0, 52.0))
			camera.look_at(returned_gallery.to_global(Vector3(0.0, 11.0, 15.0)),
				Vector3.UP)
			camera.fov = 64.0
			camera.far = 500.0
			camera.make_current()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__ARTEA_GALLERY_AUDIT__ = %s;" % JSON.stringify(report), true)
	print("GALLERY_WEB_AUDIT: %s" % JSON.stringify(report))
