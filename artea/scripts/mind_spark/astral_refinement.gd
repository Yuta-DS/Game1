extends Node3D
## The v16 art has independent crank parts. Perimeter collision is owned by
## IslandTwoPerimeterRepairs, which matches the visible replacement railing.

var _engines: Array[Dictionary] = []
var _phase := 0.0


func configure(zone: Node3D, foundation: Node3D) -> void:
	name = "AstralMechanismController"
	for side in ["West", "East"]:
		var engine := {}
		for part in ["Flywheel", "Pinion", "ConnectingRod", "Crosshead"]:
			engine[part] = foundation.find_child(side + part + "_v16", true, false) as Node3D
			assert(engine[part] != null, "Missing v16 mechanism: " + side + part)
		engine.side = -1.0 if side == "West" else 1.0
		_engines.append(engine)
	set_meta("gear_ratio", 20.0 / 12.0)
	set_meta("mechanism", "piston to crank to 20:12 gears to generator to lift collar")
	advance(0.0)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	advance(delta)


func advance(delta: float) -> void:
	_phase = fposmod(_phase + delta * 0.65, TAU)
	for engine in _engines:
		var wheel := engine.Flywheel as Node3D
		var pinion := engine.Pinion as Node3D
		wheel.rotation.x = _phase
		pinion.rotation.x = -_phase * 20.0 / 12.0
		var crank := Vector3(float(engine.side) * 0.88,
			-1.26 + 0.055 * cos(_phase), -0.04 + 0.055 * sin(_phase))
		var slider := Vector3(crank.x,
			crank.y + sqrt(0.205 * 0.205 - pow(0.055 * sin(_phase), 2)), -0.04)
		var rod := engine.ConnectingRod as Node3D
		rod.position = (crank + slider) * 0.5
		rod.quaternion = Quaternion(Vector3.UP, (slider - crank).normalized())
		(engine.Crosshead as Node3D).position = slider
