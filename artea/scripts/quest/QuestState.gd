extends Node

## Tracks Mind Spark quest progress and the player's Thought Spark inventory.
##
## Registered as the `QuestState` autoload. Every quest object in PART 4 of the
## Mind Spark developer guide reads and writes through here rather than talking
## to each other, so a socket in one zone and a gate in another stay in sync
## without either knowing the other exists.
##
## The guide's SAVE RULE — "Save after each quest and before the boss. A retry
## keeps earlier quests." — is why completion is stored per save ID and written
## out the moment it changes, rather than at a checkpoint.

## Emitted when the player picks up or spends a Spark.
signal sparks_changed(carried: int)

## Emitted when a quest object reports itself complete. `save_id` is the
## object's own id, so listeners (gates, paths, VFX) can react to one specific
## object without polling.
signal objective_completed(save_id: String)

## Emitted when a socket's placed-count changes, for HUD counters.
signal socket_progress(save_id: String, placed: int, required: int)

const SAVE_PATH := "user://mind_spark_progress.save"

## Sparks the player is carrying and has not yet placed.
var carried_sparks: int = 0

## save_id -> true for every completed quest object.
var completed: Dictionary = {}

## save_id -> placed count, so a partly-filled socket survives a reload.
var socket_counts: Dictionary = {}


func _ready() -> void:
	load_progress()


# --- Sparks ----------------------------------------------------------------

## Called when the player collects a Thought Spark in the world.
func add_spark(count: int = 1) -> void:
	carried_sparks += count
	sparks_changed.emit(carried_sparks)
	save_progress()


## Spends one carried Spark. Returns false when the player has none, which is
## what stops a socket accepting input the player cannot afford.
func spend_spark() -> bool:
	if carried_sparks <= 0:
		return false
	carried_sparks -= 1
	sparks_changed.emit(carried_sparks)
	save_progress()
	return true


func has_spark() -> bool:
	return carried_sparks > 0


# --- Objectives ------------------------------------------------------------

func is_complete(save_id: String) -> bool:
	return completed.get(save_id, false)


func mark_complete(save_id: String) -> void:
	if completed.get(save_id, false):
		return
	completed[save_id] = true
	# Saved before the signal fires: the guide requires quest completion to be
	# on disk before the next gate or path opens, and a listener may open one.
	save_progress()
	objective_completed.emit(save_id)


func get_socket_count(save_id: String) -> int:
	return socket_counts.get(save_id, 0)


func set_socket_count(save_id: String, placed: int, required: int) -> void:
	socket_counts[save_id] = placed
	socket_progress.emit(save_id, placed, required)
	save_progress()


# --- Persistence -----------------------------------------------------------

func save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("QuestState: could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify({
		"carried_sparks": carried_sparks,
		"completed": completed,
		"socket_counts": socket_counts,
	}))


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("QuestState: save file unreadable, starting fresh")
		return
	carried_sparks = int(parsed.get("carried_sparks", 0))
	completed = parsed.get("completed", {})
	socket_counts = parsed.get("socket_counts", {})


## Wipes progress. Exposed for testing and for a "new game" menu action.
func reset_progress() -> void:
	carried_sparks = 0
	completed.clear()
	socket_counts.clear()
	save_progress()
	sparks_changed.emit(carried_sparks)
