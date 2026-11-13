extends Node

## Tracks the player's progress through the Crown of Life journey.
##
## The story treats the three kingdoms as one connected adventure: a station
## only opens once the previous world's treasure has been carried back to the
## Gallery. This singleton is the authority on what the player has discovered
## and therefore on which stations and routes the Rainbow Galaxy Train may
## travel to.
##
## Global.gd holds the auth session and server URLs. Journey progress lives
## here so the two concerns stay separate.

signal treasure_discovered(treasure_id: String)
signal station_unlocked(station_id: String)
signal shortcuts_awakened()
signal identity_chosen(identity_id: String)
signal journey_completed()

const SAVE_PATH := "user://journey.save"
const SAVE_VERSION := 1

# --- Worlds, in the order the main Crown Line visits them ---
const STATION_GALLERY := "gallery"
const STATION_MIND := "mind_spark"
const STATION_HEART := "heart_melody"
const STATION_CREATOR := "creators_light"
const STATION_CASTLE := "castle"

const TREASURE_STAR := "star_of_wisdom"
const TREASURE_JEWEL := "harmony_jewel"
const TREASURE_LIGHT := "creators_light"

## Which treasure each kingdom yields, and which station that treasure opens.
## Ordering here defines the main route, so the train and the unlock logic
## never disagree about what comes next.
const CROWN_LINE: Array[Dictionary] = [
	{
		"station": STATION_MIND,
		"treasure": TREASURE_STAR,
		"display_name": "Mind Spark Kingdom",
		"guardian": "Everlasting Father",
		"scene": "res://scenes/cloud_pop_3d.tscn",
	},
	{
		"station": STATION_HEART,
		"treasure": TREASURE_JEWEL,
		"display_name": "Heart Melody Kingdom",
		"guardian": "Archangel Raphael",
		"scene": "res://scenes/music_minigame.tscn",
	},
	{
		"station": STATION_CREATOR,
		"treasure": TREASURE_LIGHT,
		"display_name": "Creator's Light Kingdom",
		"guardian": "Uriel",
		"scene": "res://scenes/drawing_tool.tscn",
	},
]

# --- Live state ---

## Treasures the player has discovered, in the order they were found.
var treasures: Array[String] = []

## Stations the train may currently travel to. The Gallery is the player's
## home station and the first kingdom is reachable from the very beginning.
var stations_unlocked: Array[String] = [STATION_GALLERY, STATION_MIND]

## The Star Shortcut lines wake up once two worlds are complete, letting the
## player travel between any pair of open stations instead of following the
## main route.
var shortcuts_enabled: bool = false

## One of the 16 game identities, chosen by the player at the finale. Empty
## until then, and always changeable — the story is explicit that the identity
## is a guide, not a box.
var identity: String = ""

## Set once the Crown of Life has been made.
var journey_complete: bool = false

## Free-form record of the choices the player made along the way. The finale
## reads this to suggest identities, so worlds append to it as they play out.
var choice_log: Array[Dictionary] = []


func _ready() -> void:
	load_journey()


# -----------------------
# DISCOVERING TREASURES
# -----------------------

## Records a treasure and opens whatever the story says it opens.
## Safe to call more than once; a treasure already held is ignored so a
## replayed world cannot double-unlock the route.
func discover_treasure(treasure_id: String) -> void:
	if treasure_id in treasures:
		return
	if not _is_known_treasure(treasure_id):
		push_warning("JourneyState: unknown treasure '%s' ignored." % treasure_id)
		return

	treasures.append(treasure_id)
	treasure_discovered.emit(treasure_id)

	_unlock_next_station()

	# After two worlds the shortcut controls wake up.
	if treasures.size() >= 2 and not shortcuts_enabled:
		shortcuts_enabled = true
		shortcuts_awakened.emit()

	# All three treasures open the castle for the finale.
	if treasures.size() == CROWN_LINE.size():
		_unlock_station(STATION_CASTLE)

	save_journey()


## Opens the station belonging to the next unvisited world on the main route.
func _unlock_next_station() -> void:
	for world in CROWN_LINE:
		if world["treasure"] in treasures:
			continue
		_unlock_station(world["station"])
		return


func _unlock_station(station_id: String) -> void:
	if station_id in stations_unlocked:
		return
	stations_unlocked.append(station_id)
	station_unlocked.emit(station_id)


func _is_known_treasure(treasure_id: String) -> bool:
	for world in CROWN_LINE:
		if world["treasure"] == treasure_id:
			return true
	return false


# -----------------------
# THE RAILWAY
# -----------------------

## True when the Destination Wheel may be turned towards this station.
func can_travel_to(station_id: String) -> bool:
	return station_id in stations_unlocked


## The station the main story route wants the player to visit next. Returns
## the castle once every treasure has been found, and an empty string if the
## journey is finished.
func next_story_station() -> String:
	for world in CROWN_LINE:
		if not world["treasure"] in treasures:
			return world["station"]
	if journey_complete:
		return ""
	return STATION_CASTLE


## Details for a station, or an empty dictionary for the Gallery and Castle,
## which are not kingdoms.
func world_info(station_id: String) -> Dictionary:
	for world in CROWN_LINE:
		if world["station"] == station_id:
			return world
	return {}


## Every station the player may currently reach from `from_station`.
## Before the shortcuts wake up the train follows the main route only, so the
## player can reach the Gallery or the next story stop and nothing else.
func reachable_from(from_station: String) -> Array[String]:
	if shortcuts_enabled:
		return stations_unlocked.filter(func(s): return s != from_station)

	var reachable: Array[String] = []
	if from_station != STATION_GALLERY:
		reachable.append(STATION_GALLERY)
	else:
		var next := next_story_station()
		if next != "" and can_travel_to(next):
			reachable.append(next)
	return reachable


# -----------------------
# IDENTITY AND FINALE
# -----------------------

## Records something the player did, for the finale to read back.
## `world` is a station id, `kind` a short tag such as "thought" or "artwork".
func record_choice(world: String, kind: String, detail: Variant = null) -> void:
	choice_log.append({
		"world": world,
		"kind": kind,
		"detail": detail,
		"at": Time.get_unix_time_from_system(),
	})
	save_journey()


func choose_identity(identity_id: String) -> void:
	identity = identity_id
	identity_chosen.emit(identity_id)
	save_journey()


## Called when the Maker forms the Crown of Life.
func complete_journey() -> void:
	if journey_complete:
		return
	journey_complete = true
	journey_completed.emit()
	save_journey()


func has_all_treasures() -> bool:
	return treasures.size() == CROWN_LINE.size()


# -----------------------
# PERSISTENCE
# -----------------------

func save_journey() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("JourneyState: could not write %s (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return

	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"treasures": treasures,
		"stations_unlocked": stations_unlocked,
		"shortcuts_enabled": shortcuts_enabled,
		"identity": identity,
		"journey_complete": journey_complete,
		"choice_log": choice_log,
	}))
	file.close()


func load_journey() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("JourneyState: could not read %s (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return

	var raw := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("JourneyState: save file was unreadable, starting a new journey.")
		return

	var data: Dictionary = parsed
	if data.get("version", 0) != SAVE_VERSION:
		push_warning("JourneyState: save file is version %s, expected %d. Starting a new journey."
			% [data.get("version", "?"), SAVE_VERSION])
		return

	treasures = _to_string_array(data.get("treasures", []))
	stations_unlocked = _to_string_array(data.get("stations_unlocked", [STATION_GALLERY, STATION_MIND]))
	shortcuts_enabled = bool(data.get("shortcuts_enabled", false))
	identity = str(data.get("identity", ""))
	journey_complete = bool(data.get("journey_complete", false))

	choice_log.clear()
	for entry in data.get("choice_log", []):
		if typeof(entry) == TYPE_DICTIONARY:
			choice_log.append(entry)

	# The Gallery is always reachable, even if a save was written by hand.
	if not STATION_GALLERY in stations_unlocked:
		stations_unlocked.append(STATION_GALLERY)


## JSON gives back an untyped Array, which will not assign to Array[String].
func _to_string_array(source: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(source) != TYPE_ARRAY:
		return result
	for value in source:
		result.append(str(value))
	return result


## Wipes progress and starts the journey over. Used by a "new game" option.
func reset_journey() -> void:
	treasures.clear()
	stations_unlocked = [STATION_GALLERY, STATION_MIND]
	shortcuts_enabled = false
	identity = ""
	journey_complete = false
	choice_log.clear()

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
