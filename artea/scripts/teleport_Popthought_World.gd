extends Area3D
const SceneLoader := preload("res://scripts/scene_loader.gd")

const TARGET_SCENE_PATH = "res://scenes/popThoughtsMenu.tscn"

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		SceneLoader.change_scene(get_tree(), TARGET_SCENE_PATH)
