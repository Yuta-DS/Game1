# gallery_piano.gd
#
# The white-and-gold grand piano standing near the middle of the rotunda, and
# the sit-down playing mode that goes with it.
#
# Built at runtime rather than authored as a .tscn, for the reason the rest of
# the gallery is: the whole feature is one script plus one node line in the
# scene, so it can be pulled back out without leaving a scene diff behind.
#
# Playing it:
#
# * Walk up and press the `interact` key.  The camera tweens to a seated view
#   looking down at the keyboard and the cursor is freed.
# * Click a key, or drag across several, to play.  Every one of the 88 keys
#   sounds; see `_play_note` for how two octaves of samples cover them.
# * `ui_cancel` stands up again.
#
# The case is a real grand's plan view -- a straight spine down the bass side
# and a curved bent side sweeping round the tail -- extruded between two
# heights, so the silhouette reads correctly from anywhere in the room.
extends Node3D

## Camera3D running CameraFollow.gd.  Set in the scene.
@export var camera_path: NodePath

## Keys live on their own physics layer so the picking ray cannot be blocked
## by the player, the floor, or anything else that wanders between the camera
## and the keyboard.  Deliberately clear of layer 4 (`Cuttable`) -- the Lens of
## Seeing does mesh surgery on anything it finds there.
const KEY_LAYER := 6

const CASE_WIDTH := 1.46        # bass spine to the widest point of the bent side
const CASE_LENGTH := 2.62       # front edge to tail
const RIM_BOTTOM := 0.62
const RIM_TOP := 0.90
const KEY_BED_Y := 0.715        # top face of the shelf the keys rest on
const KEY_WELL_Z := -0.26       # where the keyboard recess ends and the body begins
const CHEEK_WIDTH := 0.115      # blocks that cap the keyboard at either end
const LID_ANGLE_DEGREES := 52.0
const LID_THICKNESS := 0.035
const TRIM_BAND := 0.032      # height of the gilded band at each rim edge
## Metres covered by one repeat of a surface UV.  Only the front panel is
## textured, and it sets its own UVs; everywhere else this just keeps the
## generated coordinates in one consistent scale.
const DAMASK_TILE := 1.45

const RIM_TOP_BAND := 0.075     # width of the polished flat on top of the rim
const PLATE_DROP := 0.185       # how far the gilt plate sits below that flat
const STRING_COURSES := 34

const WHITE_KEY_LENGTH := 0.148
const WHITE_KEY_THICKNESS := 0.022
const BLACK_KEY_LENGTH := 0.096
const BLACK_KEY_THICKNESS := 0.014
const KEY_GAP := 0.0016
const KEY_DIP_DEGREES := 3.4

## Where the camera sits while playing, in the piano's own space.  Public so
## tools/capture_gallery_piano.gd frames its preview on the real seated view
## rather than an approximation that drifts away from it.
##
## 0.56 out from the keys at 60 degrees above them, rather than the 0.83 at 37
## degrees this started with.  Both numbers matter for aiming at a key: the
## closer stand puts the keyboard across about three quarters of the screen
## instead of half, and the steeper angle stops the keys foreshortening -- at
## 37 degrees a white key showed 60% of its length, at 60 degrees it shows 87%,
## so there is that much more of it to click.
const SEAT_FOCUS := Vector3(0.0, KEY_BED_Y, KEY_WELL_Z + 0.012 + WHITE_KEY_LENGTH * 0.5)
const SEAT_VIEW := Vector3(0.0, 0.526, 0.192)

const FIRST_MIDI := 21          # A0, the bottom of an 88-key board
const LAST_MIDI := 108          # C8
const WHITE_PITCH_CLASSES := [0, 2, 4, 5, 7, 9, 11]
const NOTE_NAMES := ["C", "Cs", "D", "Ds", "E", "F", "Fs", "G", "Gs", "A", "As", "B"]
const SAMPLE_OCTAVES := [1, 4, 7]  # matches tools/audio/build_piano_notes.py
const VOICES := 24

var _materials := {}
var _samples := {}              # "<name><octave>" -> AudioStream
var _voices: Array[AudioStreamPlayer3D] = []
var _voice_index := 0
var _keys := {}                 # midi -> Node3D (hinged at the key's back edge)
var _key_white := {}            # midi -> bool
var _camera: Node = null
var _player_in_range := false
var _seated := false
var _dragging := false
var _last_dragged_midi := -1
var _prompt: Label = null
var _prompt_layer: CanvasLayer = null
var _hidden_visuals: Array[Node3D] = []
var _white_span := 0.0


func _ready() -> void:
	_camera = get_node_or_null(camera_path)
	if _camera == null:
		push_warning("gallery_piano: no camera at %s; interaction disabled" % camera_path)
	_build_materials()
	_load_samples()
	_build_voices()
	_build_case()
	_build_lid()
	_build_legs()
	_build_pedals()
	_build_keyboard()
	_build_music_desk()
	_build_case_collision()
	_build_interaction_area()
	_build_prompt()
	set_process_unhandled_input(true)


# ---------------------------------------------------------------- materials

func _make_material(colour: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	material.metallic = metallic
	return material


func _build_materials() -> void:
	# Polished white lacquer.  Low roughness plus clearcoat is what separates a
	# piano finish from flat white paint under the rotunda's lights.
	var lacquer := _make_material(Color(0.965, 0.957, 0.941), 0.09)
	lacquer.clearcoat_enabled = true
	lacquer.clearcoat = 0.85
	lacquer.clearcoat_roughness = 0.04
	_materials.lacquer = lacquer

	var gold := _make_material(Color(0.855, 0.690, 0.345), 0.26, 0.92)
	_materials.gold = gold

	# The gilding on the legs and trim is a shade deeper so the carved parts
	# read against the flat gold bands rather than merging with them.
	_materials.gold_deep = _make_material(Color(0.735, 0.565, 0.255), 0.34, 0.88)

	# No patterned lining anywhere: the reference instrument is plain white
	# gloss inside the lid and round the body, and carries its ornament as
	# sparse gold appliqué -- which a tiling damask cannot stand in for.  The
	# gold is all in the rim bands, the plate, the keyslip, the lyre and the
	# leg capitals, which is where the reference has it too.

	# The gilt frame the strings are strung over.  Held well short of the case
	# gold's metallic: at 0.9 and up almost all the albedo goes to reflection,
	# and with little around the instrument to reflect, the inside of the body
	# renders as a dark brown hole rather than gilding.
	_materials.plate = _make_material(Color(0.880, 0.720, 0.355), 0.30, 0.45)
	# Pale steel, against that gold rather than with it -- strings toned to the
	# plate disappear into it from any distance at all.
	_materials.strings = _make_material(Color(0.820, 0.830, 0.845), 0.22, 0.70)

	var ivory := _make_material(Color(0.975, 0.968, 0.945), 0.26)
	ivory.clearcoat_enabled = true
	ivory.clearcoat = 0.45
	_materials.ivory = ivory

	_materials.ebony = _make_material(Color(0.045, 0.043, 0.050), 0.22)
	_materials.felt = _make_material(Color(0.62, 0.11, 0.16), 0.85)


# ----------------------------------------------------------------- geometry

## The plan view of the case, counter-clockwise from the front-left corner.
## Straight spine down the bass (-X) side, bent side sweeping round the tail.
func _case_outline() -> PackedVector2Array:
	var half := CASE_WIDTH * 0.5
	var control := PackedVector2Array([
		Vector2(half, 0.0),
		Vector2(half, -0.78),
		Vector2(half - 0.015, -1.22),
		Vector2(half - 0.065, -1.60),
		Vector2(half - 0.145, -1.94),
		Vector2(half - 0.255, -2.21),
		Vector2(half - 0.390, -2.42),
		Vector2(half - 0.550, -2.545),
		Vector2(half - 0.730, -2.60),
		Vector2(-0.25, -CASE_LENGTH),
		Vector2(-0.55, -CASE_LENGTH),
		Vector2(-half, -2.58),
	])
	var outline := PackedVector2Array([Vector2(-half, 0.0)])
	outline.append_array(_smooth(control, 4))
	return outline


## Catmull-Rom through the control points, so the bent side is a curve rather
## than a run of visible flat facets.
func _smooth(points: PackedVector2Array, subdivisions: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := points.size()
	for index in range(count - 1):
		var p0 := points[maxi(index - 1, 0)]
		var p1 := points[index]
		var p2 := points[index + 1]
		var p3 := points[mini(index + 2, count - 1)]
		for step in range(subdivisions):
			var t := float(step) / float(subdivisions)
			out.append(_catmull_rom(p0, p1, p2, p3, t))
	out.append(points[count - 1])
	return out


func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		2.0 * p1
		+ (p2 - p0) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


func _add_mesh(name_hint: String, tool: SurfaceTool, material: Material,
		parent: Node3D = null) -> MeshInstance3D:
	tool.index()
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = name_hint
	instance.mesh = tool.commit()
	instance.material_override = material
	(parent if parent != null else self).add_child(instance)
	return instance


func _begin() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


## One quad as two triangles, wound so the face you want to see is the one you
## travel clockwise around when looking at it -- the generated normal comes out
## along cross(c - a, b - a), and a quad wound the other way is not shaded
## wrongly, it is culled and simply never appears.
##
## `uvs` gives a coordinate per corner, in the same order as the corners; pass them whenever the surface also gets a `_cap`,
## because the first vertex added to a SurfaceTool fixes whether that surface
## carries UVs at all and every later `set_uv` on one that does not is an error.
func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		uvs := PackedVector2Array()) -> void:
	var corners: Array[Vector3] = [a, b, c, d]
	for corner in [0, 1, 2, 0, 2, 3]:
		if not uvs.is_empty():
			tool.set_uv(uvs[corner])
		tool.add_vertex(corners[corner])


## Cap a plan-view polygon at height `y`.  `face_up` picks the winding so the
## generated normal points the right way; a cap wound the wrong way disappears
## under backface culling rather than merely looking wrong.
##
## UVs are laid out in metres over DAMASK_TILE, so the damask keeps one scale
## across every surface it lands on instead of stretching to each polygon's
## own extents -- the lid and the soundboard are very different shapes.
func _cap(tool: SurfaceTool, polygon: PackedVector2Array, y: float, face_up: bool) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty():
		push_warning("gallery_piano: could not triangulate a cap polygon")
		return
	var step := 3
	for base in range(0, indices.size(), step):
		var tri := [indices[base], indices[base + 1], indices[base + 2]]
		if not face_up:
			tri.reverse()
		for i in tri:
			var point := polygon[i]
			tool.set_uv(Vector2(point.x, point.y) / DAMASK_TILE)
			tool.add_vertex(Vector3(point.x, y, point.y))


## Extrude the closed outline between two heights.
##
## UVs follow the same metres-over-DAMASK_TILE scheme as `_cap`: U is how far
## along the outline the vertex sits, V is its height.  Measuring U along the
## whole run rather than per quad matters -- it leaves the edge each pair of
## quads shares with one identical coordinate, so `index()` still welds the
## wall into a single smooth skin instead of a ring of separate facets.
## Walls come out facing away from the ring, for an outline wound the way
## `_case_outline` winds one.  Pass a reversed polygon to line a cavity instead.
##
## `from_edge` skips the first edges of the ring while still measuring U across
## them, so a run that leaves one out keeps the same UVs as one that does not.
func _extrude_walls(tool: SurfaceTool, outline: PackedVector2Array,
		bottom: float, top: float, from_edge := 0) -> void:
	var count := outline.size()
	var v0 := bottom / DAMASK_TILE
	var v1 := top / DAMASK_TILE
	var run := 0.0
	for index in range(count):
		var a := outline[index]
		var b := outline[(index + 1) % count]
		var u0 := run / DAMASK_TILE
		run += a.distance_to(b)
		var u1 := run / DAMASK_TILE
		if index < from_edge:
			continue
		_quad(tool,
			Vector3(b.x, bottom, b.y),
			Vector3(a.x, bottom, a.y),
			Vector3(a.x, top, a.y),
			Vector3(b.x, top, b.y),
			PackedVector2Array([
				Vector2(u1, v0), Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1),
			]))


## Shrink a convex plan polygon by `amount`, each vertex sliding along its own
## corner bisector.  Point count, order and winding all survive, so the result
## pairs one-to-one with the source and `_band` can stitch between them.
##
## Convexity is what makes a bisector offset safe -- on a reflex corner it can
## cross its neighbours and turn the polygon inside out.  The case plan has no
## reflex corners: the bent side only ever narrows towards the tail.
func _inset_convex(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
	var inset := _offset_plan(polygon, amount, 1.0)
	# Rather than reason about which way the outline is wound, try one sign and
	# keep the one that came out smaller.
	if _plan_area(inset) > _plan_area(polygon):
		inset = _offset_plan(polygon, amount, -1.0)
	return inset


func _offset_plan(polygon: PackedVector2Array, amount: float,
		facing: float) -> PackedVector2Array:
	var count := polygon.size()
	var out := PackedVector2Array()
	for index in range(count):
		var here := polygon[index]
		var n0 := _edge_normal(polygon[(index - 1 + count) % count], here, facing)
		var n1 := _edge_normal(here, polygon[(index + 1) % count], facing)
		var bisector := n0 + n1
		if bisector.length() < 0.0001:
			out.append(here)
			continue
		bisector = bisector.normalized()
		# Reach along the bisector so both edges move `amount`, instead of less
		# than that wherever the two meet at an angle.
		out.append(here + bisector * (amount / maxf(bisector.dot(n0), 0.25)))
	return out


func _edge_normal(a: Vector2, b: Vector2, facing: float) -> Vector2:
	var along := b - a
	if along.length() < 0.00001:
		return Vector2.ZERO
	along = along.normalized()
	return Vector2(-along.y, along.x) * facing


func _plan_area(polygon: PackedVector2Array) -> float:
	var total := 0.0
	var count := polygon.size()
	for index in range(count):
		var a := polygon[index]
		var b := polygon[(index + 1) % count]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5


func _reverse_plan(polygon: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for index in range(polygon.size() - 1, -1, -1):
		out.append(polygon[index])
	return out


## How far back the plan reaches at `x`: the most distant Z on its boundary in
## that slice.  Sets the string lengths.
func _plan_depth_at(polygon: PackedVector2Array, x: float) -> float:
	var deepest := 0.0
	var found := false
	var count := polygon.size()
	for index in range(count):
		var a := polygon[index]
		var b := polygon[(index + 1) % count]
		if absf(b.x - a.x) < 0.00001:
			continue
		var t := (x - a.x) / (b.x - a.x)
		if t < 0.0 or t > 1.0:
			continue
		var z: float = a.y + (b.y - a.y) * t
		if not found or z < deepest:
			deepest = z
			found = true
	return deepest if found else 0.0


## Fill the ring between two matched plan polygons at height `y`, facing up.
func _band(tool: SurfaceTool, outer: PackedVector2Array,
		inner: PackedVector2Array, y: float) -> void:
	var count := outer.size()
	for index in range(count):
		var a := inner[index]
		var b := inner[(index + 1) % count]
		var c := outer[(index + 1) % count]
		var d := outer[index]
		_quad(tool,
			Vector3(a.x, y, a.y), Vector3(b.x, y, b.y),
			Vector3(c.x, y, c.y), Vector3(d.x, y, d.y),
			PackedVector2Array([a / DAMASK_TILE, b / DAMASK_TILE,
				c / DAMASK_TILE, d / DAMASK_TILE]))


func _build_case() -> void:
	var outline := _case_outline()

	# Rim: the outer wall of the case, plus a floor underneath it.  The gilded
	# bands are cut out of the same wall rather than floated outside it -- an
	# offset moulding has to follow a vertex normal, and the outline's normals
	# are unreliable exactly where the smoothed points bunch together.
	# Edge 0 is the keyboard front, and all three runs leave it out.  Carried to
	# RIM_TOP like the rest of the wall it stands a blank board in front of the
	# keys at 0.87, above the key tops at 0.74, so the keyboard is invisible to
	# anyone not looking down on the instrument.  `_build_front_board` puts that
	# edge back at the height of the key shelf, where the reference has it.
	var rim := _begin()
	_extrude_walls(rim, outline, RIM_BOTTOM + TRIM_BAND, RIM_TOP - TRIM_BAND, 1)
	_cap(rim, outline, RIM_BOTTOM, false)
	_add_mesh("Rim", rim, _materials.lacquer)

	var bands := _begin()
	_extrude_walls(bands, outline, RIM_BOTTOM, RIM_BOTTOM + TRIM_BAND, 1)
	_extrude_walls(bands, outline, RIM_TOP - TRIM_BAND, RIM_TOP, 1)
	_add_mesh("RimBands", bands, _materials.gold)

	_build_front_board()

	# The top splits at the keyboard well: everything behind KEY_WELL_Z is the
	# body at full height, everything in front is the lower shelf the keys sit
	# on, with a step between them.
	var body := PackedVector2Array()
	for point in outline:
		if point.y <= KEY_WELL_Z:
			body.append(point)
	# Both split points go on the front of the run, in outline order: the
	# filtered points already start partway down the bent side, so appending
	# the second one instead would close the ring back across itself and
	# triangulation would refuse the whole polygon.
	var half := CASE_WIDTH * 0.5
	body.insert(0, Vector2(half, KEY_WELL_Z))
	body.insert(0, Vector2(-half, KEY_WELL_Z))

	# The body is open, as a grand standing with its lid up is.  What was here
	# before was a cap over the whole polygon at RIM_TOP with a soundboard 55mm
	# beneath it -- the cap hid the soundboard outright, and the instrument read
	# as a sealed white slab with a lid hovering above it.  The rim keeps only
	# its polished top edge now and the case is hollow down to the plate.
	var rim_inner := _inset_convex(body, RIM_TOP_BAND)
	var plate_y := RIM_TOP - PLATE_DROP

	var top := _begin()
	_band(top, body, rim_inner, RIM_TOP)
	_add_mesh("CaseTop", top, _materials.lacquer)

	# Inner face of the rim, reversed so the wall looks into the case.
	var cavity := _begin()
	_extrude_walls(cavity, _reverse_plan(rim_inner), plate_y, RIM_TOP)
	# (the reverse is what turns the outward default inwards)
	_add_mesh("CaseWell", cavity, _materials.lacquer)

	var plate := _begin()
	_cap(plate, rim_inner, plate_y, true)
	_add_mesh("Plate", plate, _materials.plate)

	_build_strings(rim_inner, plate_y)

	var shelf := _begin()
	var well := PackedVector2Array([
		Vector2(-half, 0.0), Vector2(half, 0.0),
		Vector2(half, KEY_WELL_Z), Vector2(-half, KEY_WELL_Z),
	])
	_cap(shelf, well, KEY_BED_Y, true)
	# Step up from the key shelf to the case top.
	_quad(shelf,
		Vector3(half, KEY_BED_Y, KEY_WELL_Z),
		Vector3(-half, KEY_BED_Y, KEY_WELL_Z),
		Vector3(-half, RIM_TOP, KEY_WELL_Z),
		Vector3(half, RIM_TOP, KEY_WELL_Z),
		PackedVector2Array([
			Vector2(half, KEY_BED_Y) / DAMASK_TILE, Vector2(-half, KEY_BED_Y) / DAMASK_TILE,
			Vector2(-half, RIM_TOP) / DAMASK_TILE, Vector2(half, RIM_TOP) / DAMASK_TILE,
		]))
	_add_mesh("KeyBed", shelf, _materials.lacquer)

	# Keyslip: the gilded lip the keys sit behind.  The reference instrument
	# carries gold at every edge where two surfaces meet, and this is the one
	# the player looks straight down at while seated.
	var keyslip := _begin()
	# Directly against the key fronts, not at the case edge: the keys stop
	# well short of z = 0, and a lip out there reads as a rail hanging in
	# mid air rather than part of the keyboard.
	var lip_front := KEY_WELL_Z + 0.012 + WHITE_KEY_LENGTH
	var lip := PackedVector2Array([
		Vector2(-half, lip_front + 0.014), Vector2(half, lip_front + 0.014),
		Vector2(half, lip_front - 0.006), Vector2(-half, lip_front - 0.006),
	])
	_extrude_walls(keyslip, lip, KEY_BED_Y, KEY_BED_Y + 0.026)
	_cap(keyslip, lip, KEY_BED_Y + 0.026, true)
	_add_mesh("Keyslip", keyslip, _materials.gold)

	# Cheek blocks framing the keyboard at either end.
	for side: float in [-1.0, 1.0]:
		var outer := side * half
		var inner := side * (half - CHEEK_WIDTH)
		var cheek := _begin()
		var plan := PackedVector2Array([
			Vector2(minf(outer, inner), 0.0), Vector2(maxf(outer, inner), 0.0),
			Vector2(maxf(outer, inner), KEY_WELL_Z), Vector2(minf(outer, inner), KEY_WELL_Z),
		])
		_extrude_walls(cheek, plan, KEY_BED_Y, RIM_TOP)
		_cap(cheek, plan, RIM_TOP, true)
		_add_mesh("Cheek%s" % ("L" if side < 0.0 else "R"), cheek, _materials.lacquer)


## The board across the front of the case, under the keys.  Its own run rather
## than part of the rim because it stops at the key shelf, with the rim's gilt
## line carried across its foot so the edge still reads continuous.
func _build_front_board() -> void:
	var half := CASE_WIDTH * 0.5

	var board := _begin()
	_quad(board,
		Vector3(-half, KEY_BED_Y, 0.0),
		Vector3(half, KEY_BED_Y, 0.0),
		Vector3(half, RIM_BOTTOM + TRIM_BAND, 0.0),
		Vector3(-half, RIM_BOTTOM + TRIM_BAND, 0.0))
	_add_mesh("FrontBoard", board, _materials.lacquer)

	# Bottom band only, carrying the rim's gilt line across the front.  A band
	# at both ends would leave a 30mm sliver of white between them.
	var trim := _begin()
	_quad(trim,
		Vector3(-half, RIM_BOTTOM + TRIM_BAND, 0.0),
		Vector3(half, RIM_BOTTOM + TRIM_BAND, 0.0),
		Vector3(half, RIM_BOTTOM, 0.0), Vector3(-half, RIM_BOTTOM, 0.0))
	_add_mesh("FrontBands", trim, _materials.gold)



## The string band over the plate, with the plate's bracing bars across it.
##
## Lengths come straight from the plan: bass courses run the length of the tail
## and treble ones a fraction of it.  That fan is most of what makes an open
## piano read as an open piano from across a room.
func _build_strings(inner: PackedVector2Array, plate_y: float) -> void:
	var half := CASE_WIDTH * 0.5
	var front := KEY_WELL_Z - RIM_TOP_BAND - 0.035
	var strings := _begin()
	for course in range(STRING_COURSES):
		var t := (float(course) + 0.5) / float(STRING_COURSES)
		# Bass against the spine at -X, treble round on the bent side.
		var x: float = lerpf(-half + RIM_TOP_BAND + 0.05, half - RIM_TOP_BAND - 0.13, t)
		var back := _plan_depth_at(inner, x) + 0.055
		if back >= front - 0.15:
			continue
		var w := 0.009
		_quad(strings,
			Vector3(x - w, plate_y + 0.014, back),
			Vector3(x + w, plate_y + 0.014, back),
			Vector3(x + w, plate_y + 0.014, front),
			Vector3(x - w, plate_y + 0.014, front))
	_add_mesh("Strings", strings, _materials.strings)

	var bars := _begin()
	for bar in range(3):
		var x: float = lerpf(-half + 0.26, half - 0.33, (float(bar) + 0.5) / 3.0)
		var back := _plan_depth_at(inner, x) + 0.09
		if back >= front - 0.2:
			continue
		var w := 0.035
		_quad(bars,
			Vector3(x - w, plate_y + 0.028, back),
			Vector3(x + w, plate_y + 0.028, back),
			Vector3(x + w, plate_y + 0.028, front + 0.04),
			Vector3(x - w, plate_y + 0.028, front + 0.04))
	_add_mesh("PlateBars", bars, _materials.plate)


func _build_lid() -> void:
	var outline := _case_outline()
	# Hinged on the spine, so the lid is built in a local frame whose origin
	# sits on that edge and whose +X runs across the instrument.
	var hinge := Node3D.new()
	hinge.name = "Lid"
	hinge.position = Vector3(-CASE_WIDTH * 0.5, RIM_TOP, 0.0)
	hinge.rotation.z = deg_to_rad(LID_ANGLE_DEGREES)
	add_child(hinge)

	var local := PackedVector2Array()
	for point in outline:
		local.append(Vector2(point.x + CASE_WIDTH * 0.5, point.y))

	var slab := _begin()
	_extrude_walls(slab, local, 0.0, LID_THICKNESS)
	_cap(slab, local, LID_THICKNESS, true)
	_add_mesh("LidTop", slab, _materials.lacquer, hinge)

	# Underside is a separate mesh so the gilded interior shows when open.
	var under := _begin()
	_cap(under, local, 0.0, false)
	_add_mesh("LidUnder", under, _materials.lacquer, hinge)

	var edge := _begin()
	_extrude_walls(edge, local, LID_THICKNESS - 0.009, LID_THICKNESS + 0.001)
	_add_mesh("LidTrim", edge, _materials.gold, hinge)

	_build_lid_prop(hinge)


func _build_lid_prop(hinge: Node3D) -> void:
	# The stick runs from the case top to a point on the raised lid.  Taking
	# that point from the hinge's own transform keeps the two ends together if
	# LID_ANGLE_DEGREES is ever changed.
	var anchor_local := Vector3(1.02, 0.0, -0.98)
	var top := hinge.transform * anchor_local
	var base := Vector3(0.40, RIM_TOP, -0.92)
	_add_strut("LidProp", base, top, 0.016, _materials.gold)


func _add_strut(name_hint: String, from: Vector3, to: Vector3, radius: float,
		material: Material, parent: Node3D = null) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 10
	var instance := MeshInstance3D.new()
	instance.name = name_hint
	instance.mesh = mesh
	instance.material_override = material
	(parent if parent != null else self).add_child(instance)
	instance.position = (from + to) * 0.5
	var axis := (to - from).normalized()
	# CylinderMesh runs along +Y; align that to the strut, guarding the case
	# where the two are already parallel and the cross product collapses.
	#
	# Built as a basis rather than with look_at_from_position, which resolves
	# against global space: handed a local position, as it was here, it planted
	# every strut at those numbers read as world coordinates.  The pedal lyre
	# and the lid prop stood near the world origin -- just inside the gallery
	# doors -- however far away the piano itself was.
	if absf(axis.dot(Vector3.UP)) < 0.9999:
		var side := Vector3.UP.cross(axis).normalized()
		instance.basis = Basis(side, axis, side.cross(axis))


## Three legs, as a grand has: two flanking the keyboard, one under the tail.
func _build_legs() -> void:
	var half := CASE_WIDTH * 0.5
	var feet := [
		Vector3(-half + 0.20, 0.0, -0.34),
		Vector3(half - 0.20, 0.0, -0.34),
		Vector3(-half + 0.36, 0.0, -2.26),
	]
	for index in range(feet.size()):
		_build_leg("Leg%d" % index, feet[index])


func _build_leg(name_hint: String, base: Vector3) -> void:
	var leg := Node3D.new()
	leg.name = name_hint
	leg.position = base
	add_child(leg)

	# A tapered octagonal column between a moulded base and a gilded capital,
	# which is as close to the reference's carved legs as plain geometry gets.
	var shaft := _begin()
	var segments := [
		{"y": 0.00, "r": 0.086},
		{"y": 0.055, "r": 0.070},
		{"y": 0.095, "r": 0.062},
		{"y": 0.430, "r": 0.050},
		{"y": 0.500, "r": 0.066},
		{"y": 0.560, "r": 0.078},
		{"y": RIM_BOTTOM, "r": 0.082},
	]
	var sides := 8
	# White column between a gilt foot and a gilt capital, as the reference has
	# it -- legs gilded end to end read as brass posts rather than carved wood.
	# Bands 0 and 1 are the foot and 3 upwards the capital; only the long
	# middle run is lacquer.
	var gilt := _begin()
	for index in range(segments.size() - 1):
		var lower: Dictionary = segments[index]
		var upper: Dictionary = segments[index + 1]
		var tool: SurfaceTool = shaft if index == 2 else gilt
		for side in range(sides):
			var a := TAU * float(side) / float(sides)
			var b := TAU * float(side + 1) / float(sides)
			_quad(tool,
				Vector3(cos(a) * lower.r, lower.y, sin(a) * lower.r),
				Vector3(cos(b) * lower.r, lower.y, sin(b) * lower.r),
				Vector3(cos(b) * upper.r, upper.y, sin(b) * upper.r),
				Vector3(cos(a) * upper.r, upper.y, sin(a) * upper.r))
	_add_mesh("Shaft", shaft, _materials.lacquer, leg)
	_add_mesh("ShaftGilt", gilt, _materials.gold_deep, leg)

	var caster := SphereMesh.new()
	caster.radius = 0.040
	caster.height = 0.080
	caster.radial_segments = 12
	caster.rings = 6
	var wheel := MeshInstance3D.new()
	wheel.name = "Caster"
	wheel.mesh = caster
	wheel.material_override = _materials.gold
	leg.add_child(wheel)
	wheel.position = Vector3(0.0, 0.030, 0.0)


## The pedal lyre hanging under the keyboard.
func _build_pedals() -> void:
	var lyre := Node3D.new()
	lyre.name = "PedalLyre"
	lyre.position = Vector3(0.0, 0.0, -0.42)
	add_child(lyre)

	_add_strut("LyreStem", Vector3(0.0, RIM_BOTTOM, 0.0), Vector3(0.0, 0.30, 0.10),
		0.022, _materials.gold_deep, lyre)
	for side: float in [-1.0, 1.0]:
		_add_strut("LyreArm%s" % side, Vector3(0.0, RIM_BOTTOM - 0.02, 0.02),
			Vector3(side * 0.13, 0.27, 0.11), 0.013, _materials.gold_deep, lyre)

	# The foot the pedals hang off.  Without it the three pedals read as loose
	# plates lying near the floor rather than part of the instrument.
	var foot := BoxMesh.new()
	foot.size = Vector3(0.30, 0.055, 0.085)
	var foot_instance := MeshInstance3D.new()
	foot_instance.name = "LyreFoot"
	foot_instance.mesh = foot
	foot_instance.material_override = _materials.gold_deep
	lyre.add_child(foot_instance)
	foot_instance.position = Vector3(0.0, 0.285, 0.085)

	for index in range(3):
		var pedal := BoxMesh.new()
		pedal.size = Vector3(0.048, 0.013, 0.135)
		var instance := MeshInstance3D.new()
		instance.name = "Pedal%d" % index
		instance.mesh = pedal
		instance.material_override = _materials.gold
		lyre.add_child(instance)
		instance.position = Vector3((index - 1) * 0.072, 0.272, 0.183)
		instance.rotation.x = deg_to_rad(-7.0)


func _build_music_desk() -> void:
	var desk := Node3D.new()
	desk.name = "MusicDesk"
	desk.position = Vector3(0.0, RIM_TOP, KEY_WELL_Z - 0.02)
	desk.rotation.x = deg_to_rad(-22.0)
	add_child(desk)

	# Slim, as the reference's is.  Taller than this and it stands across the
	# open body like a shutter and undoes the point of having opened it.
	var panel := BoxMesh.new()
	panel.size = Vector3(CASE_WIDTH - 0.44, 0.175, 0.014)
	var instance := MeshInstance3D.new()
	instance.mesh = panel
	instance.material_override = _materials.lacquer
	desk.add_child(instance)
	instance.position = Vector3(0.0, 0.088, 0.0)


# ----------------------------------------------------------------- keyboard

func _build_keyboard() -> void:
	var white_count := 0
	for midi in range(FIRST_MIDI, LAST_MIDI + 1):
		if WHITE_PITCH_CLASSES.has(midi % 12):
			white_count += 1
	var span := CASE_WIDTH - 2.0 * CHEEK_WIDTH - 0.012
	var white_pitch := span / float(white_count)
	_white_span = span

	var keyboard := Node3D.new()
	keyboard.name = "Keyboard"
	add_child(keyboard)

	var left := -span * 0.5
	var white_index := 0
	for midi in range(FIRST_MIDI, LAST_MIDI + 1):
		var is_white: bool = WHITE_PITCH_CLASSES.has(midi % 12)
		_key_white[midi] = is_white
		var centre: float
		if is_white:
			centre = left + (float(white_index) + 0.5) * white_pitch
			white_index += 1
		else:
			# A black key straddles the joint between the two white keys that
			# surround it, which is the white boundary just passed.
			centre = left + float(white_index) * white_pitch
		_build_key(keyboard, midi, is_white, centre, white_pitch)


func _build_key(keyboard: Node3D, midi: int, is_white: bool, centre: float,
		white_pitch: float) -> void:
	var length := WHITE_KEY_LENGTH if is_white else BLACK_KEY_LENGTH
	var thickness := WHITE_KEY_THICKNESS if is_white else BLACK_KEY_THICKNESS
	var width := (white_pitch - KEY_GAP) if is_white else (white_pitch * 0.56)
	var base_y := KEY_BED_Y + (0.0 if is_white else WHITE_KEY_THICKNESS * 0.86)

	# The pivot sits at the key's back edge so pressing is a rotation about the
	# balance rail, the way a real key moves, rather than a slab sliding down.
	var pivot := Node3D.new()
	pivot.name = "Key%d" % midi
	pivot.position = Vector3(centre, base_y, KEY_WELL_Z + 0.012)
	keyboard.add_child(pivot)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, thickness, length)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _materials.ivory if is_white else _materials.ebony
	pivot.add_child(instance)
	instance.position = Vector3(0.0, thickness * 0.5, length * 0.5)

	var body := StaticBody3D.new()
	body.collision_layer = 1 << (KEY_LAYER - 1)
	body.collision_mask = 0
	body.set_meta("midi", midi)
	pivot.add_child(body)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# The hit box is taller than the key so a click just above the surface
	# still lands -- clicking a 14 mm sliver from a seated camera is fiddly.
	box.size = Vector3(width, thickness + 0.03, length)
	shape.shape = box
	shape.position = Vector3(0.0, thickness * 0.5, length * 0.5)
	body.add_child(shape)

	_keys[midi] = pivot


func _press_key(midi: int) -> void:
	var pivot: Node3D = _keys.get(midi)
	if pivot == null:
		return
	var tween := create_tween()
	tween.tween_property(pivot, "rotation:x", deg_to_rad(KEY_DIP_DEGREES), 0.035)
	tween.tween_property(pivot, "rotation:x", 0.0, 0.16).set_trans(Tween.TRANS_SINE)


# -------------------------------------------------------------------- sound

func _load_samples() -> void:
	for octave in SAMPLE_OCTAVES:
		for name in NOTE_NAMES:
			var key := "%s%d" % [name, octave]
			var path := "res://assets/audio/piano/piano_%s.ogg" % key
			var stream := load(path)
			if stream == null:
				push_warning("gallery_piano: missing sample %s" % path)
				continue
			_samples[key] = stream


func _build_voices() -> void:
	var rack := Node3D.new()
	rack.name = "Voices"
	rack.position = Vector3(0.0, RIM_TOP, -1.1)
	add_child(rack)
	for index in range(VOICES):
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Voice%d" % index
		voice.unit_size = 6.0
		voice.max_distance = 45.0
		voice.volume_db = -4.0
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		rack.add_child(voice)
		_voices.append(voice)


## Octave a note is in, in scientific pitch notation: MIDI 60 is C4.
static func octave_of(midi: int) -> int:
	return int(floor(float(midi) / 12.0)) - 1


## Which sample set plays this octave -- the nearest one, so nothing is ever
## shifted more than an octave in either direction.
static func base_octave_for(octave: int) -> int:
	var best: int = SAMPLE_OCTAVES[0]
	for candidate: int in SAMPLE_OCTAVES:
		if absi(candidate - octave) < absi(best - octave):
			best = candidate
	return best


func _play_note(midi: int) -> void:
	if _voices.is_empty():
		return
	var octave := octave_of(midi)
	var base := base_octave_for(octave)
	var stream: AudioStream = _samples.get("%s%d" % [NOTE_NAMES[midi % 12], base])
	if stream == null:
		return

	# Round-robin, so holding a chord does not cut its own notes off.
	var voice := _voices[_voice_index]
	_voice_index = (_voice_index + 1) % _voices.size()
	voice.stream = stream
	voice.pitch_scale = pow(2.0, float(octave - base))
	# Bass strings carry more weight than the top octave on a real instrument.
	voice.volume_db = lerpf(-1.0, -9.0, clampf(float(midi - FIRST_MIDI) / 87.0, 0.0, 1.0))
	voice.play()


# -------------------------------------------------------------- interaction

## A solid body round the case, so the instrument is something to walk around
## rather than through.
##
## The hull runs from the floor up to the rim rather than starting at the case
## bottom.  Three slim legs leave gaps wide enough for the player capsule to
## wedge into, and a prop that catches you halfway is worse than one that is
## honestly solid.  The case plan is already convex -- the bent side only ever
## narrows towards the tail -- so a single convex hull is an exact fit for it
## rather than the usual loose approximation.
##
## Layer 1, with the walls and the floor: not KEY_LAYER, which carries the key
## bodies alone so the picking ray cannot be blocked by the case in front of
## them, and not layer 4, which the Lens of Seeing cuts up.
func _build_case_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "CaseCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var points := PackedVector3Array()
	for point in _case_outline():
		points.append(Vector3(point.x, 0.0, point.y))
		points.append(Vector3(point.x, RIM_TOP, point.y))

	var hull := ConvexPolygonShape3D.new()
	hull.points = points

	var shape := CollisionShape3D.new()
	shape.name = "CaseHull"
	shape.shape = hull
	body.add_child(shape)


func _build_interaction_area() -> void:
	var area := Area3D.new()
	area.name = "InteractionArea"
	area.monitoring = true
	add_child(area)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CASE_WIDTH + 2.4, 3.0, CASE_LENGTH + 2.4)
	shape.shape = box
	shape.position = Vector3(0.0, 1.0, -CASE_LENGTH * 0.5)
	area.add_child(shape)

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _build_prompt() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "PianoPrompt"
	_prompt_layer.layer = 40
	add_child(_prompt_layer)

	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_color", Color(1, 1, 1))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_prompt.add_theme_constant_override("outline_size", 5)
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -96.0
	_prompt.offset_bottom = -60.0
	_prompt.visible = false
	_prompt_layer.add_child(_prompt)


func _show_prompt(text: String) -> void:
	if _prompt == null:
		return
	_prompt.text = text
	_prompt.visible = text != ""


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_in_range = true
		if not _seated:
			_show_prompt("Press Q to play the piano")


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_in_range = false
		if _seated:
			_stand_up()
		_show_prompt("")


func _unhandled_input(event: InputEvent) -> void:
	if not _seated:
		if _player_in_range and event.is_action_pressed("interact"):
			_sit_down()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		_stand_up()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_strike_at(event.position, true)
		else:
			_last_dragged_midi = -1
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		# Dragging glissandos across the keyboard, but only sounds a key when
		# the pointer crosses onto a new one.
		_strike_at(event.position, false)


## Ray from the cursor into the keyboard.  `always` sounds the key even if it
## is the one already under the pointer, which is what a fresh click means.
func _strike_at(screen_position: Vector2, always: bool) -> void:
	var camera := _camera as Camera3D
	if camera == null:
		return
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 6.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 << (KEY_LAYER - 1)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		if not always:
			_last_dragged_midi = -1
		return
	var collider: Object = hit.get("collider")
	if collider == null or not collider.has_meta("midi"):
		return
	var midi: int = collider.get_meta("midi")
	if not always and midi == _last_dragged_midi:
		return
	_last_dragged_midi = midi
	_play_note(midi)
	_press_key(midi)


func _sit_down() -> void:
	if _camera == null or not _camera.has_method("enter_inspect_framed"):
		push_warning("gallery_piano: camera has no enter_inspect_framed(); cannot sit")
		return
	_seated = true
	_dragging = false
	_last_dragged_midi = -1
	# Look at the middle of the keyboard from just above and in front of it --
	# the player's own view when seated, rather than the head-on framing the
	# paintings use.
	_camera.enter_inspect_framed(self, SEAT_FOCUS, SEAT_VIEW)
	_set_player_input(false)
	_set_player_shown(false)
	_show_prompt("Click the keys to play    ·    Esc to stand up")


func _stand_up() -> void:
	if not _seated:
		return
	_seated = false
	_dragging = false
	_last_dragged_midi = -1
	if _camera != null and _camera.has_method("exit_inspect"):
		_camera.exit_inspect()
	_set_player_shown(true)
	_set_player_input(true)
	_show_prompt("Press Q to play the piano" if _player_in_range else "")


## Take the player's model out of shot while they are seated.
##
## The seated camera sits just in front of the keyboard, which is where the
## player is standing -- without this you play the piano through the back of
## your own character.  Only nodes that were visible when sitting down are
## recorded, so standing up cannot reveal something that was already hidden,
## like the shield the player only raises while blocking.
func _set_player_shown(shown: bool) -> void:
	if shown:
		for node in _hidden_visuals:
			if is_instance_valid(node):
				node.visible = true
		_hidden_visuals.clear()
		return
	for player in get_tree().get_nodes_in_group("Player"):
		for child in (player as Node).get_children():
			if child is CollisionShape3D or child is Camera3D:
				continue
			var visual := child as Node3D
			if visual != null and visual.visible:
				visual.visible = false
				_hidden_visuals.append(visual)


func _set_player_input(enabled: bool) -> void:
	for player in get_tree().get_nodes_in_group("Player"):
		if player.has_method("set_input_enabled"):
			player.set_input_enabled(enabled)
