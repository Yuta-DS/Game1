extends RefCounted

# Offline fallback for semantic reconstruction. It separates connected painted
# regions from the paper/background and returns one bounded subject per region.
# The vision model replaces these colour-region labels with real meanings when
# available, but the game can still construct individual art objects when the
# API or player login is unavailable.

const GRID_WIDTH := 48
const GRID_HEIGHT := 48
const MIN_REGION_CELLS := 3
const MAX_SUBJECTS := 24


static func extract(image: Image) -> Array:
	if image == null or image.is_empty():
		return []
	var grid_height := clampi(int(round(GRID_WIDTH * float(image.get_height()) / maxf(image.get_width(), 1))), 24, GRID_HEIGHT)
	var colours: Array[Color] = []
	var buckets: Array[String] = []
	var background := _background_colour(image)
	for y in grid_height:
		for x in GRID_WIDTH:
			var colour := _sample(image, x, y, GRID_WIDTH, grid_height)
			colours.append(colour)
			buckets.append("" if _is_background(colour, background) else _bucket(colour))

	var visited := PackedByteArray()
	visited.resize(GRID_WIDTH * grid_height)
	var regions: Array[Dictionary] = []
	for y in grid_height:
		for x in GRID_WIDTH:
			var index := y * GRID_WIDTH + x
			if visited[index] != 0 or buckets[index].is_empty():
				continue
			var region := _flood_region(x, y, GRID_WIDTH, grid_height, buckets, colours, visited)
			if int(region.get("cells", 0)) >= MIN_REGION_CELLS:
				regions.append(region)

	regions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("cells", 0)) > int(b.get("cells", 0)))
	var output: Array = []
	for i in mini(regions.size(), MAX_SUBJECTS):
		var region: Dictionary = regions[i]
		var left := float(region["min_x"]) / GRID_WIDTH
		var top := float(region["min_y"]) / grid_height
		var width := float(region["max_x"] - region["min_x"] + 1) / GRID_WIDTH
		var height := float(region["max_y"] - region["min_y"] + 1) / grid_height
		var colour: Color = region["colour_sum"] / float(region["cells"])
		output.append({
			"id": "painted_subject_%02d" % i,
			"label": "%s painted shape" % _colour_name(colour),
			"type": "art_shape",
			"description": "A separate %s shape detected in the player's artwork" % _colour_name(colour),
			"bounding_box": {"x": left, "y": top, "width": width, "height": height},
			"normalized_position": {"x": left + width * 0.5, "y": top + height * 0.5},
			"depth_layer": _depth_for_y(top + height * 0.5),
			"scale_hint": _scale_for_area(width * height),
			"colour": "#" + colour.to_html(false),
			"source": "on_device_image_analysis",
			"child_editable": true,
		})
	return output


static func _flood_region(start_x: int, start_y: int, width: int, height: int,
		buckets: Array[String], colours: Array[Color], visited: PackedByteArray) -> Dictionary:
	var wanted := buckets[start_y * width + start_x]
	var queue: Array[Vector2i] = [Vector2i(start_x, start_y)]
	var cursor := 0
	var region := {
		"min_x": start_x, "max_x": start_x,
		"min_y": start_y, "max_y": start_y,
		"cells": 0, "colour_sum": Color(0, 0, 0, 0),
	}
	while cursor < queue.size():
		var point := queue[cursor]
		cursor += 1
		var index := point.y * width + point.x
		if visited[index] != 0 or buckets[index] != wanted:
			continue
		visited[index] = 1
		region["min_x"] = mini(region["min_x"], point.x)
		region["max_x"] = maxi(region["max_x"], point.x)
		region["min_y"] = mini(region["min_y"], point.y)
		region["max_y"] = maxi(region["max_y"], point.y)
		region["cells"] += 1
		region["colour_sum"] += colours[index]
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = point + direction
			if next.x >= 0 and next.y >= 0 and next.x < width and next.y < height:
				var next_index: int = next.y * width + next.x
				if visited[next_index] == 0 and buckets[next_index] == wanted:
					queue.append(next)
	return region


static func _sample(image: Image, x: int, y: int, width: int, height: int) -> Color:
	var px := clampi(int((float(x) + 0.5) / width * image.get_width()), 0, image.get_width() - 1)
	var py := clampi(int((float(y) + 0.5) / height * image.get_height()), 0, image.get_height() - 1)
	var colour := image.get_pixel(px, py)
	return Color.WHITE if colour.a < 0.08 else colour


static func _background_colour(image: Image) -> Color:
	var margin_x := maxi(1, image.get_width() / 30)
	var margin_y := maxi(1, image.get_height() / 30)
	return (
		image.get_pixel(margin_x, margin_y)
		+ image.get_pixel(image.get_width() - margin_x - 1, margin_y)
		+ image.get_pixel(margin_x, image.get_height() - margin_y - 1)
		+ image.get_pixel(image.get_width() - margin_x - 1, image.get_height() - margin_y - 1)
	) / 4.0


static func _is_background(colour: Color, background: Color) -> bool:
	var difference := Vector3(colour.r - background.r, colour.g - background.g, colour.b - background.b).length()
	return difference < 0.13


static func _bucket(colour: Color) -> String:
	return "%d:%d:%d" % [roundi(colour.r * 5.0), roundi(colour.g * 5.0), roundi(colour.b * 5.0)]


static func _colour_name(colour: Color) -> String:
	if colour.get_luminance() < 0.18:
		return "dark"
	if colour.r > colour.g * 1.25 and colour.r > colour.b * 1.25:
		return "red"
	if colour.g > colour.r * 1.2 and colour.g > colour.b * 1.15:
		return "green"
	if colour.b > colour.r * 1.2 and colour.b > colour.g * 1.1:
		return "blue"
	if colour.r > 0.72 and colour.g > 0.58 and colour.b < 0.48:
		return "golden"
	if colour.r > 0.65 and colour.b > 0.60:
		return "purple-pink"
	return "colourful"


static func _depth_for_y(y: float) -> String:
	if y < 0.33:
		return "far"
	if y > 0.72:
		return "near"
	return "middle"


static func _scale_for_area(area: float) -> String:
	if area > 0.18:
		return "large"
	if area < 0.035:
		return "small"
	return "medium"
