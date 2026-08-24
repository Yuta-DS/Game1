extends SceneTree

const OUTPUT_DIR := "res://artifacts/castle_galaxy_bridge_ingame"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 80:
		await process_frame
	for layer in gallery.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	for label in gallery.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false

	var holder := gallery.get_node_or_null(
		"ArtCastleFloatingWorld/CastleToGalaxyBridge175m/ReferenceFrontGate") as Node3D
	if holder == null:
		push_error("CASTLE_GALAXY_BRIDGE_CAPTURE: Blender asset holder missing")
		quit(1)
		return
	var bounds := _visual_bounds(holder)
	print("CASTLE_GALAXY_BRIDGE_CAPTURE: imported bounds position=%s size=%s" % [
		bounds.position, bounds.size])
	if bounds.size.x < 40.0 or bounds.size.y < 50.0 or bounds.size.z < 169.0:
		push_error("CASTLE_GALAXY_BRIDGE_CAPTURE: imported asset is below authored scale")
		quit(1)
		return

	var camera := gallery.get_node("Camera3D") as Camera3D
	camera.set_script(null)
	camera.far = 1200.0
	camera.fov = 58.0
	camera.global_position = Vector3(42.0, 28.0, 48.0)
	camera.look_at(Vector3(0.0, 17.0, 182.0), Vector3.UP)
	await _save("%s/bridge_gate_hero.png" % OUTPUT_DIR)
	camera.fov = 68.0
	camera.global_position = Vector3(0.0, 3.2, 63.0)
	camera.look_at(Vector3(0.0, 16.0, 184.0), Vector3.UP)
	await _save("%s/bridge_gate_player.png" % OUTPUT_DIR)
	camera.fov = 60.0
	camera.global_position = Vector3(31.0, 18.0, 154.0)
	camera.look_at(Vector3(0.0, 22.0, 184.0), Vector3.UP)
	await _save("%s/gate_masonry_detail.png" % OUTPUT_DIR)
	print("CASTLE_GALAXY_BRIDGE_CAPTURE: PASS")
	quit()


func _visual_bounds(root_node: Node3D) -> AABB:
	var found := false
	var result := AABB()
	for candidate in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_aabb := mesh_instance.mesh.get_aabb()
		var transformed := mesh_instance.global_transform * local_aabb
		if not found:
			result = transformed
			found = true
		else:
			result = result.merge(transformed)
	return result


func _save(path: String) -> void:
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("CASTLE_GALAXY_BRIDGE_CAPTURE: failed %s" % path)
		quit(error)
