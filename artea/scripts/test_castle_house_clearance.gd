extends SceneTree

const STAIR_BASE := Vector2(-1.4, 27.41)
const BUILDING_CLEAR_RADIUS := 35.0
const BUILDING_TOKENS: Array[String] = [
	"home", "house", "blacksmith", "archery", "tavern", "market",
	"church", "lumbermill", "watermill",
]


func _fail(message: String) -> void:
	push_error("CASTLE_HOUSE_CLEARANCE_TEST: %s" % message)
	quit(1)


func _is_building_name(node_name: String) -> bool:
	var lower_name := node_name.to_lower()
	for token in BUILDING_TOKENS:
		if lower_name.contains(token):
			return true
	return false


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 60:
		await process_frame
		await physics_frame

	var district := hub.get_node_or_null("District_HeartMelody")
	if district == null:
		_fail("Heart Melody district is missing")
		return

	var offenders: Array[String] = []
	for candidate in district.get_children():
		if not (candidate is Node3D) or not _is_building_name(String(candidate.name)):
			continue
		var building := candidate as Node3D
		var building_xz := Vector2(building.global_position.x, building.global_position.z)
		var distance := building_xz.distance_to(STAIR_BASE)
		if distance < BUILDING_CLEAR_RADIUS:
			offenders.append("%s at %.2f m" % [building.name, distance])
	if not offenders.is_empty():
		_fail("village buildings remain inside stair precinct: %s" % ", ".join(offenders))
		return

	# A home in the main Heart Melody village remains well beyond the exterior
	# row. Keeping it proves the cleanup is local to the Art Castle precinct
	# rather than erasing the village.
	if district.get_node_or_null("hm_home_6") == null:
		_fail("far village home was removed; cleanup radius is too broad")
		return

	print("CASTLE_HOUSE_CLEARANCE_TEST: PASS — no village houses or workshops remain within 35 m of the Art Castle stair; farther district preserved")
	quit()


func _init() -> void:
	call_deferred("_run")
