extends CanvasLayer

## The quiet on-screen helper for Mind Spark Kingdom.
##
## Shows what the nearest thing wants, and how far along the journey is. The
## wording never scolds or counts mistakes, because there are none to count —
## it only ever describes the next kind thing the player could do.

@export var kingdom_path: NodePath = NodePath("..")
@export var carrier_path: NodePath = NodePath("../ThoughtCarrier")
@export var storm_path: NodePath = NodePath("../Storm/Approach")

@onready var _prompt: Label = get_node_or_null("Prompt")
@onready var _progress: Label = get_node_or_null("Progress")
@onready var _thought: Label = get_node_or_null("CarriedThought")

var _kingdom: Node = null
var _carrier: Node = null
var _storm: Node = null


func _ready() -> void:
	_kingdom = get_node_or_null(kingdom_path)
	_carrier = get_node_or_null(carrier_path)
	_storm = get_node_or_null(storm_path)

	if _kingdom:
		if _kingdom.has_signal("forest_lit"):
			_kingdom.forest_lit.connect(_on_forest_lit)
		if _kingdom.has_signal("storm_calmed"):
			_kingdom.storm_calmed.connect(_on_storm_calmed)
		if _kingdom.has_signal("treasure_found"):
			_kingdom.treasure_found.connect(_on_treasure_found)


func _process(_delta: float) -> void:
	_update_prompt()
	_update_progress()
	_update_carried_thought()


func _update_prompt() -> void:
	if _prompt == null:
		return
	# The storm speaks first when the player is standing in it.
	var text := ""
	if _storm and _storm.has_method("prompt"):
		text = _storm.prompt()
	if text == "" and _carrier and _carrier.has_method("prompt"):
		text = _carrier.prompt()
	_prompt.text = text


func _update_progress() -> void:
	if _progress == null or _kingdom == null:
		return

	if _kingdom.treasure_taken():
		_progress.text = "The Star of Wisdom is yours."
	elif _kingdom.storm_is_calm():
		_progress.text = "The storm is gentle rain now."
	elif _kingdom.forest_is_lit():
		_progress.text = "%d thoughts left inside the storm" % _kingdom.storm_thoughts_left()
	else:
		var done: int = _kingdom.thoughts_transformed()
		var needed: int = _kingdom.thoughts_to_light_forest
		_progress.text = "%d of %d thoughts have found a kinder path" % [done, needed]


func _update_carried_thought() -> void:
	if _thought == null or _carrier == null:
		return
	# The carrier may not have its script attached on the first frame.
	var held: Variant = _carrier.get("carried")
	if held != null and is_instance_valid(held):
		_thought.text = "\"%s\"" % held.current_text()
	else:
		_thought.text = ""


func _on_forest_lit() -> void:
	_flash("The forest is waking up.")


func _on_storm_calmed() -> void:
	_flash("The storm became gentle rain.")


func _on_treasure_found() -> void:
	_flash("You found the courage to understand your thoughts and choose hope.")


## A line that fades on its own, so nothing has to be dismissed.
func _flash(message: String) -> void:
	var banner: Label = get_node_or_null("Banner")
	if banner == null:
		return
	banner.text = message
	banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(banner, "modulate:a", 0.0, 1.5)
