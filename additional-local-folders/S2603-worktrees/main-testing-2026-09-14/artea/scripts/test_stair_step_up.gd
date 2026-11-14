extends SceneTree

# Physics regression for new_player.gd's _try_step_up().
#
# The castle spiral (hub_castle_stairs.gd) builds treads that deliberately
# OVERLAP along the arc: centres sit ~0.90 m apart while each tread box is
# 1.6 m deep. That means the next plateau begins only ~0.19 m ahead of the
# riser the player is standing against, but the step probe reaches
# STEP_FORWARD_PROBE (0.45 m) forward.
#
# The old code treated any contact during that forward probe as "a wall, not a
# step" and bailed out, so the raised capsule — which always grazes the
# FOLLOWING riser on an overlapping flight — could never complete a step. The
# stair was unclimbable by arithmetic, top to bottom, and every tight step
# around the castle failed the same way.
#
# This builds an isolated overlapping flight with the real numbers and walks a
# real player body up it, so the fix is verified against the physics server
# rather than against the geometry maths alone.

const PLAYER := preload("res://scenes/entities/NewPlayer.tscn")

const STEP_RISE := 0.3
const STEP_SPACING := 0.897   # matches the spiral's arc distance between treads
const TREAD_DEPTH := 1.6      # deliberately > spacing, so treads overlap
const TREAD_WIDTH := 3.8
const TREAD_THICKNESS := 0.34
const STEP_COUNT := 12

var _failures: Array[String] = []


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _build_flight(root: Node3D) -> void:
	# A ground slab to stand on before the first riser.
	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(8.0, 1.0, 8.0)
	ground_shape.shape = ground_box
	ground.add_child(ground_shape)
	root.add_child(ground)
	ground.global_position = Vector3(0.0, -0.5, -2.0)

	for i in STEP_COUNT:
		var tread := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(TREAD_WIDTH, TREAD_THICKNESS, TREAD_DEPTH)
		shape.shape = box
		tread.add_child(shape)
		root.add_child(tread)
		# Marching along +Z, rising in Y — the flattened equivalent of the spiral.
		tread.global_position = Vector3(
			0.0,
			STEP_RISE * float(i),
			STEP_SPACING * float(i))


func _run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	_build_flight(root)

	var player: CharacterBody3D = PLAYER.instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process_input(false)
	# Start on the ground slab, just short of the first riser.
	player.global_position = Vector3(0.0, 1.2, -1.0)

	# Settle with the same explicit motion loop used by the traversal below. The
	# packed controller is disabled so it cannot apply a second move_and_slide().
	for _i in 120:
		player.velocity.y -= 20.0 * (1.0 / 60.0)
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			break

	var start_y := player.global_position.y
	var start_z := player.global_position.z

	# Drive the body forward for a few seconds of simulated walking. The real
	# controller reads Input, so push the body directly and call the same
	# move/step pipeline _physics_process would.
	var walked_frames := 0
	for _i in 600:
		player.velocity.x = 0.0
		player.velocity.z = 5.0
		player.velocity.y -= 20.0 * (1.0 / 60.0)

		var was_on_floor := player.is_on_floor()
		var pre := player.global_position
		var intended := player.velocity
		player.move_and_slide()
		player._try_step_up(was_on_floor, pre, intended, 1.0 / 60.0)
		walked_frames += 1
		await physics_frame
		# Stop on the last tread. The former test kept walking far beyond the
		# isolated flight, fell into empty space, and reported that fall as a stair
		# failure even after the player had climbed successfully.
		if player.global_position.z >= STEP_SPACING * float(STEP_COUNT - 1):
			break

	var climbed := player.global_position.y - start_y
	var advanced := player.global_position.z - start_z
	var top_y := STEP_RISE * float(STEP_COUNT - 1)

	print("start y=%.2f z=%.2f -> end y=%.2f z=%.2f (climbed %.2f, advanced %.2f)" % [
		start_y, start_z, player.global_position.y, player.global_position.z,
		climbed, advanced])
	print("flight top tread surface y=%.2f" % (top_y + TREAD_THICKNESS * 0.5))

	# The decisive assertion: the body must actually gain height. Before the fix
	# it stalled against the first riser and climbed ~0.
	if climbed < top_y * 0.75:
		_fail("player failed to climb the overlapping flight: gained only %.2f m of %.2f m"
			% [climbed, top_y])

	if advanced < STEP_SPACING * float(STEP_COUNT) * 0.6:
		_fail("player stalled horizontally: advanced only %.2f m" % advanced)

	if _failures.is_empty():
		print("PASS: overlapping stair flight is climbable")
	else:
		print("FAILURES: %d" % _failures.size())

	quit(0 if _failures.is_empty() else 1)


func _init() -> void:
	call_deferred("_run")
