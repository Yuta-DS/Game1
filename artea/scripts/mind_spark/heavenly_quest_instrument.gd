extends Node3D
## Presentation only: the puzzle's persisted state remains authoritative.
var control_id: String = ""
var _motion: Tween
var _rest: Dictionary = {}
var displayed_value: int = -1
static var _kit_materials: Dictionary = {}


func _ready() -> void:
	# GLB imports contain duplicate copies of the same atlas/materials. Share the
	# runtime resources across the kit; state feedback uses per-instance overrides.
	for instance in find_children("*", "MeshInstance3D", true, false):
		var mesh := (instance as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as BaseMaterial3D
			if material == null:
				continue
			var key := material.resource_name
			if not _kit_materials.has(key):
				_kit_materials[key] = material
			mesh.surface_set_material(surface, _kit_materials[key])
	for part_name in ["Mechanism", "Valve", "Card0", "Card1", "Card2", "Card3",
			"Charge0", "Charge1", "Charge2"]:
		var part := find_child(part_name, true, false) as Node3D
		if part != null:
			_rest[part_name] = part.transform


func apply_puzzle_state(state: Dictionary, animate: bool) -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	var value := int(state.get(control_id, -1))
	if control_id.begins_with("echo_signal_"):
		value = int(state.get("echo_classifications", [-1, -1, -1])[int(control_id.right(1)) - 1])
	elif control_id == "echo_question":
		value = int(state.get("protective_question", -1))
	elif control_id == "echo_collector":
		value = int(state.get("echo_collected", 0))
	elif control_id == "analysis_console":
		value = 1 if bool(state.get("composition_analyzed", false)) else 0
	elif control_id == "confirm":
		value = 1 if bool(state.get("signal_observatory_complete", false)) else 0
	elif control_id == "echo_beacon":
		value = 1 if bool(state.get("echo_garden_complete", false)) else 0
	displayed_value = value
	var mechanism := find_child("Mechanism", true, false) as Node3D
	if mechanism != null:
		var pose: Transform3D = _rest["Mechanism"]
		if control_id in ["outer_ring", "middle_ring", "inner_ring"]:
			_move(mechanism, "rotation:z", -float(value) * TAU / 8.0, animate)
		elif control_id == "colour_prism":
			_move(mechanism, "rotation:z", -float(maxi(value, 0)) * TAU / 3.0, animate)
		elif control_id == "rhythm_prism":
			_move(mechanism, "rotation:z", float(value - 1) * 0.38 if value >= 0 else 0.0, animate)
		elif control_id.ends_with("regulator"):
			_move(mechanism, "position:y", pose.origin.y + float(value) * .25, animate)
		elif control_id == "confirm":
			_move(mechanism, "rotation:x", -.48 if value == 1 else 0.0, animate)
		elif control_id == "echo_beacon":
			_move(mechanism, "position:y", pose.origin.y + (.25 if value == 1 else 0.0), animate)
		else:
			var count := 4 if control_id == "echo_question" else 3
			_move(mechanism, "position:x", float(value - (count - 1) * .5) * .86 if value >= 0 else 0.0, animate)
	var valve := find_child("Valve", true, false) as Node3D
	if valve != null:
		if control_id.begins_with("echo_signal_"):
			var index := int(control_id.right(1)) - 1
			_move(valve, "rotation:z", -float(state.get("echo_phases", [0,0,0])[index]) * TAU / 8.0, animate)
		else:
			_move(valve, "rotation:z", -float(value) * PI / 2.0, animate)
	for i in 4:
		var card := find_child("Card%d" % i, true, false) as Node3D
		if card == null:
			continue
		var pose: Transform3D = _rest["Card%d" % i]
		var selected := value == i
		if control_id == "analysis_console":
			selected = value == 1 or int(state.get(["colour_prism", "rhythm_prism", "weight_prism"][i], -1)) >= 0
		_move(card, "position:z", pose.origin.z + (.22 if selected else 0.0), animate)
	for i in 3:
		var charge := find_child("Charge%d" % i, true, false) as Node3D
		if charge != null:
			charge.visible = i < value


func _move(part: Node3D, property: String, target: float, animate: bool) -> void:
	if animate:
		if _motion == null:
			_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_motion.tween_property(part, property, target, .35)
	else:
		part.set_indexed(NodePath(property), target)
