extends Node3D

## Heart Melody Kingdom — World Two.
##
## Theme: my feelings have a voice. A green valley of waterfalls and giant
## instruments, silent because the feelings are stuck. The player gives each
## feeling a voice; Milo turns every sound into something the valley can stand
## on. Neither can finish alone.
##
## Built on the same shape as MindSparkKingdom: the world script owns the story
## beats and the treasure, the mechanic lives in its own nodes.

signal feeling_voiced(feeling: String, distinct_so_far: int)
signal milo_answered(feeling: String, built: String)
signal valley_singing()
signal treasure_found()

## The story is clear that a healthy heart does not sing only happy songs, so
## the jewel asks for a range of feelings rather than a quantity of notes.
@export var feelings_for_the_song: int = 4

@onready var _instruments: Node3D = get_node_or_null("Instruments")
@onready var _milo: Node3D = get_node_or_null("Milo")
@onready var _jewel: Node3D = get_node_or_null("HarmonyJewel")
@onready var _guardian: Node3D = get_node_or_null("Raphael")
@onready var _valley_light: DirectionalLight3D = get_node_or_null("ValleyLight")
@onready var _built: Node3D = get_node_or_null("MilosAnswers")

var _journey: Node = null
var _voiced: Dictionary = {}
var _song: Array[String] = []
var _valley_sings: bool = false
var _treasure_taken: bool = false


func _ready() -> void:
	_journey = get_node_or_null("/root/JourneyState")

	if _jewel:
		_jewel.visible = false
	if _guardian:
		_guardian.visible = false

	_quieten_valley()
	_hide_milos_answers()
	_connect_instruments()
	_aim_the_sun(_valley_light)


func _connect_instruments() -> void:
	if _instruments == null:
		return
	for instrument in _instruments.get_children():
		if instrument.has_signal("played"):
			instrument.played.connect(_on_instrument_played.bind(instrument))


## The valley should be full of music, but everything is quiet at first.
func _quieten_valley() -> void:
	if _valley_light:
		_valley_light.light_energy = 1.1


## Milo's platforms and bridges only appear as the feelings that call for them
## are given a voice.
func _hide_milos_answers() -> void:
	if _built == null:
		return
	for answer in _built.get_children():
		answer.visible = false


func _on_instrument_played(feeling: String, _note_colour: Color, instrument: Node) -> void:
	_song.append(feeling)

	var already_voiced: bool = _voiced.has(feeling)
	_voiced[feeling] = true

	if _journey:
		_journey.record_choice(_journey.STATION_HEART, "feeling", feeling)

	feeling_voiced.emit(feeling, _voiced.size())

	# Milo answers every feeling, not only the new ones — the story's second
	# half of the partnership.
	_milo_answers(feeling, instrument)

	if not already_voiced and not _valley_sings and _voiced.size() >= feelings_for_the_song:
		_let_the_valley_sing()


## Milo turns the feeling into something solid: a platform, a boat lifted by
## raindrops, a safe path, a resting place, the morning light.
func _milo_answers(feeling: String, instrument: Node) -> void:
	var built: String = instrument.milos_answer if instrument else "platform"

	if _built:
		var answer: Node3D = _built.get_node_or_null(built.to_pascal_case())
		if answer and not answer.visible:
			_raise_into_place(answer)

	milo_answered.emit(feeling, built)


## Milo's machines lift the answer into place rather than snapping it on, so
## the player can see their feeling being built into something they can stand
## on. That visible cause and effect is the whole point of the partnership.
func _raise_into_place(answer: Node3D) -> void:
	var resting := answer.position
	answer.position = resting - Vector3(0, 6.0, 0)
	answer.scale = Vector3(0.4, 0.4, 0.4)
	answer.visible = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(answer, "position", resting, 1.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(answer, "scale", Vector3.ONE, 0.9) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Every puzzle adds one new sound. At the end the sounds join together, and
## the song is different for every player because it is made of their choices.
func _let_the_valley_sing() -> void:
	_valley_sings = true

	if _valley_light:
		var tween := create_tween()
		tween.tween_property(_valley_light, "light_energy", 2.4, 2.5)

	# The song the player built now plays over the whole valley.
	var song: AudioStreamPlayer = get_node_or_null("ValleySong")
	if song and not song.playing:
		song.play()

	if _jewel:
		_jewel.visible = true
	if _guardian:
		_guardian.visible = true

	valley_singing.emit()


## The Harmony Jewel appears inside the final note, with every feeling still
## visible as a colour inside it.
func take_the_jewel() -> bool:
	if _treasure_taken or not _valley_sings:
		return false
	_treasure_taken = true

	if _journey:
		_journey.record_choice(_journey.STATION_HEART, "song", ", ".join(_song))
		_journey.discover_treasure(_journey.TREASURE_JEWEL)

	treasure_found.emit()
	return true


# -----------------------
# STATE, FOR UI AND TESTS
# -----------------------

## The feelings the player has given a voice to, in the order first voiced.
func voiced_feelings() -> Array:
	return _voiced.keys()


## The whole song, including repeats — this is what makes it personal.
func the_song() -> Array[String]:
	return _song


func feelings_left() -> int:
	return maxi(0, feelings_for_the_song - _voiced.size())


func valley_is_singing() -> bool:
	return _valley_sings


func treasure_taken() -> bool:
	return _treasure_taken


func guardian_words() -> String:
	return "Your feelings matter. Your heart has a beautiful voice."

## Points the sun steeply down at the island. A 3000m island lit at a grazing
## angle reads as black, so the direction is set here rather than trusted to a
## hand-written transform in the scene file.
func _aim_the_sun(light: DirectionalLight3D) -> void:
	if light == null:
		return
	light.global_position = Vector3(300, 600, 300)
	light.look_at(Vector3.ZERO, Vector3.UP)
