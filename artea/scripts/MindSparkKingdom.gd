extends Node3D

## Mind Spark Kingdom — World One.
##
## Theme: I can understand my thoughts. The player walks Thought Sparks through
## three gates, finds a kinder path for each, and lights the forest. At the
## centre a storm of worried thoughts is not fought but slowed, looked at one
## thought at a time, and walked through.
##
## This is the template the other two kingdoms follow: a world script that owns
## the story beats and the treasure, with the mechanic in its own nodes.

signal thought_transformed(kind_thought: String, remaining: int)
signal forest_lit()
signal storm_calmed()
signal treasure_found()

## How many gates a thought must pass before it can become kinder. The story
## names three questions, so a thought is looked at from three angles.
@export var gates_per_thought: int = 3

## How many thoughts must be transformed before the storm can be approached.
@export var thoughts_to_light_forest: int = 3

## How many thoughts the player slows the storm down with, one at a time.
@export var storm_thoughts: int = 3

@onready var _sparks: Node3D = get_node_or_null("ThoughtSparks")
@onready var _gates: Node3D = get_node_or_null("ThoughtGates")
@onready var _storm: Node3D = get_node_or_null("Storm")
@onready var _star: Node3D = get_node_or_null("StarOfWisdom")
@onready var _guardian: Node3D = get_node_or_null("EverlastingFather")
@onready var _forest_light: DirectionalLight3D = get_node_or_null("ForestLight")

var _journey: Node = null
var _transformed_count: int = 0
var _storm_calmed_count: int = 0
var _forest_is_lit: bool = false
var _treasure_taken: bool = false


func _ready() -> void:
	_journey = get_node_or_null("/root/JourneyState")

	# The star grows from the oldest tree only once the storm is gentle.
	if _star:
		_star.visible = false
	if _guardian:
		_guardian.visible = false

	_connect_sparks()
	_darken_forest()
	_aim_the_sun(_forest_light)


func _connect_sparks() -> void:
	if _sparks == null:
		return
	for spark in _sparks.get_children():
		if spark.has_signal("transformed"):
			spark.transformed.connect(_on_spark_transformed)


## The forest starts dim: the thoughts are tangled, so no clear path shows.
func _darken_forest() -> void:
	if _forest_light:
		_forest_light.light_energy = 0.85


func _on_spark_transformed(_spark: Node3D, kind_thought: String) -> void:
	_transformed_count += 1

	# A small, warm sound for a thought that found a kinder path.
	var chime: AudioStreamPlayer = get_node_or_null("KinderThoughtChime")
	if chime:
		chime.play()

	if _journey:
		_journey.record_choice(_journey.STATION_MIND, "kind_thought", kind_thought)

	var remaining: int = maxi(0, thoughts_to_light_forest - _transformed_count)
	thought_transformed.emit(kind_thought, remaining)

	if not _forest_is_lit and _transformed_count >= thoughts_to_light_forest:
		_light_the_forest()


## Step five of the story: the new thought becomes a bright path, trees wake up,
## and the player can continue.
func _light_the_forest() -> void:
	_forest_is_lit = true
	if _forest_light:
		var tween := create_tween()
		tween.tween_property(_forest_light, "light_energy", 2.0, 2.5)
	if _storm:
		_storm.visible = true

	# The forest wakes up, and so does its music.
	var song: AudioStreamPlayer = get_node_or_null("ForestSong")
	if song and not song.playing:
		song.play()

	forest_lit.emit()


## The storm is made of many worried thoughts at once. The player does not
## fight it — each call slows it a little by looking at one thought.
func slow_the_storm() -> bool:
	if not _forest_is_lit or _storm_calmed_count >= storm_thoughts:
		return false

	_storm_calmed_count += 1
	_ease_storm()

	if _storm_calmed_count >= storm_thoughts:
		_calm_the_storm()
	return true


func _ease_storm() -> void:
	if _storm == null:
		return
	# The storm gentles rather than vanishing: it becomes rain, not nothing.
	var t: float = float(_storm_calmed_count) / float(maxi(1, storm_thoughts))
	var particles := _storm.get_node_or_null("Rain")
	if particles and particles is GPUParticles3D:
		particles.speed_scale = lerp(2.5, 0.6, t)


## When the storm becomes gentle rain, the Star of Wisdom grows from the roots
## of the oldest tree.
func _calm_the_storm() -> void:
	storm_calmed.emit()
	if _star:
		_star.visible = true
	if _guardian:
		_guardian.visible = true


## The player takes the star. This is what awards the treasure and opens the
## next station on the Crown Line.
func take_the_star() -> bool:
	if _treasure_taken or _storm_calmed_count < storm_thoughts:
		return false
	_treasure_taken = true

	if _journey:
		_journey.record_choice(_journey.STATION_MIND, "cleared_thoughts")
		_journey.discover_treasure(_journey.TREASURE_STAR)

	treasure_found.emit()
	return true


# -----------------------
# STATE, FOR UI AND TESTS
# -----------------------

func thoughts_transformed() -> int:
	return _transformed_count


func forest_is_lit() -> bool:
	return _forest_is_lit


func storm_is_calm() -> bool:
	return _storm_calmed_count >= storm_thoughts


## How many thoughts inside the storm still need looking at.
func storm_thoughts_left() -> int:
	return maxi(0, storm_thoughts - _storm_calmed_count)


func treasure_taken() -> bool:
	return _treasure_taken


## The guardian's closing words, spoken once the storm is gentle.
func guardian_words() -> String:
	return "You found the courage to understand your thoughts and choose hope."

## Points the sun steeply down at the island. A 3000m island lit at a grazing
## angle reads as black, so the direction is set here rather than trusted to a
## hand-written transform in the scene file.
func _aim_the_sun(light: DirectionalLight3D) -> void:
	if light == null:
		return
	light.global_position = Vector3(300, 600, 300)
	light.look_at(Vector3.ZERO, Vector3.UP)
