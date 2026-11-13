extends Node3D

## Creator's Light Kingdom — World Three.
##
## Theme: I was created to create. An empty world of floating shapes and blank
## frames, waiting for the player's imagination. Anything drawn inside Uriel's
## frame becomes real and can be used.
##
## The finale is the Perfect Blank, which insists nothing is ready and nothing
## is good enough. The player answers it not with a masterpiece but with one
## unfinished picture, and Milo adds one small light.
##
## Same shape as the other two kingdoms: the world script owns the story beats
## and the treasure; the mechanic lives in its own nodes.

signal picture_became_real(prompt_id: String, cells: int)
signal world_waking(frames_used: int)
signal perfect_blank_answered()
signal treasure_found()

## How many frames must be filled before the Perfect Blank will open. The story
## shows the player a few prompts before the final empty space.
@export var pictures_to_wake_the_world: int = 2

@onready var _frames: Node3D = get_node_or_null("Frames")
@onready var _blank: Node3D = get_node_or_null("PerfectBlank")
@onready var _flame: Node3D = get_node_or_null("CreatorsLight")
@onready var _guardian: Node3D = get_node_or_null("Uriel")
@onready var _world_light: DirectionalLight3D = get_node_or_null("WorldLight")
@onready var _waiting: Node3D = get_node_or_null("WaitingThings")

var _journey: Node = null
var _pictures_made: int = 0
var _blank_answered: bool = false
var _treasure_taken: bool = false


func _ready() -> void:
	_journey = get_node_or_null("/root/JourneyState")

	if _flame:
		_flame.visible = false
	if _blank:
		_blank.visible = false

	_empty_the_world()
	_connect_frames()
	_aim_the_sun(_world_light)


func _connect_frames() -> void:
	if _frames == null:
		return
	for frame in _frames.get_children():
		if frame.has_signal("picture_became_real"):
			frame.picture_became_real.connect(_on_picture_became_real)


## The world has everything it needs, but it is waiting: plants inside glass
## seeds, rivers inside silver pipes, nothing yet awake.
func _empty_the_world() -> void:
	if _world_light:
		_world_light.light_energy = 0.95
	if _waiting == null:
		return
	for thing in _waiting.get_children():
		thing.visible = false


func _on_picture_became_real(prompt_id: String, cells: int) -> void:
	_pictures_made += 1

	if _journey:
		_journey.record_choice(_journey.STATION_CREATOR, "artwork", prompt_id)

	var spark: AudioStreamPlayer = get_node_or_null("MadeRealSound")
	if spark:
		spark.play()

	picture_became_real.emit(prompt_id, cells)
	_wake_one_waiting_thing()
	world_waking.emit(_pictures_made)

	if not _blank_answered and _pictures_made >= pictures_to_wake_the_world:
		_open_the_perfect_blank()


## Each picture the player makes real wakes one of the waiting things, so the
## world visibly grows around what they made.
func _wake_one_waiting_thing() -> void:
	if _waiting == null:
		return
	for thing in _waiting.get_children():
		if not thing.visible:
			thing.visible = true
			if thing is Node3D:
				var resting: Vector3 = thing.scale
				thing.scale = Vector3.ZERO
				var tween := create_tween()
				tween.tween_property(thing, "scale", resting, 0.9) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			return


## The huge empty space that says nothing is ready and nothing is good enough.
func _open_the_perfect_blank() -> void:
	if _blank:
		_blank.visible = true
	if _world_light:
		var tween := create_tween()
		tween.tween_property(_world_light, "light_energy", 1.4, 2.0)


## The player's answer to the Perfect Blank: one unfinished picture, placed
## anyway. The story is explicit that this is the whole lesson — the answer is
## not perfect art, it is the courage to begin.
##
## Nothing about the picture is inspected. Any drawing counts, finished or not.
func answer_the_perfect_blank() -> bool:
	if _blank_answered or _blank == null or not _blank.visible:
		return false

	_blank_answered = true

	if _journey:
		_journey.record_choice(_journey.STATION_CREATOR, "courage_to_begin")

	# Milo adds one small light, and the world grows around their shared work.
	var milos_light: Node3D = _blank.get_node_or_null("MilosLight")
	if milos_light:
		milos_light.visible = true

	if _world_light:
		var tween := create_tween()
		tween.tween_property(_world_light, "light_energy", 2.3, 2.5)

	var song: AudioStreamPlayer = get_node_or_null("WorldSong")
	if song and not song.playing:
		song.play()

	if _flame:
		_flame.visible = true
	if _guardian:
		_guardian.visible = true

	perfect_blank_answered.emit()
	return true


## The Creator's Light appears as a glowing flame carrying colours from the
## player's own artwork.
func take_the_flame() -> bool:
	if _treasure_taken or not _blank_answered:
		return false
	_treasure_taken = true

	if _journey:
		_journey.discover_treasure(_journey.TREASURE_LIGHT)

	treasure_found.emit()
	return true


# -----------------------
# STATE, FOR UI AND TESTS
# -----------------------

func pictures_made() -> int:
	return _pictures_made


func pictures_left() -> int:
	return maxi(0, pictures_to_wake_the_world - _pictures_made)


func perfect_blank_is_open() -> bool:
	return _blank != null and _blank.visible and not _blank_answered


func blank_answered() -> bool:
	return _blank_answered


func treasure_taken() -> bool:
	return _treasure_taken


func guardian_words() -> String:
	return "Your creativity is a gift that only you can share with the world."

## Points the sun steeply down at the island. A 3000m island lit at a grazing
## angle reads as black, so the direction is set here rather than trusted to a
## hand-written transform in the scene file.
func _aim_the_sun(light: DirectionalLight3D) -> void:
	if light == null:
		return
	light.global_position = Vector3(300, 600, 300)
	light.look_at(Vector3.ZERO, Vector3.UP)
