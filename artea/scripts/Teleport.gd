extends Area3D

@export var target_scene_path: String = "res://levels/Level2.tscn"

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.is_in_group("player"):  # Make sure only the player triggers it
		get_tree().change_scene_to_file('res://scenes/drawing_tool.tscn')
