extends Node3D

@onready var anim_player = $AnimationPlayer
@onready var player = get_node("../NewPlayer")

@export var dialogue_start_node := "start_zephyr_dialogue"
@export var model_yaw_offset := 180.0  # flip if facing backwards

var player_in_range := false
var is_in_dialogue := false

var wave_timer := 0.0
var is_waving := false


func _ready():
	anim_player.play("Idle_3")


func _process(delta):
	_update_facing()

	# -----------------------
	# INTERACTION (ADDED)
	# -----------------------
	if player_in_range and Input.is_action_just_pressed("interact") and !player.interacting:
		start_dialogue()

	if is_in_dialogue and Input.is_action_just_pressed("ui_cancel"):
		GameManager.end_dialogue()
		return

	# -----------------------
	# ORIGINAL ANIMATION LOGIC (UNCHANGED)
	# -----------------------
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
	target_pos.y = global_position.y

	look_at(target_pos, Vector3.UP)
	rotate_y(deg_to_rad(model_yaw_offset))


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "Wave_One_Hand":
		is_waving = false
		anim_player.play("Idle_3")


# -----------------------
# DIALOGUE (MATCH KNIGHT)
# -----------------------

func start_dialogue():
	if dialogue_start_node == "":
		print("Dialogue not set")
		return

	print("Dialogue triggered from:", name, " node:", dialogue_start_node)

	is_in_dialogue = true
	player.interacting = true

	GameManager.start_dialogue(dialogue_start_node, self)


func end_dialogue():
	is_in_dialogue = false
	player.interacting = false


# -----------------------
# AREA DETECTION
# -----------------------

func _on_area_3d_body_entered(body):
	if body == player:
		player_in_range = true


func _on_area_3d_body_exited(body):
	if body == player:
		player_in_range = false
		end_dialogue()
