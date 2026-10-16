extends Node3D
const SceneLoader := preload("res://scripts/scene_loader.gd")


func _on_pop_thoughts_pressed() -> void:
	SceneLoader.change_scene(get_tree(), "res://scenes/popThoughtsMenu.tscn")
