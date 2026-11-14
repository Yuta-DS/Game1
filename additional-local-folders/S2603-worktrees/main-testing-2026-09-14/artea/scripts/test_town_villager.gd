extends SceneTree

const VillagerScene := preload("res://scenes/characters/town_villager.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _run() -> void:
	var villager := VillagerScene.instantiate() as CharacterBody3D
	villager.wander_enabled = false
	root.add_child(villager)
	await process_frame
	_check(villager is TownVillager, "scene uses TownVillager behavior")
	_check(villager.is_in_group("npc") and villager.is_in_group("villager"), "NPC groups are present")
	_check(villager.collision_layer == 0, "villager does not block the player route")
	_check(villager.get_node_or_null("NavigationAgent3D") is NavigationAgent3D, "navigation agent is present")
	_check(villager.get_node_or_null("DialogueArea/CollisionShape3D") != null, "dialogue area is present")
	_check(villager.find_child("AnimationPlayer", true, false) is AnimationPlayer, "animated low-poly model is present")
	_check(villager.get_node_or_null("CombatHitbox") == null, "villager has no combat hitbox")
	var source := FileAccess.get_file_as_string("res://scripts/npc/town_villager.gd")
	for forbidden in ["func attack", "func take_damage", "func die"]:
		_check(source.find(forbidden) == -1, "non-combat script excludes %s" % forbidden)
	var hub := load("res://scenes/New_Hub_World.tscn") as PackedScene
	var hub_state := hub.get_state()
	var found_instance := false
	for index in hub_state.get_node_count():
		if String(hub_state.get_node_name(index)) == "Villager_Greeter":
			found_instance = true
	_check(found_instance, "new villager is placed in the hub")
	villager.queue_free()
	if _failures.is_empty():
		print("TOWN_VILLAGER_TEST: PASS — animated low-poly civilian, safe wandering, greeting area, no combat")
		quit(0)
	else:
		for failure in _failures:
			push_error("TOWN_VILLAGER_TEST: %s" % failure)
		quit(1)

