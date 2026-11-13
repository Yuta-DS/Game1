extends Area3D

## A doorway in ARTÉA Town leading to one of the three kingdoms.
##
## The gate asks JourneyState whether its station is open. A locked gate does
## not turn the player away with a failure message — the story is about
## discovery, not being told off — it simply says the path is still sleeping
## and points back towards the story's next stop.

signal gate_entered(station_id: String)
signal gate_refused(station_id: String)
signal boarding_requested(station_id: String, destination_scene: String)

## Which Crown Line station this gate belongs to. Must match one of the
## STATION_* constants in JourneyState.
@export var station_id: String = ""

## Scene to load when the player walks through an open gate. Left empty while
## a kingdom is still being built, in which case the gate reports and does
## nothing.
@export_file("*.tscn") var destination_scene: String = ""

## Colour of the gate light, so each kingdom reads at a distance.
@export var gate_colour: Color = Color.WHITE

## When true the gate asks the Rainbow Galaxy Train to carry the player, which
## is what the story wants. Left false, the gate falls back to loading the
## kingdom directly — useful while a world is still being built.
@export var board_the_train: bool = true

@onready var _light: OmniLight3D = $GateLight if has_node("GateLight") else null

## Resolved from the scene tree rather than the autoload global so the gate can
## also be exercised from a headless test, where autoloads are not registered.
var _journey: Node = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	if station_id == "":
		push_warning("StationGate at %s has no station_id set." % get_path())

	_journey = get_node_or_null("/root/JourneyState")
	if _journey == null:
		push_error("StationGate: JourneyState singleton not found; gate stays shut.")
		return

	_refresh_light()

	# The gate may open while the player is standing in the town, so follow
	# the journey rather than only reading it once.
	if _journey.station_unlocked.connect(_on_station_unlocked) != OK:
		push_warning("StationGate: could not connect to JourneyState.station_unlocked")


func _on_station_unlocked(unlocked_id: String) -> void:
	if unlocked_id == station_id:
		_refresh_light()


func _refresh_light() -> void:
	if _light == null:
		return
	var open := is_open()
	_light.light_color = gate_colour
	# An open gate burns bright; a sleeping one only glimmers.
	_light.light_energy = 4.0 if open else 0.6


func is_open() -> bool:
	if _journey == null:
		_journey = get_node_or_null("/root/JourneyState")
	if _journey == null:
		return false
	return _journey.can_travel_to(station_id)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	if not is_open():
		gate_refused.emit(station_id)
		return

	gate_entered.emit(station_id)

	if destination_scene == "":
		# The kingdom has not been built yet. Say so in the log rather than
		# dropping the player into a missing scene.
		print("StationGate: '%s' is open but has no destination scene yet." % station_id)
		return

	if board_the_train:
		# The story is clear that the player rides rather than cuts. Whoever is
		# listening — the hub's train platform — takes it from here.
		boarding_requested.emit(station_id, destination_scene)
		return

	get_tree().change_scene_to_file(destination_scene)
