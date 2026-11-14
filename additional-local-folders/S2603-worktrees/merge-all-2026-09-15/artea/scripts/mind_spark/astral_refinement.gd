extends Node3D
## The v16 art has real-scale perimeter protection and independent crank parts.
## The mechanism is kinematic scenery, not a new physics/quest system.

const BARRIER_DATA := "res://assets3D/mind_spark/celestial_astral_v16/barriers.json"
var _engines: Array[Dictionary] = []
var _phase := 0.0


func configure(zone: Node3D, foundation: Node3D) -> void:
	name = "AstralMechanismController"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BARRIER_DATA))
	var guard := StaticBody3D.new()
	guard.name = "AstralPerimeterBarrier"
	guard.set_meta("rail_height_m", data.height_m)
	guard.set_meta("bridge_half_width_m", data.bridge_half_width_m)
	zone.add_child(guard)
	var radius := float(data.radius_m)
	for interval in data.panel_angles:
		var a := float(interval[0])
		var b := float(interval[1])
		var start := Vector3(cos(a) * radius, 0, -sin(a) * radius)
		var finish := Vector3(cos(b) * radius, 0, -sin(b) * radius)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.38, float(data.collision_height_m) + 0.08, start.distance_to(finish) + 0.025)
		shape.shape = box
		shape.position = (start + finish) * 0.5 + Vector3.UP * (float(data.collision_height_m) * 0.5 - 0.04)
		shape.rotation.y = atan2((finish - start).x, (finish - start).z)
		guard.add_child(shape)
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
