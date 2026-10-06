extends SceneTree
const Replay := preload("res://scripts/mind_spark/recorder_replay.gd")
func _init() -> void:
	assert(Replay.order({})==[2,0,1])
	assert(Replay.order({"completed":true})==[0,1,2])
	var start := Replay.sample([0,1,2],0)
	assert(start.drift and start.flow==1 and start.shutter_open)
	var middle := Replay.sample([0,1,2],1.7)
	assert(middle.drift and middle.flow==.25 and middle.shutter_open)
	var end := Replay.sample([0,1,2],5)
	assert(end.finished and not end.shutter_open)
	var mismatch := Replay.sample([2,0,1],0)
	assert(not mismatch.drift and mismatch.flow==1 and not mismatch.shutter_open,
		"Incorrect player order must replay its contradiction, not silently replay the answer")
	print("RECORDER_REPLAY: PASS — actual player order, causal steps, legacy completed order")
	quit()
