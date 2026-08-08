# Sky Isles rail network: three hub-and-spoke lines linking the castle to
# each kingdom island, rendered as suspended sky railways.
#
# Hub-and-spoke, matching CONTRACT.md's island layout: castle<->mind,
# castle<->heart, castle<->creator. No direct kingdom-to-kingdom rail exists
# by design — travel_controller.gd routes those journeys as two legs via the
# castle, or refuses them; see that file for the reasoning.
#
# Build order is not guaranteed between agents, so this node waits a couple
# of frames for Agent B's island nodes to exist before reading their
# `platform_pos` meta, and degrades gracefully (skipping a line, not
# crashing) if an island is still missing after that grace period.
#
# Everything here is runtime-authored per CONTRACT.md rule 2: no meshes are
# baked into the scene file, only this script and its parent node are.
extends Node3D

# How many lines exist and their canonical hub-and-spoke endpoints. Order
# matters only for iteration; travel_controller looks lines up by isle_id.
const LINES := [
	{"id": "mind", "from": "castle", "to": "mind"},
	{"id": "heart", "from": "castle", "to": "heart"},
	{"id": "creator", "from": "castle", "to": "creator"},
]

# How far the rail sags below the straight line between its two islands, as
# a fraction of the span length. A real suspended cable sags under its own
# weight; a dead-straight beam between floating islands would read as a
# ruler, not a railway.
const SAG_RATIO := 0.12

# Tube cross-section. Kept to a triangle-count-friendly few sides per
# CONTRACT.md's performance budget — a hexagonal tube is indistinguishable
# from round at this scale but costs a fraction of the tris.
const RAIL_SIDES := 6
const RAIL_RADIUS := 0.35
const CURVE_SUBDIVS := 24  # baked points sampled along each Curve3D

const PILLAR_COUNT := 5
const PILLAR_RADIUS := 0.5

const TRAIN_SIZE := Vector3(3.2, 2.0, 1.6)

# Fallback palette used only if Agent A's sky_isles_world.gd is not yet
# reachable (e.g. this node's _ready runs before the world root script has
# been added, or during isolated testing). Mirrors CONTRACT.md's PALETTE
# vibrant colours; overwritten by the real PALETTE the moment it is found.
const FALLBACK_PALETTE := {
	"castle": Color(0.85, 0.80, 0.92),
	"mind": Color(0.45, 0.62, 1.00),
	"heart": Color(1.00, 0.55, 0.62),
	"creator": Color(1.00, 0.76, 0.30),
}

# isle_id -> Curve3D, built lazily as islands become available. Exposed via
# get_curve() for travel_controller.gd to sample.
var _curves: Dictionary = {}
# isle_id -> Node3D (the train mesh for the line ending at that isle).
var _trains: Dictionary = {}
# isle_id -> bool, true once that line's geometry has been built, so a
# retry pass (islands can appear late) never double-builds a line.
var _built: Dictionary = {}


func _ready() -> void:
	# Agent B's island nodes and Agent A's world root may not exist on the
	# first frame — build order between sibling agents is not guaranteed.
	# Retry a handful of times, a frame apart, rather than gambling on one
	# await. Any line whose islands never appear is simply skipped; this
	# node must never crash the scene for another agent's missing work.
	for attempt in 6:
		await get_tree().process_frame
		_try_build_all_lines()
		if _built.size() == LINES.size():
			break


func _try_build_all_lines() -> void:
	for line in LINES:
		var id: String = line["id"]
		if _built.get(id, false):
			continue

		var from_isle := _find_isle(line["from"])
		var to_isle := _find_isle(line["to"])
		if from_isle == null or to_isle == null:
			continue

		if not from_isle.has_meta("platform_pos") or not to_isle.has_meta("platform_pos"):
			continue

		_build_line(id, line["from"], line["to"], from_isle, to_isle)
		_built[id] = true


# --- island / world lookups --------------------------------------------

func _find_isle(isle_id: String) -> Node3D:
	# owner/parent rather than get_tree().current_scene, which is null when
	# the scene is instantiated manually instead of loaded as the main scene
	# (test harnesses, loading screens, sub-viewports).
	var world: Node = owner if owner != null else get_parent()
	if world == null:
		return null
	var node := world.find_child("Isle_%s" % isle_id, true, false)
	return node as Node3D


# Reads Agent A's single-source-of-truth palette from sky_isles_world.gd.
# Falls back to the mirrored constants above if that script isn't reachable
# yet, so a line can still render (with the right colour, just not
# necessarily hot-reloaded) even if built before the world root script.
func _destination_color(isle_id: String) -> Color:
	var world: Node = owner if owner != null else get_parent()
	if world != null and world.get_script() != null and "PALETTE" in world:
		var palette: Dictionary = world.PALETTE
		if palette.has(isle_id) and typeof(palette[isle_id]) == TYPE_DICTIONARY:
			var entry: Dictionary = palette[isle_id]
			if entry.has("vibrant"):
				return entry["vibrant"]

	return FALLBACK_PALETTE.get(isle_id, Color.WHITE)


# --- line construction ---------------------------------------------------

func _build_line(id: String, from_id: String, to_id: String, from_isle: Node3D, to_isle: Node3D) -> void:
	var start: Vector3 = from_isle.get_meta("platform_pos")
	var end: Vector3 = to_isle.get_meta("platform_pos")

	var curve := _make_sagging_curve(start, end)
	_curves[id] = curve

	var line_root := Node3D.new()
	line_root.name = "Line_%s" % id
	add_child(line_root)

	var color := _destination_color(to_id)

	line_root.add_child(_build_rail_mesh(curve, color))
	line_root.add_child(_build_pillars(curve))

	var train := _build_train(color, to_id)
	# Rest position: parked near the departure end, sitting on the rail
	# rather than floating beside it. A hair above t=0 so the train mesh's
	# own height doesn't clip into the tube.
	var rest_transform := _sample_curve_transform(curve, 0.04)
	train.transform = rest_transform
	line_root.add_child(train)
	_trains[id] = train


# Builds a Curve3D from start to end with a single sagging control point,
# like a cable hanging under its own weight. The midpoint is pulled toward
# world-down (not "down relative to the chord") so the sag reads correctly
# even for the heart line, whose two islands sit at different heights.
func _make_sagging_curve(start: Vector3, end: Vector3) -> Curve3D:
	var curve := Curve3D.new()

	var mid := (start + end) * 0.5
	var span := start.distance_to(end)
	mid.y -= span * SAG_RATIO

	# Smooth in/out tangents so the curve leaves each platform roughly
	# level (a train departing a station shouldn't lurch downward
	# instantly) and arrives the same way.
	var to_mid := mid - start
	var from_mid := end - mid

	curve.add_point(start, Vector3.ZERO, to_mid * 0.5)
	curve.add_point(mid, -to_mid * 0.35, from_mid * 0.35)
	curve.add_point(end, -from_mid * 0.5, Vector3.ZERO)

	return curve


# Extrudes a low-sided tube along the curve's baked points. Building the
# mesh by hand (SurfaceTool) rather than reaching for a CSGPolygon/Path
# node keeps this a plain MeshInstance3D with no extra scene nodes, and
# keeps full control over the (small) side count for the tri budget.
func _build_rail_mesh(curve: Curve3D, color: Color) -> MeshInstance3D:
	curve.bake_interval = max(curve.get_baked_length() / float(CURVE_SUBDIVS), 0.5)
	var points := curve.get_baked_points()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings: Array[Array] = []
	for i in points.size():
		var forward: Vector3
		if i == 0:
			forward = (points[1] - points[0]).normalized()
		elif i == points.size() - 1:
			forward = (points[i] - points[i - 1]).normalized()
		else:
			forward = (points[i + 1] - points[i - 1]).normalized()

		var up := Vector3.UP
		if abs(forward.dot(up)) > 0.99:
			up = Vector3.RIGHT
		var right := forward.cross(up).normalized()
		var true_up := right.cross(forward).normalized()

		var ring: Array[Vector3] = []
		for s in RAIL_SIDES:
			var angle := TAU * float(s) / float(RAIL_SIDES)
			var offset := (right * cos(angle) + true_up * sin(angle)) * RAIL_RADIUS
			ring.append(points[i] + offset)
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

			st.set_normal((a - points[i]).normalized())
			st.add_vertex(a)
			st.set_normal((c - points[i + 1]).normalized())
			st.add_vertex(c)
			st.set_normal((b - points[i]).normalized())
			st.add_vertex(b)

			st.set_normal((b - points[i]).normalized())
			st.add_vertex(b)
			st.set_normal((c - points[i + 1]).normalized())
			st.add_vertex(c)
			st.set_normal((d - points[i + 1]).normalized())
			st.add_vertex(d)

	st.generate_normals()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Rail"
	mesh_instance.mesh = st.commit()

	var material := StandardMaterial3D.new()
	material.albedo_color = color.lightened(0.15)
	material.metallic = 0.6
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.35
	mesh_instance.material_override = material

	return mesh_instance


# A handful of thin support pillars dropped from the curve down to a floor
# well below the sky plane, purely as visual anchoring (the rail is the
# thing that matters; pillars just stop it from reading as floating wire).
func _build_pillars(curve: Curve3D) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Pillars"

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.28, 0.34)
	material.metallic = 0.4
	material.roughness = 0.7

	for i in PILLAR_COUNT:
		# Spread pillars along the middle of the span, skipping the very
		# ends where a pillar would collide with the station platforms.
		# lerp() returns Variant; type explicitly for warnings-as-errors.
		var t: float = lerpf(0.15, 0.85, float(i) / float(max(PILLAR_COUNT - 1, 1)))
		var point: Vector3 = curve.sample_baked(t * curve.get_baked_length())

		var pillar := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = PILLAR_RADIUS
		mesh.bottom_radius = PILLAR_RADIUS * 1.3
		# Drop far enough to vanish into the fog below rather than visibly
		# ending in mid-air.
		var drop := 60.0
		mesh.height = drop
		mesh.radial_segments = 6
		pillar.mesh = mesh
		pillar.material_override = material
		pillar.position = point - Vector3(0, drop * 0.5, 0)

		holder.add_child(pillar)

	return holder


# One simple train mesh: a body block plus a slightly narrower cab block,
# colour-matched to the destination island. Cheap primitives per the
# CONTRACT.md performance budget — this is a toy train, not a hero asset.
func _build_train(color: Color, isle_id: String) -> Node3D:
	var train := Node3D.new()
	train.name = "Train_%s" % isle_id

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.2
	material.roughness = 0.5
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.5

	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := BoxMesh.new()
	body_mesh.size = TRAIN_SIZE
	body.mesh = body_mesh
	body.material_override = material
	body.position.y = TRAIN_SIZE.y * 0.5
	train.add_child(body)

	var cab := MeshInstance3D.new()
	cab.name = "Cab"
	var cab_mesh := BoxMesh.new()
	cab_mesh.size = Vector3(TRAIN_SIZE.x * 0.32, TRAIN_SIZE.y * 0.75, TRAIN_SIZE.z * 0.85)
	cab.mesh = cab_mesh
	cab.material_override = material
	cab.position = Vector3(TRAIN_SIZE.x * 0.5, TRAIN_SIZE.y * 0.375, 0)
	train.add_child(cab)

	# Clickable collision so input picking (travel_controller) can select
	# the train directly, not just its station. A single box covering both
	# body and cab is enough — this never needs per-part picking.
	var area := Area3D.new()
	area.name = "ClickArea"
	area.input_ray_pickable = true
	area.set_meta("isle_id", isle_id)
	area.set_meta("is_train", true)
	train.add_child(area)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(TRAIN_SIZE.x * 1.3, TRAIN_SIZE.y * 1.2, TRAIN_SIZE.z * 1.2)
	collision.shape = shape
	collision.position.y = TRAIN_SIZE.y * 0.5
	area.add_child(collision)

	return train


# --- curve sampling helpers ----------------------------------------------

# Returns a world-space Transform3D at parameter t in [0,1] along the
# curve, oriented so -Z (Godot's forward) points along the direction of
# travel. Used both to park trains at rest and by travel_controller.gd to
# ride the camera.
func _sample_curve_transform(curve: Curve3D, t: float) -> Transform3D:
	var length := curve.get_baked_length()
	var dist := clampf(t, 0.0, 1.0) * length

	var pos := curve.sample_baked(dist)
	var ahead := curve.sample_baked(clampf(dist + 0.5, 0.0, length))
	var forward := (ahead - pos)
	if forward.length() < 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()

	var basis := Basis.looking_at(forward, Vector3.UP)
	return Transform3D(basis, pos)


# --- public API for travel_controller.gd ---------------------------------

# Returns the Curve3D for the line whose destination end is isle_id (i.e.
# "mind" returns the castle<->mind curve). Null if that line hasn't been
# built yet (islands still missing) or isle_id is not a kingdom.
func get_curve(isle_id: String) -> Curve3D:
	return _curves.get(isle_id, null)


# Returns the train mesh for the line ending at isle_id. Null under the
# same conditions as get_curve().
func get_train(isle_id: String) -> Node3D:
	return _trains.get(isle_id, null)


# True once a line's geometry (and therefore its curve/train) exists.
func has_line(isle_id: String) -> bool:
	return _built.get(isle_id, false)


# Every kingdom isle_id this network currently has a built line for. Used
# by travel_controller.gd to validate travel_to() calls and to wire up
# click handling once lines exist.
func get_line_ids() -> Array:
	return _curves.keys()


# Convenience for travel_controller.gd: samples world position + forward-
# facing transform at parameter t (0..1) along the named line's curve.
# Returns a Transform3D at the origin-forward with an empty basis if the
# line doesn't exist, so a bad lookup produces an inert transform rather
# than crashing the caller.
func sample_line(isle_id: String, t: float) -> Transform3D:
	var curve := get_curve(isle_id)
	if curve == null:
		return Transform3D.IDENTITY
	return _sample_curve_transform(curve, t)
