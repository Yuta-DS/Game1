@tool
extends Node3D

## Lays glowing rails between the Gallery Station and a kingdom gate.
##
## The story describes the shortcut lines as rails that "grow across the galaxy"
## once a world is open, so a sleeping line is drawn dim and thin and only
## brightens when its station unlocks.

## Where the line runs from and to, in this node's own space.
@export var from_point: Vector3 = Vector3.ZERO:
	set(value):
		from_point = value
		_rebuild()

@export var to_point: Vector3 = Vector3(0, 0, -100):
	set(value):
		to_point = value
		_rebuild()

## How many sleepers to lay along the line.
@export_range(2, 200, 1) var sleeper_count: int = 40:
	set(value):
		sleeper_count = value
		_rebuild()

@export var sleeper_size: Vector3 = Vector3(2.4, 0.15, 0.5):
	set(value):
		sleeper_size = value
		_rebuild()

## The station this line leads to, so it can watch for its own unlock.
@export var station_id: String = ""

@export var rail_colour: Color = Color(0.91, 0.784, 0.416):
	set(value):
		rail_colour = value
		_rebuild()

var _multimesh: MultiMeshInstance3D = null
var _journey: Node = null


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return

	_journey = get_node_or_null("/root/JourneyState")
	if _journey:
		_journey.station_unlocked.connect(_on_station_unlocked)
	_refresh_brightness()


func _rebuild() -> void:
	if not is_inside_tree():
		return

	if _multimesh == null:
		_multimesh = get_node_or_null("Sleepers")
		if _multimesh == null:
			_multimesh = MultiMeshInstance3D.new()
			_multimesh.name = "Sleepers"
			add_child(_multimesh)
			if Engine.is_editor_hint() and get_tree():
				_multimesh.owner = get_tree().edited_scene_root

	var sleeper := BoxMesh.new()
	sleeper.size = sleeper_size

	var material := StandardMaterial3D.new()
	material.albedo_color = rail_colour
	material.emission_enabled = true
	material.emission = rail_colour
	material.emission_energy_multiplier = 0.5

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sleeper
	mm.instance_count = sleeper_count

	var direction := to_point - from_point
	var length := direction.length()
	if length < 0.001:
		_multimesh.multimesh = mm
		return

	var forward := direction.normalized()
	# Lay each sleeper across the line rather than along it.
	var basis := Basis.looking_at(forward, Vector3.UP)

	for i in sleeper_count:
		var t := float(i) / maxf(1.0, float(sleeper_count - 1))
		var point := from_point + direction * t
		mm.set_instance_transform(i, Transform3D(basis, point))

	_multimesh.multimesh = mm
	_multimesh.material_override = material


func _on_station_unlocked(unlocked_id: String) -> void:
	if unlocked_id == station_id:
		_refresh_brightness()


## An open line glows; a sleeping one is barely there.
func _refresh_brightness() -> void:
	if _multimesh == null or _multimesh.material_override == null:
		return
	var material: StandardMaterial3D = _multimesh.material_override
	material.emission_energy_multiplier = 1.4 if is_open() else 0.15


func is_open() -> bool:
	if _journey == null:
		return false
	return bool(_journey.can_travel_to(station_id))
