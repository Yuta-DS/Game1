extends Area3D

## One of the giant instruments in Heart Melody Kingdom.
##
## The story splits the work in two: the player touches flowers, water, drums,
## bells and glowing strings to express a feeling, and Milo turns that feeling
## into platforms, bridges, lights and safe paths. Neither can finish alone.
##
## So playing an instrument here does not solve anything by itself. It gives a
## feeling a voice and hands it to Milo, who answers.

signal played(feeling: String, note_colour: Color)

## The feeling this instrument gives a voice to. The story names six.
@export_enum("joy", "sadness", "frustration", "fear", "peace", "hope")
var feeling: String = "joy"

## What Milo builds in answer. Purely descriptive — the kingdom reads it.
@export_enum("platform", "raindrop_boat", "safe_path", "resting_place", "morning_light")
var milos_answer: String = "platform"

@export var note_colour: Color = Color(1, 0.71, 0.278)

## Each feeling sounds at its own pitch, so the valley's music genuinely
## changes shape as the player's song grows. Low for the heavy feelings, high
## for the light ones — none of them is wrong, only different.
@export_range(0.5, 2.0, 0.05) var note_pitch: float = 1.0

## Instruments can be played more than once. The story never says a feeling is
## finished with.
@export var repeatable: bool = true

@onready var _glow: OmniLight3D = get_node_or_null("Glow")
@onready var _label: Label3D = get_node_or_null("Label")
@onready var _audio: AudioStreamPlayer3D = get_node_or_null("Sound")

var _player_in_range: bool = false
var times_played: int = 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if _glow:
		_glow.light_color = note_colour
		_glow.light_energy = 0.8
	if _label:
		_label.text = feeling.capitalize()
		_label.modulate = note_colour


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _process(_delta: float) -> void:
	if not _player_in_range:
		return
	if not Input.is_action_just_pressed("interact"):
		return
	play()


func play() -> bool:
	if times_played > 0 and not repeatable:
		return false

	times_played += 1
	_ring()
	_sound()
	played.emit(feeling, note_colour)
	return true


## Plays the instrument's note. Silent if no sound is attached, which is fine —
## the kingdom still works, it is just quieter.
func _sound() -> void:
	if _audio == null:
		return
	_audio.pitch_scale = note_pitch
	# Each note starts a little way into the sample so repeats do not sound
	# mechanically identical.
	_audio.play(randf() * 0.15)


## The instrument brightens as it sounds, then settles.
func _ring() -> void:
	if _glow == null:
		return
	var tween := create_tween()
	tween.tween_property(_glow, "light_energy", 5.0, 0.12)
	tween.tween_property(_glow, "light_energy", 0.8, 0.8)


func prompt() -> String:
	if not _player_in_range:
		return ""
	return "Press Q to let %s have a voice" % feeling
