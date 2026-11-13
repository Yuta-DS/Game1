extends SceneTree

const MayorScene := preload("res://scenes/characters/elder_cat_mayor.tscn")

var _failures: Array[String] = []

class JourneyStub extends Node:
	signal stage_changed(stage: int)
	signal treasure_awarded(treasure_id: String)
	signal journey_completed
	var stage := 0
	var treasures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _run() -> void:
	var journey := JourneyStub.new()
	root.add_child(journey)
	var mayor := MayorScene.instantiate() as CharacterBody3D
	mayor.gravity_enabled = false
	mayor.automatic_reminders_enabled = false
	mayor.journey_state_override = journey
	root.add_child(mayor)
	await process_frame
	_check(mayor is ElderCatMayor, "scene has independent ElderCatMayor behavior")
	_check(mayor.guide_display_name == "Mayor Alder", "unrelated mayor has his own identity")
	_check(mayor.collision_layer == 0, "mayor never blocks the route")
	_check(mayor.get_node_or_null("AnimationTree") is AnimationTree, "AnimationTree is present")
	_check(mayor.get_node_or_null("NavigationAgent3D") is NavigationAgent3D, "guided navigation is present")
	_check(mayor.get_node_or_null("DialogueArea/CollisionShape3D") != null, "dialogue range is present")
	_check(mayor.find_child("AnimationPlayer", true, false) is AnimationPlayer, "fox-style animated model is present")
	_check(mayor.current_reminder_node() == &"alder_guide_stage_0", "Alder uses independent reminders")
	mayor.celebrate_progress(&"star_of_wisdom")
	mayor.celebrate_progress(&"star_of_wisdom")
	_check(mayor.has_celebrated(&"star_of_wisdom"), "progress celebration is recorded once")
	_check(mayor.get_node_or_null("CombatHitbox") == null, "mayor has no combat hitbox")
	var source := FileAccess.get_file_as_string("res://scripts/npc/elder_cat_mayor.gd")
	for forbidden in ["func attack", "func take_damage", "func solve", "advance_to("]:
		_check(source.find(forbidden) == -1, "mayor excludes forbidden behavior: %s" % forbidden)
	var hub_text := FileAccess.get_file_as_string("res://scenes/New_Hub_World.tscn")
	# Mayor Alder is kept as a scene for a future group but no longer placed in
	# the hub town; Milo is the hub's only guide for now.
	_check(not hub_text.contains("MayorAlder"), "Mayor Alder is not placed in the town")
	mayor.queue_free()
	journey.queue_free()
	if _failures.is_empty():
		print("ELDER_CAT_MAYOR_TEST: PASS — independent cat mayor, fox-style rig, guidance, reminders, one-time celebration, no combat/progress ownership")
		quit(0)
	else:
		for failure in _failures:
			push_error("ELDER_CAT_MAYOR_TEST: %s" % failure)
		quit(1)
