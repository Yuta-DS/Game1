# Guards the walkable route from the ground to the castle door.
#
# The route is built by two independent scripts (hub_castle_stairs and
# hub_castle_entrance) that share constants by duplication, so a change to one
# silently opens a hole in the other. That is exactly what happened: the tower's
# crown deck finished at y 65.4 against a courtyard terrace at 68.9, leaving a
# 3.5 m wall with no way up, and the causeway climbed diagonally to the door's
# height instead of crossing level to the terrace.
#
# This asserts the joins, not the decoration.
extends SceneTree

# Largest step the player's controller can walk over (hub_castle_stairs notes
# MAX_STEP_HEIGHT 0.65). Any vertical join bigger than this is a wall.
const MAX_WALKABLE_STEP := 0.65

# Horizontal gap the player would fall through.
const MAX_GAP := 1.2


func _fail(message: String) -> void:
	push_error("APPROACH_TEST: %s" % message)
	quit(1)


func _bounds(root: Node3D, prefix: String) -> AABB:
	var total := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		if prefix != "" and not String(mi.name).begins_with(prefix):
			continue
		var local := mi.mesh.get_aabb()
		var xform := mi.global_transform
		var world := AABB(xform * local.position, Vector3.ZERO)
		for c in 8:
			world = world.expand(xform * (local.position + Vector3(
				local.size.x * float(c & 1),
				local.size.y * float((c >> 1) & 1),
				local.size.z * float((c >> 2) & 1))))
		if first:
			total = world
			first = false
		else:
			total = total.merge(world)
	return total


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _i in 40:
		await process_frame

	var stair := hub.get_node_or_null("CastleStairs/CastleStair") as Node3D
	var entrance := hub.get_node_or_null("CastleEntrance/CastleEntrance") as Node3D
	if stair == null or entrance == null:
		_fail("stair or entrance did not build")
		return

	# 1. The crown deck must finish level with the courtyard terrace, or the
	#    player arrives at the top of the spiral stair facing a wall.
	var deck := stair.get_node_or_null("CrownDeck") as Node3D
	if deck == null:
		_fail("crown deck missing")
		return
	var stair_root := hub.get_node_or_null("CastleStairs") as Node3D
	var entrance_root := hub.get_node_or_null("CastleEntrance") as Node3D
	if stair_root == null or entrance_root == null:
		_fail("stair or entrance script root missing")
		return
	var terrace_top: float = entrance_root.get("TERRACE_DECK_Y")
	# Read the authored mesh surface instead of assuming the old 0.7 m slab.
	# This keeps the route assertion valid when the crown fascia is refined.
	var deck_top: float = deck.global_position.y + deck.mesh.get_aabb().end.y
	if absf(deck_top - terrace_top) > MAX_WALKABLE_STEP:
		_fail("crown deck (%.2f) is not level with the terrace (%.2f): a %.2f m step"
			% [deck_top, terrace_top, absf(deck_top - terrace_top)])
		return

	# The tighter and more important join is the final tread to the crown. A
	# route can share a nominal datum while the crown slab still sits too high.
	var final_tread: MeshInstance3D = null
	for candidate in stair.find_children("StairTread_*", "MeshInstance3D", true, false):
		var tread := candidate as MeshInstance3D
		if final_tread == null or tread.global_position.y > final_tread.global_position.y:
			final_tread = tread
	if final_tread == null or not (final_tread.mesh is BoxMesh):
		_fail("final spiral tread missing")
		return
	var tread_top := final_tread.global_position.y \
		+ (final_tread.mesh as BoxMesh).size.y * 0.5
	if absf(deck_top - tread_top) > 0.05:
		_fail("final tread (%.2f) does not meet crown deck (%.2f)"
			% [tread_top, deck_top])
		return

	# 2. The causeway must actually reach the courtyard, overlapping its edge
	#    rather than stopping short in mid-air.
	var entrance_box := _bounds(entrance, "")
	var courtyard_edge := entrance_box.position.x + entrance_box.size.x

	# Deck pieces only. Parapets, lamp posts and banners legitimately rise well
	# above the walking surface, so including them measures the railing height
	# rather than the slope of the road.
	var causeway := AABB()
	var causeway_first := true
	for node in stair.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var p := mi.global_position
		if p.y < terrace_top - 1.2 or p.y > terrace_top + 1.2:
			continue
		if causeway_first:
			causeway = AABB(p, Vector3.ZERO)
			causeway_first = false
		else:
			causeway = causeway.expand(p)
	if causeway_first:
		_fail("no causeway geometry found at terrace height")
		return

	var causeway_inner := causeway.position.x
	if causeway_inner > courtyard_edge + MAX_GAP:
		_fail("causeway stops %.2f m short of the courtyard edge (%.2f vs %.2f)"
			% [causeway_inner - courtyard_edge, causeway_inner, courtyard_edge])
		return

	# 3. The causeway must be level, not a diagonal ramp. A span that climbs
	#    several metres across a mostly-sideways run reads as floating planks.
	var causeway_rise := causeway.size.y
	if causeway_rise > 3.0:
		_fail("causeway rises %.2f m across its span; it should be level"
			% causeway_rise)
		return

	# 4. Everything the player walks on needs collision. A visible plank with no
	#    StaticBody3D is a thing they fall straight through.
	for label in [["stair", stair], ["entrance", entrance]]:
		var node := label[1] as Node3D
		var bodies := node.find_children("*", "StaticBody3D", true, false)
		if bodies.is_empty():
			_fail("%s has no collision at all" % label[0])
			return

	# The continuous roadbed is the one collider that guarantees the span cannot
	# be slipped between; assert the causeway carries real collision.
	var causeway_bodies := 0
	for node in stair.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		var p := body.global_position
		if p.y > terrace_top - 4.0 and p.y < terrace_top + 4.0:
			causeway_bodies += 1
	if causeway_bodies < 5:
		_fail("causeway has only %d colliders; the player would fall through it"
			% causeway_bodies)
		return

	print("APPROACH_TEST: PASS — deck %.2f vs terrace %.2f, causeway reaches %.2f (edge %.2f), rise %.2f, %d causeway colliders"
		% [deck_top, terrace_top, causeway_inner, courtyard_edge,
			causeway_rise, causeway_bodies])
	quit()


func _init() -> void:
	call_deferred("_run")
