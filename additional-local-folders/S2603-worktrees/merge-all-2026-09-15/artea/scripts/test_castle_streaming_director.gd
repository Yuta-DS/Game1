extends SceneTree

# Regression test for world_streaming_director.gd.
#
# The director hides distant parts of the castle's floating world by distance.
# It cached each cell's bounding box once, and decided whether a cell could
# move by looking for a script inside that cell's own subtree.
#
# The Crown Line train breaks that assumption: RainbowGalaxyTrain carries no
# script of its own, it is driven by art_castle_story_railway.gd on an
# ANCESTOR node assigning _train.transform. So the train's cells were treated
# as static and kept the box from where the train was parked. Riding it away,
# the distance was measured to that stale box, it grew past the cull threshold,
# and the train was hidden out from under the player mid-ride.
#
# Anything moved by an ancestor's script hits this, so the test drives the real
# train rather than a synthetic stand-in.

const TARGET := "res://scenes/art_gallery_3d_inprogress.tscn"


func _initialize() -> void:
	var failures: Array[String] = []
	var scene := (load(TARGET) as PackedScene).instantiate()
	root.add_child(scene)
	for _i in 30:
		await process_frame

	var director := scene.find_child("WorldStreamingDirector", true, false)
	if director == null:
		_finish(["no WorldStreamingDirector in the castle scene"])
		return

	var railway := scene.find_child("StoryCrownRailway", true, false) as Node3D
	var train := railway.get_node_or_null("RainbowGalaxyTrain") as Node3D \
		if railway != null else null
	if train == null:
		_finish(["no RainbowGalaxyTrain under StoryCrownRailway"])
		return

	var player := scene.get_node_or_null("Player3D") as Node3D
	if player == null:
		_finish(["no Player3D"])
		return

	# Board and drive, which is what a player does. The rider's position is
	# driven from the train by the railway, so the player travels with it.
	# board_as_driver() requires the player to actually be standing at the
	# driver's door, so put them there first.
	player.global_position = railway.call("get_driver_interaction_position")
	await process_frame
	if not bool(railway.call("board_as_driver")):
		_finish(["board_as_driver() refused"])
		return

	# RainbowGalaxyTrain holds ~975 visual nodes, more than the director's cell
	# budget, so it splits INSIDE the train: the cells are the train's own
	# carriages and fittings. The train node itself therefore stays visible
	# while its parts are culled, and counting visible descendants is the only
	# assertion that catches that.
	var parked := _visible_parts(train)
	print("train has %d visible parts while parked" % parked)
	if parked == 0:
		_finish(["train has no visible parts even while parked"])
		return

	var start := train.global_position
	var travelled := 0.0
	var worst_parts := parked
	var worst_at := Vector3.ZERO
	# Long enough to leave the starting station well behind: the cull threshold
	# that was being crossed is a few hundred metres.
	for _step in 900:
		railway.call("drive_manual", 1.0, 1.0 / 60.0)
		await process_frame
		travelled = maxf(travelled, start.distance_to(train.global_position))
		var parts := _visible_parts(train)
		if parts < worst_parts:
			worst_parts = parts
			worst_at = train.global_position

	print("train travelled %.0f m; visible parts fell to %d of %d" % [
		travelled, worst_parts, parked])
	if travelled < 200.0:
		failures.append("train only moved %.0f m - the test never left the station, so it proves nothing" % travelled)
	# Some flicker of a part or two would be tolerable; losing most of the train
	# is the reported bug.
	if worst_parts < parked / 2:
		failures.append("train lost most of itself while being ridden: %d of %d parts visible, %.0f m from start"
			% [worst_parts, parked, start.distance_to(worst_at)])
	var ended_with := _visible_parts(train)
	if ended_with < parked / 2:
		failures.append("train ended the ride with only %d of %d parts visible" % [ended_with, parked])

	# The player rides the train, so it must still be visible from where they
	# actually are, not from where it was parked.
	var distance := player.global_position.distance_to(train.global_position)
	if distance > 60.0:
		failures.append("player is %.0f m from the train - the ride did not carry them" % distance)

	_finish(failures)


## Visible VisualInstance3D descendants of `node`, which is what the player
## actually sees of the train.
func _visible_parts(node: Node3D) -> int:
	var total := 0
	var stack: Array = [node]
	while stack.size() > 0:
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)
		if current is VisualInstance3D and not (current is Light3D) 				and (current as Node3D).is_visible_in_tree():
			total += 1
	return total


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("CASTLE_STREAMING_DIRECTOR: PASS — the ridden train stays visible while it moves")
		quit()
		return
	for failure in failures:
		push_error("CASTLE_STREAMING_DIRECTOR: %s" % failure)
	quit(1)
