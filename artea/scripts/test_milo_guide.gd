extends SceneTree

const GuideScene := preload("res://scenes/characters/milo_guide.tscn")
const GuidePointScript := preload("res://scripts/npc/milo_guide_point.gd")

class TestJourneyState:
	extends Node
	var stage := 0
	var treasures := {
		"star_of_wisdom": false,
		"harmony_jewel": false,
		"creators_light": false,
	}


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("MILO_GUIDE_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "NewPlayer"
	player.position = Vector3(20, 0, 20)
	world.add_child(player)

	var points := Node3D.new()
	points.name = "MiloGuidePoints"
	world.add_child(points)
	var home := _point("HomePoint", &"home", Vector3.ZERO)
	var destination := _point("ReminderPoint", &"reminder", Vector3(1.2, 0, 0))
	var celebration := _point("CelebrationPoint", &"celebration", Vector3(0.8, 0, 0.8))
	points.add_child(home)
	points.add_child(destination)
	points.add_child(celebration)

	var milo := GuideScene.instantiate() as CharacterBody3D
	milo.name = "MiloGuide"
	milo.set("gravity_enabled", false)
	milo.set("automatic_reminders_enabled", false)
	var isolated_journey := TestJourneyState.new()
	world.add_child(isolated_journey)
	milo.set("journey_state_override", isolated_journey)
	world.add_child(milo)
	await process_frame

	_check(milo != null, "guide scene is a CharacterBody3D")
	_check(milo.get_node_or_null("AnimationTree") is AnimationTree, "AnimationTree is present")
	var tree := milo.get_node("AnimationTree") as AnimationTree
	_check(tree.active and tree.tree_root is AnimationNodeStateMachine,
		"AnimationTree owns the guide state machine")
	_check(milo.get_node_or_null("DialogueArea/CollisionShape3D") != null,
		"dialogue Area3D and shape are present")
	_check(milo.get_node_or_null("NavigationAgent3D") is NavigationAgent3D,
		"NavigationAgent3D is present")
	_check(milo.collision_layer == 0, "Milo cannot physically block the player")
	_check(milo.find_child("CombatHitbox", true, false) == null,
		"no combat hitbox exists")

	var source := FileAccess.get_file_as_string("res://scripts/npc/milo_guide.gd").to_lower()
	for forbidden in ["func attack", "func damage", "func solve", "func complete_objective"]:
		_check(not source.contains(forbidden), "guide owns no forbidden action: %s" % forbidden)

	var journey: Node = isolated_journey
	var stage_before := int(journey.stage)
	var treasures_before: Dictionary = journey.treasures.duplicate(true)
	var walk_start := milo.global_position
	milo.call("request_guide_point", destination)
	_check(str(milo.call("guide_state_name")) == "WALKING_TO_POINT",
		"requesting a guide point enters WALKING_TO_POINT")
	for _frame in 24:
		await physics_frame
	var walked := Vector2(milo.global_position.x - walk_start.x,
		milo.global_position.z - walk_start.z).length()
	_check(walked > 0.2, "Milo walks toward an explicitly requested guide point (%.3f, %s, start=%s target=%s end=%s)" % [walked, milo.call("guide_state_name"), walk_start, destination.global_position, milo.global_position])
	_check(str(milo.call("guide_state_name")) in ["WALKING_TO_POINT", "IDLE"],
		"guide movement stays inside the non-combat state machine")
	milo.call("open_dialogue", &"milo_guide_stage_0")
	await process_frame
	_check(str(milo.call("guide_state_name")) == "TALKING" and is_zero_approx(milo.velocity.x),
		"Milo stops when dialogue begins")
	var dialogue_manager := root.get_node_or_null("GameManager")
	_check(dialogue_manager != null, "existing dialogue owner is available")
	dialogue_manager.call("end_dialogue")
	await process_frame
	_check(str(milo.call("guide_state_name")) == "IDLE",
		"Milo releases dialogue state when the existing UI closes")

	_check(StringName(milo.call("current_reminder_node")) == &"milo_guide_stage_0",
		"stage-aware reminder selects the opening mission")
	var celebrations := {"count": 0}
	milo.connect("celebration_started",
		func(_id: StringName) -> void: celebrations.count += 1)
	milo.call("celebrate_progress", &"test_objective")
	milo.call("celebrate_progress", &"test_objective")
	# Move Milo to the point immediately so arrival owns the celebration state.
	milo.global_position = celebration.global_position
	for _frame in 3:
		await physics_frame
	_check(int(celebrations.count) == 1, "an objective is celebrated only once")
	_check(bool(milo.call("has_celebrated", &"test_objective")),
		"celebration history is retained")

	if journey != null:
		_check(int(journey.stage) == stage_before, "Milo never changes journey stage")
		_check(journey.treasures == treasures_before, "Milo never awards puzzle treasure")

	_check(FileAccess.get_file_as_string("res://scenes/New_Hub_World.tscn").contains("MiloGuidePoints"),
		"the hub provides authored Marker3D guide points")
	print("MILO_GUIDE_TEST: PASS — AnimationTree, dialogue area, requested guide movement, non-blocking body, short reminders, one-time celebration, no progress ownership")
	world.queue_free()
	await process_frame
	quit()


func _point(node_name: String, point_id: StringName, point_position: Vector3) -> Marker3D:
	var point := Marker3D.new()
	point.name = node_name
	point.set_script(GuidePointScript)
	point.set("guide_point_id", point_id)
	point.position = point_position
	return point
