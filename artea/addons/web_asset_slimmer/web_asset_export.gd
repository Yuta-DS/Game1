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
## On Web, a texture stored losslessly or lossily is capped at MAX_TEXTURE_SIZE
## and re-stored as lossy WebP when it is a 3D texture (has mipmaps) or larger
## than MIN_SIZE_TO_REENCODE. Small UI icons and pixel-art sprites are left
## alone: lossy WebP smudges hard pixel edges.
##
## A VRAM-compressed (S3TC/BPTC) texture is capped the same way and re-stored as
## Basis Universal, which stays GPU-compressed: the browser transcodes it to
## whatever it supports (S3TC/BPTC on desktop, ETC2/ASTC on mobile, which plain
## S3TC does not reach). Flat 2D art that was imported as VRAM shrinks by 30x
## and more (joyring.png 3.6 MB -> 36 KB); detailed 3D textures stay about the
## same size and quality (Milo's skin 2.73 -> 2.78 MB, same PSNR as the DXT1).
## Nothing is dropped - every texture is still exported.

const MAX_TEXTURE_SIZE := 2048
const MIN_SIZE_TO_REENCODE := 1024
const LOSSY_QUALITY := 0.85
# LDR block formats Basis can stand in for. HDR (BPTC_RF*) and normal-map RGTC
# imports are left as they are.
const BASIS_SOURCE_FORMATS := [Image.FORMAT_DXT1, Image.FORMAT_DXT3,
	Image.FORMAT_DXT5, Image.FORMAT_BPTC_RGBA]

var _stats := {}


func _get_name() -> String:
	return "WebAssetSlimmer"


func _get_customization_configuration_hash() -> int:
	# Changing any setting must invalidate the export cache of customised files.
	return hash("web_asset_slimmer v4 %d %d %.2f" % [
		MAX_TEXTURE_SIZE, MIN_SIZE_TO_REENCODE, LOSSY_QUALITY])


func _begin_customize_scenes(platform: EditorExportPlatform, _features: PackedStringArray) -> bool:
	return platform.get_os_name() == "Web"


func _customize_scene(scene: Node, _path: String) -> Node:
	# Godot 4.7's export resource walker reads all four advertised particle
	# mesh properties even when only one pass is allocated. Allocate the empty
	# slots in the Web copy; their null meshes draw nothing. Native scenes and
	# the authored particle effect remain unchanged.
	var pending: Array[Node] = [scene]
	var changed := false
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		pending.append_array(node.get_children())
		if node is GPUParticles3D and node.draw_passes < 4:
			node.draw_passes = 4
			changed = true
	return scene if changed else null


func _begin_customize_resources(platform: EditorExportPlatform,
		_features: PackedStringArray) -> bool:
	_stats = {"seen": 0, "reencoded": 0, "vram_seen": 0, "basis": 0, "downscaled": 0}
	return platform.get_os_name() == "Web"


func _end_customize_resources() -> void:
	if _stats.is_empty():
		return
	print("WebAssetSlimmer: %d of %d uncompressed textures re-encoded as lossy WebP, %d of %d VRAM textures as Basis Universal (%d downscaled)" % [
		_stats.reencoded, _stats.seen, _stats.basis, _stats.vram_seen, _stats.downscaled])


func _customize_resource(resource: Resource, path: String) -> Resource:
	# Standalone texture files only. A texture embedded in a scene (path is
	# empty) would make Godot re-save that whole scene, and the re-saved copy
	# came out far larger than the import - Father_output went 12 -> 23 MiB -
	# more than undoing the texture saving. Files are referenced by path, so
	# swapping one leaves every scene that uses it untouched.
	if path.is_empty() or not (resource is CompressedTexture2D or resource is ImageTexture):
		return null
	var image := (resource as Texture2D).get_image()
	if image == null or image.is_empty():
		return null
	var vram := image.is_compressed()
	if vram:
		_stats.vram_seen += 1
		if image.get_format() not in BASIS_SOURCE_FORMATS or image.decompress() != OK:
			return null
	else:
		_stats.seen += 1
	var had_mipmaps := image.has_mipmaps()
	var longest := maxi(image.get_width(), image.get_height())
	if not vram and not had_mipmaps and longest <= MIN_SIZE_TO_REENCODE:
		return null

	if longest > MAX_TEXTURE_SIZE:
		var scale := float(MAX_TEXTURE_SIZE) / float(longest)
		image.resize(maxi(1, roundi(image.get_width() * scale)),
			maxi(1, roundi(image.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
		_stats.downscaled += 1
	if had_mipmaps and not image.has_mipmaps():
		image.generate_mipmaps()

	var slim := PortableCompressedTexture2D.new()
	if vram:
		slim.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_BASIS_UNIVERSAL)
		_stats.basis += 1
	else:
		slim.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY,
			false, LOSSY_QUALITY)
		_stats.reencoded += 1
	return slim
