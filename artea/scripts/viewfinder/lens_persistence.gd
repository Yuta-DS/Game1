# Save and restore what the player placed with the Lens of Seeing.
#
# A placed seeing is runtime-generated geometry with no source asset, so it
# cannot be saved by reference. `ViewFinder.txt` §R5 gives the two options:
# serialize the mesh data, or serialize the CUT and replay it on load. Replay
# is far cheaper — a placement is two transforms and a distance, about 100
# bytes, against tens of kilobytes of vertex data per fragment — and it stays
# correct if the cutter or the source props change.
#
# So a saved placement records WHERE THE PLAYER STOOD, twice:
#   - the pose the seeing was taken from
#   - the pose it was placed at
# Reloading re-runs capture at the first pose and place at the second.
#
# The consequence worth knowing: replay is only faithful while the underlying
# props are unchanged. If a prop moves between sessions the restored placement
# follows the prop, not the old pixels. That is the right behaviour for Artéa —
# the world is authored, not user-built — but it is a real difference from
# serializing the geometry.
extends RefCounted

const SAVE_PATH := "user://lens_placements.json"

# A placement replay drives the same public API the player does, so there is no
# second code path that could drift from the real one.


# Record of one completed placement.
static func make_record(taken_from: Transform3D, placed_at: Transform3D,
		roll_steps: int) -> Dictionary:
	return {
		"taken_from": _transform_to_array(taken_from),
		"placed_at": _transform_to_array(placed_at),
		"roll_steps": roll_steps,
	}


static func save_placements(placements: Array, path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("LensPersistence: could not write %s" % path)
		return false
	file.store_string(JSON.stringify({"placements": placements}))
	return true


static func load_placements(path: String = SAVE_PATH) -> Array:
	if not FileAccess.file_exists(path):
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("LensPersistence: could not read %s" % path)
		return []

	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		# A corrupt file must not take the world down with it. The player loses
		# their placements, not their session.
		push_error("LensPersistence: %s is corrupt, ignoring it" % path)
		return []

	var placements = data.get("placements", [])
	if typeof(placements) != TYPE_ARRAY:
		return []

	# Drop malformed entries rather than replaying garbage transforms into the
	# world, where a bad pose would cut a hole in an arbitrary place.
	var valid: Array = []
	for record in placements:
		if _is_valid_record(record):
			valid.append(record)
	return valid


static func clear(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# Replay every saved placement through the live lens.
#
# `mover` is called with the pose the player must be standing at; the caller
# owns how that happens (teleporting a player, moving a camera), because this
# has no business reaching into a scene's player rig.
static func replay(lens: Node, placements: Array, mover: Callable) -> int:
	if lens == null or not mover.is_valid():
		return 0

	var restored := 0
	for record in placements:
		if not _is_valid_record(record):
			continue

		mover.call(_array_to_transform(record["taken_from"]))
		if not lens.capture():
			# The prop that was framed is gone or changed. Skip this placement
			# rather than aborting the rest — one stale record must not cost
			# the player every other thing they placed.
			continue

		var steps := int(record.get("roll_steps", 0))
		if steps != 0:
			lens.rotate_held(steps)

		mover.call(_array_to_transform(record["placed_at"]))
		if lens.place():
			restored += 1
		else:
			# Could not put it down: drop it rather than leaving the lens
			# holding a seeing the player never asked for.
			lens.release()

	return restored


static func _is_valid_record(record) -> bool:
	if typeof(record) != TYPE_DICTIONARY:
		return false
	for key in ["taken_from", "placed_at"]:
		var value = record.get(key)
		if typeof(value) != TYPE_ARRAY or value.size() != 12:
			return false
		for n in value:
			if typeof(n) not in [TYPE_INT, TYPE_FLOAT]:
				return false
			# NaN and infinity survive a JSON round trip in some writers and
			# would place geometry nowhere.
			if not is_finite(float(n)):
				return false
	return true


# Transforms are stored as 12 plain floats rather than Godot's Transform3D
# string form, so the file stays readable and portable.
static func _transform_to_array(xf: Transform3D) -> Array:
	return [
		xf.basis.x.x, xf.basis.x.y, xf.basis.x.z,
		xf.basis.y.x, xf.basis.y.y, xf.basis.y.z,
		xf.basis.z.x, xf.basis.z.y, xf.basis.z.z,
		xf.origin.x, xf.origin.y, xf.origin.z,
	]


static func _array_to_transform(a: Array) -> Transform3D:
	return Transform3D(
		Basis(
			Vector3(a[0], a[1], a[2]),
			Vector3(a[3], a[4], a[5]),
			Vector3(a[6], a[7], a[8])),
		Vector3(a[9], a[10], a[11]))
