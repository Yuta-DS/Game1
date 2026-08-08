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

# The stair stops short of the castle so it still reads as floating rather
# than resting on the structure.
const LANDING_GAP := 3.5

# The tower is offset from the castle's axis: the castle's spire hangs down
# the centre line, so a shaft directly beneath it would collide. Standing it
# to one side also gives the climb a silhouette from the village.
const TOWER_OFFSET := Vector2(17.0, 9.0)

const TOWER_TOP_RADIUS := 4.2
const TOWER_BOTTOM_RADIUS := 6.4
const TOWER_SIDES := 8            # octagonal, matching the village towers

# Stair geometry. Steps wrap the tower shaft closely so they read as cut into
# it rather than hovering beside it.
const STAIR_RADIUS := 5.6
const STEP_COUNT := 96
const STEP_WIDTH := 3.4
const STEP_DEPTH := 1.5
const STEP_RISE := 0.42           # visible riser under each tread
const TURNS := 3.0

const BRIDGE_SEGMENTS := 7        # walkway from tower top across to the castle

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

	_build_tower(rig, base, ground, top_y)
	_build_stair(rig, base, ground, top_y)
	_build_crown(rig, base, top_y)
	_build_bridge(rig, base, top_y)


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

	for i in STEP_COUNT:
		var t := float(i) / float(STEP_COUNT - 1)
		var angle := start_angle + t * TAU * TURNS
		var y: float = lerpf(ground + 0.4, top_y, t)
		var pos := Vector3(base.x + cos(angle) * STAIR_RADIUS, y, base.y + sin(angle) * STAIR_RADIUS)

		# Tread — the surface the player runs on.
		var tread := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(STEP_WIDTH, 0.34, STEP_DEPTH)
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

		# Outer parapet, so the climb feels enclosed rather than exposed.
		var rail := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.34, 1.0, STEP_DEPTH + 0.15)
		rail.mesh = wm
		rail.material_override = light
		parent.add_child(rail)
		rail.global_position = Vector3(
			base.x + cos(angle) * (STAIR_RADIUS + STEP_WIDTH * 0.5),
			y + 0.6,
			base.y + sin(angle) * (STAIR_RADIUS + STEP_WIDTH * 0.5))
		rail.rotation.y = -angle

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


# A short walkway from the tower deck toward the castle underside, so the climb
# visibly arrives somewhere.
func _build_bridge(parent: Node3D, base: Vector2, top_y: float) -> void:
	var target := Vector3(CASTLE_XZ.x, CASTLE_BASE_Y - 1.0, CASTLE_XZ.y)
	var start := Vector3(base.x, top_y + 0.9, base.y)
	var light := _stone(STONE_LIGHT)
	var dark := _stone(STONE_DARK)

	for i in BRIDGE_SEGMENTS:
		var t := (float(i) + 0.5) / float(BRIDGE_SEGMENTS)
		var p := start.lerp(target, t * 0.72)
		var plank := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(3.0, 0.34, (start.distance_to(target) * 0.72) / float(BRIDGE_SEGMENTS) + 0.3)
		plank.mesh = mesh
		plank.material_override = light if i % 2 == 0 else dark
		parent.add_child(plank)
		plank.global_position = p
		plank.look_at(target, Vector3.UP)
		plank.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		_add_box_body(plank, mesh.size)


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
