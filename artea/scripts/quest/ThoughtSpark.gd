@tool
class_name ThoughtSpark
extends Area3D

## A collectable Thought Spark — the currency the socket consumes.
##
## Quest 1 of the Mind Spark guide is "Wake two server roots; collect two
## Sparks", so Sparks are picked up in the world and spent at sockets. The
## pickup is automatic on touch rather than prompted: it is a collectable, not
## one of PART 4's interaction objects, and gating it behind a button press
## would add a step the guide never asks for.

## Unique id so a collected Spark stays collected across a reload.
@export var save_id: String = ""

## How many Sparks this pickup grants.
@export_range(1, 3, 1) var value: int = 1

signal collected(save_id: String)

var _visual: Node3D
var _time: float = 0.0


func _ready() -> void:
	_build_visual()
	if Engine.is_editor_hint():
		return

	# Already taken in an earlier session: remove it rather than let the player
	# farm the same Spark twice.
	if not save_id.is_empty() and QuestState.is_complete(save_id):
		queue_free()
		return

	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(_visual):
		return
	# Slow bob and spin, so the pickup reads as active from across the zone.
	_time += delta
	_visual.position.y = 0.6 + sin(_time * 1.8) * 0.09
	_visual.rotate_y(delta * 1.4)


func _on_body_entered(body: Node3D) -> void:
	if not QuestObjectBase._is_player(body):
		return
	QuestState.add_spark(value)
	if not save_id.is_empty():
		QuestState.mark_complete(save_id)
	collected.emit(save_id)
	queue_free()


## Builds the pickup mesh and its trigger shape when the scene has not authored
## them, so a Spark can be dropped into a level as a bare node.
func _build_visual() -> void:
	if get_node_or_null(^"Shape") == null:
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var sphere := SphereShape3D.new()
		sphere.radius = 0.9
		shape.shape = sphere
		shape.position.y = 0.6
		add_child(shape)

	_visual = get_node_or_null(^"Visual") as Node3D
	if _visual != null:
		return

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	# Reuses the altar's crystal brick so a loose Spark and a placed one are
	# recognisably the same object.
	var mesh := AltarParts.build_crystal(0.13, 0.30, 0.45, 8)
	var mat := AltarParts.crystal_material(AltarParts.ARCANE_BRIGHT, 2.0)
	var body := MeshInstance3D.new()
	body.name = "Crystal"
	body.mesh = mesh
	body.material_override = mat
	_visual.add_child(body)

	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = AltarParts.ARCANE_PURPLE
	light.light_energy = 1.4
	light.omni_range = 3.0
	light.position.y = 0.15
	_visual.add_child(light)
