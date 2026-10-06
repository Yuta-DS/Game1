extends Node3D
## Fourth-district lift-engine animation. Perimeter collision belongs to the
## visible IslandTwoPerimeterRepairs railing assembled by World One.

var _engines: Array[Dictionary] = []
var _phase := 0.0


func configure(zone: Node3D, foundation: Node3D) -> void:
	name = "DawnViaductController"
	for side in ["West", "East"]:
		var wheel := foundation.find_child(side + "SunFlywheel_v17", true, false) as Node3D
		var pinion := foundation.find_child(side + "LiftPinion_v17", true, false) as Node3D
		# The first generated asset predates the explicit revision suffix. Keeping
		# this alias makes the authoring rebuild forward-compatible without moving
		# the saved source or changing any animation semantics.
		if wheel == null:
			wheel = foundation.find_child(side + "SunFlywheel", true, false) as Node3D
		if pinion == null:
			pinion = foundation.find_child(side + "LiftPinion", true, false) as Node3D
		var engine := {"wheel": wheel, "pinion": pinion}
		assert(engine.wheel != null and engine.pinion != null,
			"Missing Dawn lift mechanism: " + side)
		_engines.append(engine)
	set_meta("gear_ratio", 20.0 / 12.0)
	set_meta("mechanism", "paired buoyancy drums driven by mirrored 20:12 gear trains")
	advance(0.0)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	advance(delta)


func advance(delta: float) -> void:
	_phase = fposmod(_phase + delta * 0.55, TAU)
	for engine in _engines:
		(engine.wheel as Node3D).rotation.x = _phase
		(engine.pinion as Node3D).rotation.x = -_phase * 20.0 / 12.0
