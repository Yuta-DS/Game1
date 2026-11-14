extends Area3D

var artwork_path := ""
var artwork_title := "Artwork"
var _player_inside := false
var _opening := false
var _layer: CanvasLayer
var _prompt: Label

const GALLERY_FRAME_RITUAL_PATH = "res://scenes/gallery_frame_ritual.tscn"


func configure(path: String, title: String) -> void:
	artwork_path = path
	artwork_title = title if not title.strip_edges().is_empty() else path.get_file().get_basename().replace("_", " ")


func _ready() -> void:
	monitoring = true
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or _opening:
		return
	if event.is_action_pressed("ui_accept"):
		_open_artwork_world()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D or body.is_in_group("Player"):
		_player_inside = true
		_prompt.text = "Enter / Space — begin the Gallery Frame Ritual for ‘%s’" % artwork_title
		_layer.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D or body.is_in_group("Player"):
		_player_inside = false
		_layer.visible = false


func _open_artwork_world() -> void:
	if artwork_path.is_empty() or not FileAccess.file_exists(artwork_path):
		_prompt.text = "This artwork file is no longer available."
		return
	_opening = true
	_prompt.text = "Opening the Gallery Frame Ritual…"
	var state := get_node_or_null("/root/CreationWorldState")
	if state == null:
		_opening = false
		_prompt.text = "The Gallery Frame Ritual is not available in this scene."
		return
	if not ResourceLoader.exists(GALLERY_FRAME_RITUAL_PATH):
		_opening = false
		_prompt.text = "The Gallery Frame Ritual is still being prepared. Please try again shortly."
		return
	state.prepare_artwork(artwork_path, artwork_title)
	var transition_error := get_tree().change_scene_to_file(GALLERY_FRAME_RITUAL_PATH)
	if transition_error != OK:
		_opening = false
		_prompt.text = "The Gallery Frame Ritual could not open yet. Please try again."


func _build_prompt() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 40
	_layer.visible = false
	add_child(_layer)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -420
	_prompt.offset_right = 420
	_prompt.offset_top = -110
	_prompt.offset_bottom = -65
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.add_theme_font_size_override("font_size", 19)
	_prompt.add_theme_color_override("font_color", Color("fff0b2"))
	_layer.add_child(_prompt)
