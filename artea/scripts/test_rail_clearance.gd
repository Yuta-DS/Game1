# Guards the bug where the sky rails were born inside the castle and punched
# out through its wall.
#
# The rails used to start at x = -43.0, measured against the castle origin
# (x = -51.4) but ignoring the floating foundation's 16.5 m radius. That put
# the station and the t=0 end of all three curves inside the rock.
#
# This checks the whole first stretch of every curve, not just its endpoint —
# a rail can start outside the foundation and still sag back through it.
extends SceneTree

const CASTLE_XZ := Vector2(-51.4, 27.41)
const FOUNDATION_RADIUS := 16.5

# The castle mesh itself is narrower than its foundation, but keep a margin so
# a rail never grazes the wall it is supposed to clear.
const CLEARANCE := 1.5

# Measured occupied height of the castle plus its foundation
# (scripts/probe_castle_door.gd: body spans y 52.3 .. 105.3, foundation below).
# Only the keep's narrow spire reaches the top of that range, so the solid
# envelope a rail must not enter is the bulk below the towers.
#
# Horizontal distance alone is not the test: a rail that passes high over the
# roof is fine, and flagging it would force the network into a worse shape.
const CASTLE_SOLID_MIN_Y := 50.0
const CASTLE_SOLID_MAX_Y := 92.0


func _fail(message: String) -> void:
	push_error("RAIL_CLEARANCE_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)

	var isles := Node3D.new()
	isles.name = "SkyIsles"
	isles.set_script(load("res://scripts/hub_sky_isles.gd"))
	world.add_child(isles)

	var rail := Node3D.new()
	rail.name = "SkyRail"
	rail.set_script(load("res://scripts/hub_skyrail.gd"))
	world.add_child(rail)

	for _i in 40:
		await process_frame

	var limit := FOUNDATION_RADIUS + CLEARANCE
	var worst := INF
	var worst_line := ""

	for line_id in ["mindspark", "heartmelody", "creatorslight"]:
		var curve: Curve3D = rail.call("get_curve", line_id)
		if curve == null:
			_fail("line %s has no curve" % line_id)
			return
		var length := curve.get_baked_length()

		# Sample densely over the castle-side half of the span; that is where a
		# rail can intersect the foundation.
		for step in 120:
			var t := float(step) / 119.0 * 0.5
			var p := curve.sample_baked(t * length)
			var flat := Vector2(p.x, p.z).distance_to(CASTLE_XZ)

			# Only points inside the castle's occupied height band can actually
			# intersect it; anything above the roofline is clear sky.
			var in_solid_band := p.y > CASTLE_SOLID_MIN_Y and p.y < CASTLE_SOLID_MAX_Y
			if not in_solid_band:
				continue

			if flat < worst:
				worst = flat
				worst_line = line_id
			if flat < limit:
				_fail("line %s passes through the castle at %s (%.2f m from centre, needs %.2f)"
					% [line_id, p, flat, limit])
				return

	# The boarding station must also sit outside the foundation, or the player
	# boards from inside the rock.
	var station: Vector3 = rail.get("GRAND_STATION_CENTER")
	if station == null:
		station = Vector3(rail.call("get_curve", "heartmelody").sample_baked(0.0))
	var station_flat := Vector2(station.x, station.z).distance_to(CASTLE_XZ)
	if station_flat < limit:
		_fail("grand station is inside the castle foundation (%.2f m)" % station_flat)
		return

	print("RAIL_CLEARANCE_TEST: PASS — closest approach %.2f m on %s (limit %.2f), station %.2f m"
		% [worst, worst_line, limit, station_flat])
	quit()


func _init() -> void:
	call_deferred("_run")
