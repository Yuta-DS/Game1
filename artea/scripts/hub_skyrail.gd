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
# The castle end is shared: this is a hub-and-spoke network, the same shape
# the journey itself has.
#
# RIDES_ABOVE is added to every endpoint's authored Y. The hub's ground sits
# in a Y 15-24 band and the village towers rise well past that, so a rail
# hung at portal height runs *through* the terrain instead of over it — the
# first port of this system did exactly that and the trains skimmed grass.
# Lifting the whole network clears the rooftops and reads as sky railway.
const RIDES_ABOVE := 42.0

const CASTLE_HUB := Vector3(-32.3, 20.0 + RIDES_ABOVE, -2.0)

const LINES := [
	{
		"id": "mindspark",
		"label": "Mind Spark",
		# Pop Thoughts — the thoughts kingdom.
		"dest": Vector3(90.3, 15.0 + RIDES_ABOVE, -83.0),
		"color": Color(0.42, 0.62, 1.00),   # cold blue, matches the portal pylon
	},
	{
		"id": "heartmelody",
		"label": "Heart Melody",
		# Music minigame — the emotions kingdom.
		"dest": Vector3(80.0, 18.7 + RIDES_ABOVE, 72.0),
		"color": Color(0.95, 0.55, 0.30),   # warm amber
	},
	{
		"id": "creatorslight",
		"label": "Creator's Light",
		# Drawing tool — the creativity kingdom.
		"dest": Vector3(58.8, 16.0 + RIDES_ABOVE, -43.0),
		"color": Color(1.00, 0.76, 0.30),   # gold
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

# Train travel speed along its line, in curve-fraction per second. Slow: the
# trains are ambience seen from the ground, not a vehicle the player boards.
const TRAIN_SPEED := 0.035

const WAKE_SECONDS := 2.0

var _rail_materials: Array[StandardMaterial3D] = []
var _train_materials: Array[StandardMaterial3D] = []
var _curves: Dictionary = {}
var _trains: Dictionary = {}

# Per-train progress along its curve, 0..1, keyed by line id.
var _train_t: Dictionary = {}

# Trains only run once the world has begun to wake. A moving train in a
# dormant world reads as a system running without a driver.
var _running := false


func _ready() -> void:
	# Let the hub finish building before adding to it, matching
	# hub_magitech.gd — the terrain and props author themselves first.
	await get_tree().process_frame

	for line in LINES:
		_build_line(line)

	apply_stage(_current_stage())


func _process(delta: float) -> void:
	if not _running:
		return

	for id in _trains:
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
			target * 1.6, WAKE_SECONDS).set_trans(Tween.TRANS_SINE)
	for material in _train_materials:
		tween.tween_property(material, "emission_energy_multiplier",
			target * 2.2, WAKE_SECONDS).set_trans(Tween.TRANS_SINE)


# --- construction ------------------------------------------------------

func _build_line(line: Dictionary) -> void:
	var id: String = line["id"]
	var color: Color = line["color"]
	var dest: Vector3 = line["dest"]

	var holder := Node3D.new()
	holder.name = "Rail_%s" % id
	add_child(holder)

	var curve := _make_sagging_curve(CASTLE_HUB, dest)
	_curves[id] = curve

	holder.add_child(_build_rail_mesh(curve, color))
	holder.add_child(_build_pillars(curve))

	var train := _build_train(color, line["label"])
	holder.add_child(train)
	_trains[id] = train
	# Stagger the trains so three lines never move as one animation.
	_train_t[id] = float(_trains.size()) * 0.4
	_place_on_curve(train, curve, 0.0, true)


# A rail that dips between its endpoints. Tangents leave each station
# roughly level so a train departing doesn't lurch downward instantly.
func _make_sagging_curve(start: Vector3, end: Vector3) -> Curve3D:
	var curve := Curve3D.new()

	var mid := (start + end) * 0.5
	mid.y -= start.distance_to(end) * SAG_RATIO

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


# One train per line, colour-matched to its destination kingdom so a glance
# at the sky tells the player which way it is heading.
func _build_train(color: Color, label: String) -> Node3D:
	var train := Node3D.new()
	train.name = "Train_%s" % label.replace(" ", "")

	var body_material := _emissive_material(color, 0.5)
	_train_materials.append(body_material)

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	# Scaled with the rail: read from the village below, not from close up.
	body_mesh.size = Vector3(3.4, 2.8, 7.2)
	body.mesh = body_mesh
	body.material_override = body_material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	train.add_child(body)

	# A rounded nose so the train has a facing direction at a distance.
	var nose := MeshInstance3D.new()
	var nose_mesh := SphereMesh.new()
	nose_mesh.radius = 1.7
	nose_mesh.height = 3.4
	nose_mesh.radial_segments = 6
	nose_mesh.rings = 3
	nose.mesh = nose_mesh
	nose.position.z = 3.6
	nose.material_override = body_material
	nose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	train.add_child(nose)

	# The train lights the rail under it — short range so three trains can
	# never wash out the stage lighting hub_awakening controls.
	var lamp := OmniLight3D.new()
	lamp.light_color = color
	lamp.light_energy = 1.6
	lamp.omni_range = 14.0
	lamp.shadow_enabled = false
	train.add_child(lamp)

	return train


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
	material.emission_energy_multiplier = 0.0
	return material


func _current_stage() -> int:
	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return 0
	return clampi(js.stage, 0, STAGE_GLOW.size() - 1)
