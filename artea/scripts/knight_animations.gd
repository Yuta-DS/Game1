extends Node3D

@onready var anim_player = $AnimationPlayer

@export var player_path: NodePath
@onready var player = get_node("../NewPlayer")

@export var model_yaw_offset := 180.0

var timer := 0.0
var next_cheer_time := 0.0
var is_cheering := false
var cheer_duration := 1.5  # fallback safety


func _ready():
	anim_player.play("Idle")
	_schedule_next_cheer()


func _process(delta):
	_update_facing()

	timer += delta

	if is_cheering:
		# safety fallback in case signal fails
		if timer >= next_cheer_time:
			_end_cheer()
		return

	if anim_player.current_animation != "Idle":
		anim_player.play("Idle")

	if timer >= next_cheer_time:
		_start_cheer()


func _update_facing():
	if player == null:
		return

	var target_pos = player.global_position
	target_pos.y = global_position.y

	look_at(target_pos, Vector3.UP)
	rotate_y(deg_to_rad(model_yaw_offset))


func _start_cheer():
	is_cheering = true
	anim_player.play("Cheer")

	# fallback safety timer in case animation_finished doesn't fire
	next_cheer_time = timer + cheer_duration


func _end_cheer():
	is_cheering = false
	anim_player.play("Idle")
	_schedule_next_cheer()


func _schedule_next_cheer():
	next_cheer_time = timer + randf_range(5.0, 8.0)
