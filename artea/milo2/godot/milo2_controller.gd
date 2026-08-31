extends CharacterBody3D

@export var walk_speed := 1.55
@export var preferred_distance := 2.7
@export var follow_distance := 4.2
@export var interaction_distance := 4.5
@export var turn_speed := 5.5

@onready var skin: Node3D = $Milo2Skin
@onready var interaction_prompt: Label3D = $InteractionPrompt

var player: Node3D
var player_is_near := false
var _wave_time := 0.0


func _ready() -> void:
	add_to_group("milo")
	add_to_group("milo_2")
	player = get_tree().get_first_node_in_group("player") as Node3D
	_play(&"Milo2_Idle")


func _physics_process(delta: float) -> void:
	if _wave_time > 0.0:
		_wave_time -= delta
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 5.0 * delta)
		move_and_slide()
		if _wave_time <= 0.0:
			_play(&"Milo2_Idle")
		return

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(player):
		_play(&"Milo2_Idle")
		return

	var flat_offset := player.global_position - global_position
	flat_offset.y = 0.0
	var distance := flat_offset.length()
	if distance > 0.08:
		var target_yaw := atan2(flat_offset.x, flat_offset.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, turn_speed * delta))

	if distance > follow_distance:
		var direction := flat_offset.normalized()
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
		_play(&"Milo2_Walk")
	elif distance < preferred_distance * 0.72:
		var retreat := -flat_offset.normalized()
		velocity.x = retreat.x * walk_speed * 0.42
		velocity.z = retreat.z * walk_speed * 0.42
		_play(&"Milo2_Walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 6.0 * delta)
		_play(&"Milo2_Idle")
	move_and_slide()

	player_is_near = distance <= interaction_distance
	interaction_prompt.visible = player_is_near
	if player_is_near and Input.is_action_just_pressed("ui_accept"):
		_wave_time = 1.5
		_play(&"Milo2_Wave")


func get_milo_generation() -> int:
	return 2


func _play(clip: StringName) -> void:
	if skin != null and skin.has_method("play"):
		skin.call("play", clip)

