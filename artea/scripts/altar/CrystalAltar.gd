@tool
class_name CrystalAltar
extends Node3D

## Procedural crystal altar, assembled from the bricks in AltarParts.gd.
##
## The whole prop is generated in code: drop this script on a Node3D (or
## instance `altar.tscn`) and the geometry rebuilds itself. Nothing is baked to
## disk, so tweaking a radius is a one-line change rather than a re-export.
##
## Structure mirrors the LEGO breakdown — each sub-assembly is its own child
## node, and inside the tiers *every masonry block is its own MeshInstance3D*
## with its own slight rotation and radial offset. That per-block separation is
## what stops the stonework reading as a lathed ring: real courses are laid by
## hand and no two blocks sit perfectly flush.
##
##   CrystalAltar
##   ├── Tiers/        three courses of individually-placed stone blocks
##   ├── Core/         stepped well, glow rings and rune tiles
##   ├── Spires/       rim crystals in claw settings, on faceted sockets
##   ├── GemMount/     multi-ring front bezel with its own claw prongs
##   ├── Medallion/    hanging ring, boss and state emblem
##   └── Effects/      beam, focus orb, burst star and sparkle particles
##
## `charge` drives all three reference states at once (see ChargeLevel), and
## `detail` trades piece count against viewing distance — from a distant
## silhouette up to HERO, where every masonry block, capstone, crystal band and
## star facet is placed as its own piece.

enum ChargeLevel {
	DORMANT,  ## Stone only. No beam, no orb, hollow medallion.
	AWAKENED,  ## Purple orb, thin beam, ringed medallion.
	ASCENDANT,  ## Star burst, wide beam, star medallion.
}

## Detail tiers. Mirrors the resolution ladder: the further the altar is from
## the camera, the fewer blocks and facets it is worth paying for.
enum DetailLevel {
	LOW,  ## Silhouette only — distant props and minimap-scale views.
	MEDIUM,  ## Tier separation and spires readable.
	HIGH,  ## Every block, chamfer, facet and rune. Standard in-world detail.
	HERO,  ## Staggered capstone courses, banded crystals. Close-up/hero detail.
}

@export var charge: ChargeLevel = ChargeLevel.DORMANT:
	set(value):
		charge = value
		if _built:
			_apply_charge()

@export var detail: DetailLevel = DetailLevel.HIGH:
	set(value):
		detail = value
		if _built:
			rebuild()

## Overall scale multiplier. 1.0 gives a ~2 m wide, ~1.1 m tall altar.
@export_range(0.25, 4.0, 0.05) var altar_scale: float = 1.0:
	set(value):
		altar_scale = value
		if _built:
			rebuild()

## Seed for the per-block placement jitter. Change it to re-lay the masonry
## without touching any dimensions — handy for placing several altars in one
## scene without them looking cloned.
@export var masonry_seed: int = 20260815:
	set(value):
		masonry_seed = value
		if _built:
			rebuild()

## Rebuilds the mesh from scratch. Exposed as a button in the inspector so the
## prop can be re-generated after editing AltarParts.gd without reloading.
@export var rebuild_now: bool = false:
	set(_value):
		rebuild_now = false
		if _built:
			rebuild()

## Idle animation — the spires bob and the orb spins. Disabled in-editor.
@export var animate: bool = true

const P := preload("res://scripts/altar/AltarParts.gd")

## Names of the sub-assemblies this script owns. Anything else parented to the
## altar — the collision body, the interact zone, the core light authored in
## crystal_altar.tscn — is left alone by rebuild().
const GENERATED_GROUPS := ["Tiers", "Core", "Spires", "GemMount", "Medallion", "Effects"]

# Authoring dimensions, before `altar_scale` is applied.
const BASE_OUTER := 1.00
const MID_OUTER := 0.86
const TOP_OUTER := 0.74
const TIER_HEIGHT := 0.20
## Outward lean of each tier. Shared with the seam bands so they line up with
## the course's top face rather than overhanging it.
const RING_BEVEL := 0.10

var _tiers: Node3D
var _core: Node3D
var _spires: Node3D
var _gem_mount: Node3D
var _medallion: Node3D
var _effects: Node3D

var _orb: MeshInstance3D
var _burst: Node3D
var _beam: MeshInstance3D
var _beam_inner: MeshInstance3D
var _sparkles: GPUParticles3D
var _core_well: MeshInstance3D
var _emblem: MeshInstance3D
var _seam_materials: Array[StandardMaterial3D] = []
var _rune_materials: Array[StandardMaterial3D] = []
var _crystal_materials: Array[StandardMaterial3D] = []
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()

## False until the first rebuild() completes. Property setters check this so
## that assigning `detail`/`charge` during scene instantiation — which happens
## before _ready() — doesn't try to build into a half-initialised node. The
## first real build comes from _ready(), by which point every exported value is
## already in place.
var _built: bool = false


func _ready() -> void:
	rebuild()


func _process(delta: float) -> void:
	if not animate or Engine.is_editor_hint():
		return
	_time += delta

	# Charged states get a slow orbit plus a breathing pulse; dormant sits still.
	if charge == ChargeLevel.DORMANT:
		return

	if is_instance_valid(_orb):
		_orb.position.y = _orb_height() + sin(_time * 1.6) * 0.03
		_orb.rotate_y(delta * 0.8)
	if is_instance_valid(_burst):
		_burst.rotate_z(delta * 0.5)
		var pulse := 1.0 + sin(_time * 2.2) * 0.08
		_burst.scale = Vector3(pulse, pulse, pulse)
	if is_instance_valid(_beam):
		var flicker := 1.0 + sin(_time * 5.0) * 0.12
		_beam.scale.x = flicker
		_beam.scale.z = flicker
	if is_instance_valid(_beam_inner):
		var core_flicker := 1.0 + sin(_time * 7.3 + 1.1) * 0.18
		_beam_inner.scale.x = core_flicker
		_beam_inner.scale.z = core_flicker


# --- Assembly --------------------------------------------------------------

## Tears down and re-creates every sub-assembly.
func rebuild() -> void:
	for group_name in GENERATED_GROUPS:
		var existing := get_node_or_null(NodePath(group_name))
		if existing:
			# Renamed first so the fresh group can claim the name immediately
			# rather than waiting for the deferred free.
			existing.name = "%s_discarded" % group_name
			existing.queue_free()
	_seam_materials.clear()
	_rune_materials.clear()
	_crystal_materials.clear()
	_rng.seed = masonry_seed

	_tiers = _add_group("Tiers")
	_core = _add_group("Core")
	_spires = _add_group("Spires")
	_gem_mount = _add_group("GemMount")
	_medallion = _add_group("Medallion")
	_effects = _add_group("Effects")

	_build_tiers()
	_build_core()
	_build_spires()
	_build_gem_mount()
	_build_medallion()
	_build_effects()

	scale = Vector3.ONE * altar_scale
	_built = true
	_apply_charge()

func _add_group(group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	add_child(node)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		node.owner = owner
	return node


## Steps 1-3 of the build order: three courses of masonry.
##
## Each course is laid block by block. Every block gets its own mesh, its own
## small radial push and its own tilt, so the course has the irregularity of
## hand-laid stone. Uniform blocks were the single biggest thing making the
## earlier version read as programmer geometry.
func _build_tiers() -> void:
	var blocks := _block_counts()

	# Each course is a shallow ring wall, not a deep wedge: the blocks are only
	# ~0.16 m from inner to outer face. Deep blocks read as vertical slabs and
	# swallow the chamfer detail, which is what makes masonry legible up close.
	var tier_specs := [
		{"inner": BASE_OUTER - 0.17, "outer": BASE_OUTER, "y": 0.0, "count": blocks[0]},
		{"inner": MID_OUTER - 0.16, "outer": MID_OUTER, "y": TIER_HEIGHT, "count": blocks[1]},
		{"inner": TOP_OUTER - 0.15, "outer": TOP_OUTER, "y": TIER_HEIGHT * 2.0, "count": blocks[2]},
	]

	var arc_segs := _arc_segments()

	for i in tier_specs.size():
		var spec: Dictionary = tier_specs[i]

		# Each course is a hollow ring of blocks, so it needs a floor: without
		# one the camera looks straight through the wall into empty space.
		# It stops at the next course's outer radius (or the core well on the
		# top course) — a full disc would cover the recess it is meant to frame.
		var deck_inner: float = 0.40 if i == tier_specs.size() - 1 else float(tier_specs[i + 1].outer) - 0.02
		var deck := _mesh_node(
			"Deck%d" % (i + 1),
			P.build_annulus(deck_inner, spec.inner + 0.01, _ring_segments()),
			P.stone_material(P.STONE_DARK.darkened(0.2)),
			_tiers
		)
		deck.position.y = spec.y + TIER_HEIGHT + _cap_lift()

		# Backing wall behind the masonry. The mortar joints are deliberately
		# wide and undercut, which means you can see *through* them — without a
		# drum sitting just inside the blocks the gaps show the hollow interior
		# and the altar reads as a paper shell. It is inset far enough to stay
		# in shadow, so it reads as darkness between the stones.
		var backing := _mesh_node(
			"Backing%d" % (i + 1),
			P.build_drum(
				float(spec.inner) + 0.026,
				float(spec.inner) + 0.026,
				TIER_HEIGHT + _cap_lift() + 0.01,
				_ring_segments(),
				false
			),
			_backing_material(),
			_tiers
		)
		backing.position.y = spec.y - 0.005
		var course := Node3D.new()
		course.name = "Course%d" % (i + 1)
		_tiers.add_child(course)
		if Engine.is_editor_hint() and is_instance_valid(owner):
			course.owner = owner

		var count: int = spec.count
		var step := TAU / float(count)
		# Mortar gap between neighbouring blocks, as a fraction of the arc.
		var gap := step * 0.055

		for b in count:
			# Per-block variation: a little radial push, a little height, a
			# little tilt. Small numbers — enough to break the lathe look
			# without the course falling apart.
			var push := _rng.randf_range(-0.010, 0.014)
			var lift := _rng.randf_range(-0.006, 0.006)
			var tilt := _rng.randf_range(-0.012, 0.012)
			var shade := _rng.randf_range(0.82, 1.18)

			# Stones are not all the same width. Each block borrows or gives up a
			# little arc at its two ends, so the course reads as individually cut
			# masonry rather than a ring divided into equal slices. Both ends use
			# the *neighbour's* seed so adjacent blocks agree on the joint between
			# them and no overlap or hole opens up.
			var edge_lo := _joint_offset(b, count) * step
			var edge_hi := _joint_offset(b + 1, count) * step

			var mesh := P.build_plate(
				spec.inner,
				spec.outer + push,
				TIER_HEIGHT + lift,
				step * b + edge_lo + gap,
				step * (b + 1) + edge_hi - gap,
				0.022,
				0.016,
				arc_segs,
				0.026,
				0.12
			)
			# Lower courses sit in shadow, upper courses catch the light.
			var base_tint: Color = P.STONE_DARK.lerp(P.STONE_MID, float(i) / 2.0)
			var block := _mesh_node(
				"Block%02d" % b,
				mesh,
				P.stone_material(base_tint * shade),
				course
			)
			block.position.y = spec.y
			block.rotation.z = tilt
			block.rotation.x = _rng.randf_range(-0.008, 0.008)

		# HERO adds a thin capstone course on top of each wall, offset by half a
		# block so the joints stagger like real coursed masonry. This is where
		# most of HERO's extra piece count comes from, and it is the detail that
		# survives a camera pushed right up against the stone.
		if detail == DetailLevel.HERO:
			var cap_count: int = int(spec.count)
			var cap_step := TAU / float(cap_count)
			var cap_gap := cap_step * 0.07
			for b in cap_count:
				var cap_mesh := P.build_plate(
					float(spec.inner) + 0.012,
					float(spec.outer) - 0.014 + _rng.randf_range(-0.004, 0.004),
					0.036,
					cap_step * b + cap_step * 0.5 + cap_gap,
					cap_step * (b + 1) + cap_step * 0.5 - cap_gap,
					0.009,
					0.006,
					arc_segs,
					0.014,
					0.18
				)
				var cap_shade := _rng.randf_range(0.9, 1.2)
				var cap := _mesh_node(
					"Cap%02d" % b,
					cap_mesh,
					P.stone_material(P.STONE_MID * cap_shade),
					course
				)
				cap.position.y = spec.y + TIER_HEIGHT
				cap.rotation.z = _rng.randf_range(-0.006, 0.006)

		# Seam glow: a narrow emissive band running around the top lip of each
		# course. Kept thin — a full-width disc reads as a glowing plate and
		# swamps the stone, which is the opposite of the reference where the
		# light is a hairline between courses.
		if detail != DetailLevel.LOW:
			var seam_mat := P.glow_material(P.GLOW_CYAN, 1.6)
			_seam_materials.append(seam_mat)
			# Matches the block's chamfered top radius so the band sits on the
			# stone instead of overhanging it.
			var band_outer: float = spec.outer * (1.0 - RING_BEVEL)
			var seam := _mesh_node(
				"Course%dSeam" % (i + 1),
				P.build_annulus(band_outer - 0.028, band_outer, _ring_segments()),
				seam_mat,
				_tiers
			)
			# Flush with the block tops, lifted by a hair to beat z-fighting —
			# or above the capstones when HERO has laid a second course.
			var cap_lift: float = 0.036 if detail == DetailLevel.HERO else 0.0
			seam.position.y = spec.y + TIER_HEIGHT + cap_lift + 0.003

	if _is_detailed():
		_build_light_bars()
		_build_rivets()

## The eight light bars set into the mid course's outer wall, each in its own
## recessed housing.
func _build_light_bars() -> void:
	var housing_mesh := P.build_bevel_box(Vector3(0.13, 0.075, 0.028), 0.006)
	var lamp_mesh := P.build_bevel_box(Vector3(0.095, 0.042, 0.022), 0.004)

	for i in 8:
		var angle := TAU * float(i) / 8.0 + PI * 0.125
		var slot := Node3D.new()
		slot.name = "Lamp%d" % i
		slot.position = Vector3(cos(angle) * MID_OUTER * 0.99, TIER_HEIGHT * 1.5, sin(angle) * MID_OUTER * 0.99)
		slot.rotation.y = -angle
		_tiers.add_child(slot)
		if Engine.is_editor_hint() and is_instance_valid(owner):
			slot.owner = owner

		_mesh_node("Housing", housing_mesh, P.metal_material(P.STONE_DARK), slot)
		var lamp_mat := P.glow_material(P.GLOW_CYAN, 2.2)
		_seam_materials.append(lamp_mat)
		var lamp := _mesh_node("Lamp", lamp_mesh, lamp_mat, slot)
		lamp.position.x = 0.008


## Small metal studs punched around the base course. Pure greeble — they cost
## almost nothing and give the eye something to find at close range.
func _build_rivets() -> void:
	var rivet_mesh := P.build_drum(0.012, 0.009, 0.014, 8)
	for i in 24:
		var angle := TAU * float(i) / 24.0
		var rivet := _mesh_node("Rivet%02d" % i, rivet_mesh, P.metal_material(P.STONE_LIGHT), _tiers)
		rivet.position = Vector3(
			cos(angle) * BASE_OUTER * 0.985,
			TIER_HEIGHT * 0.45 + _rng.randf_range(-0.01, 0.01),
			sin(angle) * BASE_OUTER * 0.985
		)
		rivet.rotation = Vector3(deg_to_rad(90.0), 0.0, -angle)


## Step 4: the recessed well in the top face — stepped terraces rather than
## flat discs, so the recess has real depth, plus a ring of rune tiles.
func _build_core() -> void:
	var top_y := _deck_height()
	_core.position.y = top_y

	if detail == DetailLevel.LOW:
		_mesh_node("CoreBowl", P.build_annulus(0.0, 0.40, 20), P.stone_material(P.STONE_DARK), _core)
		return

	# Terraced bowl: four steps dropping toward the middle.
	_mesh_node(
		"CoreBowl",
		P.build_stepped_ring(0.16, 0.40, 4, 0.014, _ring_segments()),
		P.stone_material(P.STONE_DARK),
		_core
	)

	var ring_mat := P.glow_material(P.GLOW_CYAN, 1.4)
	_seam_materials.append(ring_mat)
	var ring := _mesh_node("CoreRing", P.build_annulus(0.26, 0.33, _ring_segments()), ring_mat, _core)
	ring.position.y = -0.002

	# The well is the part that changes colour with charge, so it is kept as a
	# member rather than being fire-and-forget like the rest.
	_core_well = _mesh_node(
		"CoreWell",
		P.build_annulus(0.0, 0.155, _ring_segments()),
		P.glow_material(P.ARCANE_PURPLE, 0.0),
		_core
	)
	_core_well.position.y = -0.056

	if _is_detailed():
		_build_runes()


## Twelve rune tiles set into the terrace around the well. These light with
## the altar, so they are tracked separately from the structural seams.
func _build_runes() -> void:
	var rune_mesh := P.build_bevel_box(Vector3(0.032, 0.008, 0.052), 0.004)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var rune_mat := P.glow_material(P.GLOW_CYAN, 1.0)
		_rune_materials.append(rune_mat)
		var rune := _mesh_node("Rune%02d" % i, rune_mesh, rune_mat, _core)
		# On top of the outermost terrace, clear of the bowl lip — set any
		# further in and the rim hides them completely.
		rune.position = Vector3(cos(angle) * 0.455, 0.004, sin(angle) * 0.455)
		rune.rotation.y = -angle


## Steps 5-6: the two rim crystals, each on a faceted socket and held by a
## ring of claw prongs rather than a plain collar.
func _build_spires() -> void:
	# Stubbier and wider than a "needle" crystal — the reference spires are
	# roughly three times as tall as they are wide, not six.
	var spire_mesh := P.build_crystal(0.105, 0.30, 0.52, _crystal_sides())
	var socket_mesh := P.build_drum(0.115, 0.09, 0.035, _crystal_sides())
	var prong_mesh := P.build_prong(0.026, 0.014, 0.055, 0.3)
	var prong_count := 5 if _is_detailed() else 3

	# Angled forward-left and forward-right to match the reference framing.
	for i in 2:
		var angle := PI * 0.75 if i == 0 else PI * 0.25
		var slot := Node3D.new()
		slot.name = "SpireSlot%d" % i
		# Seated on the top course's ring wall, between its inner and outer face.
		slot.position = Vector3(cos(angle) * 0.665, _deck_height(), sin(angle) * 0.665)
		_spires.add_child(slot)
		if Engine.is_editor_hint() and is_instance_valid(owner):
			slot.owner = owner

		_mesh_node("Socket", socket_mesh, P.metal_material(P.STONE_MID), slot)

		# Claw setting: prongs arranged around the socket, each leaning in.
		if detail != DetailLevel.LOW:
			for p in prong_count:
				var pa := TAU * float(p) / float(prong_count)
				var prong := _mesh_node("Prong%d" % p, prong_mesh, P.metal_material(P.STONE_LIGHT), slot)
				prong.position = Vector3(cos(pa) * 0.072, 0.03, sin(pa) * 0.072)
				prong.rotation.y = -pa + PI * 0.5

		var crystal_mat := P.crystal_material(P.CRYSTAL_PALE, 1.6)
		_crystal_materials.append(crystal_mat)

		# A crystal built as one solid cone reads as a plastic spike. Real quartz
		# grows in stacked zones, so the spire is assembled from separate bands
		# that each taper a little further and twist against the one below —
		# giving the internal cleave lines the reference art shows.
		var spire := Node3D.new()
		spire.name = "Crystal"
		spire.position.y = 0.055
		# Slight outward lean so the pair frames the core instead of standing
		# dead vertical.
		spire.rotation = Vector3(deg_to_rad(-6.0), angle, 0.0)
		slot.add_child(spire)
		if Engine.is_editor_hint() and is_instance_valid(owner):
			spire.owner = owner

		_build_banded_crystal(spire, 0.105, 0.30, crystal_mat)


## Assembles one crystal from a stack of separate growth bands plus a capping
## point.
##
## Each band is its own node, tapering and twisting relative to the one below,
## so the joints show as real cleave lines rather than smooth-shaded creases.
## The number of bands scales with detail — at LOW it collapses to a single
## solid crystal, since the seams are invisible at that range anyway.
func _build_banded_crystal(
	parent: Node3D,
	radius: float,
	height: float,
	material: Material
) -> void:
	var sides := _crystal_sides()

	if detail == DetailLevel.LOW:
		_mesh_node("Solid", P.build_crystal(radius, height, 0.52, sides), material, parent)
		return

	var bands: int = 3 if detail == DetailLevel.MEDIUM else (4 if detail == DetailLevel.HIGH else 6)
	# The bands occupy the lower portion; the faceted point caps the rest.
	var shaft := height * 0.62
	var band_h := shaft / float(bands)

	for b in bands:
		var t0 := float(b) / float(bands)
		var t1 := float(b + 1) / float(bands)
		# A gentle, monotonic taper. An earlier version swelled each band at its
		# own midpoint, which stacked into a row of mushroom caps instead of a
		# crystal — the shaft should narrow steadily and only the joints should
		# show.
		var r0 := radius * lerpf(1.0, 0.72, t0)
		var r1 := radius * lerpf(1.0, 0.72, t1)

		var band := _mesh_node(
			"Band%d" % b,
			P.build_crystal_segment(r0, r1, band_h, sides, 1.012),
			material,
			parent
		)
		band.position.y = band_h * b
		# Each band twists a little against its neighbour so the vertical facet
		# lines break rather than running dead straight up the whole spire.
		band.rotation.y = deg_to_rad(_rng.randf_range(-3.5, 3.5))

	# The point: a full faceted crystal, scaled to sit on top of the stack.
	var tip_r := radius * 0.72
	var tip := _mesh_node(
		"Point",
		P.build_crystal(tip_r, height - shaft, 0.30, sides),
		material,
		parent
	)
	tip.position.y = shaft
	tip.rotation.y = deg_to_rad(_rng.randf_range(-5.0, 5.0))


## Step 7: the bezel and gem set into the front of the base course, built as a
## stack of rings with its own claw setting.
func _build_gem_mount() -> void:
	if detail == DetailLevel.LOW:
		return

	var mount := Node3D.new()
	mount.name = "FrontBezel"
	# Sits proud of the mid course's outer face. Small — an earlier version had
	# this at torus-major 0.115, which made a 23 cm donut that swallowed the
	# whole front of the altar.
	mount.position = Vector3(0.0, TIER_HEIGHT * 1.45, MID_OUTER * 0.99)
	mount.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)
	_gem_mount.add_child(mount)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		mount.owner = owner

	# Two concentric rings instead of one — an outer band and an inner seat.
	_mesh_node("BezelOuter", P.build_torus(0.062, 0.018, 20, 8, 0.7), P.metal_material(P.STONE_MID), mount)
	_mesh_node("BezelInner", P.build_torus(0.044, 0.010, 18, 6, 0.6), P.metal_material(P.STONE_LIGHT), mount)

	if _is_detailed():
		var prong_mesh := P.build_prong(0.014, 0.008, 0.028, 0.35)
		for p in 4:
			var pa := TAU * float(p) / 4.0 + PI * 0.25
			var prong := _mesh_node("Prong%d" % p, prong_mesh, P.metal_material(P.STONE_LIGHT), mount)
			prong.position = Vector3(cos(pa) * 0.042, -0.012, sin(pa) * 0.042)
			prong.rotation.y = -pa + PI * 0.5

	var gem_mat := P.crystal_material(P.CRYSTAL_DEEP, 1.8)
	_crystal_materials.append(gem_mat)
	var gem := _mesh_node("Gem", P.build_crystal(0.040, 0.062, 0.42, _crystal_sides()), gem_mat, mount)
	gem.position.y = -0.014


## Step 8: the medallion hanging below the front lip of the base.
func _build_medallion() -> void:
	if detail == DetailLevel.LOW:
		return

	# Tucked just under the front lip of the base so the ring reads as hanging
	# off the altar rather than floating below and behind it.
	# Hangs below the front lip of the base, tilted to face the camera. Rotated
	# about X so the ring's plane is vertical rather than lying flat.
	_medallion.position = Vector3(0.0, -0.17, BASE_OUTER * 0.80)
	_medallion.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)

	_mesh_node("Band", P.build_torus(0.135, 0.026, 32, 10, 1.0), P.metal_material(P.STONE_MID), _medallion)
	_mesh_node("InnerRim", P.build_torus(0.104, 0.011, 26, 6, 1.0), P.metal_material(P.STONE_LIGHT), _medallion)
	_mesh_node(
		"Face",
		P.build_stepped_ring(0.0, 0.104, 3, 0.005, _ring_segments()),
		P.stone_material(P.STONE_DARK.darkened(0.2)),
		_medallion
	)

	# Emblem geometry is swapped per charge level in _apply_charge().
	_emblem = _mesh_node(
		"Emblem",
		P.build_annulus(0.042, 0.080, 28),
		P.glow_material(P.ARCANE_PURPLE, 2.0),
		_medallion
	)
	_emblem.position.z = 0.012

	if _is_detailed():
		# Studs around the band, matching the rivets on the base course.
		var stud_mesh := P.build_drum(0.008, 0.006, 0.009, 6)
		for i in 12:
			var a := TAU * float(i) / 12.0
			var stud := _mesh_node("Stud%02d" % i, stud_mesh, P.metal_material(P.STONE_LIGHT), _medallion)
			stud.position = Vector3(cos(a) * 0.135, sin(a) * 0.135, 0.022)
			stud.rotation.x = deg_to_rad(-90.0)


## Step 9: beam, orb, burst and sparkles. All built up front and toggled by
## charge level, so switching state never allocates.
func _build_effects() -> void:
	if detail == DetailLevel.LOW:
		return

	var core_y := _deck_height()

	# Beam — a tall thin drum rather than a billboard, so it still reads
	# correctly when the player circles the altar. Two nested shells give the
	# beam a hot core inside a softer halo.
	_beam = _mesh_node(
		"BeamHalo",
		P.build_drum(0.10, 0.042, 0.55, 14, false),
		P.additive_material(P.ARCANE_PURPLE, 0.22),
		_effects
	)
	_beam.position.y = core_y

	_beam_inner = _mesh_node(
		"BeamCore",
		P.build_drum(0.045, 0.018, 0.56, 10, false),
		P.additive_material(P.ARCANE_BRIGHT, 0.4),
		_effects
	)
	_beam_inner.position.y = core_y

	var sphere := SphereMesh.new()
	sphere.radius = 0.085
	sphere.height = 0.17
	sphere.radial_segments = 24
	sphere.rings = 12
	var orb_mat := P.crystal_material(P.ARCANE_PURPLE, 2.4)
	_crystal_materials.append(orb_mat)
	_orb = _mesh_node("FocusOrb", sphere, orb_mat, _effects)
	_orb.position.y = _orb_height()

	# The burst crowns the beam rather than sitting inside it — at the orb's
	# height the star was swallowed by the beam cylinder.
	#
	# It is a container, not a single mesh: the star reads as a solid faceted
	# object only because several parts overlay each other (see _build_burst).
	_burst = Node3D.new()
	_burst.name = "BurstStar"
	_burst.position.y = _orb_height() + 0.16
	_effects.add_child(_burst)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		_burst.owner = owner
	_build_burst(_burst)

	if _is_detailed():
		_build_sparkles(core_y)


## Assembles the four-point burst star from overlapping parts.
##
## The earlier version was a single flat star mesh, which is why it looked like
## a sticker: from any angle off dead-on it collapsed to a line, and it had no
## interior shape at all. This builds it the way the reference reads — as a
## layered object:
##
##   1. a solid faceted gem star, the body that catches light on real facets
##   2. a second copy rotated 45° and scaled down, filling the diagonals
##   3. a bright core gem at the centre where the arms meet
##   4. thin cross flares that extend past the arms into a glare
##
## Each layer is its own node, so they can be tuned or culled independently.
func _build_burst(parent: Node3D) -> void:
	var sides := _crystal_sides()

	# 1. The main body. Solid and faceted rather than additive, so it reads as
	#    an object rather than as a light card.
	# Solid and opaque, NOT emissive. An emissive star clips every facet to the
	# same white and collapses back into a flat silhouette — the exact problem
	# this rebuild exists to fix. The glow comes from the flares and the core
	# behind it; the body itself is a lit object, so its facets stay readable.
	var body_mat := P.toon_base(Color(0.74, 0.70, 0.92))
	body_mat.rim_enabled = true
	body_mat.rim = 0.8
	_mesh_node("Body", P.build_star_gem(4, 0.26, 0.46, 0.34, 0.20), body_mat, parent)

	if detail == DetailLevel.LOW:
		return

	# 2. A smaller star turned 45°, so the silhouette has eight rays and the
	#    gaps between the main arms are not empty.
	# Darker than the body so the diagonals read as behind it, not merged in.
	var inner_mat := P.toon_base(Color(0.42, 0.33, 0.70))
	inner_mat.rim_enabled = true
	inner_mat.rim = 0.7
	var diagonal := _mesh_node(
		"Diagonals", P.build_star_gem(4, 0.17, 0.44, 0.38, 0.24), inner_mat, parent
	)
	diagonal.rotation.z = deg_to_rad(45.0)

	# 3. Core gem: the hot centre the arms radiate from.
	var core_mat := P.glow_material(P.ARCANE_BRIGHT, 1.5)
	var core := _mesh_node(
		"Core", P.build_crystal(0.038, 0.06, 0.5, maxi(6, sides)), core_mat, parent
	)
	core.position.y = -0.03
	core.rotation.x = deg_to_rad(90.0)

	if not _is_detailed():
		return

	# 4. Glare flares — thin additive blades along the two main axes, extending
	#    past the solid arms so the star bleeds light at its tips.
	for i in 2:
		var flare := _mesh_node(
			"Flare%d" % i,
			P.build_star_gem(2, 0.34, 0.05, 0.05, 0.012),
			P.additive_material(P.ARCANE_BRIGHT, 0.16),
			parent
		)
		flare.rotation.z = deg_to_rad(90.0 * i)


## Rising motes around the beam. Only present at HIGH detail — particles are
## the first thing worth cutting at distance.
func _build_sparkles(core_y: float) -> void:
	_sparkles = GPUParticles3D.new()
	_sparkles.name = "Sparkles"
	_sparkles.amount = 36
	_sparkles.lifetime = 2.2
	_sparkles.position.y = core_y + 0.15
	_sparkles.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.22
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.spread = 12.0
	proc.initial_velocity_min = 0.12
	proc.initial_velocity_max = 0.32
	proc.gravity = Vector3(0.0, 0.05, 0.0)
	proc.scale_min = 0.3
	proc.scale_max = 1.0
	proc.color = P.ARCANE_BRIGHT
	_sparkles.process_material = proc

	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.03)
	_sparkles.draw_pass_1 = quad
	# Particle quads are the one additive surface that does want billboarding,
	# so the motes always face the camera instead of turning edge-on.
	var spark_mat := P.additive_material(P.ARCANE_BRIGHT, 0.9)
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_sparkles.material_override = spark_mat

	_effects.add_child(_sparkles)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		_sparkles.owner = owner


# --- State -----------------------------------------------------------------

## Applies the current charge level to the parts that vary between the three
## reference variants: core well, runes, medallion emblem and the FX group.
func _apply_charge() -> void:
	var lit := charge != ChargeLevel.DORMANT
	var ascendant := charge == ChargeLevel.ASCENDANT
	var accent := P.ARCANE_BRIGHT if ascendant else P.ARCANE_PURPLE

	if is_instance_valid(_core_well):
		# The glow materials are UNSHADED, so albedo alone still renders at full
		# brightness with the emission turned off. Dropping the energy is not
		# enough to read as "dark" — the albedo has to go dark with it.
		var mat := _core_well.material_override as StandardMaterial3D
		var well_tint := P.STONE_DARK if not lit else accent
		mat.albedo_color = well_tint
		mat.emission = well_tint
		mat.emission_energy_multiplier = 0.0 if not lit else (3.2 if ascendant else 1.8)

	# Seams warm from cyan toward the arcane accent as the altar charges.
	for mat in _seam_materials:
		var tint := P.GLOW_CYAN if not lit else P.GLOW_CYAN.lerp(accent, 0.55 if ascendant else 0.3)
		mat.albedo_color = tint
		mat.emission = tint
		mat.emission_energy_multiplier = 1.2 if not lit else (2.6 if ascendant else 1.9)

	# Runes stay dark until the altar wakes, then take the accent directly.
	for mat in _rune_materials:
		var tint := P.STONE_DARK if not lit else accent
		mat.albedo_color = tint
		mat.emission = tint
		mat.emission_energy_multiplier = 0.0 if not lit else (3.0 if ascendant else 1.6)

	# The rim crystals pick up the arcane tint as the altar charges.
	# The spire crystals and focus orb brighten with charge. The burst star is
	# deliberately not in this list — its parts carry hand-tuned energies that a
	# single global value would clip to white, erasing the facets.
	for mat in _crystal_materials:
		mat.emission_energy_multiplier = 1.2 if not lit else (2.6 if ascendant else 1.8)

	if is_instance_valid(_emblem):
		# Hollow → double ring → star, matching the three medallion faces.
		match charge:
			ChargeLevel.DORMANT:
				_emblem.mesh = P.build_annulus(0.062, 0.080, 28)
				_emblem.material_override = P.metal_material(P.STONE_MID)
			ChargeLevel.AWAKENED:
				_emblem.mesh = P.build_annulus(0.042, 0.080, 28)
				_emblem.material_override = P.glow_material(P.ARCANE_PURPLE, 2.0)
			ChargeLevel.ASCENDANT:
				_emblem.mesh = P.build_star(4, 0.088, 0.030, 0.008)
				_emblem.material_override = P.glow_material(P.ARCANE_BRIGHT, 2.8)

	for beam in [_beam, _beam_inner]:
		if is_instance_valid(beam):
			beam.visible = lit
			var beam_mat := beam.material_override as StandardMaterial3D
			var is_core: bool = beam == _beam_inner
			var base_alpha := 0.4 if is_core else 0.22
			var beam_tint := P.ARCANE_BRIGHT if is_core else accent
			beam_mat.albedo_color = Color(
				beam_tint.r, beam_tint.g, beam_tint.b,
				base_alpha * (1.45 if ascendant else 1.0)
			)
			beam.scale = Vector3(1.5, 1.3, 1.5) if ascendant else Vector3.ONE

	if is_instance_valid(_orb):
		# The orb is the awakened silhouette; ascendant replaces it with the star.
		_orb.visible = charge == ChargeLevel.AWAKENED

	if is_instance_valid(_burst):
		_burst.visible = ascendant

	if is_instance_valid(_sparkles):
		_sparkles.emitting = lit
		_sparkles.amount = 56 if ascendant else 36

	# The scene's OmniLight3D is authored in crystal_altar.tscn rather than
	# generated here, so it survives rebuild() and is looked up by name.
	var core_light := get_node_or_null(^"CoreLight") as OmniLight3D
	if core_light:
		core_light.light_color = accent
		core_light.light_energy = 0.0 if not lit else (2.4 if ascendant else 1.2)


# --- Helpers ---------------------------------------------------------------

## Masonry block counts per course, thinned out at lower detail levels.
## HERO doubles the course density and adds a fourth sub-course (see
## _build_tiers), which is where most of its piece count comes from.
func _block_counts() -> Array:
	match detail:
		DetailLevel.LOW:
			return [10, 9, 8]
		DetailLevel.MEDIUM:
			return [18, 16, 14]
		DetailLevel.HIGH:
			return [22, 19, 16]
		_:
			# HERO keeps the stones the same size and adds the capstone course
			# instead — doubling the count again just makes them narrow.
			return [30, 26, 22]


## How finely each block's curved wall is subdivided.
func _arc_segments() -> int:
	match detail:
		DetailLevel.LOW:
			return 1
		DetailLevel.MEDIUM:
			return 2
		DetailLevel.HIGH:
			return 4
		_:
			return 6


## Segment count for the flat glow rings and terraces.
func _ring_segments() -> int:
	match detail:
		DetailLevel.LOW:
			return 16
		DetailLevel.MEDIUM:
			return 32
		DetailLevel.HIGH:
			return 64
		_:
			return 96


func _crystal_sides() -> int:
	match detail:
		DetailLevel.LOW:
			return 5
		DetailLevel.MEDIUM:
			return 8
		DetailLevel.HIGH:
			return 14
		_:
			return 20


## Material for the drum that sits behind the masonry.
##
## Culling is disabled because the drum is only ever seen edge-on through a
## mortar joint, which means the camera looks at its *inside* — with normal
## back-face culling those faces are invisible and the gap still shows through.
func _backing_material() -> StandardMaterial3D:
	var mat := P.stone_material(P.STONE_DARK.darkened(0.15))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## How far joint `index` is nudged from its even position, as a fraction of one
## block's arc.
##
## Two neighbouring blocks share a joint, so both must compute the same offset
## for it or they will overlap or leave a hole. Drawing from `_rng` per block
## cannot do that — the value has to be a pure function of the joint index, so
## this hashes the index (and the masonry seed) instead. Joint 0 is pinned so
## the ring still closes exactly.
func _joint_offset(index: int, count: int) -> float:
	if index <= 0 or index >= count:
		return 0.0
	var h := hash(Vector2i(index, masonry_seed))
	# Hash to a stable -0.5..0.5, then damp so stones vary by at most ~±22% of a
	# block width — enough to look hand-cut without any stone becoming a sliver.
	return (float(h % 1000) / 1000.0 - 0.5) * 0.44


## True for the detail levels that get the full greeble pass.
func _is_detailed() -> bool:
	return detail >= DetailLevel.HIGH


## Extra height added by HERO's staggered capstone course. Everything that sits
## on top of a wall — decks, the core, the spire sockets — has to clear it.
func _cap_lift() -> float:
	return 0.036 if detail == DetailLevel.HERO else 0.0


## Y of the finished top surface, capstones included.
func _deck_height() -> float:
	return TIER_HEIGHT * 3.0 + _cap_lift()


func _orb_height() -> float:
	return _deck_height() + 0.52


func _mesh_node(
	node_name: String,
	mesh: Mesh,
	material: Material,
	parent: Node3D
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	if Engine.is_editor_hint() and is_instance_valid(owner):
		node.owner = owner
	return node
