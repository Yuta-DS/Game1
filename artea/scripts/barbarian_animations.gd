extends Node3D

const RestoreCharacterTexture = preload("res://scripts/npc/restore_character_texture.gd")
const BARBARIAN_ATLAS = preload("res://assets3D/characters/barbarian_texture.png")

@onready var anim_player = $AnimationPlayer

@export var player_path: NodePath
@onready var player = get_node("../NewPlayer")

@export var dialogue_start_node := "start_patron_pallete"
@export var model_yaw_offset := 180.0

var player_in_range := false

var timer := 0.0
var next_cheer_time := 0.0

var is_cheering := false
var is_in_dialogue := false

var cheer_duration := 1.5


func _ready():
	RestoreCharacterTexture.apply(self, BARBARIAN_ATLAS)
	anim_player.play("Idle")
	_schedule_next_cheer()


func _process(delta):
	_update_facing()

	timer += delta

	# interaction ONLY inside zone
	if player_in_range and Input.is_action_just_pressed("interact") and !player.interacting:
		start_dialogue()

	if is_in_dialogue and Input.is_action_just_pressed("ui_cancel"):
		var game_manager := get_node_or_null("/root/GameManager")
		if game_manager != null:
			game_manager.call("end_dialogue")
		return

	# freeze all behavior during dialogue
	if is_in_dialogue:
		return

	# handle cheer timing
	if is_cheering:
		if timer >= next_cheer_time:
			_end_cheer()
		return

	# ensure idle animation
	if anim_player.current_animation != "Idle":
		anim_player.play("Idle")

	# trigger cheer
	if timer >= next_cheer_time:
		_start_cheer()



func _update_facing():
	if player == null:
		return

	var target_pos = player.global_position
	target_pos.y = global_position.y

	look_at(target_pos, Vector3.UP)
	rotate_y(deg_to_rad(model_yaw_offset))


# -----------------------
# CHEER SYSTEM
# -----------------------

func _start_cheer():
	if is_in_dialogue:
		return

	is_cheering = true
	anim_player.play("Cheer")

	next_cheer_time = timer + cheer_duration


func _end_cheer():
	is_cheering = false
	anim_player.play("Idle")
	_schedule_next_cheer()


func _schedule_next_cheer():
	next_cheer_time = timer + randf_range(5.0, 8.0)


# -----------------------
# DIALOGUE SYSTEM
# -----------------------

func start_dialogue():
	if dialogue_start_node == "":
		print("Dialogue not set")
		return
		
	print("Dialogue triggered from:", name, " node:", dialogue_start_node)

	is_in_dialogue = true
	player.interacting = true

	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager != null:
		game_manager.call("start_dialogue", dialogue_start_node, self)


func end_dialogue():
	is_in_dialogue = false
	player.interacting = false
	_schedule_next_cheer()


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
