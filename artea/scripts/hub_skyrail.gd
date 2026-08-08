# Sky rails linking the castle to the three kingdom destinations.
#
# Ported from the Sky Isles prototype (scripts/sky_isles/rail_network.gd)
# onto the real hub. The prototype floated four islands in an empty sky;
# here the "islands" are the destinations that already exist in
# New_Hub_World.tscn, so this builds only the connective tissue — sagging
# rails, support pillars, and a train per line — above the terrain the
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

const GRAND_STATION_CENTER := Vector3(-28.8, 63.8, 39.0)

const LINES := [
	{
		"id": "mindspark",
		"isle": "mind",
		"label": "Mind Spark",
		# Pop Thoughts — the thoughts kingdom.
		"dest": Vector3(90.3, 15.0 + RIDES_ABOVE, -83.0),
		"color": Color(0.42, 0.62, 1.00),   # cold blue, matches the portal pylon
		"start": Vector3(-28.8, 64.5, 31.0),
	},
	{
		"id": "heartmelody",
		"isle": "heart",
		"label": "Heart Melody",
		# Music minigame — the emotions kingdom.
		"dest": Vector3(80.0, 18.7 + RIDES_ABOVE, 72.0),
		"color": Color(0.95, 0.55, 0.30),   # warm amber
		"start": Vector3(-28.8, 64.5, 39.0),
	},
	{
		"id": "creatorslight",
		"isle": "creator",
		"label": "Creator's Light",
		# Drawing tool — the creativity kingdom.
		"dest": Vector3(58.8, 16.0 + RIDES_ABOVE, -43.0),
		"color": Color(1.00, 0.76, 0.30),   # gold
		"start": Vector3(-28.8, 64.5, 47.0),
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

# Sized to read from the ground across a ~120-unit span, not from the close
# orbit framing the prototype used. A 0.35-radius tube that looked right in
# an empty sky vanishes to a hairline over a detailed village.
const RAIL_RADIUS := 0.9
const RAIL_SIDES := 5          # low: three long tubes are on screen at once
const RAIL_SEGMENTS := 24

const PILLAR_COUNT := 4
const PILLAR_RADIUS := 1.1

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
	holder.add_child(_build_pillars(curve))

	var train := _build_train(color, line["label"])
	holder.add_child(train)
	_trains[id] = train
	# Stagger the trains so three lines never move as one animation.
	_train_t[id] = float(_trains.size()) * 0.4
	_place_on_curve(train, curve, 0.0, true)


# Open-air hub platform where all three lines terminate. One low-poly deck and
# canopy replaces the former invisible station coordinates; its generous floor
# overlaps the castle stair crown so the route is continuously walkable.
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
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(13.0, 1.2, 27.0)
	deck.mesh = deck_mesh
	deck.position = GRAND_STATION_CENTER
	deck.material_override = stone
	station.add_child(deck)
	_add_static_box(station, deck_mesh.size, deck.position)

	# Three luminous track beds show the hub-and-spoke choice before the player
	# reaches the individual rune boarding pads.
	for line in LINES:
		var start: Vector3 = line["start"]
		var color: Color = line["color"]
		var bed_material := _emissive_material(color, 0.68)
		_train_materials.append(bed_material)
		var bed := MeshInstance3D.new()
		var bed_mesh := BoxMesh.new()
		bed_mesh.size = Vector3(9.5, 0.16, 2.5)
		bed.mesh = bed_mesh
		bed.position = Vector3(GRAND_STATION_CENTER.x + 1.2, 64.46, start.z)
		bed.material_override = bed_material
		bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		station.add_child(bed)

	# High open canopy: shelter and silhouette without obscuring the scenic view
	# during boarding or catching the third-person spring arm.
	for z in [27.0, 51.0]:
		for x in [-34.2, -23.4]:
			_add_station_box(station, Vector3(0.38, 7.4, 0.38),
				Vector3(x, 68.0, z), brass)
	_add_station_box(station, Vector3(12.5, 0.38, 0.55),
		Vector3(GRAND_STATION_CENTER.x, 71.5, 27.0), brass)
	_add_station_box(station, Vector3(12.5, 0.38, 0.55),
		Vector3(GRAND_STATION_CENTER.x, 71.5, 51.0), brass)
	for z in [31.0, 39.0, 47.0]:
		_add_station_box(station, Vector3(12.5, 0.22, 0.32),
			Vector3(GRAND_STATION_CENTER.x, 71.5, z), brass)

	# Rune clock suspended above the central concourse.
	var clock := MeshInstance3D.new()
	var clock_mesh := TorusMesh.new()
	clock_mesh.inner_radius = 1.45
	clock_mesh.outer_radius = 1.75
	clock_mesh.rings = 16
	clock_mesh.ring_segments = 5
	clock.mesh = clock_mesh
	clock.position = Vector3(GRAND_STATION_CENTER.x, 70.2, GRAND_STATION_CENTER.z)
	clock.rotation_degrees.x = 90.0
	clock.material_override = glow
	clock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	station.add_child(clock)

	var title := Label3D.new()
	title.text = "ARTÉA GRAND STATION"
	title.position = Vector3(GRAND_STATION_CENTER.x, 72.2, GRAND_STATION_CENTER.z)
	title.font_size = 42
	title.outline_size = 9
	title.modulate = Color(1.0, 0.88, 0.58)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station.add_child(title)

	# Slender supports visually carry the station into the castle foundation.
	for z in [28.0, 50.0]:
		for x in [-33.0, -24.5]:
			var support := MeshInstance3D.new()
			var support_mesh := CylinderMesh.new()
			support_mesh.top_radius = 0.48
			support_mesh.bottom_radius = 0.72
			support_mesh.height = 20.0
			support_mesh.radial_segments = 6
			support.mesh = support_mesh
			support.position = Vector3(x, 53.2, z)
			support.material_override = brass
			support.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			station.add_child(support)


func _add_station_box(parent: Node3D, size: Vector3, position: Vector3,
		material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = position
	part.material_override = material
	parent.add_child(part)
	return part


func _add_static_box(parent: Node3D, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	parent.add_child(body)


# A rail that dips between its endpoints. Tangents leave each station
# roughly level so a train departing doesn't lurch downward instantly.
func _make_sagging_curve(start: Vector3, end: Vector3) -> Curve3D:
	var curve := Curve3D.new()

	var mid := (start + end) * 0.5

	# Lines climb from the village up to the islands, so a sag applied to the
	# raw span length would drag the midpoint back down into the rooftops.
	# Instead the midpoint is lifted toward the high end and only the
	# horizontal run contributes sag — a climbing cable still bows, but it
	# bows above what it crosses, not through it.
	var horizontal := Vector2(end.x - start.x, end.z - start.z).length()
	mid.y = maxf(start.y, end.y) - horizontal * SAG_RATIO * 0.5

	var to_mid := mid - start
	var from_mid := end - mid

	curve.add_point(start, Vector3.ZERO, to_mid * 0.5)
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


# Thin supports dropping from the rail toward the ground. They stop short
# rather than reaching terrain: the hub's ground height varies along each
# span, and a pillar punching through a hillside looks worse than one that
# fades into the haze below.
func _build_pillars(curve: Curve3D) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Pillars"

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.30, 0.28, 0.34)
	material.metallic = 0.4
	material.roughness = 0.7

	var length := curve.get_baked_length()

	for i in PILLAR_COUNT:
		# Spread along the middle of the span, skipping the ends where a
		# pillar would collide with the station structures.
		var t: float = lerpf(0.2, 0.8, float(i) / float(maxi(PILLAR_COUNT - 1, 1)))
		var top: Vector3 = curve.sample_baked(t * length)

		var pillar := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = PILLAR_RADIUS
		mesh.bottom_radius = PILLAR_RADIUS * 1.4
		# Long enough to visibly descend toward the village below without
		# being terrain-sampled — the ground height varies along each span,
		# so these fade into the haze rather than meeting it exactly.
		mesh.height = 30.0
		mesh.radial_segments = 6
		pillar.mesh = mesh
		pillar.position = top - Vector3(0.0, 15.0, 0.0)
		pillar.material_override = material
		pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(pillar)

	return holder


# One train per line, colour-matched to its destination kingdom. The silhouette
# mixes a small tram with a spell-powered observatory: riveted brass structure,
# luminous glass, a faceted aether core and visible levitation coils.
func _build_train(color: Color, label: String) -> Node3D:
	var train := Node3D.new()
	train.name = "Train_%s" % label.replace(" ", "")

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
		clampf(t * length + ahead_offset, 0.0, length))

	node.position = pos + Vector3(0.0, RAIL_RADIUS + 0.9, 0.0)
	if ahead.distance_to(pos) > 0.01:
		node.look_at_from_position(node.position, ahead + Vector3(0.0, RAIL_RADIUS + 0.9, 0.0), Vector3.UP)


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
