extends Node3D
## Fourth-island perimeter safety and fictional lift-engine animation.

const BARRIER_DATA := "res://assets3D/mind_spark/celestial_dawn_v17/barriers.json"
var _engines: Array[Dictionary] = []
var _phase := 0.0


func configure(zone: Node3D, foundation: Node3D) -> void:
	name = "DawnViaductController"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BARRIER_DATA))
	assert(not data.is_empty(), "Dawn barrier data is missing")
	var guard := StaticBody3D.new()
	guard.name = "DawnPerimeterBarrier"
	guard.set_meta("rail_height_m", data.height_m)
	guard.set_meta("bridge_half_width_m", data.bridge_half_width_m)
	zone.add_child(guard)
	var radius := float(data.radius_m)
	var intervals: Array = data.get("panel_angles", data.get("panels", []))
	assert(not intervals.is_empty(), "Dawn barrier intervals are missing")
	for interval in intervals:
		var a := float(interval[0])
		var b := float(interval[1])
		var start := Vector3(cos(a) * radius, 0, -sin(a) * radius)
		var finish := Vector3(cos(b) * radius, 0, -sin(b) * radius)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.38, float(data.collision_height_m) + 0.08,
			start.distance_to(finish) + 0.025)
		shape.shape = box
		shape.position = (start + finish) * 0.5 \
			+ Vector3.UP * (float(data.collision_height_m) * 0.5 - 0.04)
		shape.rotation.y = atan2((finish - start).x, (finish - start).z)
		guard.add_child(shape)
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
	advance(delta)


func advance(delta: float) -> void:
	_phase = fposmod(_phase + delta * 0.55, TAU)
	for engine in _engines:
		(engine.wheel as Node3D).rotation.x = _phase
		(engine.pinion as Node3D).rotation.x = -_phase * 20.0 / 12.0
