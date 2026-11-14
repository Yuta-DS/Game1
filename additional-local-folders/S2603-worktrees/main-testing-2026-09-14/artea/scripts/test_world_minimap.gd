extends SceneTree

const MinimapScript := preload("res://scripts/art_castle_minimap.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("WORLD_MINIMAP_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var root_node := Node.new()
	root_node.name = "MinimapHarness"
	root.add_child(root_node)
	current_scene = root_node
	var player := CharacterBody3D.new()
	player.name = "NewPlayer"
	player.add_to_group("player")
	root_node.add_child(player)
	var layer := CanvasLayer.new()
	root_node.add_child(layer)
	var minimap := Control.new()
	minimap.set_script(MinimapScript)
	minimap.set("map_context", "hub")
	layer.add_child(minimap)
	await process_frame

	if minimap.call("get_map_context") != "hub":
		_fail("outside scene did not select the kingdom map")
		return
	var first: Vector2 = minimap.call("map_point_for_world", Vector3.ZERO)
	player.global_position = Vector3(80.0, 0.0, 45.0)
	var moved: Vector2 = minimap.call("map_point_for_world", player.global_position)
	if moved.distance_to(first) < 10.0:
		_fail("live player coordinates do not move across the atlas")
		return
	var player_center: Vector2 = minimap.call("compact_point_for_world", player.global_position)
	var expected_center := Vector2(143.0, 126.0)
	if player_center.distance_to(expected_center) > 0.1:
		_fail("compact map does not keep the player centred")
		return
	var east: Vector2 = minimap.call("compact_point_for_world", player.global_position + Vector3(20, 0, 0))
	var north: Vector2 = minimap.call("compact_point_for_world", player.global_position + Vector3(0, 0, 20))
	if east.x <= player_center.x or north.y >= player_center.y:
		_fail("compact projection does not map world +X right and world +Z north")
		return
	player.velocity = Vector3(10, 0, 0)
	minimap.call("_process", 0.25)
	var facing_east: Vector2 = minimap.call("get_player_facing_screen")
	if facing_east.x < 0.9:
		_fail("player arrow does not follow eastward movement")
		return
	player.velocity = Vector3(0, 0, 10)
	minimap.call("_process", 0.25)
	var facing_north: Vector2 = minimap.call("get_player_facing_screen")
	if facing_north.y > -0.9:
		_fail("player arrow is vertically inverted from world movement")
		return
	var camera := Camera3D.new()
	root_node.add_child(camera)
	camera.make_current()
	camera.rotation.y = PI * 0.5
	minimap.call("_process", 0.25)
	var cursor_left: Vector2 = minimap.call("get_player_facing_screen")
	if cursor_left.x > -0.9:
		_fail("cursor-left camera heading is mirrored to the right on the minimap")
		return
	camera.rotation.y = -PI * 0.5
	minimap.call("_process", 0.25)
	var cursor_right: Vector2 = minimap.call("get_player_facing_screen")
	if cursor_right.x < 0.9:
		_fail("cursor-right camera heading is mirrored to the left on the minimap")
		return

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	minimap.call("_on_gui_input", click)
	if not bool(minimap.call("is_full_map_open")) or minimap.size.x < 500.0:
		_fail("clicking the minimap does not expand it over the viewport")
		return
	minimap.call("set_full_map_open", false)
	var map_key := InputEventKey.new()
	map_key.keycode = KEY_M
	map_key.pressed = true
	minimap.call("_unhandled_input", map_key)
	if not bool(minimap.call("is_full_map_open")):
		_fail("M does not open the full map")
		return
	minimap.call("set_full_map_open", false)
	minimap.call("configure", "galaxy", player)
	if minimap.call("get_map_context") != "galaxy":
		_fail("inside scene did not switch to the separate Castle Galaxy map")
		return
	for required_method in ["_draw_compact_landscape", "_draw_hub_full_landscape",
			"_draw_galaxy_full_landscape", "_clip_segment_to_circle"]:
		if not minimap.has_method(required_method):
			_fail("restored minimap is missing %s" % required_method)
			return

	print("WORLD_MINIMAP_TEST: PASS — outside/inside atlases, live tracking, and full map toggle")
	quit()
