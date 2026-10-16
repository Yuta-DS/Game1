extends Node3D
const SceneLoader := preload("res://scripts/scene_loader.gd")


func _on_paint_pressed() -> void:
	SceneLoader.change_scene(get_tree(), "res://scenes/drawing_tool.tscn")
