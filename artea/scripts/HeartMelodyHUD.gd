extends CanvasLayer

## The on-screen helper for Heart Melody Kingdom.
##
## Shows the song as it is built, and what the nearest instrument is offering.
## It never says a feeling was the wrong one to play — the story is explicit
## that feelings are not good or bad.

@export var kingdom_path: NodePath = NodePath("..")

@onready var _prompt: Label = get_node_or_null("Prompt")
@onready var _progress: Label = get_node_or_null("Progress")
@onready var _song: Label = get_node_or_null("Song")
@onready var _banner: Label = get_node_or_null("Banner")

var _kingdom: Node = null


func _ready() -> void:
	_kingdom = get_node_or_null(kingdom_path)
	if _kingdom == null:
		return

	if _kingdom.has_signal("milo_answered"):
		_kingdom.milo_answered.connect(_on_milo_answered)
	if _kingdom.has_signal("valley_singing"):
		_kingdom.valley_singing.connect(_on_valley_singing)
	if _kingdom.has_signal("treasure_found"):
		_kingdom.treasure_found.connect(_on_treasure_found)


func _process(_delta: float) -> void:
	if _kingdom == null:
		return
	_update_prompt()
	_update_progress()
	_update_song()


func _update_prompt() -> void:
	if _prompt == null:
		return

	var instruments: Node = _kingdom.get_node_or_null("Instruments")
	if instruments:
		for instrument in instruments.get_children():
			if instrument.has_method("prompt"):
				var text: String = instrument.prompt()
				if text != "":
					_prompt.text = text
					return

	var jewel: Node = _kingdom.get_node_or_null("HarmonyJewel/Pickup")
	if jewel and jewel.has_method("prompt"):
		_prompt.text = jewel.prompt()
		return

	_prompt.text = ""


func _update_progress() -> void:
	if _progress == null:
		return
	if _kingdom.treasure_taken():
		_progress.text = "The Harmony Jewel is yours."
	elif _kingdom.valley_is_singing():
		_progress.text = "The valley is singing."
	else:
		var left: int = _kingdom.feelings_left()
		_progress.text = "%d more feeling%s to give a voice" % [left, "" if left == 1 else "s"]


## The song is shown as it grows, because it is the player's own.
func _update_song() -> void:
	if _song == null:
		return
	var voiced: Array = _kingdom.voiced_feelings()
	if voiced.is_empty():
		_song.text = ""
		return
	_song.text = "Your song so far: " + ", ".join(voiced)


func _on_milo_answered(feeling: String, built: String) -> void:
	_flash("Milo turns your %s into a %s." % [feeling, built.replace("_", " ")])


func _on_valley_singing() -> void:
	_flash("A healthy heart does not sing only happy songs.")


func _on_treasure_found() -> void:
	_flash("Your feelings matter. Your heart has a beautiful voice.")


func _flash(message: String) -> void:
	if _banner == null:
		return
	_banner.text = message
	_banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(_banner, "modulate:a", 0.0, 1.5)
