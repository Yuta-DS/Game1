extends Node3D

## Milo travelling with the player through a kingdom.
##
## The existing milo_animations.gd handles him standing in the hub and opening
## the chatbot. This adds the part the story asks for inside the worlds: Milo
## reacts. He waves when the player makes something, he keeps them company, and
## in Heart Melody he is visibly the other half of the work.
##
## Attach to the Milo instance inside a kingdom scene.

## How long Milo waves for before settling back.
@export var wave_time: float = 1.8

## How close Milo tries to stay to the player, in metres.
@export var follow_distance: float = 4.0

## How fast he drifts after them. Gentle on purpose — he accompanies rather
## than chases.
@export var follow_speed: float = 1.6

## Milo drifts alongside instead of standing still.
@export var follows_player: bool = true

@onready var _anim: AnimationPlayer = _find_animation_player()

var _player: Node3D = null
var _waving := false
var _wave_left := 0.0
var _bob := 0.0


func _ready() -> void:
	_player = get_node_or_null("../NewPlayer")
	_settle()
	_listen_to_the_kingdom()


## Milo answers whatever this world does, without needing to know which world
## it is. Each signal carries a different number of arguments, so every one
## gets a handler with a matching shape.
func _listen_to_the_kingdom() -> void:
	var kingdom := get_parent()
	if kingdom == null:
		return

	# No arguments.
	for signal_name in ["perfect_blank_answered", "valley_singing", "forest_lit",
			"storm_calmed", "treasure_found"]:
		if kingdom.has_signal(signal_name):
			kingdom.connect(signal_name, wave)

	# Two arguments.
	for signal_name in ["picture_became_real", "milo_answered", "thought_transformed"]:
		if kingdom.has_signal(signal_name):
			kingdom.connect(signal_name, _on_two_arg_event)


func _on_two_arg_event(_first: Variant, _second: Variant) -> void:
	wave()


func _process(delta: float) -> void:
	_bob += delta
	if _waving:
		_wave_left -= delta
		if _wave_left <= 0.0:
			_waving = false
			_settle()

	if follows_player:
		_drift_after_player(delta)


## Milo keeps the player company without crowding them.
func _drift_after_player(delta: float) -> void:
	if _player == null:
		return

	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()

	if distance > follow_distance:
		var step := to_player.normalized() * follow_speed * delta
		global_position += step
		_play("Walking", "Idle_3")
	elif not _waving:
		_play("Idle_3", "Idle")

	# He floats, so a small bob keeps him alive even when still.
	position.y = _resting_height() + sin(_bob * 1.6) * 0.12

	if distance > 0.05:
		var wanted := atan2(to_player.x, to_player.z)
		rotation.y = lerp_angle(rotation.y, wanted, clampf(delta * 3.0, 0.0, 1.0))


var _resting: float = -1.0

func _resting_height() -> float:
	if _resting < 0.0:
		_resting = position.y
	return _resting


## Milo's visible "well done" — the story has him celebrate every brave moment.
func wave() -> void:
	_waving = true
	_wave_left = wave_time
	_play("Wave_One_Hand", "Idle_3")


func _settle() -> void:
	_play("Idle_3", "Idle")


## Plays whichever animation the model actually has.
func _play(preferred: String, fallback: String) -> void:
	if _anim == null:
		return
	if _anim.current_animation == preferred:
		return
	if _anim.has_animation(preferred):
		_anim.play(preferred)
	elif _anim.has_animation(fallback):
		_anim.play(fallback)


func _find_animation_player() -> AnimationPlayer:
	var direct := get_node_or_null("AnimationPlayer")
	if direct is AnimationPlayer:
		return direct
	for child in get_children():
		if child is AnimationPlayer:
			return child
	return null
