extends SceneTree

# Numeric diff of the before/after captures written by
# capture_streaming_compare.gd, plus a per-pixel difference image.

const NAMES := ["inside_north", "doorway_out", "wide_vista"]
const DIR := "res://artifacts/streaming_compare/"


func _init() -> void:
	for name in NAMES:
		var off := Image.load_from_file(DIR + name + "_off.png")
		var on := Image.load_from_file(DIR + name + "_on.png")
		if off == null or on == null:
			print(name, ": MISSING")
			continue
		var w := off.get_width()
		var h := off.get_height()
		var total := w * h
		var changed := 0
		var strong := 0
		var diff := Image.create(w, h, false, Image.FORMAT_RGB8)
		for y in h:
			for x in w:
				var a := off.get_pixel(x, y)
				var b := on.get_pixel(x, y)
				var delta: float = maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))
				if delta > 0.03:
					changed += 1
				if delta > 0.16:
					strong += 1
					diff.set_pixel(x, y, Color.RED)
				elif delta > 0.03:
					diff.set_pixel(x, y, Color(0.25, 0.25, 0.25))
		diff.save_png(DIR + name + "_diff.png")
		print("%-14s changed>3%%: %6.3f%%   changed>16%%: %6.3f%%" % [
			name, 100.0 * float(changed) / float(total),
			100.0 * float(strong) / float(total)])
	quit()
