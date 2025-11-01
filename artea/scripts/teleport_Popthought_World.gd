extends Area3D

const TARGET_SCENE_PATH = "res://scenes/popThoughtsMenu.tscn"

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		get_tree().change_scene_to_file(TARGET_SCENE_PATH)
