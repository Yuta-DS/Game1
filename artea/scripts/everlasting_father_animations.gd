extends Node3D

@onready var anim_player = $AnimationPlayer

@export var player_path: NodePath
@onready var player = get_node("../NewPlayer")

@export var model_yaw_offset := 180.0  # flip if facing backwards

var wave_timer := 0.0
var is_waving := false


func _ready():
	anim_player.play("Idle_3")


func _process(delta):
	_update_facing()

	if is_waving:
		return

	wave_timer += delta

	if anim_player.current_animation != "Idle_3":
		anim_player.play("Idle_3")

	if wave_timer >= 5.0:
		is_waving = true
		wave_timer = 0.0
		anim_player.play("Wave_One_Hand")


func _update_facing():
	if player == null:
		return

	var target_pos = player.global_position
	target_pos.y = global_position.y  # keep upright

	look_at(target_pos, Vector3.UP)

	# fixes backwards-facing models
	rotate_y(deg_to_rad(model_yaw_offset))


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "Wave_One_Hand":
		is_waving = false
		anim_player.play("Idle_3")
