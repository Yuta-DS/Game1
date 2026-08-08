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
const BOARD_RADIUS := 3.8

# Where the player stands relative to the train while riding.
const RIDE_OFFSET := Vector3(0.0, 2.2, 0.0)

var _rail: Node3D = null
var _isles: Node3D = null
var _player: CharacterBody3D = null

var _riding := false
var _ride_target := ""

# Station markers keyed by a unique station id. Each record stores its line,
# direction and physical boarding point so rides work both out and back.
var _stations: Dictionary = {}

var _prompt: Label = null
var _near_station := ""


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

	_near_station = _nearest_station()

	if _prompt != null:
		if _near_station == "":
			_prompt.visible = false
		else:
			var station: Dictionary = _stations[_near_station]
			_prompt.visible = true
			_prompt.text = "Press Enter / Space to ride to %s" % station["destination"]


func _unhandled_input(event: InputEvent) -> void:
	if _riding or _near_station == "":
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		var station: Dictionary = _stations[_near_station]
		board(station["line_id"], station["forward"])
		get_viewport().set_input_as_handled()


# Public so a future station prop, or Milo, can put the player on a train.
func board(line_id: String, forward := true) -> void:
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
	if _rail.has_method("set_train_riding"):
		_rail.call("set_train_riding", line_id, true)

	var train: Node3D = null
	if _rail.has_method("get_train"):
		train = _rail.call("get_train", line_id)

	var length := curve.get_baked_length()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(t: float) -> void: _ride_step(curve, length, t, train, forward),
		0.0, 1.0, RIDE_SECONDS)
	await tween.finished

	_arrive(line_id, forward)


# Moves the player (and the line's train, so they travel together) along the
# curve. Called every tween step.
func _ride_step(curve: Curve3D, length: float, t: float, train: Node3D,
		forward: bool) -> void:
	if _player == null:
		return
	var progress := t if forward else 1.0 - t
	if _rail.has_method("place_train"):
		_rail.call("place_train", _ride_target, progress, forward)
	else:
		var pos := curve.sample_baked(clampf(progress, 0.0, 1.0) * length)
		if train != null:
			train.global_position = pos
	if train != null:
		_player.global_position = train.global_position + RIDE_OFFSET
	else:
		var fallback_pos := curve.sample_baked(clampf(progress, 0.0, 1.0) * length)
		_player.global_position = fallback_pos + RIDE_OFFSET


# Sets the player down on the destination island's platform and gives
# control back.
func _arrive(line_id: String, forward: bool) -> void:
	var isle_id := _isle_for_line(line_id)
	var landing := Vector3.ZERO

	if forward and _isles != null and _isles.has_method("get_platform_pos"):
		landing = _isles.call("get_platform_pos", isle_id)
	elif not forward:
		var home_key := "%s:out" % line_id
		if _stations.has(home_key):
			var home: Dictionary = _stations[home_key]
			landing = home["position"]

	if landing != Vector3.ZERO and _player != null:
		# A little above the deck so the player settles onto it rather than
		# spawning inside the collision box.
		_player.global_position = landing + Vector3(0.0, 2.0, 0.0)

	if _player != null:
		_player.velocity = Vector3.ZERO
		_player.set_physics_process(true)
	if _rail != null and _rail.has_method("set_train_riding"):
		_rail.call("set_train_riding", line_id, false, 1.0 if forward else 0.0)

	_riding = false
	_ride_target = ""


# --- setup -------------------------------------------------------------

# Boarding points sit at the castle end of each line — t=0 on the curve,
# which hub_skyrail builds from the castle outward.
func _build_stations() -> void:
	if not _rail.has_method("get_curve"):
		return

	for line_id in ["mindspark", "heartmelody", "creatorslight"]:
		var curve: Curve3D = _rail.call("get_curve", line_id)
		if curve == null:
			continue
		# Boarding happens at the castle end of the line, which hub_skyrail
		# deliberately keeps down near the village floor so the player can
		# walk to it. Y is dropped from the comparison in _nearest_station,
		# so the stored height is informational only.
		# Every rail now starts at its own physical dock in Grand Station, so the
		# visible train, rune pad and interaction point all occupy one place.
		var station: Vector3 = curve.sample_baked(0.0)
		var out_key := "%s:out" % line_id
		_stations[out_key] = {
			"line_id": line_id,
			"position": station,
			"forward": true,
			"destination": _line_label(line_id),
		}
		_build_station_marker(line_id, station, "TO %s" % _line_label(line_id))

		# Every island also gets a return pad. Without this the first successful
		# ride strands the player at the destination.
		if _isles != null and _isles.has_method("get_platform_pos"):
			var isle_station: Vector3 = _isles.call(
				"get_platform_pos", _isle_for_line(line_id))
			if isle_station != Vector3.ZERO:
				var back_key := "%s:back" % line_id
				_stations[back_key] = {
					"line_id": line_id,
					"position": isle_station,
					"forward": false,
					"destination": "Lumen Castle",
				}
				_build_station_marker(line_id, isle_station, "RETURN TO CASTLE")


# A visible brass-and-rune boarding pad. Previously station positions existed
# only in a Dictionary (and called a missing function), so players had nothing
# to walk toward and setup stopped with an invalid-method error.
func _build_station_marker(line_id: String, station: Vector3, caption: String) -> void:
	var marker := Node3D.new()
	marker.name = "Station_%s_%d" % [line_id, _stations.size()]
	add_child(marker)
	marker.global_position = station

	var color := _line_color(line_id)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.76, 0.52, 0.20)
	brass.metallic = 0.8
	brass.roughness = 0.3

	var glow := StandardMaterial3D.new()
	glow.albedo_color = color.darkened(0.15)
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 1.4
	glow.roughness = 0.25

	var pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 3.0
	pad_mesh.bottom_radius = 3.35
	pad_mesh.height = 0.42
	pad_mesh.radial_segments = 12
	pad.mesh = pad_mesh
	pad.material_override = brass
	marker.add_child(pad)

	var rune := MeshInstance3D.new()
	var rune_mesh := TorusMesh.new()
	rune_mesh.inner_radius = 2.05
	rune_mesh.outer_radius = 2.35
	rune_mesh.rings = 16
	rune_mesh.ring_segments = 5
	rune.mesh = rune_mesh
	rune.position.y = 0.27
	rune.material_override = glow
	marker.add_child(rune)

	for i in 3:
		var crystal := MeshInstance3D.new()
		var crystal_mesh := SphereMesh.new()
		crystal_mesh.radius = 0.24
		crystal_mesh.height = 0.75
		crystal_mesh.radial_segments = 6
		crystal_mesh.rings = 3
		crystal.mesh = crystal_mesh
		var angle := TAU * float(i) / 3.0
		crystal.position = Vector3(cos(angle) * 2.65, 0.85, sin(angle) * 2.65)
		crystal.material_override = glow
		marker.add_child(crystal)

	var label := Label3D.new()
	label.text = caption
	label.position = Vector3(0.0, 2.0, 0.0)
	label.font_size = 30
	label.outline_size = 7
	label.modulate = color.lightened(0.35)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.add_child(label)

	var lamp := OmniLight3D.new()
	lamp.position.y = 0.8
	lamp.light_color = color
	lamp.light_energy = 1.4
	lamp.omni_range = 8.0
	lamp.shadow_enabled = false
	marker.add_child(lamp)


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

	for station_id in _stations:
		var record: Dictionary = _stations[station_id]
		var station: Vector3 = record["position"]
		var station_flat := Vector3(station.x, 0.0, station.z)
		var dist := player_flat.distance_to(station_flat)
		if dist < best_dist:
			best_dist = dist
			best = station_id

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


func _line_color(line_id: String) -> Color:
	match line_id:
		"mindspark": return Color(0.42, 0.62, 1.00)
		"heartmelody": return Color(0.95, 0.55, 0.30)
		"creatorslight": return Color(1.00, 0.76, 0.30)
	return Color.WHITE


func _find_player() -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p is CharacterBody3D:
			return p
	# The hub authors the player as "NewPlayer"; fall back to that if the
	# group is ever dropped.
	var node := get_parent().get_node_or_null("NewPlayer")
	return node as CharacterBody3D
