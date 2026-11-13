@tool
class_name ThoughtSparkSocket
extends QuestObjectBase

## Object 01 from the Mind Spark guide — the Thought Spark Socket.
##
##   Player action : Place one found Spark.
##   Story result  : Shows 0/3, 1/3, 2/3, then opens the linked task.
##   Godot build   : Node3D + Area3D + three MeshInstance3D pips + AnimationPlayer.
##   Clear feedback: Big count, icon and sound.
##
## This is the gameplay behaviour for the crystal altar built in
## `scripts/altar/`. The altar supplies the visuals — its three ChargeLevel
## states map onto the socket's fill progress — and this script supplies the
## action, the count, the save and the signal that opens whatever comes next.
##
## The guide's meaningful-use check is what shapes the feedback here: the count
## appears in the prompt (`0/3`), the altar's charge state changes shape and
## light on every placement, and a sound fires per Spark — "Success uses shape,
## icon, text and sound; colour is extra support."

## How many Sparks this socket needs. The guide's example is three; the Calm
## Rain Basin at the end of quest 4 uses one.
@export_range(1, 8, 1) var required_sparks: int = 3:
	set(value):
		required_sparks = maxi(1, value)
		if is_inside_tree():
			_sync_visuals()

## The altar whose charge level mirrors this socket's progress. Optional — the
## socket works headless if a level uses different art.
@export var altar_path: NodePath

## Emitted on each Spark placed, for HUD counters and tutorial prompts.
signal spark_placed(placed: int, required: int)

## Sound played when a Spark goes in but the socket is not yet full.
@export var place_sound: AudioStream

## Sound played on the placement that completes the socket.
@export var complete_sound: AudioStream

var _placed: int = 0
var _altar: Node3D
var _pips: Array[MeshInstance3D] = []


func _ready() -> void:
	# QuestObjectBase._ready() builds the shared area/prompt and restores
	# completion, so the socket's own restore has to run after it.
	super._ready()
	if Engine.is_editor_hint():
		return

	_altar = get_node_or_null(altar_path) as Node3D
	if not save_id.is_empty():
		_placed = mini(QuestState.get_socket_count(save_id), required_sparks)
	if is_objective_complete():
		_placed = required_sparks

	_build_pips()
	_sync_visuals()
	_refresh_prompt()


# --- QuestObjectBase hooks -------------------------------------------------

## Only allowed while the player actually carries a Spark. Without this the
## prompt would invite an action that silently fails.
func _can_interact() -> bool:
	return QuestState.has_spark()


func _perform_interact() -> bool:
	# Guard before spending: QuestObjectBase already blocks a completed object,
	# but a direct call (or a subclass that finishes early) must never burn a
	# Spark the socket cannot hold.
	if _placed >= required_sparks:
		return false
	if not QuestState.spend_spark():
		return false

	_placed += 1
	if not save_id.is_empty():
		QuestState.set_socket_count(save_id, _placed, required_sparks)
	spark_placed.emit(_placed, required_sparks)
	_sync_visuals()

	if _placed >= required_sparks:
		play_sound(complete_sound)
		_finish()
	else:
		play_sound(place_sound)
	return true


## "Big count" from the guide's feedback column — the running total is the
## prompt, not a separate UI element the player has to look away for.
func _prompt_text() -> String:
	if is_objective_complete():
		return "%s  %d/%d" % [completed_label, required_sparks, required_sparks]
	if not QuestState.has_spark():
		var no_spark := blocked_label if not blocked_label.is_empty() else "Find a Thought Spark"
		return "%s  %d/%d" % [no_spark, _placed, required_sparks]
	return "%s  %d/%d" % [prompt_label, _placed, required_sparks]


func _on_restore_complete() -> void:
	_placed = required_sparks


# --- Visuals ---------------------------------------------------------------

## Drives the altar's charge level and the pip row from the current count.
func _sync_visuals() -> void:
	_sync_altar()
	_sync_pips()


## Maps fill fraction onto the altar's three ChargeLevel states, so the prop
## reads as dormant, waking and fully lit as Sparks go in.
func _sync_altar() -> void:
	if not is_instance_valid(_altar):
		return
	if not (_altar is CrystalAltar):
		return
	var altar := _altar as CrystalAltar
	if _placed >= required_sparks:
		altar.charge = CrystalAltar.ChargeLevel.ASCENDANT
	elif _placed > 0:
		altar.charge = CrystalAltar.ChargeLevel.AWAKENED
	else:
		altar.charge = CrystalAltar.ChargeLevel.DORMANT


## One pip per required Spark, arranged in a row above the socket. Filled pips
## are bright and raised; empty ones sit dark and flush — a shape difference,
## not only a colour one.
func _build_pips() -> void:
	for pip in _pips:
		if is_instance_valid(pip):
			pip.queue_free()
	_pips.clear()

	var holder := get_node_or_null(^"Pips") as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = "Pips"
		holder.position.y = prompt_height - 0.28
		add_child(holder)
	else:
		for child in holder.get_children():
			child.queue_free()

	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	mesh.radial_segments = 12
	mesh.rings = 6

	var spacing := 0.17
	var start := -spacing * (required_sparks - 1) * 0.5
	for i in required_sparks:
		var pip := MeshInstance3D.new()
		pip.name = "Pip%d" % i
		pip.mesh = mesh
		pip.position = Vector3(start + spacing * i, 0.0, 0.0)
		holder.add_child(pip)
		_pips.append(pip)


func _sync_pips() -> void:
	for i in _pips.size():
		var pip := _pips[i]
		if not is_instance_valid(pip):
			continue
		var filled := i < _placed
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("e0d4ff") if filled else Color("3f4658")
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if filled else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		if filled:
			mat.emission_enabled = true
			mat.emission = Color("9b6cff")
			mat.emission_energy_multiplier = 2.2
		pip.material_override = mat
		# Filled pips also rise slightly, so the count is readable without
		# relying on colour alone.
		pip.position.y = 0.05 if filled else 0.0
		pip.scale = Vector3.ONE * (1.0 if filled else 0.72)


## Current fill, for HUD or debugging.
func get_placed() -> int:
	return _placed
