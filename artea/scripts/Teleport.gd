extends Area3D

# NOTE: _on_body_entered ignores this and hard-codes the drawing tool, so this
# export currently does nothing. Left pointing at a real scene rather than the
# old res://levels/Level2.tscn (which does not exist) so that wiring it up
# later does not silently fail.
@export var target_scene_path: String = "res://scenes/drawing_tool.tscn"

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.is_in_group("player"):  # Make sure only the player triggers it
		get_tree().change_scene_to_file('res://scenes/drawing_tool.tscn')
