extends Node3D

## A single Thought Spark drifting between the tower-trees of Mind Spark.
##
## The story is careful about these: a thought is not an enemy and it is never
## destroyed. The player slows it down, looks at it, walks it through the gates,
## and finds a kinder path. So this node has no health and no fail state — only
## a thought, the gates it has passed, and the kinder thought it can become.

signal picked_up(spark: Node3D)
signal released(spark: Node3D)
signal transformed(spark: Node3D, kind_thought: String)

## The worried thought, in the player's own voice.
@export var thought: String = "I am not good enough"

## What this thought can become once it has been looked at honestly.
@export var kind_thought: String = "I am learning and growing"

## Which kind of thought this is, for the guardian's closing words.
@export_enum("worry", "fear", "dream", "hope") var flavour: String = "worry"

## How far the spark bobs as it drifts, in metres.
@export var drift_height: float = 0.35

@export var drift_speed: float = 1.1

@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh")
@onready var _glow: OmniLight3D = get_node_or_null("Glow")
@onready var _label: Label3D = get_node_or_null("Label")

## Gates this spark has already been through, in order.
var gates_passed: Array[String] = []

var is_held: bool = false
var is_transformed: bool = false

var _home := Vector3.ZERO
var _phase := 0.0


func _ready() -> void:
	_home = position
	_phase = randf() * TAU
	_refresh_label()


func _process(delta: float) -> void:
	if is_held:
		return
	# Something else may have moved the spark — the island's districts place it
	# after _ready — so adopt any new position as home rather than dragging it
	# back to where it first appeared.
	var drift := Vector3(0.0, sin(_phase) * drift_height, 0.0)
	if not position.is_equal_approx(_home + drift):
		_home = position - drift
	_phase += delta * drift_speed
	position = _home + Vector3(0.0, sin(_phase) * drift_height, 0.0)


## The player picks the thought up to carry it to a gate.
func pick_up() -> void:
	if is_transformed:
		return
	is_held = true
	picked_up.emit(self)


func release() -> void:
	is_held = false
	_home = position
	released.emit(self)


## Walks the thought through one of the gates. Returns true the first time each
## gate is passed. No gate can reject a thought — the gates are questions, not
## tests.
func pass_gate(gate_id: String) -> bool:
	if is_transformed or gate_id in gates_passed:
		return false
	gates_passed.append(gate_id)
	return true


## True once the thought has been looked at from enough angles.
func can_transform(required_gates: int) -> bool:
	return not is_transformed and gates_passed.size() >= required_gates


## The story's step five: the new thought becomes a bright path and lights the
## forest.
##
## Named become_kinder rather than transform because Node3D already has a
## `transform` property, and the two silently collide.
func become_kinder() -> bool:
	if is_transformed:
		return false
	is_transformed = true
	is_held = false
	_refresh_label()
	_brighten()
	transformed.emit(self, kind_thought)
	return true


func _refresh_label() -> void:
	if _label:
		_label.text = kind_thought if is_transformed else thought


## A transformed thought stops being a dim, anxious flicker and becomes a warm
## light the player can see across the forest.
func _brighten() -> void:
	if _glow:
		_glow.light_color = Color(1.0, 0.902, 0.6)
		_glow.light_energy = 3.2
	if _mesh and _mesh.get_surface_override_material(0):
		var material: StandardMaterial3D = _mesh.get_surface_override_material(0)
		material.emission = Color(1.0, 0.902, 0.6)
		material.emission_energy_multiplier = 2.4


func current_text() -> String:
	return kind_thought if is_transformed else thought
