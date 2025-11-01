# PaintingInteraction.gd (reuse for all frames)
extends Node3D

@export var painting_id: int = 0
@export var camera_path: NodePath  # drag your Camera3D here in the Inspector

var _player_in_range := false
var _camera: Node = null

func _ready() -> void:
	_camera = get_node_or_null(camera_path)
	if has_node("InteractionArea"):
		$InteractionArea.connect("body_entered", Callable(self, "_on_body_entered"))
		$InteractionArea.connect("body_exited", Callable(self, "_on_body_exited"))
	else:
		push_warning("Missing InteractionArea under %s" % name)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_in_range = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_in_range = false

func _process(_delta: float) -> void:
	# Enter inspect
	if _player_in_range and Input.is_action_just_pressed("ui_accept"):
		if _camera and _camera.has_method("enter_inspect"):
			_camera.enter_inspect(self)
		_lock_player(true)

	# Exit inspect
	if Input.is_action_just_pressed("ui_cancel"):
		if _camera and _camera.has_method("exit_inspect"):
			_camera.exit_inspect()
		_lock_player(false)

func _lock_player(lock: bool) -> void:
	var players := get_tree().get_nodes_in_group("Player")
	if players.size() > 0 and players[0].has_method("set_input_enabled"):
		players[0].set_input_enabled(not lock)
