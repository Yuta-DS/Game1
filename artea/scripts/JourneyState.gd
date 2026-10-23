# Persistent record of the player's journey through Artéa.
#
# Autoload. Separate from Global.gd on purpose: Global holds session auth
# and is cleared on logout, but the journey belongs to the player and must
# survive logout.
#
# Thought text is personal and stays on this machine. Never upload it.
extends Node

signal treasure_awarded(treasure_id: String)
signal journey_completed

const SAVE_PATH := "user://journey.json"

# Where this instance actually reads and writes. Defaults to the player's real
# journey; tests point it at a scratch file so running the suite can never
# overwrite or erase a real child's record. Instance state rather than a const
# because that is the only way a test can redirect it.
var save_path: String = SAVE_PATH
var campaign_version: int = 2

# 0 = not started, 1 = thoughts, 2 = emotions, 3 = creativity, 4 = identity
var stage: int = 0

var thoughts: Array = []    # [{text, popped, emotion}]
var emotions: Array = []    # [{name, colour, visited}]
var creations: Array = []   # [{id, path, title, prompt_answered}]
var strengths: Array = []   # ["courage", "emotional-awareness", ...]

# Creator's Light is earned by completing the Gallery Frame Ritual, not by
# merely exporting an image. Each entry is a small local proof of a voluntary
# frame choice; it never contains an AI interpretation of the artwork.
var creation_rituals: Array = []   # [{creation_id, motif_id}]

# Each time the player carried a seeing across a gap with the Lens of Seeing
# (scripts/viewfinder/). Counted, not just flagged, so the ceremony can cite
# how many times it happened — the same evidentiary standard as the rest.
#
# Deliberately NOT a fourth treasure: the Crown of Life stays gated on the
# three kingdoms, so a player who never finds the lens is still crowned.
var bridgings: Array = []   # [{from, to}]

# Named discoveries make the three activities one quest. They are stored
# independently from stage so replaying a world cannot erase another reward.
var treasures: Dictionary = {
	"star_of_wisdom": false,
	"harmony_jewel": false,
	"creators_light": false,
}

# Evidence that the player completed a chapter of the optional Crown of Life
# Lens story (scenes/viewfinder/crown_of_life_story.tscn), independent from the
# canonical kingdoms. These flags are replay history only: they never award a
# treasure, unlock a kingdom, or substitute for real mini-game completion.
var story_chapters: Dictionary = {
	"mind_spark": false,
	"heart_melody": false,
	"creators_light": false,
}

# Faith is ARTÉA's authentic default. Facilitators can select "universal" for
# settings that need the same dignity/purpose message without explicit faith
# language; progression and rewards never change between modes.
var audience_mode: String = "faith"
## Version 2 earns Heart's treasure through the adventure, never a feeling choice.
## Loading a pre-version save retains that journey's established entitlement.
var heart_campaign_version: int = 2


func _ready() -> void:
	load_journey()


# --- recording -------------------------------------------------------

func record_thought(text: String) -> void:
	thoughts.append({"text": text, "popped": false, "emotion": ""})
	save()


## Records one curated Mind Spark card. The ID is local encounter evidence,
## not a judgement about the player or a copy of any free-text disclosure.
func record_thought_echo(text: String, echo_id: String) -> void:
	if text.strip_edges().is_empty() or echo_id.strip_edges().is_empty():
		return
	thoughts.append({
		"text": text,
		"popped": false,
		"emotion": "",
		"mind_echo_id": echo_id,
	})
	save()


func mark_popped(text: String) -> void:
	for t in thoughts:
		if t.get("text", "") == text and not t.get("popped", false):
			t["popped"] = true
			save()
			return


## The canonical Mind Spark completion. A Star of Wisdom can only follow a
## full curated encounter: at least the UI's minimum number of selected cards,
## and every one of those cards actually resolved. It is idempotent so replay
## never duplicates a reward.
func complete_mind_spark(minimum_echoes: int = 2, required_echo_ids: Array = []) -> bool:
	if minimum_echoes < 1:
		return false
	# A bounded encounter may provide its own authored round IDs. This prevents
	# an abandoned older session from permanently blocking a later completed
	# Two Lenses journey, while still requiring honest evidence for every round
	# in the current encounter.
	if not required_echo_ids.is_empty():
		var resolved_by_id := {}
		for raw_id in required_echo_ids:
			var required_id := str(raw_id)
			if required_id.is_empty() or resolved_by_id.has(required_id):
				return false
			resolved_by_id[required_id] = false
		if resolved_by_id.size() < minimum_echoes:
			return false
		for thought in thoughts:
			var thought_id := str(thought.get("mind_echo_id", ""))
			if resolved_by_id.has(thought_id) and bool(thought.get("popped", false)):
				resolved_by_id[thought_id] = true
		for required_id in resolved_by_id:
			if not bool(resolved_by_id[required_id]):
				return false
		_grant("courage")
		_award_treasure("star_of_wisdom")
		save()
		return true
	var selected_echoes := 0
	for thought in thoughts:
		if str(thought.get("mind_echo_id", "")).is_empty():
			continue
		selected_echoes += 1
		if not bool(thought.get("popped", false)):
			return false
	if selected_echoes < minimum_echoes:
		return false
	_grant("courage")
	_award_treasure("star_of_wisdom")
	save()
	return true


func record_emotion(emotion_name: String, colour: Color) -> void:
	emotions.append({
		"name": emotion_name,
		"colour": colour.to_html(),
		"visited": true,
	})
	_grant("emotional-awareness")
	if heart_campaign_version < 2:
		_award_treasure("harmony_jewel")
	save()


func complete_heart_melody() -> bool:
	# The production Heart Melody finale is the canonical version-two reward
	# boundary. Replays are idempotent and never manufacture extra progress.
	var already_owned := has_treasure("harmony_jewel")
	_award_treasure("harmony_jewel")
	save()
	return not already_owned and has_treasure("harmony_jewel")


func record_creation(path: String, title: String) -> String:
	var creation_id := "creation_%d_%d" % [Time.get_ticks_usec(), creations.size()]
	creations.append({
		"id": creation_id,
		"path": path,
		"title": title,
		"prompt_answered": false,
	})
	_grant("creativity")
	save()
	return creation_id


func creation_id_for_path(path: String) -> String:
	for index in range(creations.size() - 1, -1, -1):
		var creation: Dictionary = creations[index]
		if str(creation.get("path", "")) == path:
			return _creation_id_for(creation, index)
	return ""


# The one canonical Creator completion. The ritual is idempotent so a player
# can revisit a frame without duplicating a reward or turning the ceremony into
# a score chase.
func complete_creator_frame_ritual(creation_id: String, motif_id: String) -> bool:
	if creation_id.is_empty() or motif_id.is_empty():
		return false
	var found := false
	for index in creations.size():
		var creation: Dictionary = creations[index]
		if _creation_id_for(creation, index) == creation_id:
			found = true
			break
	if not found:
		return false
	for ritual in creation_rituals:
		if str(ritual.get("creation_id", "")) == creation_id:
			return true
	creation_rituals.append({"creation_id": creation_id, "motif_id": motif_id})
	_award_treasure("creators_light")
	save()
	return true


func has_completed_creator_frame_ritual(creation_id: String = "") -> bool:
	if creation_id.is_empty():
		return not creation_rituals.is_empty()
	for ritual in creation_rituals:
		if str(ritual.get("creation_id", "")) == creation_id:
			return true
	return false


# One completed bridging with the Lens of Seeing. Grants "perception" rather
# than a treasure — see the note on `bridgings`.
func record_bridging(from_place: String = "", to_place: String = "") -> void:
	bridgings.append({"from": from_place, "to": to_place})
	_grant("perception")
	save()


# A chapter of the optional Crown of Life Lens story was completed by carrying
# a seeing across its gap. This remains replay evidence only: it must never
# manufacture a standalone Mind/Heart/Creator reward or unlock a kingdom.
# `record_bridging()` separately keeps its honest Lens-specific perception
# evidence. Idempotent — replaying a chapter cannot change canonical progress.
func record_story_chapter(chapter_id: String) -> void:
	if not story_chapters.has(chapter_id):
		return
	story_chapters[chapter_id] = true
	save()


func has_story_chapter(chapter_id: String) -> bool:
	return bool(story_chapters.get(chapter_id, false))


func story_chapters_complete() -> bool:
	for chapter_id in story_chapters:
		if not bool(story_chapters[chapter_id]):
			return false
	return true


func bridgings_count() -> int:
	return bridgings.size()


func advance_to(new_stage: int) -> void:
	# Stage only ever moves forward. Replaying Pop Thoughts after reaching
	# the gallery must not demote the castle back to stage 1.
	if new_stage >= 4 and not has_all_treasures():
		return
	if new_stage > stage:
		stage = new_stage
		save()


# --- queries used by the scenes --------------------------------------

func popped_count() -> int:
	var n := 0
	for t in thoughts:
		if t.get("popped", false):
			n += 1
	return n


# Longest thought written, as a stand-in for "the heaviest one".
func heaviest_thought() -> String:
	var heaviest := ""
	for t in thoughts:
		var text: String = t.get("text", "")
		if text.length() > heaviest.length():
			heaviest = text
	return heaviest


func has_journey() -> bool:
	return not thoughts.is_empty() or not emotions.is_empty() or not creations.is_empty()


func has_treasure(treasure_id: String) -> bool:
	return bool(treasures.get(treasure_id, false))


func has_all_treasures() -> bool:
	return has_treasure("star_of_wisdom") \
		and has_treasure("harmony_jewel") \
		and has_treasure("creators_light")


func treasure_count() -> int:
	var count := 0
	for treasure_id in treasures:
		if bool(treasures[treasure_id]):
			count += 1
	return count


func set_audience_mode(mode: String) -> void:
	if mode not in ["faith", "universal"]:
		return
	audience_mode = mode
	save()


# --- persistence -----------------------------------------------------

func save() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("JourneyState: could not write %s" % save_path)
		return
	file.store_string(JSON.stringify({
		"heart_campaign_version": heart_campaign_version,
		"stage": stage,
		"thoughts": thoughts,
		"emotions": emotions,
		"creations": creations,
		"creation_rituals": creation_rituals,
		"strengths": strengths,
		"bridgings": bridgings,
		"treasures": treasures,
		"story_chapters": story_chapters,
		"audience_mode": audience_mode,
	}))


func load_journey() -> void:
	if not FileAccess.file_exists(save_path):
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("JourneyState: could not read %s" % save_path)
		return

	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("JourneyState: %s is corrupt, starting fresh" % save_path)
		return

	stage = int(data.get("stage", 0))
	heart_campaign_version = int(data.get("heart_campaign_version", 1))
	thoughts = data.get("thoughts", [])
	emotions = data.get("emotions", [])
	creations = data.get("creations", [])
	var has_ritual_field: bool = data.has("creation_rituals")
	creation_rituals = data.get("creation_rituals", []) if has_ritual_field else []
	if not creation_rituals is Array:
		creation_rituals = []
	strengths = data.get("strengths", [])
	bridgings = data.get("bridgings", [])
	var loaded_treasures = data.get("treasures", {})
	if typeof(loaded_treasures) == TYPE_DICTIONARY:
		for treasure_id in treasures:
			treasures[treasure_id] = bool(loaded_treasures.get(treasure_id, false))
	# Migration-safe: a save from before this field existed simply has no
	# chapters recorded yet, which is the honest state — it does not mean the
	# player completed them.
	var loaded_chapters = data.get("story_chapters", {})
	if typeof(loaded_chapters) == TYPE_DICTIONARY:
		for chapter_id in story_chapters:
			story_chapters[chapter_id] = bool(loaded_chapters.get(chapter_id, false))
	# Backward-compatible migration: previous saves already contain reliable
	# evidence even though they predate explicit treasure ownership.
	if popped_count() > 0:
		treasures["star_of_wisdom"] = true
	if heart_campaign_version < 2 and not emotions.is_empty():
		treasures["harmony_jewel"] = true
	# Before the Gallery Frame Ritual existed, saving an artwork immediately
	# earned Creator's Light. Preserve those established journeys exactly once.
	# New saves include creation_rituals (possibly empty) and therefore require
	# the ritual instead of granting a treasure on export.
	if not has_ritual_field and not creations.is_empty():
		treasures["creators_light"] = true
	audience_mode = str(data.get("audience_mode", "faith"))
	if audience_mode not in ["faith", "universal"]:
		audience_mode = "faith"


# The player can erase their journey at any time. No confirmation maze,
# no partial wipe — the file goes and the state resets.
func clear_journey() -> void:
	if save_path == SAVE_PATH and is_inside_tree():
		var tracker := get_node_or_null("/root/PlayerIdentityTracker")
		if tracker != null: tracker.clear_world_evidence("heart_melody")
	for suffix in ["", ".bak", ".tmp"]:
		var heart_path: String = "user://heart_melody_island_one.json" + suffix
		if save_path == SAVE_PATH and FileAccess.file_exists(heart_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(heart_path))
	stage = 0
	heart_campaign_version = 2
	thoughts.clear()
	emotions.clear()
	creations.clear()
	creation_rituals.clear()
	strengths.clear()
	bridgings.clear()
	for treasure_id in treasures:
		treasures[treasure_id] = false
	for chapter_id in story_chapters:
		story_chapters[chapter_id] = false
	audience_mode = "faith"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _grant(strength: String) -> void:
	if not strengths.has(strength):
		strengths.append(strength)


func _creation_id_for(creation: Dictionary, index: int) -> String:
	var stored := str(creation.get("id", ""))
	if not stored.is_empty():
		return stored
	# Legacy records had no id. This deterministic local identifier lets a
	# legacy artwork be framed without rewriting its original record first.
	return "legacy_%d_%s" % [index, str(creation.get("path", "")).sha256_text()]


func _award_treasure(treasure_id: String) -> void:
	if not treasures.has(treasure_id) or bool(treasures[treasure_id]):
		return
	treasures[treasure_id] = true
	treasure_awarded.emit(treasure_id)
	if has_all_treasures():
		journey_completed.emit()
