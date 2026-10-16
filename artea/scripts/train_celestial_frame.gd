extends Control
## Resolution-independent Artéa train trim. Decoration never intercepts input.

const Hud := preload("res://scripts/ui/artea_hud_theme.gd")
const GOLD := Color("c89e48")
const LIGHT_GOLD := Color("f4dda0")
const GOLD_WHITE := Color("fff3c9")
const DEEP_GOLD := Color("92651e")
const PEARL := Color("fff9eb")
const ICE := Color("a5cfda")
const VIOLET := Color("d5c9e3")
const RAINBOW := [Color("ebc9bc"), Color("eed7b6"), Color("f4e8c0"),
	Color("cfe1cc"), Color("c6e1e5"), Color("cddbe8"), Color("ded2e5")]
var compact := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _outline(rect: Rect2, cut: float) -> PackedVector2Array:
	var a := rect.position
	var b := rect.end
	return PackedVector2Array([Vector2(a.x + cut, a.y), Vector2(b.x - cut, a.y),
		Vector2(b.x, a.y + cut), Vector2(b.x, b.y - cut), Vector2(b.x - cut, b.y),
		Vector2(a.x + cut, b.y), Vector2(a.x, b.y - cut), Vector2(a.x, a.y + cut)])

func _edge(points: PackedVector2Array, colour: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, colour, width, true)

func _gold_plate(points: PackedVector2Array) -> void:
	draw_polygon(points, PackedColorArray([GOLD_WHITE, LIGHT_GOLD, GOLD,
		DEEP_GOLD, LIGHT_GOLD, GOLD, DEEP_GOLD, GOLD]))

func _plaque(rect: Rect2, cut: float) -> void:
	var outer := _outline(rect, cut)
	_gold_plate(outer)
	_edge(outer, DEEP_GOLD, 1.5)
	_edge(_outline(rect.grow(-2), cut - 1), GOLD_WHITE, 1)
	var inner := _outline(rect.grow(-8), cut - 3)
	draw_polygon(inner, PackedColorArray([Color("fffdf5"), Color("fffdf5"),
		PEARL, Color("f4ecd8"), Color("f4ecd8"), Color("f4ecd8"), PEARL, PEARL]))
	_edge(inner, DEEP_GOLD, 1.5)
	_edge(_outline(rect.grow(-14), maxf(5, cut - 6)), Color("cdb57a"), 1)

func _gem(at: Vector2, half_size: Vector2, colour: Color) -> void:
	var p := PackedVector2Array([at + Vector2(0, -half_size.y),
		at + Vector2(half_size.x, 0), at + Vector2(0, half_size.y),
		at - Vector2(half_size.x, 0)])
	var centre := at + Vector2(-half_size.x * .18, -half_size.y * .12)
	for i in 4:
		var tint := colour.lightened(.42) if i == 3 else colour.darkened(.22 if i == 1 else 0)
		draw_colored_polygon(PackedVector2Array([p[i], p[(i + 1) % 4], centre]), tint)
	_edge(p, GOLD, 1)
	draw_line(p[3], p[0], colour.lightened(.7), 1.4, true)

func _cap(at: Vector2, dimensions: Vector2) -> void:
	var rect := Rect2(at - dimensions * .5, dimensions)
	_gold_plate(_outline(rect, 4))
	_edge(_outline(rect, 4), DEEP_GOLD, 1)
	draw_line(rect.position + Vector2(5, 2), Vector2(rect.end.x - 5, rect.position.y + 2), GOLD_WHITE, 2, true)
	draw_line(Vector2(rect.position.x + 5, rect.end.y - 2), rect.end - Vector2(5, 2), DEEP_GOLD, 2, true)

func _rainbow_inlay(rect: Rect2) -> void:
	draw_rect(rect.grow(2), DEEP_GOLD)
	var segment := rect.size.x / float(RAINBOW.size())
	for i in RAINBOW.size():
		var piece := Rect2(rect.position + Vector2(i * segment, 0), Vector2(segment - 2, rect.size.y))
		draw_rect(piece, RAINBOW[i])
		draw_colored_polygon(PackedVector2Array([piece.position, Vector2(piece.end.x, piece.position.y),
			piece.position + Vector2(0, piece.size.y)]), Color(1, 1, 1, .24))

func _snowflake(at: Vector2) -> void:
	for i in range(8, 0, -1):
		draw_circle(at, 39 + i * 1.4, Color(.98, .88, .59, .014))
	var mount := PackedVector2Array()
	for i in 6:
		mount.append(at + Vector2.UP.rotated(i * TAU / 6.0) * 44)
	draw_colored_polygon(mount, GOLD)
	_edge(mount, GOLD_WHITE, 1)
	var inner := PackedVector2Array()
	for p in mount:
		inner.append(at + (p - at) * .90)
	draw_colored_polygon(inner, PEARL)
	for arm in 6:
		var direction := Vector2.UP.rotated(arm * TAU / 6.0)
		var end := at + direction * 34
		draw_line(at + Vector2(0, 2), end + Vector2(0, 2), DEEP_GOLD, 7, true)
		draw_line(at, end, LIGHT_GOLD, 5, true)
		draw_line(at - Vector2(1, 0), end - Vector2(1, 0), GOLD_WHITE, 1.5, true)
		for side in [-1.0, 1.0]:
			var fork := at + direction * 20
			var tip := fork + direction.rotated(side * PI / 3) * 12
			draw_line(fork, tip, GOLD, 4, true)
			draw_line(fork, tip, GOLD_WHITE, 1.1, true)
	_gem(at, Vector2(8, 12), ICE)

func _draw() -> void:
	if size.x < 50 or size.y < 50:
		return
	var top := 10.0 if compact else 65.0
	var rect := Rect2(10, top, size.x - 20, size.y - top - 12)
	var cut := 12.0 if compact else 24.0
	for i in range(5, 0, -1):
		draw_colored_polygon(_outline(Rect2(rect.position + Vector2(0, i + 2), rect.size).grow(i), cut), Color(.01, .025, .06, .06))
	_plaque(rect, cut)
	if compact:
		_gem(Vector2(21, size.y * .5), Vector2(5, 9), ICE)
		_gem(Vector2(size.x - 21, size.y * .5), Vector2(5, 9), VIOLET)
		_rainbow_inlay(Rect2(44, size.y - 20, size.x - 88, 4))
		return
	# Keep the train's roof construction, with the preferred champagne enamel.
	var rail := Rect2(20, 67, size.x - 40, 20)
	draw_polygon(_outline(rail, 5), PackedColorArray([GOLD_WHITE, GOLD_WHITE, LIGHT_GOLD,
		GOLD, GOLD, GOLD, LIGHT_GOLD, LIGHT_GOLD]))
	draw_line(Vector2(25, 66), Vector2(size.x - 25, 66), LIGHT_GOLD, 3, true)
	draw_line(Vector2(25, 88), Vector2(size.x - 25, 88), DEEP_GOLD, 3, true)
	for side in [-1.0, 1.0]:
		var x := 24.0 if side < 0 else size.x - 24.0
		_cap(Vector2(x, 76), Vector2(35, 34))
		_gem(Vector2(x, 76), Vector2(5, 9), ICE)
		_cap(Vector2(x, size.y - 29), Vector2(26, 25))
		draw_line(Vector2(x - side * 2, 105), Vector2(x - side * 2, size.y - 51), Color("cdb57a"), 2, true)
	var centre := Vector2(size.x * .5, 49)
	for side in [-1.0, 1.0]:
		draw_line(centre + Vector2(side * 27, 27), centre + Vector2(side * 67, 25), GOLD, 5, true)
		_gem(centre + Vector2(side * 61, 13), Vector2(9, 19), ICE if side < 0 else VIOLET)
		_gem(centre + Vector2(side * 81, 23), Vector2(6, 10), Color("ebc9bc") if side < 0 else Color("cfe1cc"))
	_snowflake(centre)
	_rainbow_inlay(Rect2(50, size.y - 27, size.x - 100, 6))
