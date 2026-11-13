extends Area3D

## One of the three doorways out of the castle, leading to a 3000m island.
##
## The doorway asks JourneyState whether its world is awake. A sleeping world
## is not a locked door with a refusal — it glimmers, and says what is waiting
## there, so the castle stays a welcoming place rather than a gate.

signal used(station_id: String)
signal refused(station_id: String)

@export var station_id: String = "mind_spark"

@export_file("*.tscn") var island_scene: String = ""

## What the doorway calls its world.
@export var world_name: String = "Mind Spark Kingdom"

## The line the story gives this world.
@export var world_theme: String = "I can understand my thoughts"

@export var doorway_colour: Color = Color(0.31, 0.847, 0.91)

@onready var _light: OmniLight3D = get_node_or_null("Glow")
@onready var _name_label: Label3D = get_node_or_null("WorldName")
@onready var _theme_label: Label3D = get_node_or_null("Theme")
@onready var _portal: MeshInstance3D = get_node_or_null("Portal")

var _journey: Node = null
var _player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_journey = get_node_or_null("/root/JourneyState")

	if _name_label:
		_name_label.text = world_name
		_name_label.modulate = doorway_colour
	if _theme_label:
		_theme_label.text = world_theme

	refresh()


func is_awake() -> bool:
	if _journey == null:
		return false
	return bool(_journey.can_travel_to(station_id))


## An awake doorway burns bright; a sleeping one only glimmers.
func refresh() -> void:
	var awake := is_awake()

	if _light:
		_light.light_color = doorway_colour
		_light.light_energy = 4.0 if awake else 0.7

	if _portal:
		var material: StandardMaterial3D = _portal.get_surface_override_material(0)
		if material:
			material.emission_energy_multiplier = 2.2 if awake else 0.3

	if _theme_label:
		_theme_label.text = world_theme if awake else "This world is still sleeping"


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _process(_delta: float) -> void:
	if not _player_in_range:
		return
	if not Input.is_action_just_pressed("interact"):
		return

	if not is_awake():
		refused.emit(station_id)
		return

	if island_scene == "":
		push_warning("WorldDoorway: '%s' is awake but has no island scene." % station_id)
		return

	used.emit(station_id)
	get_tree().change_scene_to_file(island_scene)


func prompt() -> String:
	if not _player_in_range:
		return ""
	if is_awake():
		return "Press Q to travel to %s" % world_name
	return "%s is still sleeping" % world_name
