extends Node3D

# The exported model is one smooth low-poly mesh weighted to the same skeleton
# and animation library as the market villagers.


func is_villager_lowpoly_skin() -> bool:
	return true


func _ready() -> void:
	var animation_player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		return
	var library := animation_player.get_animation_library("")
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
		if not library.has_animation(alias) and animation_player.has_animation(source):
			library.add_animation(alias, animation_player.get_animation(source).duplicate())
