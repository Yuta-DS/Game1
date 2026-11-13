extends Node3D

## Uriel, guardian of imagination in Creator's Light Kingdom.
##
## He does not test the player's art or judge it. He offers the frame, watches
## what they make, and celebrates it. So his idle is a slow spellcast — the
## world being held open — and he cheers whenever a picture becomes real.

@export var dialogue_start_node := "start_uriel_dialogue"
@export var model_yaw_offset := 180.0

## How long a celebration lasts before he settles back.
@export var cheer_time: float = 2.2

@onready var _anim: AnimationPlayer = get_node_or_null("AnimationPlayer")

var _player: Node3D = null
var _celebrating := false
var _cheer_left := 0.0


func _ready() -> void:
	_player = get_node_or_null("../NewPlayer")
	_settle()

	# Cheer whenever the player makes something real.
	var kingdom := get_parent()
	if kingdom and kingdom.has_signal("picture_became_real"):
		kingdom.picture_became_real.connect(_on_picture_became_real)
	if kingdom and kingdom.has_signal("perfect_blank_answered"):
		kingdom.perfect_blank_answered.connect(_on_blank_answered)


func _process(delta: float) -> void:
	_face_the_player(delta)

	if not _celebrating:
		return
	_cheer_left -= delta
	if _cheer_left <= 0.0:
		_celebrating = false
		_settle()


## Uriel keeps his attention on the player, because the story's guardians are
## present rather than aloof.
func _face_the_player(delta: float) -> void:
	if _player == null:
		return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.01:
		return

	var wanted := atan2(to_player.x, to_player.z) + deg_to_rad(model_yaw_offset)
	rotation.y = lerp_angle(rotation.y, wanted, clampf(delta * 3.0, 0.0, 1.0))


func _settle() -> void:
	_play("Spellcasting", "Idle")


func _on_picture_became_real(_prompt_id: String, _cells: int) -> void:
	celebrate()


func _on_blank_answered() -> void:
	celebrate()


## A visible, wordless "yes" to whatever the player just made.
func celebrate() -> void:
	_celebrating = true
	_cheer_left = cheer_time
	_play("Cheer", "Idle")


## Plays the first animation that exists, so a swapped model cannot break him.
func _play(preferred: String, fallback: String) -> void:
	if _anim == null:
		return
	if _anim.has_animation(preferred):
		_anim.play(preferred)
	elif _anim.has_animation(fallback):
		_anim.play(fallback)


func guardian_words() -> String:
	return "You do not need a perfect idea. Make one small mark, and the world will answer."
