extends Area3D


## Routed to the kingdom rather than the bare minigame so this door and the
## Crown Line gate lead to the same place. The minigame scenes still exist and
## can be opened directly if they are wanted on their own.
const TARGET_SCENE_PATH = "res://scenes/creators_light_kingdom.tscn"

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		get_tree().change_scene_to_file(TARGET_SCENE_PATH)
