# Lets the player actually ride the trains.
#
# The rails and sky islands exist; this is the thing that connects them. The
# player walks onto a castle station platform, a prompt appears, and pressing
# accept boards the train. The player is carried along the rail curve up to
# the island and set down on its platform, free to walk again.
#
# Mouse-look stays live for the whole ride: the camera keeps following the
# player as it always does, so looking around while travelling costs nothing
# extra and never fights the ride.
#
# Physics is suspended rather than fought. The player is a CharacterBody3D
# with gravity in _physics_process; leaving that running during a ride would
# drag them off the train every frame, so boarding disables their physics
# process and the ride drives global_position directly.
extends Node3D

# How long a ride takes, castle to island. Slow enough to see the world
# from above, short enough not to become a loading screen.
const RIDE_SECONDS := 7.0

# How close the player must be to a station to board.
const BOARD_RADIUS := 7.0

# Where the player stands relative to the train while riding.
const RIDE_OFFSET := Vector3(0.0, 2.2, 0.0)

var _rail: Node3D = null
var _isles: Node3D = null
var _player: CharacterBody3D = null

var _riding := false
var _ride_target := ""

# Station markers, keyed by line id: the castle-end boarding point.
var _stations: Dictionary = {}

var _prompt: Label = null
var _near_line := ""


func _ready() -> void:
	_rail = get_parent().get_node_or_null("SkyRail")
	_isles = get_parent().get_node_or_null("SkyIsles")
	_player = _find_player()

	if _rail == null:
		push_warning("hub_train_rider: SkyRail not found, riding disabled")
		return

	# The rails build their curves a couple of frames into the scene's life,
	# and the islands they query build before that. Poll for the curves
	# rather than guessing a frame count — an early _build_stations() reads
	# an empty table and leaves the player unable to board anything.
	for attempt in 20:
		await get_tree().process_frame
		if _rail.has_method("has_line") and _rail.call("has_line", "mindspark"):
			break

	_build_stations()
	_build_prompt()

	if _stations.is_empty():
		push_warning("hub_train_rider: no rail curves found, boarding disabled")


func _process(_delta: float) -> void:
	if _riding or _player == null:
		return

	_near_line = _nearest_station()

	if _prompt != null:
		if _near_line == "":
			_prompt.visible = false
		else:
			_prompt.visible = true
			_prompt.text = "Press Enter to ride to %s" % _line_label(_near_line)


func _unhandled_input(event: InputEvent) -> void:
	if _riding or _near_line == "":
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		board(_near_line)


# Public so a future station prop, or Milo, can put the player on a train.
func board(line_id: String) -> void:
	if _riding or _player == null or _rail == null:
		return
	if not _rail.has_method("get_curve"):
		return

	var curve: Curve3D = _rail.call("get_curve", line_id)
	if curve == null:
		push_warning("hub_train_rider: no curve for line '%s'" % line_id)
		return

	_riding = true
	_ride_target = line_id
	if _prompt != null:
		_prompt.visible = false

	# Suspend the player's own movement/gravity for the ride. Their camera
	# is a child and keeps running, so mouse-look stays live throughout.
	_player.set_physics_process(false)
	_player.velocity = Vector3.ZERO

	var train: Node3D = null
	if _rail.has_method("get_train"):
		train = _rail.call("get_train", line_id)

	var length := curve.get_baked_length()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(t: float) -> void: _ride_step(curve, length, t, train),
		0.0, 1.0, RIDE_SECONDS)
	await tween.finished

	_arrive(line_id)


# Moves the player (and the line's train, so they travel together) along the
# curve. Called every tween step.
func _ride_step(curve: Curve3D, length: float, t: float, train: Node3D) -> void:
	if _player == null:
		return
	var pos := curve.sample_baked(clampf(t, 0.0, 1.0) * length)
	_player.global_position = pos + RIDE_OFFSET
	if train != null:
		train.global_position = pos


# Sets the player down on the destination island's platform and gives
# control back.
func _arrive(line_id: String) -> void:
	var isle_id := _isle_for_line(line_id)
	var landing := Vector3.ZERO

	if _isles != null and _isles.has_method("get_platform_pos"):
		landing = _isles.call("get_platform_pos", isle_id)

	if landing != Vector3.ZERO and _player != null:
		# A little above the deck so the player settles onto it rather than
		# spawning inside the collision box.
		_player.global_position = landing + Vector3(0.0, 2.0, 0.0)

	if _player != null:
		_player.velocity = Vector3.ZERO
		_player.set_physics_process(true)

	_riding = false
	_ride_target = ""


# --- setup -------------------------------------------------------------

# Boarding points sit at the castle end of each line — t=0 on the curve,
# which hub_skyrail builds from the castle outward.
func _build_stations() -> void:
	if not _rail.has_method("get_curve"):
		return

	# All three lines share the castle end, so a boarding point placed exactly
	# on the curve start would be identical for every line and the player
	# could never choose a destination. Fan them out around that point into
	# three distinct spots the player walks between.
	var fan := {
		"mindspark": Vector3(6.0, 0.0, -6.0),
		"heartmelody": Vector3(8.0, 0.0, 4.0),
		"creatorslight": Vector3(-2.0, 0.0, 8.0),
	}

	for line_id in ["mindspark", "heartmelody", "creatorslight"]:
		var curve: Curve3D = _rail.call("get_curve", line_id)
		if curve == null:
			continue
		# Boarding happens at the castle end of the line, which hub_skyrail
		# deliberately keeps down near the village floor so the player can
		# walk to it. Y is dropped from the comparison in _nearest_station,
		# so the stored height is informational only.
		var offset: Vector3 = fan[line_id]
		_stations[line_id] = curve.sample_baked(0.0) + offset


# A small on-screen prompt. Deliberately a plain Label on its own
# CanvasLayer rather than a themed UI: this is a traversal affordance, and
# the hub's HUD scenes are authored elsewhere.
func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.name = "RidePrompt"
	add_child(layer)

	_prompt = Label.new()
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 0.85
	_prompt.anchor_bottom = 0.85
	_prompt.offset_left = -220.0
	_prompt.offset_right = 220.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(1, 1, 1))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.visible = false
	layer.add_child(_prompt)


# --- lookups -----------------------------------------------------------

# Nearest station within BOARD_RADIUS, compared on the horizontal plane so
# the rail's height above the village never blocks boarding.
func _nearest_station() -> String:
	if _player == null:
		return ""

	var player_flat := Vector3(
		_player.global_position.x, 0.0, _player.global_position.z)

	var best := ""
	var best_dist := BOARD_RADIUS

	for line_id in _stations:
		var station: Vector3 = _stations[line_id]
		var dist := player_flat.distance_to(station)
		if dist < best_dist:
			best_dist = dist
			best = line_id

	return best


func _isle_for_line(line_id: String) -> String:
	match line_id:
		"mindspark": return "mind"
		"heartmelody": return "heart"
		"creatorslight": return "creator"
	return ""


func _line_label(line_id: String) -> String:
	match line_id:
		"mindspark": return "Mind Spark"
		"heartmelody": return "Heart Melody"
		"creatorslight": return "Creator's Light"
	return line_id


func _find_player() -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p is CharacterBody3D:
			return p
	# The hub authors the player as "NewPlayer"; fall back to that if the
	# group is ever dropped.
	var node := get_parent().get_node_or_null("NewPlayer")
	return node as CharacterBody3D
