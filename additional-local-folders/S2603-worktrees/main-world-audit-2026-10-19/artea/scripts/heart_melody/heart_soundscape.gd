extends Node
# No continuous garden score. Fountain music, instruments and Milo have their
# own audio. Preserve this API for embedded activation and saved restoration.
var layers: Array[AudioStreamPlayer] = []
var target_state := -1

func restore(planted: bool, complete: bool) -> void:
	var state := int(planted) + 2 * int(complete)
	if state == target_state: return
	target_state = state
