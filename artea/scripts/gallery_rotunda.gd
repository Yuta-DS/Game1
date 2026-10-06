@tool
extends Node3D
## The Art Castle gallery hall: an oval rotunda under a glass sky roof, after
## the Musée de l'Orangerie's Water Lilies rooms, dressed in the same ivory
## limestone, gold trim, teal light and slate spires as the castle front gate.
##
## Everything is generated when the node enters the tree, in the editor as well
## as in game, so canvases can be arranged against the real walls. None of the
## generated nodes has an owner, so none of it is saved into the scene.
##
## The entrance faces +z. Its threshold is global z=20, where the Castle-Galaxy
## approach bridge begins, and it is centred on x=0 to meet that bridge.

const CENTRE := Vector3(0.0, 0.0, -18.0)
const RADIUS_X := 64.0          # inner wall face, east-west
const RADIUS_Z := 38.0          # inner wall face, north-south
const WALL_THICKNESS := 2.0
const WALL_HEIGHT := 17.0
const FLOOR_TOP := 0.25
const DOME_RISE := 12.0
# Wall sconces hung between the paintings (see _build_lighting for the light
# budget). Every sconce glows; only every other one casts light.
const LAMP_HEIGHT := 9.5
const LAMP_SCALE := 2.0
# Amber rather than the light colour itself: the ivory walls are so bright that
# a near-white globe or halo disappears against them.
const LAMP_GLASS_COLOR := Color("ffb040")
const LAMP_FALLBACK_COUNT := 11  # used when no paintings hang in the room
const LAMP_LIGHT_LIMIT := 6
const LAMP_RANGE := 24.0
const LAMP_ENERGY := 1.1
const LAMP_COLOR := Color("ffd9a0")
const SEGMENTS := 128
const DOME_RINGS := 12
const DOME_RIBS := 24
const DOME_LEDGE := 1.6

const ENTRANCE_FRONT_Z := 20.0  # the approach bridge starts exactly here
const ENTRANCE_BACK_Z := 14.0
const ENTRANCE_HALF_WIDTH := 16.0
const ENTRANCE_HEIGHT := 23.0
const DOOR_HALF_WIDTH := 7.0
const DOOR_HEIGHT := 16.0
const TOWER_X := 19.5
const TOWER_SIZE := 7.0
const TOWER_HEIGHT := 27.0

var _materials := {}


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		if child.owner == null:
			remove_child(child)
			child.queue_free()
	_build_materials()

	var interior := SurfaceTool.new()
	var stone := SurfaceTool.new()
	var stone_shadow := SurfaceTool.new()
	var gold := SurfaceTool.new()
	var glow := SurfaceTool.new()
	var glass := SurfaceTool.new()
	var slate := SurfaceTool.new()
	var floor_tiles := SurfaceTool.new()
	var carpet := SurfaceTool.new()
	var velvet := SurfaceTool.new()
	var wood := SurfaceTool.new()
	for st in [interior, stone, stone_shadow, gold, glow, glass, slate,
			floor_tiles, carpet, velvet, wood]:
		(st as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)

	_build_oval_walls(interior, stone, stone_shadow, gold, glow)
	_build_sky_roof(glass, gold, slate, glow)
	_build_entrance(stone, stone_shadow, gold, glow, slate, interior)
	_build_floor(floor_tiles, carpet, gold, glow, stone)
	_place_existing_paintings_on_wall()
	_build_bench(velvet, wood, gold)

	_emit_mesh("InteriorWalls", interior, _materials.interior)
	_emit_mesh("ExteriorStone", stone, _materials.stone)
	_emit_mesh("ExteriorStoneShadow", stone_shadow, _materials.stone_shadow)
	_emit_mesh("GoldTrim", gold, _materials.gold)
	_emit_mesh("TealLight", glow, _materials.teal)
	_emit_mesh("SkyRoofGlass", glass, _materials.glass, false)
	_emit_mesh("SlateRoofs", slate, _materials.slate)
	_emit_mesh("Floor", floor_tiles, _materials.floor)
	_emit_mesh("CarpetRunner", carpet, _materials.carpet)
	_emit_mesh("BenchCushion", velvet, _materials.velvet)
	_emit_mesh("BenchBase", wood, _materials.wood)

	_build_collision()
	_build_signage()
	_build_lighting()


func _place_existing_paintings_on_wall() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if not child is Sprite3D or not str(child.name).begins_with("Frame_"):
			continue
		var frame := child as Node3D
		var rel_x := frame.position.x - CENTRE.x
		var normalized_x := clampf(rel_x / RADIUS_X, -0.985, 0.985)
		var normalized_z := -sqrt(maxf(0.0, 0.985 * 0.985 - normalized_x * normalized_x))
		var wall_position := CENTRE + Vector3(rel_x, frame.position.y - CENTRE.y,
				normalized_z * RADIUS_Z)
		frame.position = wall_position
		var local_offset := wall_position - CENTRE
		var inward: Vector3 = Vector3(-local_offset.x / (RADIUS_X * RADIUS_X), 0.0,
				-local_offset.z / (RADIUS_Z * RADIUS_Z)).normalized()
		frame.global_basis = Basis(Vector3(inward.z, 0.0, -inward.x), Vector3.UP, inward)


# --- Materials --------------------------------------------------------------

func _build_materials() -> void:
	# Same palette as art_castle_floating_world.gd's gate and passage.
	_materials.interior = _make_material(Color("ebe4d6"), 0.9)
	_materials.stone = _make_material(Color("ded9cc"), 0.9)
	_materials.stone_shadow = _make_material(Color("a9a79f"), 0.94)
	_materials.gold = _make_glow(Color("f2c55e"), 0.35)
	_materials.gold.metallic = 0.6
	_materials.gold.roughness = 0.35
	_materials.teal = _make_glow(Color("65e6ef"), 0.82)
	_materials.slate = _make_material(Color("344c64"), 0.66)
	_materials.carpet = _make_material(Color("771422"), 0.95)
	_materials.velvet = _make_material(Color("2f5d6b"), 0.92)
	_materials.wood = _make_material(Color("8a5d3b"), 0.8)

	var glass := _make_material(Color(0.78, 0.92, 1.0, 0.16), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.metallic = 0.2
	glass.emission_enabled = true
	glass.emission = Color(0.55, 0.85, 1.0)
	glass.emission_energy_multiplier = 0.08
	_materials.glass = glass

	# Large pale limestone flags with fine joints, one texture tile per 4 m.
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var base := Color("e8e2d6")
	var joint := Color("c9c1b1")
	for y in 128:
		for x in 128:
			var on_joint := x % 64 <= 1 or y % 64 <= 1
			var veining := 0.018 * sin(float(x) * 0.21 + float(y) * 0.07) \
				+ 0.012 * sin(float(y) * 0.33)
			image.set_pixel(x, y, joint if on_joint else base.lightened(veining))
	image.generate_mipmaps()
	var floor_material := _make_material(Color.WHITE, 0.55)
	floor_material.albedo_texture = ImageTexture.create_from_image(image)
	floor_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials.floor = floor_material


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _make_glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := _make_material(color, 0.38)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


# --- Oval hall --------------------------------------------------------------

func _ellipse(t: float, grow: float, y: float) -> Vector3:
	return CENTRE + Vector3((RADIUS_X + grow) * cos(t), y, (RADIUS_Z + grow) * sin(t))


func _outward(t: float) -> Vector3:
	return Vector3(cos(t) / RADIUS_X, 0.0, sin(t) / RADIUS_Z).normalized()


## The hall wall runs the long way round from the entrance's west corner to
## its east corner; the entrance block closes the gap between them.
func _wall_span() -> Vector2:
	var corner := acos(ENTRANCE_HALF_WIDTH / RADIUS_X)
	return Vector2(PI - corner, corner + TAU)


func _wall_t(index: int, count: int) -> float:
	var span := _wall_span()
	return lerpf(span.x, span.y, float(index) / float(count))


## Adds a band that follows the wall between two offsets from the inner face
## (negative is into the room) and two heights.
func _ring_band(st: SurfaceTool, grow_in: float, grow_out: float, y0: float,
		y1: float, count: int = SEGMENTS, span_override := Vector2.ZERO) -> void:
	var span := _wall_span() if span_override == Vector2.ZERO else span_override
	for i in count:
		var t0 := lerpf(span.x, span.y, float(i) / float(count))
		var t1 := lerpf(span.x, span.y, float(i + 1) / float(count))
		var n0 := _outward(t0)
		var n1 := _outward(t1)
		var i0b := _ellipse(t0, grow_in, y0)
		var i1b := _ellipse(t1, grow_in, y0)
		var i0t := _ellipse(t0, grow_in, y1)
		var i1t := _ellipse(t1, grow_in, y1)
		var o0b := _ellipse(t0, grow_out, y0)
		var o1b := _ellipse(t1, grow_out, y0)
		var o0t := _ellipse(t0, grow_out, y1)
		var o1t := _ellipse(t1, grow_out, y1)
		_quad_smooth(st, i0b, i1b, i1t, i0t, -n0, -n1)
		_quad_smooth(st, o0b, o1b, o1t, o0t, n0, n1)
		_quad(st, i0t, i1t, o1t, o0t, Vector3.UP)
		_quad(st, i0b, i1b, o1b, o0b, Vector3.DOWN)


func _build_oval_walls(interior: SurfaceTool, stone: SurfaceTool,
		stone_shadow: SurfaceTool, gold: SurfaceTool, glow: SurfaceTool) -> void:
	var t := WALL_THICKNESS
	# Inner face is the pale gallery wall; the outer shell is limestone.
	for i in SEGMENTS:
		var t0 := _wall_t(i, SEGMENTS)
		var t1 := _wall_t(i + 1, SEGMENTS)
		_quad_smooth(interior, _ellipse(t0, 0.0, 0.0), _ellipse(t1, 0.0, 0.0),
			_ellipse(t1, 0.0, WALL_HEIGHT), _ellipse(t0, 0.0, WALL_HEIGHT),
			-_outward(t0), -_outward(t1))
	_ring_band(stone, t * 0.5, t, 0.0, WALL_HEIGHT)
	_ring_band(stone, 0.0, t, WALL_HEIGHT - 0.01, WALL_HEIGHT)

	# Interior: skirting, a gold picture rail, and a gold cornice at the roof line.
	_ring_band(stone_shadow, -0.12, 0.0, 0.0, 0.9)
	_ring_band(gold, -0.16, 0.0, 12.4, 12.65)
	_ring_band(gold, -0.35, 0.0, WALL_HEIGHT - 0.9, WALL_HEIGHT - 0.5)
	_ring_band(interior, -0.6, 0.0, WALL_HEIGHT - 0.5, WALL_HEIGHT)
	_ring_band(interior, -DOME_LEDGE - 0.1, -0.5, WALL_HEIGHT, WALL_HEIGHT + 0.4)
	_ring_band(gold, -DOME_LEDGE - 0.15, -DOME_LEDGE + 0.1, WALL_HEIGHT - 0.1, WALL_HEIGHT + 0.1)
	# A thin teal light cove just under the cornice washes the walls.
	_ring_band(glow, -0.5, -0.35, WALL_HEIGHT - 1.05, WALL_HEIGHT - 0.9)

	# Exterior: stepped plinth, pilasters with gold capitals, a teal frieze and
	# a balustraded parapet around the glass roof.
	_ring_band(stone_shadow, t, t + 0.8, 0.0, 1.2)
	_ring_band(stone_shadow, t, t + 0.45, 1.2, 2.2)
	_ring_band(glow, t, t + 0.12, 13.4, 13.75)
	_ring_band(stone_shadow, t, t + 0.7, WALL_HEIGHT - 0.8, WALL_HEIGHT)
	_ring_band(stone, t - 0.6, t + 0.2, WALL_HEIGHT, WALL_HEIGHT + 0.5)
	_ring_band(stone, t - 0.6, t + 0.1, WALL_HEIGHT + 1.9, WALL_HEIGHT + 2.3)
	_ring_band(gold, t - 0.62, t + 0.12, WALL_HEIGHT + 2.3, WALL_HEIGHT + 2.4)

	var pilasters := 40
	for i in pilasters + 1:
		var tp := _wall_t(i, pilasters)
		var basis := _wall_basis(tp)
		var foot := _ellipse(tp, t, 0.0)
		var n := _outward(tp)
		_box(stone, Transform3D(basis, foot + n * 0.35 + Vector3(0, 8.0, 0)),
			Vector3(1.5, 12.0, 0.7))
		_box(gold, Transform3D(basis, foot + n * 0.45 + Vector3(0, 14.35, 0)),
			Vector3(1.9, 0.5, 0.9))
		_box(stone_shadow, Transform3D(basis, foot + n * 0.2 + Vector3(0, 11.0, 0)),
			Vector3(0.6, 3.2, 0.5))
		_box(glow, Transform3D(basis, foot + n * 0.47 + Vector3(0, 11.0, 0)),
			Vector3(0.3, 2.6, 0.05))

	var balusters := 160
	for i in balusters:
		var tb := _wall_t(i, balusters) + (_wall_span().y - _wall_span().x) / balusters * 0.5
		_box(stone_shadow, Transform3D(_wall_basis(tb),
			_ellipse(tb, t - 0.25, WALL_HEIGHT + 1.2)), Vector3(0.45, 1.4, 0.45))


func _wall_basis(t: float) -> Basis:
	var z := _outward(t)
	var x := Vector3.UP.cross(z).normalized()
	return Basis(x, Vector3.UP, z)


# --- Sky roof ---------------------------------------------------------------

func _dome_point(t: float, ring: int) -> Vector3:
	var phi := PI * 0.5 * float(ring) / float(DOME_RINGS)
	var s := cos(phi)
	# The roof rests on a cornice ledge just inside the walls, so its base never
	# reaches past the entrance façade at the oval's front point.
	var inset := -DOME_LEDGE
	return CENTRE + Vector3((RADIUS_X + inset) * s * cos(t),
		WALL_HEIGHT + 0.4 + DOME_RISE * sin(phi), (RADIUS_Z + inset) * s * sin(t))


func _build_sky_roof(glass: SurfaceTool, gold: SurfaceTool, slate: SurfaceTool,
		glow: SurfaceTool) -> void:
	var around := 72
	for ring in DOME_RINGS:
		for i in around:
			var t0 := TAU * float(i) / float(around)
			var t1 := TAU * float(i + 1) / float(around)
			var a := _dome_point(t0, ring)
			var b := _dome_point(t1, ring)
			var c := _dome_point(t1, ring + 1)
			var d := _dome_point(t0, ring + 1)
			var n := (a - CENTRE - Vector3(0, WALL_HEIGHT, 0)).normalized()
			if ring == DOME_RINGS - 1:
				_tri(glass, a, b, c, n)
			else:
				_quad(glass, a, b, c, d, n)

	# Gold ribs meet at a crown ring, with two horizontal hoops for rhythm.
	for rib in DOME_RIBS:
		var t := TAU * float(rib) / float(DOME_RIBS)
		for ring in DOME_RINGS - 2:
			_beam(gold, _dome_point(t, ring), _dome_point(t, ring + 1), 0.45)
	for hoop in [0, 4, 8, DOME_RINGS - 2]:
		for i in 96:
			var t0 := TAU * float(i) / 96.0
			var t1 := TAU * float(i + 1) / 96.0
			_beam(gold, _dome_point(t0, hoop), _dome_point(t1, hoop),
				0.6 if hoop == 0 else 0.35)

	# Lantern: a small slate cupola with a gold finial and a teal beacon.
	var crown := _dome_point(0.0, DOME_RINGS)
	var lantern_r := Vector2(4.5, 2.7)
	var lantern_base := Vector3(CENTRE.x, crown.y + 2.4, CENTRE.z)
	for post in 10:
		var t := TAU * float(post) / 10.0
		var foot := Vector3(CENTRE.x + lantern_r.x * cos(t), crown.y - 0.4,
			CENTRE.z + lantern_r.y * sin(t))
		_beam(gold, foot, Vector3(foot.x, lantern_base.y, foot.z), 0.28)
	_cone(slate, lantern_base, lantern_r * 1.2, 4.2, 20)
	_cone(gold, lantern_base + Vector3(0, 4.0, 0), Vector2(0.35, 0.35), 2.6, 10)
	_box(glow, Transform3D(Basis(), Vector3(CENTRE.x, crown.y + 1.0, CENTRE.z)),
		Vector3(1.2, 1.2, 1.2))


# --- Entrance ---------------------------------------------------------------

func _build_entrance(stone: SurfaceTool, stone_shadow: SurfaceTool, gold: SurfaceTool,
		glow: SurfaceTool, slate: SurfaceTool, interior: SurfaceTool) -> void:
	var zf := ENTRANCE_FRONT_Z
	var zb := ENTRANCE_BACK_Z
	var depth := zf - zb
	var zc := (zf + zb) * 0.5
	var side_w := ENTRANCE_HALF_WIDTH - DOOR_HALF_WIDTH
	var side_x := DOOR_HALF_WIDTH + side_w * 0.5
	for side in [-1.0, 1.0]:
		_box(stone, _at(Vector3(side * side_x, ENTRANCE_HEIGHT * 0.5, zc)),
			Vector3(side_w, ENTRANCE_HEIGHT, depth))
	_box(stone, _at(Vector3(0, (DOOR_HEIGHT + ENTRANCE_HEIGHT) * 0.5, zc)),
		Vector3(DOOR_HALF_WIDTH * 2.0, ENTRANCE_HEIGHT - DOOR_HEIGHT, depth))
	# The hall-facing side of the entrance reads as gallery wall, not stone.
	for side in [-1.0, 1.0]:
		_box(interior, _at(Vector3(side * side_x, WALL_HEIGHT * 0.5, zb - 0.03)),
			Vector3(side_w, WALL_HEIGHT, 0.06))

	# Pointed arch set into the doorway head, with filled spandrels, as on the
	# castle front gate.
	var shoulder_y := 11.5
	var apex := Vector3(0, DOOR_HEIGHT - 0.05, 0)
	for side in [-1.0, 1.0]:
		var shoulder := Vector3(side * DOOR_HALF_WIDTH, shoulder_y, 0)
		var corner := Vector3(side * DOOR_HALF_WIDTH, DOOR_HEIGHT, 0)
		_prism(stone, shoulder, apex, corner, zb, zf)
		var previous := shoulder
		for step in 6:
			var point := shoulder.lerp(apex, float(step + 1) / 6.0)
			_beam(stone_shadow, previous + Vector3(0, 0, zf + 0.3),
				point + Vector3(0, 0, zf + 0.3), 1.1)
			_beam(gold, previous + Vector3(0, -0.2, zf + 0.95),
				point + Vector3(0, -0.2, zf + 0.95), 0.22)
			previous = point
		# Jambs: bronze-gold ribs and a teal reveal the player walks past.
		_box(stone_shadow, _at(Vector3(side * (DOOR_HALF_WIDTH + 0.6), shoulder_y * 0.5, zf + 0.3)),
			Vector3(1.2, shoulder_y, 1.2))
		_box(gold, _at(Vector3(side * (DOOR_HALF_WIDTH + 0.6), shoulder_y * 0.5, zf + 0.95)),
			Vector3(0.22, shoulder_y, 0.1))
		_box(glow, _at(Vector3(side * (DOOR_HALF_WIDTH - 0.04), 6.0, zc)),
			Vector3(0.08, 9.0, depth - 1.0))

	# Façade dressing: plinth, gold string courses, stepped crown and crest.
	_box(stone_shadow, _at(Vector3(0, 0.8, zf + 0.25)),
		Vector3(ENTRANCE_HALF_WIDTH * 2.0, 1.6, 0.5))
	for side in [-1.0, 1.0]:
		_box(stone_shadow, _at(Vector3(side * side_x, 0.8, zf + 0.25)),
			Vector3(side_w, 1.6, 0.5))
	_box(gold, _at(Vector3(0, DOOR_HEIGHT + 0.15, zf + 0.1)),
		Vector3(ENTRANCE_HALF_WIDTH * 2.0, 0.3, 0.3))
	_box(gold, _at(Vector3(0, ENTRANCE_HEIGHT - 0.1, zf + 0.1)),
		Vector3(ENTRANCE_HALF_WIDTH * 2.0 + 0.4, 0.3, 0.4))
	for crown in 5:
		var h := 1.4 + (1.2 if crown == 2 else 0.0)
		_box(stone_shadow, _at(Vector3((float(crown) - 2.0) * 3.2,
			ENTRANCE_HEIGHT + h * 0.5, zc + 1.0)), Vector3(3.3, h, depth - 2.0))
	for side in [-1.0, 1.0]:
		for window in 2:
			var wx: float = side * (DOOR_HALF_WIDTH + 2.5 + float(window) * 3.5)
			_box(stone_shadow, _at(Vector3(wx, 8.0, zf + 0.12)), Vector3(1.6, 7.4, 0.2))
			_box(glow, _at(Vector3(wx, 8.0, zf + 0.24)), Vector3(0.8, 6.4, 0.08))
			_prism(glow, Vector3(wx - 0.4, 11.2, 0), Vector3(wx, 12.4, 0),
				Vector3(wx + 0.4, 11.2, 0), zf + 0.2, zf + 0.28)

	# Crest: three teal lights on a gold branch, the castle's emblem.
	var crest := Vector3(0, DOOR_HEIGHT + 4.4, zf + 0.6)
	var nodes := [crest + Vector3(0, 1.8, 0), crest + Vector3(-2.2, -0.5, 0),
		crest + Vector3(2.2, -0.5, 0)]
	for node in nodes:
		_box(glow, Transform3D(Basis().rotated(Vector3.FORWARD, PI * 0.25), node),
			Vector3(0.9, 0.9, 0.5))
	_beam(gold, nodes[0], nodes[1], 0.2)
	_beam(gold, nodes[0], nodes[2], 0.2)

	# Twin gate towers with slate spires frame the door.
	for side in [-1.0, 1.0]:
		var base := Vector3(side * TOWER_X, 0, zf - TOWER_SIZE * 0.5 + 1.0)
		_box(stone_shadow, _at(base + Vector3(0, 1.1, 0)),
			Vector3(TOWER_SIZE + 1.0, 2.2, TOWER_SIZE + 1.0))
		_box(stone, _at(base + Vector3(0, TOWER_HEIGHT * 0.5, 0)),
			Vector3(TOWER_SIZE, TOWER_HEIGHT, TOWER_SIZE))
		for course in 11:
			var y := 3.2 + float(course) * 2.1
			var stagger := 0.9 if course % 2 == 1 else 0.0
			for brick in 2:
				_box(stone_shadow, _at(base + Vector3((float(brick) - 0.5) * 3.0 + stagger - 0.45,
					y, TOWER_SIZE * 0.5 + 0.12)), Vector3(2.85, 1.9, 0.24))
		for rib in [-1.0, 1.0]:
			_box(gold, _at(base + Vector3(rib * (TOWER_SIZE * 0.5 - 0.15),
				TOWER_HEIGHT * 0.5, TOWER_SIZE * 0.5 + 0.2)),
				Vector3(0.28, TOWER_HEIGHT - 4.0, 0.2))
		_box(glow, _at(base + Vector3(0, 15.0, TOWER_SIZE * 0.5 + 0.3)),
			Vector3(0.9, 6.5, 0.12))
		_box(stone_shadow, _at(base + Vector3(0, TOWER_HEIGHT + 0.4, 0)),
			Vector3(TOWER_SIZE + 0.8, 0.8, TOWER_SIZE + 0.8))
		_box(gold, _at(base + Vector3(0, TOWER_HEIGHT + 0.85, 0)),
			Vector3(TOWER_SIZE + 0.9, 0.12, TOWER_SIZE + 0.9))
		_cone(slate, base + Vector3(0, TOWER_HEIGHT + 0.8, 0),
			Vector2(TOWER_SIZE * 0.62, TOWER_SIZE * 0.62), 11.0, 8)
		_cone(gold, base + Vector3(0, TOWER_HEIGHT + 11.4, 0), Vector2(0.4, 0.4), 2.6, 8)


func _at(position: Vector3) -> Transform3D:
	return Transform3D(Basis(), position)


# --- Floor and furnishings --------------------------------------------------

func _build_floor(floor_tiles: SurfaceTool, carpet: SurfaceTool, gold: SurfaceTool,
		glow: SurfaceTool, stone: SurfaceTool) -> void:
	# Elliptical floor fan, UVs in world metres so the flags stay square.
	var around := 96
	var centre := CENTRE + Vector3(0, FLOOR_TOP, 0)
	for i in around:
		var t0 := TAU * float(i) / float(around)
		var t1 := TAU * float(i + 1) / float(around)
		var a := _ellipse(t0, 0.5, FLOOR_TOP)
		var b := _ellipse(t1, 0.5, FLOOR_TOP)
		_tri_uv(floor_tiles, centre, a, b, Vector3.UP)
	# Floor under the entrance, out to the bridge threshold.
	var fl := Vector3(-ENTRANCE_HALF_WIDTH, FLOOR_TOP, ENTRANCE_BACK_Z - 3.0)
	var fr := Vector3(ENTRANCE_HALF_WIDTH, FLOOR_TOP, ENTRANCE_BACK_Z - 3.0)
	var br := Vector3(ENTRANCE_HALF_WIDTH, FLOOR_TOP, ENTRANCE_FRONT_Z)
	var bl := Vector3(-ENTRANCE_HALF_WIDTH, FLOOR_TOP, ENTRANCE_FRONT_Z)
	_tri_uv(floor_tiles, fl, fr, br, Vector3.UP)
	_tri_uv(floor_tiles, fl, br, bl, Vector3.UP)

	# Inlaid rings echo the oval, like the ripples of a lily pond.
	for ring in [[0.30, 0.31, gold], [0.52, 0.535, glow], [0.56, 0.57, gold],
			[0.86, 0.87, gold]]:
		_floor_ring(ring[2], ring[0], ring[1])
	# A red carpet carries the bridge's route in to the centre.
	var inner_ring_z := CENTRE.z + RADIUS_Z * 0.57
	_box(carpet, _at(Vector3(0, FLOOR_TOP + 0.02, (ENTRANCE_FRONT_Z + inner_ring_z) * 0.5)),
		Vector3(9.0, 0.04, ENTRANCE_FRONT_Z - inner_ring_z))
	for side in [-1.0, 1.0]:
		_box(gold, _at(Vector3(side * 4.6, FLOOR_TOP + 0.025, (ENTRANCE_FRONT_Z + inner_ring_z) * 0.5)),
			Vector3(0.2, 0.05, ENTRANCE_FRONT_Z - inner_ring_z))
	# Threshold step in stone at the bridge boundary.
	_box(stone, _at(Vector3(0, FLOOR_TOP + 0.03, ENTRANCE_FRONT_Z - 0.4)),
		Vector3(DOOR_HALF_WIDTH * 2.0, 0.06, 0.8))


func _floor_ring(st: SurfaceTool, s0: float, s1: float) -> void:
	var around := 128
	var y := FLOOR_TOP + 0.015
	for i in around:
		var t0 := TAU * float(i) / float(around)
		var t1 := TAU * float(i + 1) / float(around)
		var a := CENTRE + Vector3(RADIUS_X * s0 * cos(t0), y, RADIUS_Z * s0 * sin(t0))
		var b := CENTRE + Vector3(RADIUS_X * s0 * cos(t1), y, RADIUS_Z * s0 * sin(t1))
		var c := CENTRE + Vector3(RADIUS_X * s1 * cos(t1), y, RADIUS_Z * s1 * sin(t1))
		var d := CENTRE + Vector3(RADIUS_X * s1 * cos(t0), y, RADIUS_Z * s1 * sin(t0))
		_quad(st, a, b, c, d, Vector3.UP)


const BENCH_RADII := Vector2(9.0, 2.6)


func _build_bench(velvet: SurfaceTool, wood: SurfaceTool, gold: SurfaceTool) -> void:
	# The Orangerie's long oval bench, set in the middle of the room.
	_oval_prism(wood, BENCH_RADII * 0.92, FLOOR_TOP, FLOOR_TOP + 0.35)
	_oval_prism(gold, BENCH_RADII * 0.95, FLOOR_TOP + 0.35, FLOOR_TOP + 0.42)
	_oval_prism(velvet, BENCH_RADII, FLOOR_TOP + 0.42, FLOOR_TOP + 0.95)


func _oval_prism(st: SurfaceTool, radii: Vector2, y0: float, y1: float) -> void:
	var around := 48
	for i in around:
		var t0 := TAU * float(i) / float(around)
		var t1 := TAU * float(i + 1) / float(around)
		var p0 := Vector3(radii.x * cos(t0), 0, radii.y * sin(t0))
		var p1 := Vector3(radii.x * cos(t1), 0, radii.y * sin(t1))
		var n0 := Vector3(cos(t0) / radii.x, 0, sin(t0) / radii.y).normalized()
		var n1 := Vector3(cos(t1) / radii.x, 0, sin(t1) / radii.y).normalized()
		var c := CENTRE
		_quad_smooth(st, c + p0 + Vector3(0, y0, 0), c + p1 + Vector3(0, y0, 0),
			c + p1 + Vector3(0, y1, 0), c + p0 + Vector3(0, y1, 0), n0, n1)
		_tri(st, c + Vector3(0, y1, 0), c + p0 + Vector3(0, y1, 0),
			c + p1 + Vector3(0, y1, 0), Vector3.UP)


# --- Collision, signage and light -------------------------------------------

func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "RotundaCollision"
	add_child(body)
	# One floor slab, from the back wall to the bridge threshold at z=20.
	var floor_depth := ENTRANCE_FRONT_Z - (CENTRE.z - RADIUS_Z - WALL_THICKNESS)
	_shape(body, BoxShape3D.new(), Vector3((RADIUS_X + WALL_THICKNESS) * 2.0, 0.5, floor_depth),
		_at(Vector3(0, FLOOR_TOP - 0.25, ENTRANCE_FRONT_Z - floor_depth * 0.5)))
	var pieces := 72
	for i in pieces:
		var t0 := _wall_t(i, pieces)
		var t1 := _wall_t(i + 1, pieces)
		var a := _ellipse(t0, WALL_THICKNESS * 0.5, 0.0)
		var b := _ellipse(t1, WALL_THICKNESS * 0.5, 0.0)
		var mid := (a + b) * 0.5 + Vector3(0, (WALL_HEIGHT + 2.4) * 0.5, 0)
		var along := (b - a)
		var basis := Basis(along.normalized(), Vector3.UP,
			along.normalized().cross(Vector3.UP))
		_shape(body, BoxShape3D.new(),
			Vector3(along.length() + 0.4, WALL_HEIGHT + 2.4, WALL_THICKNESS),
			Transform3D(basis, mid))
	var side_w := ENTRANCE_HALF_WIDTH - DOOR_HALF_WIDTH
	var zc := (ENTRANCE_FRONT_Z + ENTRANCE_BACK_Z) * 0.5
	var depth := ENTRANCE_FRONT_Z - ENTRANCE_BACK_Z
	for side in [-1.0, 1.0]:
		_shape(body, BoxShape3D.new(), Vector3(side_w, ENTRANCE_HEIGHT, depth),
			_at(Vector3(side * (DOOR_HALF_WIDTH + side_w * 0.5), ENTRANCE_HEIGHT * 0.5, zc)))
		_shape(body, BoxShape3D.new(), Vector3(TOWER_SIZE, TOWER_HEIGHT, TOWER_SIZE),
			_at(Vector3(side * TOWER_X, TOWER_HEIGHT * 0.5,
				ENTRANCE_FRONT_Z - TOWER_SIZE * 0.5 + 1.0)))
	_shape(body, BoxShape3D.new(), Vector3(DOOR_HALF_WIDTH * 2.0, ENTRANCE_HEIGHT - DOOR_HEIGHT, depth),
		_at(Vector3(0, (DOOR_HEIGHT + ENTRANCE_HEIGHT) * 0.5, zc)))
	# The bench is an oval, so it gets a convex hull rather than a box.
	var bench := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for i in 24:
		var t := TAU * float(i) / 24.0
		var p := Vector3(BENCH_RADII.x * cos(t), 0, BENCH_RADII.y * sin(t))
		points.append(p + Vector3(0, FLOOR_TOP, 0))
		points.append(p + Vector3(0, FLOOR_TOP + 0.95, 0))
	bench.points = points
	var holder := CollisionShape3D.new()
	holder.name = "BenchShape"
	holder.shape = bench
	holder.position = CENTRE
	body.add_child(holder)


func _shape(body: StaticBody3D, box: BoxShape3D, size: Vector3, xform: Transform3D) -> void:
	box.size = size
	var holder := CollisionShape3D.new()
	holder.shape = box
	holder.transform = xform
	body.add_child(holder)


func _build_signage() -> void:
	var label := Label3D.new()
	label.name = "GalleryNameplate"
	label.text = "ARTÉA GALLERY"
	label.font_size = 128
	label.pixel_size = 0.02
	label.outline_size = 12
	label.modulate = Color("fff0b0")
	label.outline_modulate = Color("5a4312")
	label.position = Vector3(0, DOOR_HEIGHT + 1.6, ENTRANCE_FRONT_Z + 0.35)
	add_child(label)


func _build_lighting() -> void:
	# Daylight through the sky roof: a broad, soft, shadowless fill.
	var light := OmniLight3D.new()
	light.name = "SkyRoofGlow"
	light.position = CENTRE + Vector3(0, WALL_HEIGHT + 4.0, 0)
	light.omni_range = 80.0
	light.omni_attenuation = 0.6
	light.light_energy = 0.5
	light.light_color = Color("fff4e0")
	light.shadow_enabled = false
	add_child(light)

	# Wall sconces in the gaps between the paintings: a gold backplate, a
	# short arm, an upturned gold bowl and a warm glowing bulb.
	#
	# The Web build's Compatibility renderer lights each mesh with at most 8
	# omni/spot lights, and the walls and floor are each one mesh, so every
	# light here touches them all. The roof glow plus LAMP_LIGHT_LIMIT stays
	# under 8, so only every other sconce casts light; each one's range reaches
	# its unlit neighbours, so the wall still reads as evenly lit.
	var angles := _lamp_angles()
	var lit := 0
	for i in angles.size():
		var casts_light := i % 2 == 0 and lit < LAMP_LIGHT_LIMIT
		_build_sconce(i, angles[i], casts_light)
		if casts_light:
			lit += 1


## Wall angles halfway between neighbouring paintings, skipping the wide gap
## across the entrance. Falls back to even spacing when no paintings hang here.
func _lamp_angles() -> Array[float]:
	var span := _wall_span()
	var painting_angles: Array[float] = []
	var parent := get_parent()
	if parent != null and is_inside_tree():
		for child in parent.get_children():
			if child is Sprite3D and str(child.name).begins_with("Frame_"):
				var local := to_local((child as Node3D).global_position) - CENTRE
				var t := atan2(local.z / RADIUS_Z, local.x / RADIUS_X)
				# Unwrap into the wall's own angle range.
				while t < span.x:
					t += TAU
				painting_angles.append(t)
	var angles: Array[float] = []
	if painting_angles.size() < 2:
		for i in LAMP_FALLBACK_COUNT:
			angles.append(_wall_t(i * 2 + 1, LAMP_FALLBACK_COUNT * 2))
		return angles
	painting_angles.sort()
	for i in painting_angles.size() - 1:
		angles.append((painting_angles[i] + painting_angles[i + 1]) * 0.5)
	return angles


func _build_sconce(index: int, t: float, casts_light: bool) -> void:
	# Local +z points out through the wall, so the fixture builds along -z.
	# A gold backplate and arm hold a glowing frosted globe in a gold cup, with
	# a soft halo of light painted on the wall behind it.
	var sconce := Node3D.new()
	sconce.name = "WallSconce_%d" % index
	sconce.transform = Transform3D(_wall_basis(t), _ellipse(t, 0.0, LAMP_HEIGHT))
	sconce.scale = Vector3.ONE * LAMP_SCALE
	add_child(sconce)

	var halo := QuadMesh.new()
	halo.size = Vector2(5.5, 5.5)
	var halo_part := _add_sconce_part(sconce, "WallGlow", halo, _sconce_halo_material(),
		Vector3(0.0, 0.3, -0.03))
	# QuadMesh faces +z; turn it to face into the room.
	halo_part.rotation_degrees.y = 180.0

	var backplate := BoxMesh.new()
	backplate.size = Vector3(0.9, 1.8, 0.16)
	_add_sconce_part(sconce, "Backplate", backplate, _materials.gold,
		Vector3(0.0, -0.1, -0.08))

	var arm := CylinderMesh.new()
	arm.top_radius = 0.08
	arm.bottom_radius = 0.08
	arm.height = 0.95
	var arm_part := _add_sconce_part(sconce, "Arm", arm, _materials.gold,
		Vector3(0.0, -0.45, -0.55))
	arm_part.rotation_degrees.x = 90.0

	var cup := CylinderMesh.new()
	cup.top_radius = 0.42
	cup.bottom_radius = 0.18
	cup.height = 0.3
	cup.radial_segments = 20
	_add_sconce_part(sconce, "Cup", cup, _materials.gold, Vector3(0.0, -0.35, -1.05))

	var globe := SphereMesh.new()
	globe.radius = 0.55
	globe.height = 1.1
	globe.radial_segments = 20
	globe.rings = 10
	var globe_position := Vector3(0.0, 0.2, -1.05)
	_add_sconce_part(sconce, "Globe", globe, _make_glow(LAMP_GLASS_COLOR, 0.9), globe_position)

	var finial := CylinderMesh.new()
	finial.top_radius = 0.02
	finial.bottom_radius = 0.16
	finial.height = 0.32
	finial.radial_segments = 12
	_add_sconce_part(sconce, "Finial", finial, _materials.gold, Vector3(0.0, 0.88, -1.05))

	if casts_light:
		# Parented to the hall rather than the scaled fixture, so LAMP_RANGE is
		# in plain metres.
		var light := OmniLight3D.new()
		light.name = "WallSconceLight_%d" % index
		light.position = sconce.transform * (globe_position + Vector3(0.0, 0.0, -0.5))
		light.omni_range = LAMP_RANGE
		light.omni_attenuation = 1.0
		light.light_energy = LAMP_ENERGY
		light.light_color = LAMP_COLOR
		light.shadow_enabled = false
		add_child(light)


# A warm radial glow drawn on the wall behind each sconce. Shared by all of
# them; it is an unshaded tint, so it costs no lights.
func _sconce_halo_material() -> StandardMaterial3D:
	if _materials.has("sconce_halo"):
		return _materials.sconce_halo
	var gradient := Gradient.new()
	gradient.set_color(0, Color(LAMP_GLASS_COLOR, 0.42))
	gradient.set_color(1, Color(LAMP_GLASS_COLOR, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 128
	texture.height = 128
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_materials.sconce_halo = material
	return material


func _add_sconce_part(sconce: Node3D, part_name: String, mesh: Mesh,
		material: Material, position: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = material
	part.position = position
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sconce.add_child(part)
	return part


func _emit_mesh(node_name: String, st: SurfaceTool, material: Material,
		casts_shadow: bool = true) -> void:
	var mesh := st.commit()
	if mesh.get_surface_count() == 0:
		return
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	if not casts_shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


# --- Geometry helpers -------------------------------------------------------
# Godot treats clockwise triangles as front-facing. These helpers take the
# intended outward normal and order each triangle to suit it.

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var swap := b
		b = c
		c = swap
	for p in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(p)


func _tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var swap := b
		b = c
		c = swap
	for p in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(p.x, p.z) / 4.0)
		st.add_vertex(p)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		n: Vector3) -> void:
	_tri(st, a, b, c, n)
	_tri(st, a, c, d, n)


## A quad whose normal varies along a curve: a/d share na, b/c share nb.
func _quad_smooth(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3) -> void:
	var n := (na + nb).normalized()
	var flip := (b - a).cross(c - a).dot(n) > 0.0
	var tris := [[a, na, b, nb, c, nb], [a, na, c, nb, d, na]]
	for tri in tris:
		var order := [0, 4, 2] if flip else [0, 2, 4]
		for k in order:
			st.set_normal(tri[k + 1])
			st.add_vertex(tri[k])


func _box(st: SurfaceTool, xform: Transform3D, size: Vector3) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z)],
		[Vector3.LEFT, Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)],
		[Vector3.UP, Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z)],
		[Vector3.DOWN, Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)],
		[Vector3.BACK, Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)],
		[Vector3.FORWARD, Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, -h.y, -h.z)],
	]
	for face in faces:
		_quad(st, xform * face[1], xform * face[2], xform * face[3], xform * face[4],
			(xform.basis * face[0]).normalized())


func _beam(st: SurfaceTool, from: Vector3, to: Vector3, thickness: float) -> void:
	var delta := to - from
	if delta.length() < 0.001:
		return
	var direction := delta.normalized()
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
	_box(st, Transform3D(Basis.looking_at(direction, up), from.lerp(to, 0.5)),
		Vector3(thickness, thickness, delta.length()))


## A triangular prism: triangle abc (x/y, z ignored) extruded from z0 to z1.
func _prism(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, z0: float, z1: float) -> void:
	var pts := [a, b, c]
	var front: Array[Vector3] = []
	var back: Array[Vector3] = []
	for p in pts:
		front.append(Vector3(p.x, p.y, z1))
		back.append(Vector3(p.x, p.y, z0))
	_tri(st, front[0], front[1], front[2], Vector3.BACK)
	_tri(st, back[0], back[1], back[2], Vector3.FORWARD)
	var centroid := (a + b + c) / 3.0
	for i in 3:
		var j := (i + 1) % 3
		var edge_mid: Vector3 = (pts[i] + pts[j]) * 0.5
		var n := Vector3(edge_mid.x - centroid.x, edge_mid.y - centroid.y, 0).normalized()
		_quad(st, back[i], back[j], front[j], front[i], n)


## An elliptical cone standing on `base`, radii in x/z, in `sides` facets.
func _cone(st: SurfaceTool, base: Vector3, radii: Vector2, height: float, sides: int) -> void:
	var tip := base + Vector3(0, height, 0)
	for i in sides:
		var t0 := TAU * float(i) / float(sides)
		var t1 := TAU * float(i + 1) / float(sides)
		var a := base + Vector3(radii.x * cos(t0), 0, radii.y * sin(t0))
		var b := base + Vector3(radii.x * cos(t1), 0, radii.y * sin(t1))
		var mid := (a + b) * 0.5 - base
		var n := (mid.normalized() * height + Vector3.UP * mid.length()).normalized()
		_tri(st, a, b, tip, n)
		_tri(st, base, b, a, Vector3.DOWN)
