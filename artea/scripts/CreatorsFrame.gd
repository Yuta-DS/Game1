extends Area3D

## The glowing frame Uriel gives the player.
##
## "Anything drawn inside the frame can become part of the world." The player
## carries a picture here, holds it up, and the flat drawing becomes real.
##
## The frame never judges a drawing. An empty page is answered with an
## invitation, not an error, because the story's whole point is that the answer
## is not perfect art — it is the courage to begin.

signal picture_offered(prompt_id: String)
signal picture_became_real(prompt_id: String, cells: int)
signal frame_empty()

const DrawnObjectScript := preload("res://scripts/DrawnObject.gd")

## Where the finished object should stand, relative to the frame.
@export var place_at: NodePath = NodePath("Placement")

## Milo's question for this frame — the story gives him one per picture.
@export var milos_question: String = "Draw a door that leads to your dreams"

## A short id so the kingdom can tell its frames apart.
@export var prompt_id: String = "door"

## How wide the object built here should be.
@export var built_width: float = 8.0

@onready var _light: OmniLight3D = get_node_or_null("FrameGlow")
@onready var _question: Label3D = get_node_or_null("Question")
@onready var _placement: Node3D = get_node_or_null(place_at)

var _player_in_range: bool = false
var _built: Node3D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if _question:
		_question.text = milos_question


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_wake()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_settle()


func _process(_delta: float) -> void:
	if not _player_in_range or has_been_used():
		return
	if Input.is_action_just_pressed("interact"):
		offer_newest_picture()


## Takes the most recent drawing the player saved and makes it real.
func offer_newest_picture() -> bool:
	var path := newest_artwork_path()
	if path == "":
		frame_empty.emit()
		return false
	return offer_picture(path)


## Makes one specific drawing real.
func offer_picture(image_path: String) -> bool:
	picture_offered.emit(prompt_id)

	var drawn: Node3D = DrawnObjectScript.new()
	drawn.name = "Drawn_%s" % prompt_id
	drawn.world_width = built_width

	var parent: Node = _placement if _placement else self
	parent.add_child(drawn)

	var cells: int = drawn.build_from_file(image_path)
	if cells == 0:
		# A blank page is not a mistake. Take it away again and invite another.
		drawn.queue_free()
		frame_empty.emit()
		return false

	_built = drawn
	_celebrate()
	picture_became_real.emit(prompt_id, cells)
	return true


## Builds directly from an image, for tests and for a drawing handed over in
## memory rather than saved to disk.
func offer_image(image: Image) -> bool:
	picture_offered.emit(prompt_id)

	var drawn: Node3D = DrawnObjectScript.new()
	drawn.name = "Drawn_%s" % prompt_id
	drawn.world_width = built_width

	var parent: Node = _placement if _placement else self
	parent.add_child(drawn)

	var cells: int = drawn.build_from_image(image)
	if cells == 0:
		drawn.queue_free()
		frame_empty.emit()
		return false

	_built = drawn
	_celebrate()
	picture_became_real.emit(prompt_id, cells)
	return true


## The newest PNG in the player's own gallery — whatever they drew last.
func newest_artwork_path() -> String:
	var dir_path := "user://artworks/"
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""

	var newest := ""
	var newest_time := -1

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			var full := dir_path + file_name
			var modified := FileAccess.get_modified_time(full)
			if modified > newest_time:
				newest_time = modified
				newest = full
		file_name = dir.get_next()
	dir.list_dir_end()

	return newest


func has_been_used() -> bool:
	return _built != null


func built_object() -> Node3D:
	return _built


func _wake() -> void:
	if _light:
		var tween := create_tween()
		tween.tween_property(_light, "light_energy", 3.2, 0.4)


func _settle() -> void:
	if _light:
		var tween := create_tween()
		tween.tween_property(_light, "light_energy", 1.2, 0.6)


func _celebrate() -> void:
	if _light == null:
		return
	var tween := create_tween()
	tween.tween_property(_light, "light_energy", 7.0, 0.2)
	tween.tween_property(_light, "light_energy", 2.0, 1.2)


func prompt() -> String:
	if not _player_in_range:
		return ""
	if has_been_used():
		return ""
	return "Press Q to hold your picture up to the frame"
