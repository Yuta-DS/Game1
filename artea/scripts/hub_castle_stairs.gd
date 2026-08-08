# A climbable stone tower and spiral stair reaching the floating castle.
#
# The castle hangs at Y=65.5 with its spire pointing down, over ground that
# runs 35-42 m. That is a 25-30 m gap with nothing to climb, so the castle
# reads as scenery rather than somewhere the player can go.
#
# The route is built as real architecture rather than a ribbon of floating
# steps: a tapered stone tower rises out of the hillside, and the stair winds
# up its outside face with each step anchored into the shaft. Every step has
# collision, so the player runs up it the same way they walk anywhere else in
# the hub — no teleport, no invisible ramp.
#
# Built at runtime like hub_magitech.gd and aether_atlas.gd, so
# New_Hub_World.tscn stays untouched and the whole structure can be removed by
# deleting one node.
extends Node3D

# Matches building_castle_red2 in New_Hub_World.tscn.
const CASTLE_XZ := Vector2(-51.4, 27.41)
const CASTLE_BASE_Y := 65.49

# The imported castle's real door is on local +Z, which becomes world +X after
# the scene's 90-degree rotation. The previous bridge aimed at the castle origin
# and ended underneath its solid centre instead of at the visible orange door.
const CASTLE_DOOR := Vector3(-39.8, 65.8, 27.41)

# The stair stops short of the castle so it still reads as floating rather
# than resting on the structure.
const LANDING_GAP := 3.5

# The tower is offset from the castle's axis: the castle's spire hangs down
# the centre line, so a shaft directly beneath it would collide. Standing it
# to one side also gives the climb a silhouette from the village.
const TOWER_OFFSET := Vector2(17.0, 9.0)

const TOWER_TOP_RADIUS := 3.0
const TOWER_BOTTOM_RADIUS := 4.0
const TOWER_SIDES := 8            # octagonal, matching the village towers

# Stair geometry.
#
# These numbers are a walkable surface first and a silhouette second. The player
# capsule is 0.5 m in radius, so the tread has to stay clear of the shaft for
# its whole height or the climb pinches: the previous build had a 6.4 m bottom
# radius on a shaft the stair orbited at 5.6 m, so the tower literally swallowed
# the lower flight and the player wedged against it a few steps up.
#
# Invariant to preserve when tuning: the tread's inner edge
# (STAIR_RADIUS - STEP_WIDTH/2) must stay outside TOWER_BOTTOM_RADIUS with room
# for the capsule. 6.5 - 1.9 = 4.6 against a 4.0 shaft leaves 0.6 m of margin.
const STAIR_RADIUS := 6.5
const STEP_WIDTH := 3.8
const STEP_DEPTH := 1.6

# Rise per tread. Kept well under the controller's MAX_STEP_HEIGHT (0.65) so
# every step is climbed by walking, never by jumping.
const STEP_RISE := 0.3
const TURNS := 3.0

# Derived from the climb height rather than fixed, so the rise per tread stays
# constant no matter how far the castle sits above the ground. Solved in
# _build_stair() once the true height is known.
var _step_count := 96

const BRIDGE_SEGMENTS := 10       # continuous walkway from tower to castle
const BRIDGE_WIDTH := 4.2

const STONE_LIGHT := Color(0.86, 0.82, 0.70)
const STONE_DARK := Color(0.66, 0.60, 0.50)
const ROOF_RED := Color(0.79, 0.25, 0.20)   # matches the village roofs
const RAIL_GLOW := Color(1.00, 0.72, 0.30)  # matches the castle lantern


func _ready() -> void:
	# Terrain and the castle settle first; building after a frame keeps the
	# tower aligned with where they actually ended up.
	await get_tree().process_frame
	await get_tree().physics_frame
	_build()

	# proton_scatter repopulates its output asynchronously and finishes after
	# this node's first frames, so a single clearing pass during _build() gets
	# overwritten and the offending tree grows straight back through the stair.
	# Sweep again once the scatter settles.
	for _i in 4:
		await get_tree().process_frame
		await get_tree().physics_frame
	_clear_obstructions(Vector2(CASTLE_XZ.x + TOWER_OFFSET.x, CASTLE_XZ.y + TOWER_OFFSET.y))


func _build() -> void:
	var rig := Node3D.new()
	rig.name = "CastleStair"
	add_child(rig)
	# Transforms go on AFTER add_child — setting them before the node is in the
	# tree loses them, which is what left the old district paths standing on end
	# instead of lying flat.
	rig.global_position = Vector3(CASTLE_XZ.x, 0.0, CASTLE_XZ.y)

	var base := Vector2(CASTLE_XZ.x + TOWER_OFFSET.x, CASTLE_XZ.y + TOWER_OFFSET.y)
	var ground := _ground_at(base.x, base.y)
	var top_y := CASTLE_BASE_Y - LANDING_GAP

	_clear_obstructions(base)
	_build_tower(rig, base, ground, top_y)
	_build_stair(rig, base, ground, top_y)
	_build_crown(rig, base, top_y)
	_build_bridge(rig, base, top_y)


# The hillside is dressed with scattered trees and rocks (proton_scatter), which
# know nothing about a stair that is created at runtime. A single scatter tree
# growing through the spiral is enough to stop the climb dead — the player walks
# into an invisible-looking trunk a few steps up and simply cannot pass.
#
# Rather than hand-editing the scatter output, remove anything solid standing
# inside the stair's footprint. Done before the stair is built so the geometry
# below is guaranteed a clear column.
func _clear_obstructions(base: Vector2) -> void:
	# A little wider than the treads so overhanging canopies go too.
	var clear_radius := STAIR_RADIUS + STEP_WIDTH * 0.5 + 1.5
	for body in _solid_bodies_near(get_tree().get_root(), base, clear_radius):
		body.queue_free()


func _solid_bodies_near(node: Node, base: Vector2, radius: float) -> Array[Node3D]:
	var hits: Array[Node3D] = []
	for child in node.get_children():
		# Never touch the stair's own parts, or the castle it leads to.
		if child == self:
			continue
		if child is StaticBody3D and child.get_parent() is Node3D:
			var visual: Node3D = child.get_parent()
			var offset := Vector2(visual.global_position.x - base.x, visual.global_position.z - base.y)
			if offset.length() < radius and visual.global_position.y < CASTLE_BASE_Y:
				hits.append(visual)
				continue
		hits.append_array(_solid_bodies_near(child, base, radius))
	return hits


# The shaft the stair is cut into. Sunk below ground level so it grows out of
# the hillside instead of sitting on it.
func _build_tower(parent: Node3D, base: Vector2, ground: float, top_y: float) -> void:
	var height := top_y - ground + 6.0
	var shaft := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = TOWER_TOP_RADIUS
	mesh.bottom_radius = TOWER_BOTTOM_RADIUS
	mesh.height = height
	mesh.radial_segments = TOWER_SIDES
	shaft.mesh = mesh
	shaft.material_override = _stone(STONE_LIGHT)
	parent.add_child(shaft)
	shaft.global_position = Vector3(base.x, ground - 5.0 + height * 0.5, base.y)

	var body := StaticBody3D.new()
	shaft.add_child(body)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	# CylinderShape3D cannot taper, so this one shape has to stand in for a cone.
	# Sizing it to the *bottom* radius would push a 4 m wall right through the
	# inner edge of every tread — the tread's inner edge sits at 4.6 m, leaving
	# 0.6 m of walkway against a 1.0 m wide capsule, which is exactly where the
	# climb jammed. Sizing to the narrower top radius keeps the full tread walkable
	# for the whole height; the visual flare at the base is decorative and sits
	# below the first step, where the player never walks.
	cyl.radius = TOWER_TOP_RADIUS
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)

	# Banded courses break up the shaft the way the village towers are banded.
	var bands := int(height / 7.0)
	for i in range(1, bands + 1):
		var band := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = TOWER_BOTTOM_RADIUS - (TOWER_BOTTOM_RADIUS - TOWER_TOP_RADIUS) * (float(i) / float(bands + 1)) + 0.25
		bm.bottom_radius = bm.top_radius + 0.15
		bm.height = 0.5
		bm.radial_segments = TOWER_SIDES
		band.mesh = bm
		band.material_override = _stone(STONE_DARK)
		parent.add_child(band)
		band.global_position = Vector3(base.x, ground - 4.0 + height * (float(i) / float(bands + 1)), base.y)


# The spiral itself: a tread plus a riser per step, hugging the shaft.
func _build_stair(parent: Node3D, base: Vector2, ground: float, top_y: float) -> void:
	var light := _stone(STONE_LIGHT)
	var dark := _stone(STONE_DARK)
	var start_angle := atan2(CASTLE_XZ.y - base.y, CASTLE_XZ.x - base.x) + PI

	# Derive the tread count from the actual climb so the rise per step stays at
	# STEP_RISE regardless of terrain height. Hard-coding 96 steps meant the rise
	# silently changed with the ground, and on tall ground it exceeded what the
	# controller can step over — the stair became unclimbable by arithmetic.
	var climb := top_y - (ground + 0.4)
	_step_count = maxi(2, int(ceil(climb / STEP_RISE)))

	# Treads must overlap along the arc, or the capsule drops into the wedge
	# between two rotated boxes. Widen the tread until consecutive centres are
	# closer together than the box is deep.
	var arc_step: float = (TAU * TURNS * STAIR_RADIUS) / float(_step_count)
	var tread_depth: float = maxf(STEP_DEPTH, arc_step * 1.6)

	for i in _step_count:
		var t := float(i) / float(_step_count - 1)
		var angle := start_angle + t * TAU * TURNS
		var y: float = lerpf(ground + 0.4, top_y, t)
		var pos := Vector3(base.x + cos(angle) * STAIR_RADIUS, y, base.y + sin(angle) * STAIR_RADIUS)

		# Tread — the surface the player runs on.
		var tread := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(STEP_WIDTH, 0.34, tread_depth)
		tread.mesh = tm
		tread.material_override = light if i % 2 == 0 else dark
		parent.add_child(tread)
		tread.global_position = pos
		tread.rotation.y = -angle
		_add_box_body(tread, tm.size)

		# Riser — the vertical face under the tread. Without this the stair
		# reads as floating planks instead of steps.
		var riser := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(STEP_WIDTH, STEP_RISE + 0.3, 0.3)
		riser.mesh = rm
		riser.material_override = dark
		parent.add_child(riser)
		riser.global_position = pos + Vector3(0.0, -0.3, 0.0)
		riser.rotation.y = -angle

		# Outer parapet. This one is solid: a 30 m spiral with a decorative-only
		# rail is a fall waiting to happen, and the climb reads as tense rather
		# than triumphant when a sidestep ends the run.
		var rail := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.34, 1.3, tread_depth + 0.15)
		rail.mesh = wm
		rail.material_override = light
		parent.add_child(rail)
		rail.global_position = Vector3(
			base.x + cos(angle) * (STAIR_RADIUS + STEP_WIDTH * 0.5),
			y + 0.75,
			base.y + sin(angle) * (STAIR_RADIUS + STEP_WIDTH * 0.5))
		rail.rotation.y = -angle
		_add_box_body(rail, wm.size)

		if i % 12 == 0:
			_add_lantern(parent, base, angle, y)


# Battlements and a red roof cap, so the tower top matches the village towers.
func _build_crown(parent: Node3D, base: Vector2, top_y: float) -> void:
	var deck := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = TOWER_TOP_RADIUS + 1.6
	dm.bottom_radius = TOWER_TOP_RADIUS + 1.2
	dm.height = 0.7
	dm.radial_segments = TOWER_SIDES
	deck.mesh = dm
	deck.material_override = _stone(STONE_LIGHT)
	parent.add_child(deck)
	deck.global_position = Vector3(base.x, top_y + 0.5, base.y)
	var body := StaticBody3D.new()
	deck.add_child(body)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = TOWER_TOP_RADIUS + 1.6
	cyl.height = 0.7
	shape.shape = cyl
	body.add_child(shape)

	for i in TOWER_SIDES:
		var angle := TAU * float(i) / float(TOWER_SIDES)
		var merlon := MeshInstance3D.new()
		var mm := BoxMesh.new()
		mm.size = Vector3(1.5, 1.4, 0.7)
		merlon.mesh = mm
		merlon.material_override = _stone(STONE_LIGHT)
		parent.add_child(merlon)
		merlon.global_position = Vector3(
			base.x + cos(angle) * (TOWER_TOP_RADIUS + 1.1),
			top_y + 1.5,
			base.y + sin(angle) * (TOWER_TOP_RADIUS + 1.1))
		merlon.rotation.y = -angle

	# A small red pennant, echoing the castle's banners.
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.09
	pm.bottom_radius = 0.09
	pm.height = 3.2
	pole.mesh = pm
	pole.material_override = _stone(STONE_DARK)
	parent.add_child(pole)
	pole.global_position = Vector3(base.x, top_y + 2.6, base.y)

	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.6, 0.9, 0.08)
	flag.mesh = fm
	var red := StandardMaterial3D.new()
	red.albedo_color = ROOF_RED
	red.roughness = 0.9
	flag.material_override = red
	parent.add_child(flag)
	flag.global_position = Vector3(base.x + 0.8, top_y + 3.6, base.y)


# A continuous walkway from the tower deck to the castle-side landing. The old
# version aimed each box along Z and then rotated it another 90 degrees around
# X; that stood every plank upright and produced the stack of blocks visible in
# the bug screenshot. It also stopped at 72% of the span, leaving a real gap.
func _build_bridge(parent: Node3D, base: Vector2, top_y: float) -> void:
	var target := CASTLE_DOOR
	var start := Vector3(base.x, top_y + 0.9, base.y)
	var light := _stone(STONE_LIGHT)
	var dark := _stone(STONE_DARK)
	var brass := _metal(Color(0.76, 0.52, 0.20))
	var glow := _glow(RAIL_GLOW)
	var span := start.distance_to(target)
	var direction := (target - start).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	var segment_length := span / float(BRIDGE_SEGMENTS)

	for i in BRIDGE_SEGMENTS:
		var t := (float(i) + 0.5) / float(BRIDGE_SEGMENTS)
		var p := start.lerp(target, t)
		var plank := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(BRIDGE_WIDTH, 0.38, segment_length + 0.22)
		plank.mesh = mesh
		plank.material_override = light if i % 2 == 0 else dark
		parent.add_child(plank)
		plank.global_position = p
		plank.look_at(target, Vector3.UP)
		_add_box_body(plank, mesh.size)

		# Brass guard rails make the bridge safe and carry the same engineered
		# language as the trains. Short pieces follow the slope without gaps.
		for side_sign in [-1.0, 1.0]:
			var signed_side: float = side_sign
			var rail_pos: Vector3 = p + side * signed_side * (BRIDGE_WIDTH * 0.5 - 0.16)
			rail_pos.y += 1.0
			var rail := _oriented_box(parent,
				Vector3(0.18, 0.18, segment_length + 0.25), rail_pos, target, brass)
			_add_box_body(rail, Vector3(0.18, 0.18, segment_length + 0.25))

			# A post on every other segment keeps the rail connected to the deck.
			if i % 2 == 0:
				var post_pos: Vector3 = p + side * signed_side * (BRIDGE_WIDTH * 0.5 - 0.16)
				post_pos.y += 0.48
				_oriented_box(parent, Vector3(0.2, 1.15, 0.2), post_pos, target, brass)

		# A luminous centre conductor visually explains how the floating castle
		# and sky trains share power.
		var conduit_pos := p + Vector3(0.0, 0.23, 0.0)
		_oriented_box(parent, Vector3(0.16, 0.06, segment_length + 0.24),
			conduit_pos, target, glow)

	# Broad end-cap prevents the player from falling through a rounding gap
	# where the last segmented plank meets the castle collision.
	var landing := MeshInstance3D.new()
	var landing_mesh := CylinderMesh.new()
	landing_mesh.top_radius = 3.2
	landing_mesh.bottom_radius = 3.45
	landing_mesh.height = 0.48
	landing_mesh.radial_segments = 8
	landing.mesh = landing_mesh
	landing.material_override = light
	parent.add_child(landing)
	landing.global_position = target + direction * 0.5
	var landing_body := StaticBody3D.new()
	landing.add_child(landing_body)
	var landing_shape := CollisionShape3D.new()
	var landing_cylinder := CylinderShape3D.new()
	landing_cylinder.radius = 3.2
	landing_cylinder.height = 0.48
	landing_shape.shape = landing_cylinder
	landing_body.add_child(landing_shape)

	var beacon := OmniLight3D.new()
	beacon.light_color = RAIL_GLOW
	beacon.light_energy = 1.7
	beacon.omni_range = 10.0
	beacon.shadow_enabled = false
	parent.add_child(beacon)
	beacon.global_position = target + Vector3(0.0, 1.4, 0.0)


func _oriented_box(parent: Node3D, size: Vector3, position: Vector3,
		target: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = material
	parent.add_child(part)
	part.global_position = position
	part.look_at(target, Vector3.UP)
	return part


func _add_lantern(parent: Node3D, base: Vector2, angle: float, y: float) -> void:
	var r := STAIR_RADIUS + STEP_WIDTH * 0.5
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	sphere.radial_segments = 6
	sphere.rings = 3
	bulb.mesh = sphere

	var glow := StandardMaterial3D.new()
	glow.albedo_color = RAIL_GLOW
	glow.emission_enabled = true
	glow.emission = RAIL_GLOW
	glow.emission_energy_multiplier = 2.0
	bulb.material_override = glow
	parent.add_child(bulb)
	bulb.global_position = Vector3(base.x + cos(angle) * r, y + 1.5, base.y + sin(angle) * r)

	var lamp := OmniLight3D.new()
	lamp.light_color = RAIL_GLOW
	lamp.light_energy = 1.2
	lamp.omni_range = 9.0
	lamp.shadow_enabled = false
	bulb.add_child(lamp)


func _ground_at(x: float, z: float) -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, 400.0, z), Vector3(x, -100.0, z))
	var hit := space.intersect_ray(query)
	return hit.position.y if hit.has("position") else 35.5


func _add_box_body(part: MeshInstance3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	part.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)


func _stone(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	return material


func _metal(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = 0.82
	material.roughness = 0.3
	return material


func _glow(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 1.8
	material.roughness = 0.25
	return material
