class_name HeartGardenObject
extends Marker3D

## Heart's small interaction adapter; World One's object enums remain untouched.
signal used(save_id: String, result: Dictionary)
var save_id := ""
var role := ""
var index := -1
var state: RefCounted

func available_actions() -> Array:
	match role:
		"planter": return ["plant", "preview", "replay"]
		"drum": return ["play", "replay"]
		"phrase": return ["confirm", "undo", "reset", "replay", "hint"]
	return ["open"]

func interact(action: StringName = &"open", value: Variant = null) -> Dictionary:
	var result := {"accepted": false, "message": "This action is not available here."}
	if state == null or str(action) not in available_actions():
		return result
	match role:
		"planter":
			if action == &"plant": result = state.plant(index,str(value))
			else: result = {"accepted": true, "message": "Listen before choosing."}
		"drum":
			if action == &"play": result = state.enter_note(["leaf","droplet","sun"][index])
			else: result = {"accepted": true, "message": "Listen to this flower."}
		"phrase":
			if action == &"confirm": result = state.confirm_phrase()
			elif action == &"undo": result = state.revise()
			elif action == &"reset": result = state.revise(true)
			elif action == &"hint": result = state.request_hint()
			else: result = {"accepted": true, "message": "Leaf → Sun → Droplet"}
		_: result = {"accepted": true, "message": "Open this interaction."}
	used.emit(save_id,result)
	return result
