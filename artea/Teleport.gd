extends Area3D
const SceneLoader := preload("res://scripts/scene_loader.gd")

@export var target_scene_path: String = "res://levels/Level2.tscn"

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.is_in_group("player"):  # Make sure only the player triggers it
		SceneLoader.change_scene_with_loading(get_tree(), 'res://scenes/drawing_tool.tscn')
