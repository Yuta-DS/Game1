# Automated integration check for the Castle Universe world layer.
# Run with:
# Godot --headless --path artea --script res://scripts/test_castle_universe.gd
extends SceneTree

const LINES := ["mindspark", "heartmelody", "creatorslight"]

var _hub: Node3D
var _rail: Node3D
var _rider: Node3D
var _isles: Node3D
var _player: CharacterBody3D


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("CASTLE_UNIVERSE_TEST: %s" % message)
	Engine.time_scale = 1.0
	quit(1)


func _run() -> void:
	var packed := load("res://scenes/New_Hub_World.tscn") as PackedScene
	if packed == null:
		_fail("hub scene failed to load")
		return
	_hub = packed.instantiate()
	root.add_child(_hub)
	for _i in 36:
		await process_frame

	_rail = _hub.get_node_or_null("SkyRail") as Node3D
	_rider = _hub.get_node_or_null("TrainRider") as Node3D
	_isles = _hub.get_node_or_null("SkyIsles") as Node3D
	_player = _hub.get_node_or_null("NewPlayer") as CharacterBody3D
	if _rail == null or _rider == null or _isles == null or _player == null:
		_fail("required world/travel nodes are missing")
		return

	var stations: Dictionary = _rider.get("_stations")
	if stations.size() != 6:
		_fail("expected 3 outbound + 3 return pads; got %d" % stations.size())
		return
	if _rail.get_node_or_null("GrandStation") == null:
		_fail("Grand Station was not constructed")
		return
	for isle_id in ["mind", "heart", "creator"]:
		if _isles.get_node_or_null("SkyIsle_%s" % isle_id) == null:
			_fail("missing %s island" % isle_id)
			return

	var camera_controller := _find_descendant(_player, "CameraController") as Node3D
	if camera_controller == null or not camera_controller.is_processing_input():
		_fail("scenic mouse-look camera is not active")
		return

	Engine.time_scale = 25.0
	for line_id in LINES:
		var train := _rail.call("get_train", line_id) as Node3D
		if train == null or train.get_child_count() < 15:
			_fail("%s train exterior is incomplete" % line_id)
			return

		var out_key := "%s:out" % line_id
		var out_record: Dictionary = stations[out_key]
		_player.global_position = (out_record["position"] as Vector3) + Vector3.UP
		await process_frame
		if str(_rider.call("_nearest_station")) != out_key:
			_fail("%s outbound pad cannot be selected" % line_id)
			return

		_rider.call("board", line_id, true)
		await process_frame
		if _player.is_physics_processing():
			_fail("player physics stayed active during %s ride" % line_id)
			return
		if not camera_controller.is_processing_input():
			_fail("camera input stopped during %s ride" % line_id)
			return
		if not await _wait_for_ride():
			_fail("%s outbound ride timed out" % line_id)
			return

		var back_key := "%s:back" % line_id
		if str(_rider.call("_nearest_station")) != back_key:
			_fail("%s did not arrive at its island return pad" % line_id)
			return

		_rider.call("board", line_id, false)
		if not await _wait_for_ride():
			_fail("%s return ride timed out" % line_id)
			return
		if str(_rider.call("_nearest_station")) != out_key:
			_fail("%s did not return to its Grand Station dock" % line_id)
			return

	# Door regression: it must follow the real imported castle face, not the old
	# Y=37 trigger position that sat beneath the floating building.
	var castle := _hub.get_node("building_castle_red2") as Node3D
	var door := _hub.get_node("Art_Gallery") as Area3D
	var expected_door := castle.to_global(Vector3(0.0, 0.38, 1.16))
	if door.global_position.distance_to(expected_door) > 0.05:
		_fail("gallery door is not anchored to the castle")
		return

	print("CASTLE_UNIVERSE_TEST: PASS — 3 detailed trains, 6 rides, scenic camera, 4 islands, castle door")
	Engine.time_scale = 1.0
	quit(0)


func _wait_for_ride() -> bool:
	var frames := 0
	while bool(_rider.get("_riding")) and frames < 420:
		await process_frame
		frames += 1
	return not bool(_rider.get("_riding"))


func _find_descendant(node: Node, wanted_name: String) -> Node:
	if node.name == wanted_name:
		return node
	for child in node.get_children():
		var found := _find_descendant(child, wanted_name)
		if found != null:
			return found
	return null
