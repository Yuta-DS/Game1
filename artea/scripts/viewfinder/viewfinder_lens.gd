# The Lens of Seeing — Artéa's viewfinder mechanic.
#
# Two-step loop, as in ViewFinder.txt §0:
#   TAKE  — everything inside the frustum is sliced out, cloned into a held
#           "seeing", and the world is restored intact.
#   PLACE — the frustum is recomputed at the player's NEW position, whatever
#           sits there is sliced out and removed, and the held seeing drops
#           into the hole it leaves.
#
# STORY (see CASTLE_UNIVERSE_IMPLEMENTATION.md): the lens is not a camera and
# the player is not "cutting up" Artéa. They are learning that a thing seen
# from one place can be carried and made true somewhere else — the same claim
# the three kingdoms make about thoughts, feelings and creations. A gap in the
# world is not damage to be repaired; it is a place where something the player
# noticed is missing, and only they can put it there.
#
# The held seeing is parented to the capture point, so its transform RELATIVE
# TO THE PLAYER *is* the photograph. Placement needs no projection maths — the
# geometry lands exactly where it was framed, by construction (§L5).
extends Node3D

const FrustumCutterScript := preload("res://scripts/viewfinder/frustum_cutter.gd")

signal seeing_captured(fragment_count: int)
signal seeing_placed(fragment_count: int)
signal capture_refused(reason: String)
signal seeings_remaining_changed(remaining: int)

# How many seeings the player may take. The original's photo counter is a
# puzzle constraint — a limited resource makes each framing a decision rather
# than something to spam.
#
# Refilled by placing, not consumed permanently: taking costs one, placing
# gives it back, so a child can never reach a dead end where they have used up
# every seeing and the puzzle is unsolvable. That is a deliberate softening of
# the original, which lets the player strand themselves.
const MAX_SEEINGS := 5

# How far the lens reaches. Short on purpose — cost scales with the geometry
# inside the frustum (ViewFinder.txt R1).
#
# It is also what makes the lens read as FRAMING rather than vacuuming. At 18 m
# with a 70-degree camera the far plane is ~25 m across, so standing back from
# a row of props swallowed all of them at once and the player had no sense of
# choosing anything. 9 m keeps the frame around what the player is actually
# looking at.
const CAPTURE_DISTANCE := 9.0

# The lens sees a narrower cone than the player's own camera. Without this the
# capture takes in the full width of the screen, including things at the very
# edge of vision that the player never considered part of the shot — the frame
# drawn on screen would be a lie.
const LENS_FOV_SCALE := 0.62

var capture_point: Node3D
var camera: Camera3D

var _cutter: Node3D
var _lens_camera: Camera3D
var _held: Array[Node3D] = []
var _seeings_left := MAX_SEEINGS
# Turns of the held seeing, in 30-degree steps, applied about the view axis.
var _held_roll_steps := 0
# Props hidden while their captured copy is held, restored when it is placed.
var _suppressed: Array[Node3D] = []

# Props that were cut away at a PLACEMENT destination to make room for a
# seeing. Unlike `_suppressed` these are not restored by the next place() —
# the placed geometry now occupies their space — but they are still tracked, so
# the world can always be put back exactly as it was found. Without this list a
# destination prop would be hidden with nothing holding a reference to it, which
# is the one state the whole transaction design exists to prevent.
var _displaced: Array[Node3D] = []

# Every runtime-generated fragment this lens has committed into the world by
# placing: both the held seeing itself and the destination props' offcuts.
#
# These have no source asset — they exist only because a placement happened —
# so restoring the authored world means DELETING them, not hiding them. Without
# this list restore_world() would un-hide the originals underneath while the
# generated geometry stayed on top, leaving the two overlapping and the claim of
# an exact restore false.
var _committed: Array[Node3D] = []

# TRANSACTION GUARD.
#
# capture()/place()/release() each perform mesh surgery over many nodes and are
# driven straight from a mouse click. A second click landing inside the first —
# possible through a signal handler, a queued input event, or a child simply
# clicking twice fast — would re-enter mid-surgery, when `_held` and
# `_suppressed` are half-written, and could leave a prop hidden with no seeing
# to restore it: a permanent hole in the world.
#
# Every one of these operations is therefore all-or-nothing: refused outright if
# one is already running, and the flag is cleared on every exit path.
var _busy := false


func _ready() -> void:
	_cutter = FrustumCutterScript.new()
	_cutter.name = "FrustumCutter"
	add_child(_cutter)

	# A non-current camera used purely as the frustum's definition. Cutting
	# against the player's own camera would take in the full width of the
	# screen; this one is narrower, so what is sliced matches the frame the
	# player is shown.
	_lens_camera = Camera3D.new()
	_lens_camera.name = "LensFrustum"
	_lens_camera.current = false
	add_child(_lens_camera)


# The camera whose frustum defines a capture, kept aligned with the player's
# view and narrowed by LENS_FOV_SCALE.
func _framing_camera() -> Camera3D:
	if camera == null:
		return null
	if _lens_camera == null:
		return camera
	_lens_camera.global_transform = camera.global_transform
	_lens_camera.fov = camera.fov * LENS_FOV_SCALE
	return _lens_camera


func is_holding() -> bool:
	return not _held.is_empty()


func held_count() -> int:
	return _held.size()


# TAKE. Slice the frustum, keep what was inside, restore the world.
#
# The world is restored rather than left cut because the fiction is that the
# player has SEEN something, not broken it. Artéa is never damaged by being
# looked at.
func capture() -> bool:
	# Refused, not queued: the guard is checked before any state is touched, so
	# a rejected second click changes nothing at all.
	if _busy:
		capture_refused.emit("Wait — the lens is still working.")
		return false
	if camera == null or capture_point == null:
		capture_refused.emit("The lens has nothing to look through.")
		return false
	if is_holding():
		capture_refused.emit("You are already carrying something you saw.")
		return false
	if _seeings_left <= 0:
		capture_refused.emit("You have no seeings left. Place one to take another.")
		return false

	_busy = true

	var result: Dictionary = _cutter.slice_frustum(_framing_camera(), CAPTURE_DISTANCE)
	var inside: Array = result["inside"]
	var outside: Array = result["outside"]

	# Nothing framed. Say so plainly rather than handing back an empty pane —
	# an empty capture that looks successful is worse than a refusal.
	#
	# The offcuts are freed and NOTHING is hidden, so a refusal leaves the world
	# exactly as the player found it.
	if inside.is_empty():
		for fragment in outside:
			fragment.queue_free()
		_busy = false
		capture_refused.emit("There is nothing in the frame yet.")
		return false

	# The captured fragments become the held seeing: parented to the capture
	# point so they travel with the player, hidden until placed.
	for fragment in inside:
		FrustumCutterScript.place_fragment(fragment, self)
		fragment.reparent(capture_point, true)
		# Hidden AND intangible: a held seeing rides inside the player's own
		# capsule, so leaving its collision live would trap them inside the
		# thing they are carrying.
		_set_fragment_active(fragment, false)
		_held.append(fragment)

	# The offcuts were only ever scaffolding for the cut.
	for fragment in outside:
		fragment.queue_free()

	# Hide the sources so the world shows the gap the player is now carrying.
	# Hidden, not freed: placing restores them, so a capture is never
	# destructive and can always be undone by putting the seeing back.
	for source in result["sources"]:
		if source is Node3D:
			_set_prop_active(source, false)
			_suppressed.append(source)

	_seeings_left -= 1
	_held_roll_steps = 0

	# Cleared BEFORE the signals: a listener that captures or places in response
	# is doing something legitimate, and would otherwise be refused by this
	# call's own guard. The transaction is complete by this line — held state,
	# suppressed sources and the counter are all consistent.
	_busy = false
	seeings_remaining_changed.emit(_seeings_left)
	seeing_captured.emit(_held.size())
	return true


# PLACE. Cut a hole at the player's current framing and drop the seeing in.
func place() -> bool:
	if _busy:
		capture_refused.emit("Wait — the lens is still working.")
		return false
	if not is_holding():
		capture_refused.emit("You are not carrying anything to place.")
		return false
	if camera == null:
		capture_refused.emit("The lens has nothing to look through.")
		return false

	_busy = true

	# Whatever occupies the destination is removed, leaving a frustum-shaped
	# hole for the held geometry.
	var result: Dictionary = _cutter.slice_frustum(_framing_camera(), CAPTURE_DISTANCE)
	for fragment in result["inside"]:
		fragment.queue_free()
	# The offcuts are the parts of those props that were NOT displaced, so they
	# stay: removing them would delete scenery outside the frame.
	#
	# They are runtime geometry with no source asset, so they are committed —
	# restoring the authored world means deleting them, not hiding them.
	var scene := get_tree().current_scene
	for fragment in result["outside"]:
		FrustumCutterScript.place_fragment(fragment, scene if scene != null else self)
		_track_committed(fragment)

	# The destination props have been replaced by their own offcuts, so they
	# stay hidden — but they are TRACKED, not just switched off. An untracked
	# hidden prop is unrecoverable: nothing else in the lens knows it exists, so
	# neither release() nor restore_world() could ever bring it back, and the
	# player would be left with a permanent invisible hole they did not choose.
	# Reversibility is a child-safety requirement of this mechanic, not an
	# optimisation.
	# A destination prop may itself be a fragment committed by an earlier
	# placement, because placed seeings stay cuttable. Those are freed outright
	# rather than hidden and tracked: they are generated geometry that has now
	# been superseded, and resurrecting one as though it were an authored prop
	# would put geometry back that the authored world never contained.
	var displaced: Array[Node3D] = []
	for source in result["sources"]:
		if not (source is Node3D):
			continue
		if _forget_committed(source):
			source.queue_free()
			continue
		_set_prop_active(source, false)
		if not displaced.has(source):
			displaced.append(source)

	# Un-parent into the world. reparent(keep_global_transform) bakes the
	# frustum-relative pose into world space — this is the whole trick.
	var target := get_tree().current_scene
	var placed := _held.size()
	for fragment in _held:
		if target != null:
			fragment.reparent(target, true)
		# Visible and solid again: a placed seeing is part of the level, and
		# the player must be able to stand on what they put there.
		_set_fragment_active(fragment, true)
		# The seeing is now runtime geometry standing in the world, so it is
		# committed for the same reason the offcuts are.
		_track_committed(fragment)
	_held.clear()

	# The capture-site originals come back: the player moved a seeing, they did
	# not destroy the place they took it from.
	#
	# A prop cut at BOTH ends is skipped. Restoring it here would put the whole
	# prop back on top of the offcuts that were just placed for it, so the
	# player would see the destination prop and its own fragments occupying the
	# same space.
	for source in _suppressed:
		if is_instance_valid(source) and not displaced.has(source):
			_set_prop_active(source, true)
	_suppressed.clear()

	# Carried forward so the displaced props remain accounted for and can be
	# restored by restore_world().
	_displaced.append_array(displaced)

	_held_roll_steps = 0
	_seeings_left = mini(_seeings_left + 1, MAX_SEEINGS)

	# Same ordering as capture(): the transaction is finished before anyone is
	# told about it, so a handler may immediately capture again.
	_busy = false
	seeings_remaining_changed.emit(_seeings_left)
	seeing_placed.emit(placed)
	return true


# Put the held seeing back where it came from, restoring the world untouched.
# Every capture must be reversible — a child who frames the wrong thing should
# never be stuck with a hole they cannot undo.
func release() -> void:
	# Refused rather than run: releasing halfway through a capture would free
	# fragments the capture is still adding to `_held`.
	if _busy:
		capture_refused.emit("Wait — the lens is still working.")
		return
	# Nothing held means nothing to put back, and a refund here would mint a
	# seeing out of an empty gesture (Escape pressed twice).
	if not is_holding() and _suppressed.is_empty():
		return

	_busy = true

	for fragment in _held:
		if is_instance_valid(fragment):
			fragment.queue_free()
	_held.clear()

	for source in _suppressed:
		if is_instance_valid(source):
			_set_prop_active(source, true)
	_suppressed.clear()

	# Refunded: putting a seeing back must cost nothing, or cancelling would
	# quietly burn the resource and punish a child for changing their mind.
	_held_roll_steps = 0
	_seeings_left = mini(_seeings_left + 1, MAX_SEEINGS)

	_busy = false
	seeings_remaining_changed.emit(_seeings_left)


# How many props are currently hidden because a seeing was placed over them.
# Public so a test can assert placement never hides a prop the lens has lost
# track of.
func displaced_count() -> int:
	return _displaced.size()


# How many runtime fragments this lens has standing in the world. Public for
# tests and diagnostics only — nothing in the game should branch on it.
func committed_fragment_count() -> int:
	_prune_committed()
	return _committed.size()


# Record a runtime fragment now standing in the world, ignoring duplicates.
func _track_committed(fragment: Node3D) -> void:
	if fragment == null or _committed.has(fragment):
		return
	_committed.append(fragment)


# Drop `node` from the committed set. Returns whether it was there — which is
# how a caller distinguishes generated geometry from an authored prop.
func _forget_committed(node: Node3D) -> bool:
	var index := _committed.find(node)
	if index == -1:
		return false
	_committed.remove_at(index)
	return true


# Fragments can be freed by other paths (a destination cut supersedes them, a
# scene reload takes them). Stale entries must not be counted or double-freed.
func _prune_committed() -> void:
	var live: Array[Node3D] = []
	for fragment in _committed:
		if is_instance_valid(fragment):
			live.append(fragment)
	_committed = live


# Put the world back exactly as it was found.
#
# This is the "undo everything" the child-safety requirement asks for. A player
# who has rearranged a room with several placements needs one way back to the
# authored world that does not depend on remembering what they did — and a
# facilitator resetting between children needs the same.
#
# Restoring means BOTH halves, or the claim is false:
#   - delete every runtime fragment this lens committed, held or placed, since
#     none of them exist in the authored world; and
#   - un-hide the authored props that were suppressed at either end.
# Un-hiding alone would leave the generated geometry sitting on top of the
# originals it replaced.
func restore_world() -> void:
	if _busy:
		capture_refused.emit("Wait — the lens is still working.")
		return

	_busy = true

	# The held seeing is committed geometry too; it just has not been put down.
	for fragment in _held:
		_track_committed(fragment)
	_held.clear()

	for fragment in _committed:
		if is_instance_valid(fragment):
			fragment.queue_free()
	_committed.clear()

	# Only authored props are un-hidden. A committed fragment can never appear
	# here: `place()` removes one from `_committed` and frees it rather than
	# adding it to `_displaced`.
	for source in _suppressed + _displaced:
		if is_instance_valid(source):
			_set_prop_active(source, true)
	_suppressed.clear()
	_displaced.clear()

	_held_roll_steps = 0
	_seeings_left = MAX_SEEINGS

	_busy = false
	seeings_remaining_changed.emit(_seeings_left)


func seeings_left() -> int:
	return _seeings_left


# Whether a capture/place/release is mid-flight. Public so the controller can
# swallow input rather than firing calls it knows will be refused, and so a test
# can assert the flag is not left stuck after any outcome.
func is_busy() -> bool:
	return _busy


func roll_steps() -> int:
	return _held_roll_steps


# Turn the held seeing about the view axis, in 30-degree steps.
#
# The original rotates the held film to solve orientation puzzles. The whole
# seeing is turned as one rigid object about the capture point — rotating each
# fragment about its own centre would tear a multi-fragment seeing apart.
func rotate_held(steps: int = -1) -> bool:
	if not is_holding():
		capture_refused.emit("You are not carrying anything to turn.")
		return false
	if capture_point == null or camera == null:
		return false

	_held_roll_steps = wrapi(_held_roll_steps + steps, 0, 12)

	var pivot := capture_point.global_position
	var axis := -camera.global_transform.basis.z.normalized()
	var angle := deg_to_rad(30.0 * float(steps))

	for fragment in _held:
		if not is_instance_valid(fragment):
			continue
		var offset := fragment.global_position - pivot
		fragment.global_transform = Transform3D(
			Basis(axis, angle) * fragment.global_transform.basis,
			pivot + offset.rotated(axis, angle))
	return true


# Show or hide one cut fragment along with its collision.
static func _set_fragment_active(fragment: Node3D, active: bool) -> void:
	if fragment == null:
		return
	fragment.visible = active
	_set_shapes_disabled(fragment, not active)


# Hide or show a prop along with its collision, so a hidden prop cannot still
# be walked into. Collision shapes are disabled rather than removed so the
# prop can be restored exactly.
static func _set_prop_active(prop: Node3D, active: bool) -> void:
	prop.visible = active
	_set_shapes_disabled(prop, not active)
	if prop is CollisionObject3D:
		prop.process_mode = \
			Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


# Toggle EVERY CollisionShape3D at or under `node`, however deeply nested.
#
# Recursive, not one level. An imported .glb prop is a whole subtree — the
# StaticBody3D Godot generates for a mesh sits under the mesh node, which sits
# under the scene root, so a direct-children-only walk found no shapes at all
# and left the prop solid after it had visibly vanished. The player then
# collided with a hole. Fragments built by the cutter are shallow and are
# handled by the same walk.
#
# Set directly, not deferred. A deferred disable leaves the shape live until the
# next frame, and a freshly captured seeing spends that frame inside the
# player's own capsule — long enough to shove them. These calls happen from
# input handling, not from inside a physics callback, so a direct write is safe.
static func _set_shapes_disabled(node: Node, disabled: bool) -> void:
	if node == null:
		return
	if node is CollisionShape3D:
		node.disabled = disabled
	for child in node.get_children():
		_set_shapes_disabled(child, disabled)
