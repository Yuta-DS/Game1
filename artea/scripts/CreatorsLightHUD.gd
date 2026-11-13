extends CanvasLayer

## The on-screen helper for Creator's Light Kingdom.
##
## Every line here follows the story's rule about creativity: there is no wrong
## way to do it, art does not need to be perfect, and trying again is part of
## creating. So nothing is ever called finished, correct, or good enough.

@export var kingdom_path: NodePath = NodePath("..")

@onready var _prompt: Label = get_node_or_null("Prompt")
@onready var _progress: Label = get_node_or_null("Progress")
@onready var _banner: Label = get_node_or_null("Banner")

var _kingdom: Node = null


func _ready() -> void:
	_kingdom = get_node_or_null(kingdom_path)
	if _kingdom == null:
		return

	if _kingdom.has_signal("picture_became_real"):
		_kingdom.picture_became_real.connect(_on_picture_became_real)
	if _kingdom.has_signal("perfect_blank_answered"):
		_kingdom.perfect_blank_answered.connect(_on_blank_answered)
	if _kingdom.has_signal("treasure_found"):
		_kingdom.treasure_found.connect(_on_treasure_found)

	# The frames tell the player when a page came up empty.
	var frames: Node = _kingdom.get_node_or_null("Frames")
	if frames:
		for frame in frames.get_children():
			if frame.has_signal("frame_empty"):
				frame.frame_empty.connect(_on_frame_empty)


func _process(_delta: float) -> void:
	if _kingdom == null:
		return
	_update_prompt()
	_update_progress()


func _update_prompt() -> void:
	if _prompt == null:
		return

	var blank: Node = _kingdom.get_node_or_null("PerfectBlank/Approach")
	if blank and blank.has_method("prompt"):
		var blank_text: String = blank.prompt()
		if blank_text != "":
			_prompt.text = blank_text
			return

	var frames: Node = _kingdom.get_node_or_null("Frames")
	if frames:
		for frame in frames.get_children():
			if frame.has_method("prompt"):
				var text: String = frame.prompt()
				if text != "":
					_prompt.text = text
					return

	var pickup: Node = _kingdom.get_node_or_null("CreatorsLight/Pickup")
	if pickup and pickup.has_method("prompt"):
		_prompt.text = pickup.prompt()
		return

	_prompt.text = ""


func _update_progress() -> void:
	if _progress == null:
		return

	if _kingdom.treasure_taken():
		_progress.text = "The Creator's Light is yours."
	elif _kingdom.blank_answered():
		_progress.text = "The world grew around what you began."
	elif _kingdom.perfect_blank_is_open():
		_progress.text = "The Perfect Blank is waiting."
	else:
		var left: int = _kingdom.pictures_left()
		_progress.text = "%d more picture%s to bring to life" % [left, "" if left == 1 else "s"]


func _on_picture_became_real(_prompt_id: String, _cells: int) -> void:
	_flash("Your picture is real now. You can walk on it.")


## An empty page is answered with an invitation, never a complaint.
func _on_frame_empty() -> void:
	_flash("Make one small mark, and the world will answer.")


func _on_blank_answered() -> void:
	_flash("You did not need a perfect idea. You needed to begin.")


func _on_treasure_found() -> void:
	_flash("Your creativity is a gift that only you can share with the world.")


func _flash(message: String) -> void:
	if _banner == null:
		return
	_banner.text = message
	_banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(_banner, "modulate:a", 0.0, 1.5)
