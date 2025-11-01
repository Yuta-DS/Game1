# CameraFollow.gd
extends Camera3D

@export var player_path: NodePath
@export var follow_offset: Vector3 = Vector3(0, 15, 10)      # where camera sits in follow mode
@export var follow_look_at_offset: Vector3 = Vector3(0, 2, 0) # where camera looks (player chest/head)

var _mode := "follow"
var _player: Node3D
var _tween: Tween
var _inspect_focus := Vector3.ZERO

func _ready() -> void:
	_player = get_node_or_null(player_path)

func _process(_delta: float) -> void:
	if _mode == "follow" and _player:
		global_transform.origin = _player.global_transform.origin + follow_offset
		look_at(_player.global_transform.origin + follow_look_at_offset, Vector3.UP)
	elif _mode == "inspect":
		# keep looking at the painting center while zoomed
		look_at(_inspect_focus, Vector3.UP)

func enter_inspect(target: Node3D) -> void:
	_mode = "inspect"
	_inspect_focus = target.global_transform.origin

	# move the camera a bit in front of the painting, slightly up
	var forward := target.global_transform.basis.z.normalized()
	var cam_target_pos := _inspect_focus + (forward * 2.2) + Vector3(0, 1.4, 0)

	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_transform:origin", cam_target_pos, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func exit_inspect() -> void:
	_mode = "follow"
	if _tween: _tween.kill()
