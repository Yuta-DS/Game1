extends CanvasLayer

## The screen where the player chooses one of the 16 game identities.
##
## The story sets the terms and this script keeps them: the game offers two or
## three, Milo explains each in simple words, the player may say "I am still
## discovering", and they may change their mind later. No identity is presented
## as better than another, and nothing is locked in.

signal identity_picked(identity_id: String)
signal still_discovering()
signal closed()

const Identities := preload("res://scripts/GameIdentities.gd")

@export var finale_path: NodePath = NodePath("../Finale")

## Shows every one of the 16 rather than only the suggested few. The story says
## the player may choose a different identity if another feels more like them.
@export var allow_browsing_all: bool = true

@onready var _list: VBoxContainer = get_node_or_null("Panel/Margin/Layout/Scroll/Options")
@onready var _title: Label = get_node_or_null("Panel/Margin/Layout/Title")
@onready var _intro: Label = get_node_or_null("Panel/Margin/Layout/Intro")
@onready var _more_button: Button = get_node_or_null("Panel/Margin/Layout/Buttons/SeeMore")
@onready var _undecided_button: Button = get_node_or_null("Panel/Margin/Layout/Buttons/StillDiscovering")

var _finale: Node = null
var _showing_all: bool = false


func _ready() -> void:
	hide()
	_finale = get_node_or_null(finale_path)

	if _more_button:
		_more_button.pressed.connect(_on_see_more_pressed)
		_more_button.visible = allow_browsing_all
	if _undecided_button:
		_undecided_button.pressed.connect(_on_still_discovering_pressed)

	if _finale and _finale.has_signal("identities_offered"):
		_finale.identities_offered.connect(_on_identities_offered)


func _on_identities_offered(options: Array) -> void:
	_showing_all = false
	_render(options)
	show()


## Builds one card per identity. Order is the suggestion's ranking, but nothing
## in the wording says one is stronger than another.
func _render(options: Array) -> void:
	if _list == null:
		return

	for child in _list.get_children():
		child.queue_free()

	if _title:
		_title.text = "Which one feels most like you?"
	if _intro:
		_intro.text = "These are ways your light can shine. None is better than another, and you can change your mind later."

	for option in options:
		_list.add_child(_build_option(option))

	if _more_button:
		_more_button.text = "Show the first few" if _showing_all else "See all sixteen"


func _build_option(option: Dictionary) -> Control:
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 72)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.text = "%s\n%s" % [option.get("name", ""), option.get("purpose", "")]
	card.pressed.connect(_on_option_pressed.bind(str(option.get("id", ""))))
	return card


func _on_option_pressed(identity_id: String) -> void:
	if _finale and _finale.choose_identity(identity_id):
		identity_picked.emit(identity_id)
		_close()


## "I am still discovering" is a real answer and does not block the crown.
func _on_still_discovering_pressed() -> void:
	if _finale:
		_finale.stay_undecided()
	still_discovering.emit()
	_close()


func _on_see_more_pressed() -> void:
	_showing_all = not _showing_all
	if _showing_all:
		_render(_all_identities())
	elif _finale:
		_render(_finale.offered_identities())


func _all_identities() -> Array:
	var everything: Array = []
	for identity_id in Identities.all_ids():
		var info: Dictionary = Identities.info(identity_id)
		everything.append({
			"id": identity_id,
			"name": info.get("name", ""),
			"purpose": info.get("purpose", ""),
		})
	return everything


func _close() -> void:
	hide()
	closed.emit()


## Lets the finale, or a menu, reopen the chooser so the player can change
## their mind — the story says they can.
func reopen() -> void:
	if _finale:
		_render(_finale.offered_identities())
		show()
