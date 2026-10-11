@tool
extends EditorExportPlugin
## Shrinks textures in the Web export only (issue #39).
##
## The import settings in each .import file are shared by every export preset,
## so changing them would change desktop builds too. Export-time resource
## customisation is scoped by platform instead: _begin_customize_resources()
## answers false for anything but Web, so desktop presets never reach
## _customize_resource() and their packs stay byte-for-byte identical.
##
## On Web, a texture stored losslessly or lossily (not VRAM-compressed, which is
## already compact) is capped at MAX_TEXTURE_SIZE and re-stored as lossy WebP
## when it is a 3D texture (has mipmaps) or larger than MIN_SIZE_TO_REENCODE.
## Small UI icons and pixel-art sprites are left alone: lossy WebP smudges
## hard pixel edges. Nothing is dropped - every texture is still exported.

const MAX_TEXTURE_SIZE := 2048
const MIN_SIZE_TO_REENCODE := 1024
const LOSSY_QUALITY := 0.85

var _stats := {}


func _get_name() -> String:
	return "WebAssetSlimmer"


func _get_customization_configuration_hash() -> int:
	# Changing any setting must invalidate the export cache of customised files.
	return hash("web_asset_slimmer v2 %d %d %.2f" % [
		MAX_TEXTURE_SIZE, MIN_SIZE_TO_REENCODE, LOSSY_QUALITY])


func _begin_customize_resources(platform: EditorExportPlatform,
		_features: PackedStringArray) -> bool:
	_stats = {"seen": 0, "reencoded": 0, "downscaled": 0}
	return platform.get_os_name() == "Web"


func _end_customize_resources() -> void:
	if _stats.is_empty():
		return
	print("WebAssetSlimmer: %d of %d uncompressed textures re-encoded as lossy WebP (%d downscaled)" % [
		_stats.reencoded, _stats.seen, _stats.downscaled])


func _customize_resource(resource: Resource, path: String) -> Resource:
	# Standalone texture files only. A texture embedded in a scene (path is
	# empty) would make Godot re-save that whole scene, and the re-saved copy
	# came out far larger than the import - Father_output went 12 -> 23 MiB -
	# more than undoing the texture saving. Files are referenced by path, so
	# swapping one leaves every scene that uses it untouched.
	if path.is_empty() or not (resource is CompressedTexture2D or resource is ImageTexture):
		return null
	var image := (resource as Texture2D).get_image()
	if image == null or image.is_empty() or image.is_compressed():
		return null
	_stats.seen += 1
	var had_mipmaps := image.has_mipmaps()
	var longest := maxi(image.get_width(), image.get_height())
	if not had_mipmaps and longest <= MIN_SIZE_TO_REENCODE:
		return null

	if longest > MAX_TEXTURE_SIZE:
		var scale := float(MAX_TEXTURE_SIZE) / float(longest)
		image.resize(maxi(1, roundi(image.get_width() * scale)),
			maxi(1, roundi(image.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
		_stats.downscaled += 1
	if had_mipmaps and not image.has_mipmaps():
		image.generate_mipmaps()

	var slim := PortableCompressedTexture2D.new()
	slim.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY,
		false, LOSSY_QUALITY)
	_stats.reencoded += 1
	return slim
