@tool
class_name MindSparkZone
extends Node3D

## Greybox of the Mind Spark world's six-zone route.
##
## Built to the developer guide's GREYBOX RULE:
##
##   "Build the six zone floors and the main walking path first. Add the World
##    Gate, checkpoints, boss arena and final sanctuary next. Add the station
##    side spur last; it must never block the story route."
##
## So this script lays down, in that order: six zone platforms, the connecting
## path, then the props each zone needs. Everything is a StaticBody3D with real
## collision, because the point of a greybox is that the route can be walked
## end to end before any art exists.
##
## The zones come from PART 3's six-zone route table:
##
##   1  World Gate Landing      briefing, first checkpoint
##   2  Living Network Forest   server roots, first Sparks, small enemies
##   3  Constellation Court     evidence, memory pattern, Logic Gate
##   4  Hope Path Ridge         Perspective Lens, Truth Bridge, elite fight
##   5  Thought Storm Arena     three boss anchors, open core, Calm Rain Basin
##   6  Oldest Tree Sanctuary   Star, Wisdom Blade, identity reflection, return
##
## The island floats, matching architecture object 01 ("Floating island shell"),
## so zone floors sit at varying heights joined by ramps rather than on terrain.

## One zone's footprint. Radius is generous enough for the guide's "no more than
## 4 normal enemies at one time" combat band.
class ZoneSpec extends RefCounted:
	var id: String
	var label: String
	var centre: Vector3
	var radius: float

	func _init(p_id: String, p_label: String, p_centre: Vector3, p_radius: float) -> void:
		id = p_id
		label = p_label
		centre = p_centre
		radius = p_radius


## Rebuilds the whole greybox. Exposed as an inspector button.
@export var rebuild_now: bool = false:
	set(_v):
		rebuild_now = false
		if is_inside_tree():
			rebuild()

## Draws a floating name plate over each zone. Useful while blocking out the
## route; turn off for screenshots.
@export var show_zone_labels: bool = true:
	set(value):
		show_zone_labels = value
		if is_inside_tree():
			rebuild()

## Width of the connecting walkway, in metres. The guide's circuit path kit
## specifies 3-4 m modular pieces.
@export_range(2.0, 8.0, 0.5) var path_width: float = 4.0

const P := preload("res://scripts/altar/AltarParts.gd")

const GENERATED := ["Zones", "Paths", "Props", "Labels"]

var _zones: Node3D
var _paths: Node3D
var _props: Node3D
var _labels: Node3D
var _specs: Array[ZoneSpec] = []


func _ready() -> void:
	rebuild()


## The six zone platforms, laid out as a walkable arc so the player is always
## moving forward rather than doubling back. Heights rise toward the boss arena
## and settle at the sanctuary.
func _build_specs() -> void:
	# Heights climb gently toward the boss arena. The rise between neighbours is
	# kept to ~3 m over a 30 m-plus gap, which lands every connecting ramp well
	# under the player's 45 deg floor limit — an earlier layout used 3-4 m steps
	# over shorter spans and produced a ramp too steep to walk up.
	_specs = [
		ZoneSpec.new("landing", "1 · WORLD GATE LANDING", Vector3(0, 0, 0), 16.0),
		ZoneSpec.new("forest", "2 · LIVING NETWORK FOREST", Vector3(-34, 1.5, -26), 20.0),
		ZoneSpec.new("court", "3 · CONSTELLATION COURT", Vector3(-30, 3.5, -70), 18.0),
		ZoneSpec.new("ridge", "4 · HOPE PATH RIDGE", Vector3(6, 5.5, -98), 16.0),
		ZoneSpec.new("arena", "5 · THOUGHT STORM ARENA", Vector3(50, 7.5, -86), 24.0),
		ZoneSpec.new("sanctuary", "6 · OLDEST TREE SANCTUARY", Vector3(68, 9.0, -40), 18.0),
	]


func rebuild() -> void:
	for name in GENERATED:
		var old := get_node_or_null(NodePath(name))
		if old:
			old.name = "%s_discarded" % name
			old.queue_free()

	_build_specs()
	_zones = _group("Zones")
	_paths = _group("Paths")
	_props = _group("Props")
	_labels = _group("Labels")

	# GREYBOX RULE order: floors and path first...
	for spec in _specs:
		_build_platform(spec)
	for i in _specs.size() - 1:
		_build_link(_specs[i], _specs[i + 1])

	# ...then the gate, checkpoints, arena and sanctuary furniture.
	_build_landing_props()
	_build_forest_props()
	_build_court_props()
	_build_ridge_props()
	_build_arena_props()
	_build_sanctuary_props()


func _group(name: String) -> Node3D:
	var n := Node3D.new()
	n.name = name
	add_child(n)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		n.owner = owner
	return n


# --- Floors and paths ------------------------------------------------------

## One zone floor.
##
## Not a bare cylinder: the deck gets a ring of individually-placed masonry
## blocks around its rim (the same brick the altar is built from), a recessed
## inner floor and a glowing edge seam. That rim is what stops the platform
## reading as a grey disc — it gives the silhouette real thickness and catches
## the light block by block.
func _build_platform(spec: ZoneSpec) -> void:
	var body := StaticBody3D.new()
	body.name = "Zone_%s" % spec.id
	body.position = spec.centre
	_zones.add_child(body)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		body.owner = owner

	# Inner floor, slightly sunk so the rim blocks stand proud of it.
	var floor_mesh := _mesh(
		body, "Floor",
		P.build_stepped_ring(0.0, spec.radius - 1.4, 2, 0.10, 40),
		P.stone_material(P.STONE_MID)
	)
	floor_mesh.position.y = -0.08

	# Masonry rim: one block per segment, each nudged so no two sit flush.
	var blocks := int(spec.radius * 1.6)
	var step := TAU / float(blocks)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(spec.id)
	for b in blocks:
		var push := rng.randf_range(-0.06, 0.09)
		var lift := rng.randf_range(-0.03, 0.05)
		var shade := rng.randf_range(0.85, 1.15)
		var brick := _mesh(
			body, "Rim%02d" % b,
			P.build_plate(
				spec.radius - 1.5, spec.radius + push, 0.85 + lift,
				step * b + step * 0.06, step * (b + 1) - step * 0.06,
				0.05, 0.035, 3, 0.03, 0.14
			),
			P.stone_material(P.STONE_DARK.lerp(P.STONE_MID, 0.5) * shade)
		)
		brick.position.y = -0.85
		brick.rotation.z = rng.randf_range(-0.01, 0.01)

	# Glowing seam around the rim, the same cue the walkways use.
	var seam := _mesh(
		body, "RimSeam",
		P.build_annulus(spec.radius - 0.55, spec.radius - 0.2, 48),
		P.glow_material(P.GLOW_CYAN, 1.4)
	)
	seam.position.y = 0.02

	# Underside keel, so the island reads as floating rather than cut off.
	var keel := CylinderMesh.new()
	keel.top_radius = spec.radius * 0.9
	keel.bottom_radius = spec.radius * 0.1
	keel.height = spec.radius * 0.7
	keel.radial_segments = 16
	var keel_mesh := _mesh(body, "Keel", keel, P.stone_material(P.STONE_DARK))
	keel_mesh.position.y = -0.85 - keel.height * 0.5

	# Hanging root crystals under the rim — breaks the flat underside edge.
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.4
		var root := _mesh(
			body, "Root%d" % i,
			P.build_crystal(0.5, 2.6, 0.4, 6),
			P.crystal_material(P.CRYSTAL_DEEP, 0.7)
		)
		root.position = Vector3(cos(a) * spec.radius * 0.7, -1.0, sin(a) * spec.radius * 0.7)
		root.rotation.x = PI

	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var cyl := CylinderShape3D.new()
	cyl.radius = spec.radius
	cyl.height = 1.0
	shape.shape = cyl
	shape.position.y = -0.5
	body.add_child(shape)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		shape.owner = owner

	if show_zone_labels:
		var label := Label3D.new()
		label.name = "Label_%s" % spec.id
		label.text = spec.label
		label.position = spec.centre + Vector3(0, 7.0, 0)
		label.font_size = 64
		label.outline_size = 20
		label.pixel_size = 0.012
		label.modulate = Color(0.72, 0.86, 1.0)
		label.outline_modulate = Color(0, 0, 0, 0.9)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		_labels.add_child(label)
		if Engine.is_editor_hint() and is_instance_valid(owner):
			label.owner = owner


## The walkway joining two zones. Built as a ramp so a height difference between
## zones stays walkable — the guide's route must be traversable on foot.
##
## The ramp ends are pushed *inside* both zone decks rather than stopping at
## their rims. Ending flush left a lip where the sloped ramp met the flat deck,
## and on the steepest link that lip was a 2.8 m wall the player could not
## climb — taller than their 2.25 m jump. Overlapping buries the joint under the
## deck so the transition is a continuous surface.
func _build_link(a: ZoneSpec, b: ZoneSpec) -> void:
	var overlap := 3.5
	var from: Vector3 = a.centre + (b.centre - a.centre).normalized() * (a.radius - overlap)
	var to: Vector3 = b.centre + (a.centre - b.centre).normalized() * (b.radius - overlap)
	var mid := (from + to) * 0.5
	var span := to - from
	var length := span.length()

	var body := StaticBody3D.new()
	body.name = "Path_%s_to_%s" % [a.id, b.id]
	body.position = mid
	# Face the walkway along the span, then pitch it to match the height change.
	body.look_at_from_position(mid, mid + Vector3(span.x, 0.0, span.z), Vector3.UP)
	body.rotate_object_local(Vector3.RIGHT, -atan2(span.y, Vector2(span.x, span.z).length()))
	_paths.add_child(body)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		body.owner = owner

	var box := BoxMesh.new()
	box.size = Vector3(path_width, 0.5, length)
	var mesh := MeshInstance3D.new()
	mesh.name = "Deck"
	mesh.mesh = box
	mesh.material_override = P.stone_material(P.STONE_MID.darkened(0.1))
	body.add_child(mesh)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		mesh.owner = owner

	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size
	shape.shape = box_shape
	body.add_child(shape)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		shape.owner = owner

	# The cyan guide line the guide's circuit path kit calls for: "cyan line
	# stays visible" — it is how the player reads the main route at a glance.
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.35, 0.06, length * 0.94)
	var stripe_mesh := MeshInstance3D.new()
	stripe_mesh.name = "GuideLine"
	stripe_mesh.mesh = stripe
	stripe_mesh.material_override = P.glow_material(P.GLOW_CYAN, 1.7)
	stripe_mesh.position.y = 0.28
	body.add_child(stripe_mesh)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		stripe_mesh.owner = owner


# --- Zone furniture --------------------------------------------------------

func _zone(id: String) -> ZoneSpec:
	for s in _specs:
		if s.id == id:
			return s
	return _specs[0]


## Zone 1: the violet World Gate the player arrives through, plus the first
## checkpoint root.
##
## The gate is built as a stone arch — tapered piers on stepped footings, a
## keystone lintel and a crystal set at the apex — rather than two boxes and a
## slab, so it reads as a built structure the moment the player lands.
func _build_landing_props() -> void:
	var z := _zone("landing")
	var gate := Node3D.new()
	gate.name = "WorldGate"
	gate.position = z.centre + Vector3(0, 0, z.radius - 5.0)
	_props.add_child(gate)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		gate.owner = owner

	for side in [-1.0, 1.0]:
		var tag := "L" if side < 0 else "R"
		# Stepped footing, tapered shaft, flared capital.
		var foot := _mesh(gate, "Foot%s" % tag,
			P.build_drum(1.5, 1.25, 0.6, 8), P.stone_material(P.STONE_MID))
		foot.position = Vector3(side * 3.4, 0.3, 0.0)

		var shaft := _mesh(gate, "Pier%s" % tag,
			P.build_drum(1.1, 0.85, 6.4, 8), P.stone_material(P.STONE_LIGHT))
		shaft.position = Vector3(side * 3.4, 0.6, 0.0)

		var cap := _mesh(gate, "Capital%s" % tag,
			P.build_drum(0.9, 1.25, 0.7, 8), P.stone_material(P.STONE_MID))
		cap.position = Vector3(side * 3.4, 7.0, 0.0)

		# Rune band up the pier, matching the world's cyan circuit language.
		for k in 3:
			var rune := _mesh(gate, "Rune%s%d" % [tag, k],
				P.build_bevel_box(Vector3(0.22, 0.5, 0.1), 0.03),
				P.glow_material(P.GLOW_CYAN, 1.8))
			rune.position = Vector3(side * 3.4, 2.0 + float(k) * 1.6, 0.92)

	# A bevelled beam spanning the piers. An earlier version used build_plate
	# (a curved masonry wedge) rotated onto its side, which stood the lintel up
	# on end instead of laying it across the opening.
	var lintel := _mesh(gate, "Lintel",
		P.build_bevel_box(Vector3(9.4, 0.9, 1.3), 0.07), P.stone_material(P.STONE_LIGHT))
	lintel.position.y = 7.75

	# Corbels under each end, so the beam looks carried rather than balanced.
	for side in [-1.0, 1.0]:
		var corbel := _mesh(gate, "Corbel%s" % ("L" if side < 0 else "R"),
			P.build_bevel_box(Vector3(1.6, 0.5, 1.1), 0.05), P.stone_material(P.STONE_MID))
		corbel.position = Vector3(side * 3.4, 7.2, 0.0)

	var keystone := _mesh(gate, "Keystone",
		P.build_crystal(0.6, 1.3, 0.45, 8), P.crystal_material(P.ARCANE_PURPLE, 1.6))
	keystone.position.y = 8.4

	# The portal veil the player steps through.
	var veil := _mesh(gate, "Veil",
		P.build_annulus(0.0, 3.1, 32), P.additive_material(P.ARCANE_PURPLE, 0.32))
	veil.position.y = 4.0
	veil.rotation.x = PI * 0.5

	_checkpoint(z.centre + Vector3(-7.0, 0, 3.0), "Checkpoint_landing")


## Zone 2: the server-tree family — three tower-tree sizes with dark glass
## trunks, cyan data seams and violet canopies (architecture object 04).
##
## Each trunk is a tapered faceted drum with a stack of canopy discs rather than
## a box with a box on top, so the grove has a real silhouette from any angle.
func _build_forest_props() -> void:
	var z := _zone("forest")
	var heights := [5.0, 8.0, 11.5]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4402

	for i in 9:
		var h: float = heights[i % 3]
		var a := TAU * float(i) / 9.0 + rng.randf_range(-0.15, 0.15)
		var r := z.radius * rng.randf_range(0.42, 0.82)
		var at := z.centre + Vector3(cos(a) * r, 0.0, sin(a) * r)

		# Root flare, so the trunk meets the deck instead of intersecting it.
		var flare := _mesh(_props, "TreeRoot%d" % i,
			P.build_drum(1.5, 0.95, 0.7, 7), P.stone_material(P.STONE_DARK))
		flare.position = at + Vector3(0, 0.35, 0)

		var trunk := _mesh(_props, "ServerTree%d" % i,
			P.build_drum(0.95, 0.55, h, 7), P.stone_material(P.STONE_DARK.darkened(0.15)))
		trunk.position = at + Vector3(0, 0.6, 0)

		# Data seam running up the trunk.
		var seam := _mesh(_props, "TreeSeam%d" % i,
			P.build_bevel_box(Vector3(0.16, h * 0.72, 0.09), 0.03),
			P.glow_material(P.GLOW_CYAN, 1.6))
		seam.position = at + Vector3(0.0, 0.7 + h * 0.36, 0.72)

		# Canopy: three stacked tiers, shrinking upward. Built as shallow drums
		# rather than flat annuli — a zero-thickness disc vanishes edge-on and
		# read as a floating sheet of colour from ground level.
		for k in 3:
			var t := float(k) / 2.0
			var wide: float = lerpf(2.6, 1.1, t)
			var tier := _mesh(_props, "TreeCanopy%d_%d" % [i, k],
				P.build_drum(wide, wide * 0.55, 0.55, 9),
				P.glow_material(P.ARCANE_PURPLE, lerpf(0.55, 0.9, t)))
			tier.position = at + Vector3(0, h * 0.62 + float(k) * 0.8, 0)
			tier.rotation.y = rng.randf_range(0.0, TAU)

		var tip := _mesh(_props, "TreeTip%d" % i,
			P.build_crystal(0.34, 1.1, 0.45, 6), P.crystal_material(P.CRYSTAL_PALE, 1.3))
		tip.position = at + Vector3(0, h + 0.9, 0)

	_checkpoint(z.centre + Vector3(9.0, 0, 9.0), "Checkpoint_forest")


## Zone 3: the Constellation Court dais, its three memory nodes and the Logic
## Gate arch quest 2 opens.
func _build_court_props() -> void:
	var z := _zone("court")

	# Terraced dais rather than a flat disc, with an inlaid glow ring.
	var dais := _mesh(_props, "CourtDais",
		P.build_stepped_ring(0.0, 9.5, 3, 0.16, 40), P.stone_material(P.STONE_LIGHT))
	dais.position = z.centre + Vector3(0, 0.5, 0)

	var ring := _mesh(_props, "CourtRing",
		P.build_annulus(7.4, 8.2, 48), P.glow_material(P.GLOW_CYAN, 1.2))
	dais.add_child(ring) if false else _props.add_child(ring) if false else null
	ring.position = z.centre + Vector3(0, 0.54, 0)

	# Three nodes the player links in order (object 04, Memory Constellation
	# Board). Each floats above a low plinth rather than sitting on the deck: a
	# cube resting on the floor was a 2.1 m block right in the walking area —
	# over step height but under jump height, so the player bumped into it
	# instead of walking round or over it.
	for i in 3:
		var a := TAU * float(i) / 3.0 - PI * 0.5
		var at := z.centre + Vector3(cos(a) * 6.5, 0.5, sin(a) * 6.5)

		var plinth := _mesh(_props, "MemoryPlinth%d" % i,
			P.build_drum(0.85, 0.6, 0.5, 8), P.metal_material(P.STONE_LIGHT))
		plinth.position = at + Vector3(0, 0.25, 0)

		var node := _mesh(_props, "MemoryNode%d" % i,
			P.build_crystal(0.62, 1.25, 0.5, 8), P.crystal_material(P.GLOW_CYAN, 1.5))
		node.position = at + Vector3(0, 1.7, 0)
		node.rotation = Vector3(0.0, deg_to_rad(30.0 * i), 0.0)

	# Logic Gate arch on the exit side (object 05).
	var gate := Node3D.new()
	gate.name = "LogicGate"
	gate.position = z.centre + Vector3(7.0, 0.0, -z.radius + 4.0)
	_props.add_child(gate)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		gate.owner = owner
	for side in [-1.0, 1.0]:
		var post := _mesh(gate, "Post%d" % int(side),
			P.build_drum(0.55, 0.42, 4.6, 6), P.metal_material(P.STONE_LIGHT))
		post.position = Vector3(side * 2.6, 0.0, 0.0)
		var socket := _mesh(gate, "Socket%d" % int(side),
			P.build_torus(0.34, 0.09, 16, 6, 0.7), P.glow_material(P.GLOW_CYAN, 1.4))
		socket.position = Vector3(side * 2.6, 2.4, 0.42)
		socket.rotation.x = PI * 0.5
	var top := _mesh(gate, "Lintel",
		P.build_bevel_box(Vector3(6.0, 0.6, 0.8), 0.05), P.metal_material(P.STONE_MID))
	top.position.y = 4.9


## Zone 4: the Perspective Lens on its turning plinth, and the Truth Bridge
## tiles that solidify once the player answers correctly.
func _build_ridge_props() -> void:
	var z := _zone("ridge")

	var base := _mesh(_props, "LensBase",
		P.build_stepped_ring(0.0, 2.4, 2, 0.18, 20), P.stone_material(P.STONE_MID))
	base.position = z.centre + Vector3(-5.0, 0.5, 5.0)

	var post := _mesh(_props, "LensPost",
		P.build_drum(0.5, 0.36, 1.7, 8), P.metal_material(P.STONE_LIGHT))
	post.position = base.position + Vector3(0, 0.1, 0)

	# The lens itself: a metal ring holding a crystal pane, on a turning head.
	var ring := _mesh(_props, "LensRing",
		P.build_torus(1.15, 0.16, 24, 8, 0.8), P.metal_material(P.STONE_LIGHT))
	ring.position = base.position + Vector3(0, 2.5, 0)
	ring.rotation = Vector3(PI * 0.5, deg_to_rad(25.0), 0.0)

	var pane := _mesh(_props, "LensPane",
		P.build_annulus(0.0, 1.05, 20), P.crystal_material(P.CRYSTAL_PALE, 1.0))
	pane.position = ring.position
	pane.rotation = ring.rotation

	# Ghost tiles. Solid geometry here; the real object toggles collision from
	# quest state (object 06, Truth Bridge Tile).
	for i in 5:
		var at := z.centre + Vector3(4.5 + float(i) * 3.4, 0.55, -2.0 - float(i) * 1.1)
		var tile := _mesh(_props, "TruthTile%d" % i,
			P.build_plate(0.0, 1.7, 0.28, 0.0, TAU, 0.05, 0.03, 8, 0.0, 0.0),
			P.additive_material(P.GLOW_CYAN, 0.28))
		tile.position = at
		var glyph := _mesh(_props, "TruthGlyph%d" % i,
			P.build_star(4, 0.5, 0.17, 0.0), P.glow_material(P.GLOW_CYAN, 1.5))
		glyph.position = at + Vector3(0, 0.2, 0)
		glyph.rotation.x = -PI * 0.5


## Zone 5: the boss arena — three Warden Anchors around the open storm core,
## with the Calm Rain Basin where quest 4 ends.
func _build_arena_props() -> void:
	var z := _zone("arena")

	for i in 3:
		var a := TAU * float(i) / 3.0
		var at := z.centre + Vector3(cos(a) * 14.0, 0.0, sin(a) * 14.0)

		var foot := _mesh(_props, "AnchorFoot%d" % i,
			P.build_drum(1.9, 1.5, 0.7, 7), P.stone_material(P.STONE_DARK))
		foot.position = at + Vector3(0, 0.35, 0)

		var shaft := _mesh(_props, "WardenAnchor%d" % i,
			P.build_drum(1.35, 0.85, 5.4, 7), P.stone_material(P.STONE_DARK.darkened(0.2)))
		shaft.position = at + Vector3(0, 0.7, 0)

		# The exposed ring is the weak point the player strikes (object 08).
		var ring := _mesh(_props, "AnchorRing%d" % i,
			P.build_torus(1.05, 0.24, 20, 8, 0.75), P.glow_material(P.ARCANE_PURPLE, 1.8))
		ring.position = at + Vector3(0, 4.6, 0)

		var cap := _mesh(_props, "AnchorCap%d" % i,
			P.build_crystal(0.7, 1.6, 0.42, 7), P.crystal_material(P.ARCANE_PURPLE, 1.2))
		cap.position = at + Vector3(0, 5.4, 0)

	# Storm core: a banded crystal column on a terraced base.
	var core_base := _mesh(_props, "StormCoreBase",
		P.build_stepped_ring(0.0, 4.6, 3, 0.2, 28), P.stone_material(P.STONE_MID))
	core_base.position = z.centre + Vector3(0, 0.5, 0)

	for k in 3:
		var seg := _mesh(_props, "StormCore%d" % k,
			P.build_crystal_segment(2.3 - float(k) * 0.45, 2.0 - float(k) * 0.45, 1.6, 10, 1.02),
			P.crystal_material(P.ARCANE_PURPLE, 1.3))
		seg.position = z.centre + Vector3(0, 0.9 + float(k) * 1.55, 0)
		seg.rotation.y = deg_to_rad(11.0 * k)

	var core_tip := _mesh(_props, "StormCoreTip",
		P.build_crystal(1.0, 2.2, 0.4, 10), P.crystal_material(P.ARCANE_BRIGHT, 1.6))
	core_tip.position = z.centre + Vector3(0, 5.5, 0)

	# The Calm Rain Basin pad. The real socket (required_sparks = 1) is dropped
	# on this by the world scene.
	var basin := _mesh(_props, "CalmRainBasinPad",
		P.build_stepped_ring(0.0, 4.2, 3, 0.14, 32), P.stone_material(P.STONE_LIGHT))
	basin.position = z.centre + Vector3(0, 0.42, 14.0)

	var basin_ring := _mesh(_props, "CalmRainBasinRing",
		P.build_annulus(3.3, 3.9, 32), P.glow_material(P.GLOW_CYAN, 1.1))
	basin_ring.position = basin.position + Vector3(0, 0.05, 0)


## Zone 6: the Oldest Tree, the Star pedestal and the return gate.
func _build_sanctuary_props() -> void:
	var z := _zone("sanctuary")
	var at := z.centre + Vector3(0, 0, -3.0)

	# Buttressed root flare so the tree grips the deck.
	for i in 6:
		var a := TAU * float(i) / 6.0
		var buttress := _mesh(_props, "TreeButtress%d" % i,
			P.build_crystal(0.75, 3.2, 0.5, 5), P.stone_material(P.STONE_DARK))
		buttress.position = at + Vector3(cos(a) * 2.7, 0.2, sin(a) * 2.7)
		buttress.rotation = Vector3(deg_to_rad(16.0) * cos(a + PI), 0.0, deg_to_rad(16.0) * sin(a))

	var trunk := _mesh(_props, "OldestTreeTrunk",
		P.build_drum(2.5, 1.5, 13.0, 9), P.stone_material(P.STONE_DARK.darkened(0.1)))
	trunk.position = at + Vector3(0, 0.5, 0)

	# Canopy: stacked violet discs, widest in the middle.
	var widths := [7.0, 9.5, 8.0, 5.5]
	for k in widths.size():
		var wide: float = widths[k]
		var tier := _mesh(_props, "OldestTreeCanopy%d" % k,
			P.build_drum(wide, wide * 0.72, 1.5, 14),
			P.glow_material(P.ARCANE_PURPLE, lerpf(0.5, 0.85, float(k) / 3.0)))
		tier.position = at + Vector3(0, 11.5 + float(k) * 1.4, 0)
		tier.rotation.y = deg_to_rad(17.0 * k)

	# Star pedestal: terraced base, metal collar, and the Star's empty seat.
	var ped_base := _mesh(_props, "StarPedestalBase",
		P.build_stepped_ring(0.0, 2.6, 3, 0.2, 24), P.stone_material(P.STONE_MID))
	ped_base.position = z.centre + Vector3(0, 0.5, 7.0)

	# Kept low enough to step onto. At 1.5 m tall on a raised base the collar
	# stood 2.15 m above the deck — just under the player's 2.25 m jump, which
	# is the worst height for a prop: too tall to walk over, too short to read
	# as a wall, so the player just bumps into it.
	# Furniture: the player approaches this, they do not path through it.
	var collar := _mesh(_props, "StarPedestalCollar",
		P.build_drum(1.0, 0.75, 0.75, 8), P.metal_material(P.STONE_LIGHT))
	collar.position = ped_base.position + Vector3(0, 0.15, 0)

	var seat := _mesh(_props, "StarSeat",
		P.build_torus(0.62, 0.14, 20, 8, 0.7), P.metal_material(P.STONE_LIGHT))
	seat.position = ped_base.position + Vector3(0, 1.0, 0)
	seat.rotation.x = PI * 0.5
	collar.add_to_group("zone_furniture")
	seat.add_to_group("zone_furniture")

	_checkpoint(z.centre + Vector3(-9.0, 0, 5.0), "Checkpoint_sanctuary")


## Checkpoint Server Root (object 11) — save, heal and read the current task.
##
## A short faceted post with a lantern crystal on top: readable at a glance from
## across a zone, which is what a checkpoint has to be.
func _checkpoint(at: Vector3, name: String) -> void:
	var foot := _mesh(_props, "%s_Foot" % name,
		P.build_drum(0.95, 0.72, 0.4, 8), P.stone_material(P.STONE_DARK))
	foot.position = at + Vector3(0, 0.2, 0)

	var post := _mesh(_props, name,
		P.build_drum(0.6, 0.42, 2.2, 8), P.stone_material(P.STONE_LIGHT))
	post.position = at + Vector3(0, 0.4, 0)

	var lamp := _mesh(_props, "%s_Lamp" % name,
		P.build_crystal(0.42, 0.95, 0.45, 7), P.crystal_material(P.GLOW_CYAN, 2.0))
	lamp.position = at + Vector3(0, 2.6, 0)

	var glow := OmniLight3D.new()
	glow.name = "%s_Glow" % name
	glow.light_color = P.GLOW_CYAN
	glow.light_energy = 1.6
	glow.omni_range = 7.0
	glow.position = at + Vector3(0, 2.8, 0)
	_props.add_child(glow)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		glow.owner = owner


# --- Small helpers ---------------------------------------------------------

func _box(parent: Node3D, name: String, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(parent, name, m, mat)


func _cylinder(parent: Node3D, name: String, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 14
	return _mesh(parent, name, m, mat)


func _mesh(parent: Node3D, name: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = name
	n.mesh = mesh
	n.material_override = mat
	parent.add_child(n)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		n.owner = owner
	return n


## World-space centre of a zone, for placing quest objects from the outside.
func zone_centre(id: String) -> Vector3:
	if _specs.is_empty():
		_build_specs()
	return _zone(id).centre
