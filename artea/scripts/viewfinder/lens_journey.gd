# The Lens of Seeing, bound to the journey — the story layer over the cutting
# mechanic in viewfinder_lens.gd.
#
# THE FICTION
#
# The three kingdoms each make the same claim about the player's inside world:
# a thought can be looked at and changed (Mind Spark), a feeling can be given a
# voice (Heart Melody), a thing can be made that did not exist (Creator's
# Light). The Lens makes that claim about the world OUTSIDE them, so the player
# discovers by doing rather than being told:
#
#   what you notice in one place, you can carry, and make true in another.
#
# The player is never cutting Artéa up. They are SEEING — and a seeing, once
# held, can fill a gap somewhere else. Every capture is reversible
# (viewfinder_lens.release), because a child who frames the wrong thing must
# never be stuck with damage they cannot undo. That reversibility is a design
# requirement of the whole project, not a convenience.
#
# THE TREASURE
#
# Completing a bridging earns the LENS OF SEEING. It follows the same rule as
# every other treasure in Artéa (see gallery_ceremony.gd): the game only claims
# a strength the player actually demonstrated. The lens is awarded for an act
# the player performed — carrying a seeing across a gap — not for arriving.
#
# WHY THIS IS OPTIONAL
#
# JourneyState's three treasures gate the Crown of Life. This deliberately does
# NOT add a fourth gate: a child who never finds the Lens must still be able to
# complete the journey and be crowned. Perception is offered as a fourth
# strength to discover, never as a toll on the finale.
extends Node

const LensScript := preload("res://scripts/viewfinder/viewfinder_lens.gd")

signal bridging_completed
signal lens_message(text: String)

# The strength this world teaches, in the vocabulary JourneyState already uses.
const STRENGTH := "perception"

# Spoken when the player first raises the lens. Names what they are doing
# without explaining the puzzle for them.
const FIRST_LOOK := {
	"faith": "Uriel: Look carefully. What you notice, you may carry — and what you carry, you may give to a place that is missing it.",
	"universal": "The Keeper of Creativity: Look carefully. What you notice, you may carry — and what you carry, you may give to a place that is missing it.",
}

const ON_CAPTURE := "You are carrying what you saw."

const ON_PLACE := "What you saw is real here now."

# Said on completing a bridging. Cites the act, never flattery.
const ON_BRIDGE := {
	"faith": "Uriel: You saw what was missing and you carried it here yourself. That is the Lens of Seeing.",
	"universal": "The Keeper of Creativity: You saw what was missing and you carried it here yourself. That is the Lens of Seeing.",
}

var lens: Node

# Whether a bridging here counts toward the player's real journey. False in a
# sandbox like the demo room: playing with the mechanic to check a cut looks
# right must not write "perception" into a real child's record, and the demo
# would otherwise award a strength nobody earned.
var record_to_journey := true

var _bridged := false


func _ready() -> void:
	if lens == null:
		lens = get_parent().find_child("ViewfinderLens", true, false)
	if lens == null:
		return

	lens.seeing_captured.connect(_on_captured)
	lens.seeing_placed.connect(_on_placed)
	lens.capture_refused.connect(_on_refused)


func first_look_line() -> String:
	return FIRST_LOOK.get(_audience_mode(), FIRST_LOOK["faith"])


func has_lens_treasure() -> bool:
	var js := _journey_state()
	if js == null:
		return false
	return js.strengths.has(STRENGTH)


func _on_captured(_count: int) -> void:
	lens_message.emit(ON_CAPTURE)


func _on_placed(_count: int) -> void:
	lens_message.emit(ON_PLACE)
	# A placement IS the bridging: the player carried a seeing across a gap and
	# made it real somewhere else. Nothing further to verify — the act already
	# happened, and that is the whole evidentiary standard Artéa uses.
	_complete_bridging()


func _on_refused(reason: String) -> void:
	# Refusals are surfaced verbatim. A mechanic that silently does nothing
	# reads as broken to a child, who will assume they did it wrong.
	lens_message.emit(reason)


func _complete_bridging(from_place: String = "", to_place: String = "") -> void:
	var js := _journey_state()
	if js != null and record_to_journey:
		# Through JourneyState's own recording path, so it persists, counts,
		# and is wiped by clear_journey() along with everything else. Every
		# bridging is recorded, not just the first — the ceremony cites how
		# many times the player did this, so a latch here would undercount it.
		js.record_bridging(from_place, to_place)

	# The guardian's line, however, is said once. Repeating a naming speech on
	# every placement would turn the moment it names into wallpaper.
	if not _bridged:
		_bridged = true
		lens_message.emit(ON_BRIDGE.get(_audience_mode(), ON_BRIDGE["faith"]))

	bridging_completed.emit()


func _journey_state() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/JourneyState")


func _audience_mode() -> String:
	var js := _journey_state()
	if js == null:
		return "faith"
	return str(js.audience_mode)
