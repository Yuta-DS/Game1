@tool
extends "res://addons/proton_scatter/src/modifiers/base_modifier.gd"


const TERRAIN_HALF_EXTENT := 2048.0
const SURFACE_MAP_PATH := "res://resources/web_hub_surface_map.png"
const GRASS_TEXTURE_ID := 0

var _surface_map: Image


func _init() -> void:
	display_name = "Keep On Web Grass Soil"
	category = "Remove"
	can_restrict_height = false
	global_reference_frame_available = true
	local_reference_frame_available = false
	individual_instances_reference_frame_available = false
	use_global_space_by_default()

	var map_texture := load(SURFACE_MAP_PATH) as Texture2D
	if map_texture != null:
		_surface_map = map_texture.get_image()


func _process_transforms(transforms, domain, _seed) -> void:
	if transforms.is_empty():
		return
	if _surface_map == null or _surface_map.is_empty():
		transforms.list.clear()
		warning = "Web grass surface map is unavailable; grass was removed for safe placement."
		return

	var root_transform: Transform3D = domain.get_global_transform()
	var kept: Array[Transform3D] = []
	for transform in transforms.list:
		var world_position: Vector3 = (root_transform * transform).origin
		if _is_strict_grass_soil(world_position):
			kept.push_back(transform)
	transforms.list.clear()
	transforms.list.append_array(kept)


func _is_strict_grass_soil(world_position: Vector3) -> bool:
	var uv := (Vector2(world_position.x, world_position.z) + Vector2.ONE * TERRAIN_HALF_EXTENT) \
		/ (TERRAIN_HALF_EXTENT * 2.0)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return false

	var last := Vector2i(_surface_map.get_width() - 1, _surface_map.get_height() - 1)
	var center := Vector2i(roundi(uv.x * last.x), roundi(uv.y * last.y))
	# Require the centre and its immediate neighbours to be grass. This leaves a
	# clean margin around sand, brick and stone boundaries so no blade straddles
	# the edge of a non-soil surface.
	for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var pixel: Vector2i = center + offset
		if pixel.x < 0 or pixel.y < 0 or pixel.x > last.x or pixel.y > last.y:
			return false
		if _surface_id_at(pixel) != GRASS_TEXTURE_ID:
			return false
	return true


func _surface_id_at(pixel: Vector2i) -> int:
	return clampi(floori(_surface_map.get_pixelv(pixel).r * 3.0), 0, 2)
