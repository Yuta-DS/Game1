# CameraFollow.gd
extends Camera3D

@export var player_path: NodePath
@export var follow_height := 3.0        # how high the camera sits
@export var follow_distance := 7.0      # how far behind the player
@export var follow_side := 0.0          # offset to the side (0 = center)
@export var follow_look_at_offset := Vector3(0, 1.6, 0)
@export var lerp_speed := 8.0           # how smoothly it follows

var _mode := "follow"                   # "follow" or "inspect"
var _player: Node3D
var _tween: Tween
var _inspect_focus := Vector3.ZERO

func _ready() -> void:
	_player = get_node_or_null(player_path)
	current = true  # make this the active camera

func _process(delta: float) -> void:
	if _mode == "follow" and _player:
		var basis := _player.global_transform.basis
		var behind := basis.z.normalized()
		var right  := basis.x.normalized()

		var target := _player.global_transform.origin
		target += behind * follow_distance
		target += right * follow_side
		target.y += follow_height

		global_transform.origin = global_transform.origin.lerp(target, clamp(lerp_speed * delta, 0.0, 1.0))
		look_at(_player.global_transform.origin + follow_look_at_offset, Vector3.UP)

	elif _mode == "inspect":
		look_at(_inspect_focus, Vector3.UP)

func enter_inspect(target: Node3D) -> void:
	_mode = "inspect"
	_inspect_focus = target.global_transform.origin

	var forward := target.global_transform.basis.z.normalized()
	var cam_pos := _inspect_focus + (forward * 2.2) + Vector3(0, 1.4, 0)

	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_transform:origin", cam_pos, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func exit_inspect() -> void:
	_mode = "follow"
	if _tween: _tween.kill()
