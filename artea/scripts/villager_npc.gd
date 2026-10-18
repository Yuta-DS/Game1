extends CharacterBody3D

const RestoreCharacterTexture = preload("res://scripts/npc/restore_character_texture.gd")

@export var walk_speed: float = 2.0
@export var wander_radius: float = 4.0
@export var idle_anim: String = "Idle"
@export var walk_anim: String = "Walking_A"
@export var model_atlas: Texture2D

var _home: Vector3
var _target: Vector3
var _state_timer: float = 0.0
var _anim_player: AnimationPlayer

func _ready() -> void:
	RestoreCharacterTexture.apply($Model, model_atlas)
	_home = global_position
	_pick_new_target()
	_anim_player = _find_anim_player(self)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_anim_player(child)
		if found:
			return found
	return null

func _pick_new_target() -> void:
	var offset = Vector3(randf_range(-wander_radius, wander_radius), 0, randf_range(-wander_radius, wander_radius))
	_target = _home + offset
	_state_timer = randf_range(2.0, 5.0)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	_state_timer -= delta
	var to_target = _target - global_position
	to_target.y = 0

	if to_target.length() < 0.5 or _state_timer <= 0.0:
		_pick_new_target()
		to_target = _target - global_position
		to_target.y = 0

	if to_target.length() > 0.5:
		var dir = to_target.normalized()
		velocity.x = dir.x * walk_speed
		velocity.z = dir.z * walk_speed
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 6.0 * delta)
		_play_anim(walk_anim)
	else:
		velocity.x = 0
		velocity.z = 0
		_play_anim(idle_anim)

	move_and_slide()

func _play_anim(anim_name: String) -> void:
	if _anim_player == null:
		return
	if _anim_player.has_animation(anim_name) and _anim_player.current_animation != anim_name:
		_anim_player.play(anim_name)
