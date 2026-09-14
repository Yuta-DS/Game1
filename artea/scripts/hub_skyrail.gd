# Sky rails linking the castle to the three kingdom destinations.
#
# Ported from the Sky Isles prototype (scripts/sky_isles/rail_network.gd)
# onto the real hub. The prototype floated four islands in an empty sky;
# here the "islands" are the destinations that already exist in
# New_Hub_World.tscn, so this builds only the connective tissue — sagging
# rails, levitation anchors, and a train per line — above the terrain the
# player already walks.
#
# Runtime-authored, same convention as hub_magitech.gd: nothing is baked
# into New_Hub_World.tscn, so the whole network can be retuned or removed
# by deleting one node.
#
# Wakes with the journey like every other hub system: hub_awakening.gd calls
# apply_stage() on this node by name, so the rails read JourneyState.stage
# through that single orchestrator rather than polling it separately.
extends Node3D

const HubLightFade := preload("res://scripts/hub_light_fade.gd")

# Endpoints are the teleport Area3Ds already authored in the hub, so a rail
# always lands where the player actually travels. Coordinates read from
# New_Hub_World.tscn — the hub's ground sits at Y=15-20, not 0, so these are
# absolute world positions.
#
# The castle end is one Grand Station with three distinct docks. It sits on the
# terrace reached by hub_castle_stairs, beside the real floating castle rather
# than at the old gallery trigger down in the village.
#
# RIDES_ABOVE is added to every endpoint's authored Y. The hub's ground sits
# in a Y 15-24 band and the village towers rise well past that, so a rail
# hung at portal height runs *through* the terrain instead of over it — the
# first port of this system did exactly that and the trains skimmed grass.
# Lifting the whole network clears the rooftops and reads as sky railway.
const RIDES_ABOVE := 42.0

# The transit hub sits on its own terrace clear of the castle's floating
# foundation AND clear of the front-door approach.
#
# The previous centre (-43.0, 27.41) was measured against the castle origin
# (x = -51.4) without accounting for the foundation, whose island mesh has a
# 16.5 m radius (hub_lumen_citadel._build_castle_foundation). That put the
# station and the t=0 end of all three rails INSIDE the rock: every line was
# born within the foundation and punched out through the castle wall on its
# way to the islands — the "train goes through the wall" bug.
#
# Two invariants to preserve when tuning:
#   1. Station and every rail start stay outside the foundation, i.e. at least
#      FOUNDATION_RADIUS from (CASTLE_X, 27.41) on the XZ plane.
#   2. They stay off the door walkway. The door faces +X at x = -39.8 and the
#      plaza runs out to x = -30.8 with the stair tower at x = -29.4, so the
#      train court is offset in Z instead of stacked on that route. The player
#      reads stair -> causeway -> plaza -> door as one path, with the station
#      as a separate place alongside it.
# See scripts/test_rail_clearance.gd, which fails if either is broken.
const CASTLE_X := -51.4
const FOUNDATION_RADIUS := 16.5
const STATION_X := -22.0
const STATION_Z := 52.0

const GRAND_STATION_CENTER := Vector3(STATION_X, 66.15, STATION_Z)

const LINES := [
	{
		"id": "mindspark",
		"isle": "mind",
		"label": "Mind Spark",
		# Pop Thoughts — the thoughts kingdom.
		"dest": Vector3(90.3, 15.0 + RIDES_ABOVE, -83.0),
		"color": Color(0.42, 0.62, 1.00),   # cold blue, matches the portal pylon
		"start": Vector3(STATION_X, 66.45, STATION_Z - 7.9),
	},
	{
		"id": "heartmelody",
		"isle": "heart",
		"label": "Heart Melody",
		# Music minigame — the emotions kingdom.
		"dest": Vector3(80.0, 18.7 + RIDES_ABOVE, 72.0),
		"color": Color(0.95, 0.55, 0.30),   # warm amber
		"start": Vector3(STATION_X, 66.45, STATION_Z),
	},
	{
		"id": "creatorslight",
		"isle": "creator",
		"label": "Creator's Light",
		# Drawing tool — the creativity kingdom.
		"dest": Vector3(58.8, 16.0 + RIDES_ABOVE, -43.0),
		"color": Color(1.00, 0.76, 0.30),   # gold
		"start": Vector3(STATION_X, 66.45, STATION_Z + 7.9),
	},
]

# How far the span dips at its midpoint, as a fraction of its length. A
# straight line between two points reads as a wire; a sagging one reads as
# a railway that has weight.
#
# Kept shallow on purpose: these spans are 120+ units long and cross the
# village, so the prototype's 0.14 pulled the midpoint straight through the
# rooftops. The arc has to stay clear of what is under it.
const SAG_RATIO := 0.045

# How far a line runs straight out from the station before it may curve toward
# its island. See _make_sagging_curve: this is what stops a line whose island
# lies behind the castle from bowing back through the castle wall.
const DEPARTURE_RUN := 14.0

# Sized to read from the ground across a ~120-unit span, not from the close
# orbit framing the prototype used. A 0.35-radius tube that looked right in
# an empty sky vanishes to a hairline over a detailed village.
const RAIL_RADIUS := 0.9
const RAIL_SIDES := 5          # low: three long tubes are on screen at once
const RAIL_SEGMENTS := 24

const LEVITATION_ANCHOR_COUNT := 5

# Rails are visible from stage 0 — they are architecture, not a reward —
# but they only light up as the journey deepens. Index = JourneyState.stage.
const STAGE_GLOW := [0.0, 0.25, 0.5, 0.75, 1.0]

# Train travel speed along its line, in curve-fraction per second. Slow enough
# to read as public transport in the sky; hub_train_rider temporarily takes
# ownership of a train while the player is aboard.
const TRAIN_SPEED := 0.035

const WAKE_SECONDS := 2.0

var _rail_materials: Array[StandardMaterial3D] = []
var _train_materials: Array[StandardMaterial3D] = []
var _curves: Dictionary = {}
var _trains: Dictionary = {}
var _ridden_lines: Dictionary = {}
var _train_rotors: Array[Node3D] = []
var _levitation_crystals: Array[Node3D] = []
var _levitation_rings: Array[Node3D] = []

# Per-train progress along its curve, 0..1, keyed by line id.
var _train_t: Dictionary = {}

# Trains only run once the world has begun to wake. A moving train in a
# dormant world reads as a system running without a driver.
var _running := false


func _ready() -> void:
	# Let the hub finish building before adding to it, matching
	# hub_magitech.gd — the terrain and props author themselves first. The
	# sky islands also build on the first frame, and the rails need their
	# platform positions, so wait one more.
	await get_tree().process_frame
	await get_tree().process_frame

	_build_grand_station()
	for line in LINES:
		_build_line(line)

	apply_stage(_current_stage())


# Where this line's far end docks. Asks the sky islands for their platform
# so a rail can never drift away from the island it serves; falls back to
# the authored constant if the island layer is absent.
func _line_destination(line: Dictionary) -> Vector3:
	var isles := get_parent().get_node_or_null("SkyIsles")
	if isles == null:
		isles = get_parent().get_node_or_null("GalaxyIsles")
	if isles != null and isles.has_method("get_platform_pos"):
		var isle_id: String = line["isle"]
		var pos: Vector3 = isles.call("get_platform_pos", isle_id)
		if pos != Vector3.ZERO:
			return pos
	var fallback: Vector3 = line["dest"]
	return fallback


func _process(delta: float) -> void:
	# The little aether coils remain alive even while the shuttles are parked.
	for i in _train_rotors.size():
		var direction := 1.0 if i % 2 == 0 else -1.0
		_train_rotors[i].rotate_z(delta * direction * 1.4)

	# The bridge is held aloft by aether anchors, not columns. Their slow,
	# asynchronous motion makes the support system read as active magitech
	# instead of decorative pipes hanging beneath the span.
	var now := Time.get_ticks_msec() * 0.001
	for i in _levitation_crystals.size():
		var crystal := _levitation_crystals[i]
		var base_y: float = crystal.get_meta("base_y")
		var phase: float = crystal.get_meta("phase")
		crystal.position.y = base_y + sin(now * 1.25 + phase) * 0.28
		crystal.rotate_y(delta * (0.32 if i % 2 == 0 else -0.32))
	for i in _levitation_rings.size():
		_levitation_rings[i].rotate_y(delta * (0.55 if i % 2 == 0 else -0.55))

	if not _running:
		return

	for id in _trains:
		if bool(_ridden_lines.get(id, false)):
			continue
		var train: Node3D = _trains[id]
		var curve: Curve3D = _curves[id]

		# Ping-pong along the line rather than looping: a train that
		# teleports back to the start every lap breaks the illusion, and a
		# shuttle is what a two-station line would actually run.
		var t: float = _train_t[id] + TRAIN_SPEED * delta
		if t > 2.0:
			t -= 2.0
		_train_t[id] = t

		# 0..1 out, 1..0 back.
		var eased: float = t if t <= 1.0 else 2.0 - t
		_place_on_curve(train, curve, eased, t <= 1.0)


# Wake the rails to a journey stage. Called by hub_awakening.gd, which owns
# the stage for every hub system so the whole world moves together.
func apply_stage(stage: int) -> void:
	stage = clampi(stage, 0, STAGE_GLOW.size() - 1)

	# hub_awakening applies its stage before children that await a frame
	# have built their meshes; _ready applies the same stage afterwards.
	if _rail_materials.is_empty():
		return

	var target: float = STAGE_GLOW[stage]
	_running = target > 0.0

	var tween := create_tween().set_parallel()
	for material in _rail_materials:
		tween.tween_property(material, "emission_energy_multiplier",
			0.12 + target * 1.45, WAKE_SECONDS).set_trans(Tween.TRANS_SINE)
	for material in _train_materials:
		tween.tween_property(material, "emission_energy_multiplier",
			0.35 + target * 1.85, WAKE_SECONDS).set_trans(Tween.TRANS_SINE)


# --- public accessors --------------------------------------------------
#
# hub_train_rider.gd rides these curves to carry the player to an island, so
# they are the seam between "rails exist" and "rails are travel". Keep the
# names stable.

func get_curve(line_id: String) -> Curve3D:
	if _curves.has(line_id):
		var curve: Curve3D = _curves[line_id]
		return curve
	return null


func get_train(line_id: String) -> Node3D:
	if _trains.has(line_id):
		var train: Node3D = _trains[line_id]
		return train
	return null


func has_line(line_id: String) -> bool:
	return _curves.has(line_id)


# How far above the bare curve a shuttle actually rides. hub_train_rider seats
# its passenger from this so the player and the carriage cannot drift apart
# when the rail geometry is retuned. A const is not readable through get() from
# another script, which is why this is a method.
func get_ride_lift() -> float:
	return RAIL_RADIUS + 0.9


func get_line_ids() -> Array:
	return _curves.keys()


# Gives the rider sole control of one shuttle so the ambient animation cannot
# overwrite its transform halfway through a ride.
func set_train_riding(line_id: String, riding: bool, progress := -1.0) -> void:
	_ridden_lines[line_id] = riding
	if not riding and progress >= 0.0:
		_train_t[line_id] = clampf(progress, 0.0, 1.0)


# Public placement seam used by hub_train_rider. Keeping curve orientation in
# this script means the train and its passenger always agree about "forward".
func place_train(line_id: String, progress: float, forward: bool) -> void:
	if not _trains.has(line_id) or not _curves.has(line_id):
		return
	var train: Node3D = _trains[line_id]
	var curve: Curve3D = _curves[line_id]
	_place_on_curve(train, curve, progress, forward)


# --- construction ------------------------------------------------------

func _build_line(line: Dictionary) -> void:
	var id: String = line["id"]
	var color: Color = line["color"]
	var start: Vector3 = line["start"]
	var dest: Vector3 = _line_destination(line)

	var holder := Node3D.new()
	holder.name = "Rail_%s" % id
	add_child(holder)

	var curve := _make_sagging_curve(start, dest)
	_curves[id] = curve

	holder.add_child(_build_rail_mesh(curve, color))
	holder.add_child(_build_levitation_array(curve, color))

	var train := _build_train(color, line["label"])
	holder.add_child(train)
	_trains[id] = train
	# Stagger the trains so three lines never move as one animation.
	_train_t[id] = float(_trains.size()) * 0.4
	_place_on_curve(train, curve, 0.0, true)


# Compact castle Aether Court where all three routes terminate. The foundation
# beneath the castle already supplies the large walkable floor, so this adds
# only a shaped inlaid dais instead of another floating building-sized slab.
func _build_grand_station() -> void:
	var station := Node3D.new()
	station.name = "GrandStation"
	add_child(station)

	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.36, 0.38, 0.50)
	stone.roughness = 0.82
	stone.emission_enabled = true
	stone.emission = Color(0.18, 0.20, 0.32)
	stone.emission_energy_multiplier = 0.16

	var brass := _metal_material(Color(0.76, 0.52, 0.20))
	var glow := _emissive_material(Color(0.70, 0.82, 1.0), 0.75)
	_train_materials.append(glow)

	var deck := MeshInstance3D.new()
	deck.name = "StationDeck"
	var deck_mesh := CylinderMesh.new()
	deck_mesh.top_radius = 9.2
	deck_mesh.bottom_radius = 9.7
	deck_mesh.height = 0.46
	deck_mesh.radial_segments = 12
	deck.mesh = deck_mesh
	deck.position = GRAND_STATION_CENTER
	deck.material_override = stone
	station.add_child(deck)
	_add_static_cylinder(station, 9.2, 0.46, deck.position)

	# Three luminous track beds show the hub-and-spoke choice before the player
	# reaches the individual rune boarding pads.
	for line in LINES:
		var start: Vector3 = line["start"]
		var color: Color = line["color"]
		var bed_material := _emissive_material(color, 0.68)
		_train_materials.append(bed_material)
		var bed := MeshInstance3D.new()
		var bed_mesh := BoxMesh.new()
		bed_mesh.size = Vector3(7.2, 0.12, 2.15)
		bed.mesh = bed_mesh
		bed.position = Vector3(GRAND_STATION_CENTER.x + 2.0,
			GRAND_STATION_CENTER.y + 0.29, start.z)
		bed.material_override = bed_material
		bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		station.add_child(bed)

	# Small holographic island shrines bring all three realm choices into the
	# castle without trying to squeeze the full playable islands inside a room.
	for line in LINES:
		var start: Vector3 = line["start"]
		var color: Color = line["color"]
		_build_realm_shrine(station, start, color, line["label"], brass)

	# Rune clock suspended above the central concourse.
	var clock := MeshInstance3D.new()
	var clock_mesh := TorusMesh.new()
	clock_mesh.inner_radius = 1.45
	clock_mesh.outer_radius = 1.75
	clock_mesh.rings = 16
	clock_mesh.ring_segments = 5
	clock.mesh = clock_mesh
	clock.position = Vector3(GRAND_STATION_CENTER.x, 69.2, GRAND_STATION_CENTER.z)
	clock.rotation_degrees.x = 90.0
	clock.material_override = glow
	clock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	station.add_child(clock)

	var title := Label3D.new()
	title.text = "LUMEN CASTLE • AETHER COURT"
	title.position = Vector3(GRAND_STATION_CENTER.x, 70.7, GRAND_STATION_CENTER.z)
	title.font_size = 42
	title.outline_size = 9
	title.modulate = Color(1.0, 0.88, 0.58)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station.add_child(title)

	station.set_meta("inside_castle_complex", true)


func _add_static_box(parent: Node3D, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	parent.add_child(body)


func _add_static_cylinder(parent: Node3D, radius: float, height: float,
		position: Vector3) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	parent.add_child(body)


func _build_realm_shrine(parent: Node3D, dock: Vector3, color: Color,
		label_text: String, brass: Material) -> void:
	var shrine := Node3D.new()
	shrine.name = "RealmShrine_%s" % label_text.replace(" ", "")
	shrine.position = dock + Vector3(-3.0, 1.75, 0.0)
	parent.add_child(shrine)

	var glow := _emissive_material(color.lightened(0.2), 0.9)
	_rail_materials.append(glow)
	var miniature := MeshInstance3D.new()
	var miniature_mesh := SphereMesh.new()
	miniature_mesh.radius = 0.62
	miniature_mesh.height = 1.05
	miniature_mesh.radial_segments = 7
	miniature_mesh.rings = 3
	miniature.mesh = miniature_mesh
	miniature.scale = Vector3(1.35, 0.52, 1.0)
	miniature.material_override = glow
	miniature.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shrine.add_child(miniature)

	for tilt in [-28.0, 28.0]:
		var orbit := MeshInstance3D.new()
		var orbit_mesh := TorusMesh.new()
		orbit_mesh.inner_radius = 0.82
		orbit_mesh.outer_radius = 0.96
		orbit_mesh.rings = 12
		orbit_mesh.ring_segments = 4
		orbit.mesh = orbit_mesh
		orbit.rotation_degrees = Vector3(90.0, tilt, 0.0)
		orbit.material_override = brass
		orbit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shrine.add_child(orbit)
		_levitation_rings.append(orbit)

	var label := Label3D.new()
	label.text = label_text.to_upper()
	label.position.y = 1.35
	label.font_size = 22
	label.outline_size = 7
	label.modulate = color.lightened(0.32)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shrine.add_child(label)


# A rail that dips between its endpoints. Tangents leave each station
# roughly level so a train departing doesn't lurch downward instantly.
func _make_sagging_curve(start: Vector3, end: Vector3) -> Curve3D:
	var curve := Curve3D.new()

	# Every line leaves the station heading directly AWAY from the castle before
	# it is allowed to turn toward its island.
	#
	# Without this leg the first control tangent points at the span midpoint, so
	# a line whose island sits behind the castle (creatorslight, at z = -43)
	# bows back over the castle on its way out and clips the wall.
	#
	# The direction is computed from the castle rather than fixed to +X: the
	# station is offset in Z from the castle, so a hard-coded axis still let the
	# curve cut the corner. Radially outward is the only heading that guarantees
	# the first stretch increases distance from the building.
	var away := Vector3(start.x - CASTLE_X, 0.0, start.z - 27.41)
	if away.length_squared() < 0.01:
		away = Vector3.RIGHT
	away = away.normalized()

	var departure := start + away * DEPARTURE_RUN
	curve.add_point(start, Vector3.ZERO, away * (DEPARTURE_RUN * 0.5))

	var mid := (departure + end) * 0.5

	# Lines climb from the village up to the islands, so a sag applied to the
	# raw span length would drag the midpoint back down into the rooftops.
	# Instead the midpoint is lifted toward the high end and only the
	# horizontal run contributes sag — a climbing cable still bows, but it
	# bows above what it crosses, not through it.
	var horizontal := Vector2(end.x - departure.x, end.z - departure.z).length()
	mid.y = maxf(departure.y, end.y) - horizontal * SAG_RATIO * 0.5

	var to_mid := mid - departure
	var from_mid := end - mid

	curve.add_point(departure, away * (-DEPARTURE_RUN * 0.5), to_mid * 0.5)
	curve.add_point(mid, -to_mid * 0.35, from_mid * 0.35)
	curve.add_point(end, -from_mid * 0.5, Vector3.ZERO)

	return curve


# The rail itself, as a tube swept along the curve. Built by hand rather
# than with CSG so it stays a single cheap mesh.
func _build_rail_mesh(curve: Curve3D, color: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var length := curve.get_baked_length()
	var points: Array[Vector3] = []
	var rings: Array = []

	for i in RAIL_SEGMENTS + 1:
		var t := float(i) / float(RAIL_SEGMENTS)
		var centre := curve.sample_baked(t * length)
		points.append(centre)

		# Frame the ring off the local tangent so the tube twists with the
		# curve instead of shearing where the line changes direction.
		var ahead := curve.sample_baked(minf(t * length + 0.5, length))
		var behind := curve.sample_baked(maxf(t * length - 0.5, 0.0))
		var tangent := (ahead - behind).normalized()
		if tangent.length_squared() < 0.001:
			tangent = Vector3.FORWARD

		var side := tangent.cross(Vector3.UP).normalized()
		if side.length_squared() < 0.001:
			side = Vector3.RIGHT
		var up := side.cross(tangent).normalized()

		var ring: Array = []
		for s in RAIL_SIDES:
			var angle := TAU * float(s) / float(RAIL_SIDES)
			ring.append(centre + (side * cos(angle) + up * sin(angle)) * RAIL_RADIUS)
		rings.append(ring)

	for i in rings.size() - 1:
		var ring_a: Array = rings[i]
		var ring_b: Array = rings[i + 1]
		for s in RAIL_SIDES:
			var s_next := (s + 1) % RAIL_SIDES
			# Explicitly typed: rings hold untyped Arrays, so := would infer
			# Variant and trip the project's warnings-as-errors setting.
			var a: Vector3 = ring_a[s]
			var b: Vector3 = ring_a[s_next]
			var c: Vector3 = ring_b[s]
			var d: Vector3 = ring_b[s_next]

			for v in [a, c, b, b, c, d]:
				st.set_normal((v - points[i]).normalized())
				st.add_vertex(v)

	st.generate_normals()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Rail"
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = _emissive_material(color, 0.35)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rail_materials.append(mesh_instance.material_override)

	return mesh_instance


# Floating magitech anchors distributed beneath each rail. Short crystal
# assemblies keep the skyline open and unmistakably communicate levitation;
# there are no columns reaching toward the village or terrain below.
func _build_levitation_array(curve: Curve3D, color: Color) -> Node3D:
	var holder := Node3D.new()
	holder.name = "LevitationArray"

	var brass := _metal_material(Color(0.74, 0.48, 0.18))
	var glow := _emissive_material(color.lightened(0.18), 0.86)
	_rail_materials.append(glow)

	var length := curve.get_baked_length()

	for i in LEVITATION_ANCHOR_COUNT:
		# Skip the station ends and let each anchor float just below the rail.
		var t: float = lerpf(0.14, 0.86,
			float(i) / float(maxi(LEVITATION_ANCHOR_COUNT - 1, 1)))
		var top: Vector3 = curve.sample_baked(t * length)
		_add_levitation_anchor(holder, top - Vector3(0.0, 3.1, 0.0),
			color, brass, glow, 0.82)

	return holder


func _add_levitation_anchor(parent: Node3D, position: Vector3, color: Color,
		brass: Material, glow: Material, scale_factor: float) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = "AetherAnchor"
	anchor.position = position
	parent.add_child(anchor)

	# Elongated, low-poly crystal: a magical power source rather than a pipe.
	var crystal := MeshInstance3D.new()
	crystal.name = "FloatingCrystal"
	var crystal_mesh := SphereMesh.new()
	crystal_mesh.radius = 0.72 * scale_factor
	crystal_mesh.height = 2.5 * scale_factor
	crystal_mesh.radial_segments = 6
	crystal_mesh.rings = 2
	crystal.mesh = crystal_mesh
	crystal.material_override = glow
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchor.add_child(crystal)
	crystal.set_meta("base_y", crystal.position.y)
	crystal.set_meta("phase", float(_levitation_crystals.size()) * 1.37)
	_levitation_crystals.append(crystal)

	# Two perpendicular brass calibration rings visually contain the crystal.
	for axis in [Vector3(90.0, 0.0, 0.0), Vector3(0.0, 0.0, 90.0)]:
		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.95 * scale_factor
		ring_mesh.outer_radius = 1.12 * scale_factor
		ring_mesh.rings = 12
		ring_mesh.ring_segments = 5
		ring.mesh = ring_mesh
		ring.rotation_degrees = axis
		ring.material_override = brass
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		anchor.add_child(ring)
		_levitation_rings.append(ring)

	# A small rune halo projects upward toward the underside of the bridge.
	var halo := MeshInstance3D.new()
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 1.25 * scale_factor
	halo_mesh.outer_radius = 1.38 * scale_factor
	halo_mesh.rings = 14
	halo_mesh.ring_segments = 4
	halo.mesh = halo_mesh
	halo.position.y = 1.35 * scale_factor
	halo.material_override = glow
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchor.add_child(halo)
	_levitation_rings.append(halo)

	# Only the four large station anchors cast real light. The fifteen span
	# anchors use emission, avoiding a costly row of overlapping point lights.
	if scale_factor >= 1.0:
		var lamp := OmniLight3D.new()
		lamp.light_color = color.lightened(0.2)
		lamp.light_energy = 0.85 * scale_factor
		lamp.omni_range = 8.0 * scale_factor
		lamp.shadow_enabled = false
		HubLightFade.apply(lamp)
		anchor.add_child(lamp)

	return anchor


# One train per line, colour-matched to its destination kingdom. The silhouette
# mixes a small tram with a spell-powered observatory: riveted brass structure,
# luminous glass, a faceted aether core and visible levitation coils.
func _build_train(color: Color, label: String) -> Node3D:
	var train := Node3D.new()
	train.name = "Train_%s" % label.replace(" ", "")
	train.set_meta("spatial_train_root", true)

	var body_material := _emissive_material(color, 0.72)
	var glass_material := _emissive_material(color.lightened(0.35), 0.82)
	var brass_material := _metal_material(Color(0.76, 0.52, 0.20))
	var ink_material := _metal_material(Color(0.075, 0.10, 0.17))
	_train_materials.append(body_material)
	_train_materials.append(glass_material)

	# Broad lower hull and a raised passenger cabin. The open centre deck is
	# where the player stands, so the vehicle remains visible around their feet.
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(4.8, 1.35, 9.2)
	body.mesh = body_mesh
	body.material_override = body_material
	body.position.y = 0.35
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	train.add_child(body)

	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(4.0, 2.5, 3.4)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0.0, 1.85, -2.35)
	cabin.material_override = ink_material
	cabin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	train.add_child(cabin)

	# A faceted prow makes direction obvious from the ground.
	var nose := MeshInstance3D.new()
	var nose_mesh := SphereMesh.new()
	nose_mesh.radius = 2.05
	nose_mesh.height = 2.8
	nose_mesh.radial_segments = 6
	nose_mesh.rings = 3
	nose.mesh = nose_mesh
	nose.position = Vector3(0.0, 0.55, 4.55)
	nose.scale = Vector3(1.0, 0.62, 0.62)
	nose.material_override = body_material
	nose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	train.add_child(nose)

	# Brass ribs make the technology legible, while bright glass panels make
	# sure the carriage cannot collapse into a dark silhouette at sunset.
	for z in [-3.55, -1.1, 1.55, 3.65]:
		_add_train_box(train, Vector3(5.05, 0.16, 0.22), Vector3(0.0, 1.05, z), brass_material)
	for x in [-2.05, 2.05]:
		_add_train_box(train, Vector3(0.16, 1.8, 3.0), Vector3(x, 2.0, -2.25), brass_material)
		_add_train_box(train, Vector3(0.12, 1.15, 2.5), Vector3(x * 1.01, 2.05, -2.2), glass_material)

	# Guard rails around the boarding deck leave the middle open for the rider.
	for x in [-2.25, 2.25]:
		_add_train_box(train, Vector3(0.14, 1.0, 4.0), Vector3(x, 1.55, 1.65), brass_material)
		_add_train_box(train, Vector3(0.16, 0.16, 4.0), Vector3(x, 2.05, 1.65), brass_material)

	# A crystal engine floats through two counter-rotating scientific coils.
	var engine := Node3D.new()
	engine.name = "AetherEngine"
	engine.position = Vector3(0.0, 2.2, 2.7)
	train.add_child(engine)
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.58
	core_mesh.height = 1.75
	core_mesh.radial_segments = 6
	core_mesh.rings = 3
	core.mesh = core_mesh
	core.material_override = glass_material
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	engine.add_child(core)
	for angle in [-28.0, 28.0]:
		var rotor := MeshInstance3D.new()
		var rotor_mesh := TorusMesh.new()
		rotor_mesh.inner_radius = 0.82
		rotor_mesh.outer_radius = 1.03
		rotor_mesh.rings = 12
		rotor_mesh.ring_segments = 5
		rotor.mesh = rotor_mesh
		rotor.rotation_degrees = Vector3(90.0, angle, 0.0)
		rotor.material_override = brass_material
		rotor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		engine.add_child(rotor)
		_train_rotors.append(rotor)

	# Four luminous levitation coils visibly couple the hull to the sky rail.
	for z in [-3.2, 3.0]:
		for x in [-1.65, 1.65]:
			var coil := MeshInstance3D.new()
			var coil_mesh := TorusMesh.new()
			coil_mesh.inner_radius = 0.38
			coil_mesh.outer_radius = 0.62
			coil_mesh.rings = 10
			coil_mesh.ring_segments = 5
			coil.mesh = coil_mesh
			coil.position = Vector3(x, -0.45, z)
			coil.rotation_degrees.x = 90.0
			coil.material_override = glass_material
			coil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			train.add_child(coil)

	var route_label := Label3D.new()
	route_label.text = label.to_upper()
	route_label.position = Vector3(0.0, 3.45, -2.25)
	route_label.font_size = 34
	route_label.outline_size = 8
	route_label.modulate = color.lightened(0.35)
	route_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	train.add_child(route_label)

	# The core lights both the carriage and the rail beneath it.
	var lamp := OmniLight3D.new()
	lamp.light_color = color
	lamp.light_energy = 2.3
	lamp.omni_range = 16.0
	lamp.shadow_enabled = false
	HubLightFade.apply(lamp)
	lamp.position = Vector3(0.0, 1.2, 1.2)
	train.add_child(lamp)

	return train


func _add_train_box(parent: Node3D, size: Vector3, position: Vector3,
		material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = position
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


func _metal_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.82
	material.roughness = 0.28
	return material


# Sits a node on the curve at t (0..1), facing along its direction of
# travel and riding a little above the rail so it doesn't clip the tube.
func _place_on_curve(node: Node3D, curve: Curve3D, t: float, forward: bool) -> void:
	var length := curve.get_baked_length()
	var pos := curve.sample_baked(clampf(t, 0.0, 1.0) * length)

	var ahead_offset := 1.5 if forward else -1.5
	var ahead := curve.sample_baked(
		clampf(clampf(t, 0.0, 1.0) * length + ahead_offset, 0.0, length))

	var lift := Vector3(0.0, get_ride_lift(), 0.0)
	node.position = pos + lift

	# look_at_from_position works in GLOBAL space, but pos/ahead are samples of
	# a curve expressed in this node's local space. Feeding local coordinates to
	# it made the train face an arbitrary direction as soon as the rail root was
	# moved or scaled — which is exactly what the Art Castle galaxy layer does
	# (0.5 scale, offset -33 on Y). Convert both points before aiming.
	if ahead.distance_to(pos) > 0.01:
		node.look_at_from_position(
			to_global(pos + lift), to_global(ahead + lift), Vector3.UP)


func _emissive_material(color: Color, albedo_mix: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(1.0 - albedo_mix)
	material.roughness = 0.5
	material.metallic = 0.3
	# Emission is enabled but at zero energy while dormant: apply_stage
	# tweens the multiplier, and toggling the boolean instead would pop.
	material.emission_enabled = true
	material.emission = color
	# Never fully black: at journey stage 0 this still has to read as a train,
	# not as a moving shadow against the sunset.
	material.emission_energy_multiplier = 0.18
	return material


func _current_stage() -> int:
	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return 0
	return clampi(js.stage, 0, STAGE_GLOW.size() - 1)
