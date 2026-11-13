@tool
class_name QuestObjectBase
extends Node3D

## Shared base for every Mind Spark quest object.
##
## The developer guide's SHARED OBJECT RULE asks for exactly one of these:
##
##   "Build one QuestObjectBase scene with an interaction Area3D, prompt,
##    current state, completion signal, save ID and optional AnimationPlayer.
##    Each object below is a small child setup or Resource, not a new full
##    system."
##
## So this class owns the parts every object in that list shares — proximity
## detection, the floating prompt, the completed/locked state machine and the
## save hook — and subclasses supply only what makes their object different.
##
## Subclasses override:
##   * `_can_interact()` — whether the action is available right now
##   * `_perform_interact()` — do the thing; return true if it consumed the press
##   * `_prompt_text()` — one small action plus progress, per the guide's
##     meaningful-use check ("The prompt says one small action and shows
##     progress such as 0/3 or 1/3")

## Fired when this object finishes its objective. Carries `save_id` so a
## listener can key off one specific object.
signal completed(save_id: String)

## Fired on every successful interaction, complete or not — for SFX and VFX.
signal interacted(save_id: String)

## Unique id used for save data and for cross-object references. Two objects
## sharing an id would share completion state, so each must be distinct.
@export var save_id: String = ""

## Shown when the player is close enough to act.
@export_multiline var prompt_label: String = "Interact"

## Shown instead once the objective is finished.
@export_multiline var completed_label: String = "Done"

## Shown when `_can_interact()` is false — tells the player *why* they cannot
## act, rather than leaving the prompt silent.
@export_multiline var blocked_label: String = ""

## Radius the player must be inside for the prompt to appear.
@export_range(0.5, 12.0, 0.1) var interact_radius: float = 3.0:
	set(value):
		interact_radius = value
		_apply_radius()

## Height of the floating prompt above the object's origin.
@export_range(0.0, 6.0, 0.05) var prompt_height: float = 1.9:
	set(value):
		prompt_height = value
		if is_instance_valid(_label):
			_label.position.y = prompt_height

## Input action that triggers the interaction. Matches the project's existing
## `interact` binding by default.
@export var interact_action: String = "interact"

## Optional clip played on each successful interaction.
@export var interact_animation: String = ""

## Optional clip played once when the objective completes.
@export var complete_animation: String = ""

var _area: Area3D
var _label: Label3D
var _anim: AnimationPlayer
var _audio: AudioStreamPlayer3D
var _player_inside: bool = false
var _is_complete: bool = false


func _ready() -> void:
	_build_nodes()
	if Engine.is_editor_hint():
		return

	if save_id.is_empty():
		push_warning("QuestObjectBase at %s has no save_id; progress will not persist." % get_path())
	elif QuestState.is_complete(save_id):
		# Restore finished state without replaying the completion animation —
		# the player already saw it before the reload.
		_is_complete = true
		_on_restore_complete()

	_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _player_inside:
		return
	if not event.is_action_pressed(interact_action):
		return
	if _is_complete or not _can_interact():
		return
	if _perform_interact():
		get_viewport().set_input_as_handled()
		interacted.emit(save_id)
		if not interact_animation.is_empty() and is_instance_valid(_anim):
			if _anim.has_animation(interact_animation):
				_anim.play(interact_animation)
		_refresh_prompt()


# --- Subclass hooks --------------------------------------------------------

## Whether the interaction is currently allowed. Default: always.
func _can_interact() -> bool:
	return true


## Perform the interaction. Return true if it did something, false to ignore
## the press (the prompt stays up and no signal fires).
func _perform_interact() -> bool:
	return false


## The prompt line. Should name one small action and show progress.
func _prompt_text() -> String:
	if _is_complete:
		return completed_label
	if not _can_interact() and not blocked_label.is_empty():
		return blocked_label
	return prompt_label


## Called when a finished objective is restored from save, instead of
## `_finish()`. Subclasses use it to jump straight to the final visual state.
func _on_restore_complete() -> void:
	pass


# --- Completion ------------------------------------------------------------

## Marks the objective done, saves it and fires the signal. Safe to call twice.
func _finish() -> void:
	if _is_complete:
		return
	_is_complete = true
	if not save_id.is_empty():
		# QuestState writes to disk before re-emitting, satisfying the guide's
		# rule that completion is saved before the next gate opens.
		QuestState.mark_complete(save_id)
	if not complete_animation.is_empty() and is_instance_valid(_anim):
		if _anim.has_animation(complete_animation):
			_anim.play(complete_animation)
	_refresh_prompt()
	completed.emit(save_id)


func is_objective_complete() -> bool:
	return _is_complete


# --- Prompt / proximity ----------------------------------------------------

func _refresh_prompt() -> void:
	if not is_instance_valid(_label):
		return
	_label.text = _prompt_text()
	# The prompt only shows while the player is in range; a finished object
	# still shows its completed line so the result stays legible.
	_label.visible = _player_inside


func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_inside = true
	_refresh_prompt()


func _on_body_exited(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_inside = false
	_refresh_prompt()


## True for the player body.
##
## The project is inconsistent about the group's capitalisation — the 2D
## scenes use "Player" while NewPlayer.tscn uses "player" — so both are
## accepted rather than silently failing to detect the player in one of them.
static func _is_player(body: Node) -> bool:
	return body.is_in_group("player") or body.is_in_group("Player")


## Plays a one-shot sound through the object's own 3D player.
func play_sound(stream: AudioStream) -> void:
	if stream == null or not is_instance_valid(_audio):
		return
	_audio.stream = stream
	_audio.play()


# --- Construction ----------------------------------------------------------

## Creates the shared children if the scene did not already author them, so a
## subclass gets a working interaction zone with no setup.
func _build_nodes() -> void:
	_area = get_node_or_null(^"InteractArea") as Area3D
	if _area == null:
		_area = Area3D.new()
		_area.name = "InteractArea"
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		shape.shape = SphereShape3D.new()
		_area.add_child(shape)
		add_child(_area)
	# Detect bodies only; monitorable off since nothing queries this area.
	_area.monitoring = true
	_area.monitorable = false
	_apply_radius()

	if not _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.connect(_on_body_entered)
	if not _area.body_exited.is_connected(_on_body_exited):
		_area.body_exited.connect(_on_body_exited)

	_label = get_node_or_null(^"Prompt") as Label3D
	if _label == null:
		_label = Label3D.new()
		_label.name = "Prompt"
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# Drawn on top so the prompt is never buried inside the prop it labels.
		_label.no_depth_test = true
		_label.font_size = 48
		_label.outline_size = 12
		_label.pixel_size = 0.0035
		_label.modulate = Color(1, 1, 1)
		_label.outline_modulate = Color(0, 0, 0, 0.85)
		add_child(_label)
	_label.position.y = prompt_height
	_label.visible = false

	_anim = get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	_audio = get_node_or_null(^"Audio") as AudioStreamPlayer3D
	if _audio == null:
		_audio = AudioStreamPlayer3D.new()
		_audio.name = "Audio"
		add_child(_audio)


func _apply_radius() -> void:
	if not is_instance_valid(_area):
		return
	var shape := _area.get_node_or_null(^"Shape") as CollisionShape3D
	if shape and shape.shape is SphereShape3D:
		(shape.shape as SphereShape3D).radius = interact_radius
