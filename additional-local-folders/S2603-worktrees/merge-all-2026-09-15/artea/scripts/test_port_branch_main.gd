extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("PORT_BRANCH_MAIN_TEST: %s" % message)
	quit(1)

func _run() -> void:
	var hub_source := FileAccess.get_file_as_string("res://scenes/New_Hub_World.tscn")
	for required in ["res://scenes/watchtower_harbour_link.tscn",
			"[node name=\"WatchtowerHarbourLink\"", "position = Vector3(38, 0.9, 184)",
			"position = Vector3(32, 0.92, 197.4)"]:
		if not hub_source.contains(required):
			_fail("latest-main hub is missing port integration: %s" % required)
			return

	var port := (load("res://scripts/Pier.tscn") as PackedScene).instantiate() as Node3D
	var link := (load("res://scenes/watchtower_harbour_link.tscn") as PackedScene).instantiate() as Node3D
	var boat := (load("res://scenes/boat.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(port)
	root.add_child(link)
	root.add_child(boat)
	await process_frame
	if port.find_child("HarbourModel", true, false) == null:
		_fail("harbour model is missing")
		return
	if link.find_child("PorchPost*", true, false) != null:
		_fail("porch supports block the walking surface")
		return
	if link.find_children("HarbourCollision", "StaticBody3D", true, false).size() < 60:
		_fail("watchtower connector collision metadata did not bind")
		return
	if not boat.has_method("is_boarded") or not boat.has_method("disembark"):
		_fail("rideable boat controls are missing")
		return

	print("PORT_BRANCH_MAIN_TEST: PASS — port, rideable boat and clear watchtower connector are wired into latest main")
	quit(0)
