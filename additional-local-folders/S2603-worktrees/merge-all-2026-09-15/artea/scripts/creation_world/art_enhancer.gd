extends RefCounted

# A deliberately gentle, non-generative fallback. It never overwrites the
# original drawing; it creates an optional colour-and-light variation that the
# artist can keep or discard while image-generation providers are unavailable.


static func create_variation(source: Image, style_name: String, strength := 0.32) -> Image:
	if source == null:
		return null
	var output: Image = source.duplicate()
	output.convert(Image.FORMAT_RGBA8)
	var style := style_name.to_lower()
	var mix_amount := clampf(strength, 0.0, 0.55)

	for y in output.get_height():
		for x in output.get_width():
			var original: Color = output.get_pixel(x, y)
			var adjusted: Color = original
			if style.contains("water"):
				adjusted = _watercolour(original)
			elif style.contains("collage") or style.contains("paper"):
				adjusted = _paper_collage(original)
			elif style.contains("pastel") or style.contains("storybook"):
				adjusted = _storybook_pastel(original)
			else:
				adjusted = _gentle_polish(original)
			adjusted.a = original.a
			output.set_pixel(x, y, original.lerp(adjusted, mix_amount))
	return output


static func save_variation(source: Image, original_path: String, style_name: String) -> String:
	var variation: Image = create_variation(source, style_name)
	if variation == null:
		return ""
	var directory := "user://artworks/ai_variations/"
	DirAccess.make_dir_recursive_absolute(directory)
	var safe_style := style_name.to_lower().replace(" ", "_")
	for forbidden in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		safe_style = safe_style.replace(forbidden, "")
	var base := original_path.get_file().get_basename()
	var path := "%s%s_%s_%d.png" % [directory, base, safe_style, Time.get_ticks_usec()]
	return path if variation.save_png(path) == OK else ""


static func _watercolour(colour: Color) -> Color:
	var luminance := colour.get_luminance()
	var paper := Color(1.0, 0.97, 0.91)
	var softened := colour.lerp(Color(luminance, luminance, luminance), 0.08)
	return softened.lerp(paper, 0.10)


static func _paper_collage(colour: Color) -> Color:
	var levels := 7.0
	return Color(
		round(colour.r * levels) / levels,
		round(colour.g * levels) / levels,
		round(colour.b * levels) / levels,
		colour.a
	)


static func _storybook_pastel(colour: Color) -> Color:
	var lifted := Color(
		pow(colour.r, 0.88),
		pow(colour.g, 0.88),
		pow(colour.b, 0.88),
		colour.a
	)
	return lifted.lerp(Color(1.0, 0.92, 0.95), 0.09)


static func _gentle_polish(colour: Color) -> Color:
	var luminance := colour.get_luminance()
	var contrast := Color(
		clampf((colour.r - 0.5) * 1.08 + 0.5, 0.0, 1.0),
		clampf((colour.g - 0.5) * 1.08 + 0.5, 0.0, 1.0),
		clampf((colour.b - 0.5) * 1.08 + 0.5, 0.0, 1.0),
		colour.a
	)
	return contrast.lerp(Color(luminance, luminance, luminance), -0.04)
