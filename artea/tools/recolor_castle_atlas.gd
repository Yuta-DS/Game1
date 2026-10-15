extends SceneTree

# Regenerates assets3D/houses/red/hexagons_castle_rose.png, the Hub castle's
# Sleeping Beauty palette: the blue-grey masonry turns rose pink and the red
# roofs and pennants turn cobalt blue. Dark details (windows, doors) keep their
# colour. The village houses keep the original atlas; only the castle's own
# materials switch to this copy (scripts/castle_redesign.gd).
#
#   godot --headless --path artea --script res://tools/recolor_castle_atlas.gd

const SOURCE := "res://assets3D/houses/red/hexagons_castle.png"
const TARGET := "res://assets3D/houses/red/hexagons_castle_rose.png"
const ROSE_HUE := 350.0 / 360.0
const ROOF_HUE := 216.0 / 360.0


func _init() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			image.set_pixel(x, y, recolor(image.get_pixel(x, y)))
	var error := image.save_png(ProjectSettings.globalize_path(TARGET))
	print("recolor_castle_atlas: wrote %s (%s)" % [TARGET, error_string(error)])
	quit(error)


static func recolor(c: Color) -> Color:
	# Red roofs and pennants -> cobalt blue, a little darker so the roofs still
	# read against a bright sky.
	if c.r > 0.45 and c.r > c.g * 1.6 and c.r > c.b * 1.6:
		return Color.from_hsv(ROOF_HUE, clampf(c.s * 0.8, 0.0, 1.0), c.v * 0.8, c.a)
	# Grey masonry -> pale rose. Brightened so the castle reads pink rather than
	# muddy; scaling keeps the atlas's light/dark stone hierarchy.
	if c.s < 0.25 and c.v > 0.3:
		return Color.from_hsv(ROSE_HUE, 0.24 + c.s * 0.5, minf(1.0, c.v * 1.42), c.a)
	return c
