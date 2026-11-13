extends Area3D
const SceneLoader := preload("res://scripts/scene_loader.gd")

# NOTE: _on_body_entered ignores this and hard-codes the drawing tool, so this
# export currently does nothing. Left pointing at a real scene rather than the
# old res://levels/Level2.tscn (which does not exist) so that wiring it up
# later does not silently fail.
@export var target_scene_path: String = "res://scenes/drawing_tool.tscn"

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.is_in_group("player"):  # Make sure only the player triggers it
		SceneLoader.change_scene_with_loading(get_tree(), 'res://scenes/drawing_tool.tscn')
