extends Node3D


func is_villager_lowpoly_skin() -> bool:
	return true


func is_rabbit_gardener_skin() -> bool:
	return true


func _ready() -> void:
	var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return
	var library := player.get_animation_library("")
	if library == null:
		return
	var aliases := {
		"Idle_3": "Idle",
		"Walk": "Walking_A",
		"Walking": "Walking_A",
		"Run": "Running_A",
		"Running": "Running_A",
		"Wave_One_Hand": "Cheer",
	}
	for alias in aliases:
		var source: String = aliases[alias]
		if not library.has_animation(alias) and player.has_animation(source):
			library.add_animation(alias, player.get_animation(source).duplicate())
