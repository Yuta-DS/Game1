extends Area3D

## One of the gates a Thought Spark is walked through in Mind Spark Kingdom.
##
## The story names three: "is this a fear?", "is there proof?", "what else
## might be true?". A gate never rejects a thought and never scores an answer.
## It asks a question, records that the thought has been looked at from that
## angle, and lets it through.

signal thought_passed(gate_id: String, spark: Node3D)

@export var gate_id: String = "is_it_a_fear"

## The question this gate asks, in words a child can answer.
@export var question: String = "Is this thought a fear, or is it something that already happened?"

@export var gate_colour: Color = Color(0.31, 0.847, 0.91)

@onready var _light: OmniLight3D = get_node_or_null("GateLight")
@onready var _label: Label3D = get_node_or_null("Question")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	if _label:
		_label.text = question
	if _light:
		_light.light_color = gate_colour


func _on_area_entered(area: Area3D) -> void:
	_try_pass(area.get_parent())


func _on_body_entered(body: Node3D) -> void:
	# The player may be carrying a spark; if so, the spark passes with them.
	if body.is_in_group("player"):
		var carried := _carried_spark(body)
		if carried:
			_try_pass(carried)
		return
	_try_pass(body)


func _try_pass(candidate: Node) -> void:
	if candidate == null or not candidate.has_method("pass_gate"):
		return
	if candidate.pass_gate(gate_id):
		_acknowledge()
		thought_passed.emit(gate_id, candidate)


## The gate brightens when a thought passes, so the player can see they have
## been understood rather than marked correct.
func _acknowledge() -> void:
	if _light == null:
		return
	var tween := create_tween()
	tween.tween_property(_light, "light_energy", 5.0, 0.15)
	tween.tween_property(_light, "light_energy", 1.5, 0.6)


func _carried_spark(body: Node3D) -> Node:
	for child in body.get_children():
		if child.has_method("pass_gate"):
			return child
	return null
