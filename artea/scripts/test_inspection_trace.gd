extends SceneTree
const Trace := preload("res://scripts/mind_spark/inspection_trace.gd")
func _init() -> void:
	assert(Trace.series(1,0) != Trace.series(1,1), "Recorder windows must visibly differ")
	assert(Trace.series(1,3) != Trace.series(1,0), "Earlier flow must differ from closed-shutter frame")
	assert(Trace.series(1,1)[0].y > Trace.series(1,1)[24].y)
	assert(Trace.event_marker(1,1) > .42, "Shutter closure follows flow loss")
	assert(Trace.event_marker(0,2) > .36, "Ari touches after drift begins")
	for setting in 4:
		assert(Trace.shutter_open(2,setting) == (setting == 3))
		assert((Trace.clarity(0,setting) == 1) == (setting == 2))
		for channel in 3:
			for point in Trace.series(channel,setting):
				assert(point.x >= 0 and point.x <= 1 and point.y >= 0 and point.y <= 1)
	print("INSPECTION_TRACE: PASS — distinct recorder windows, causal order, focus and observable bypass response")
	quit()
