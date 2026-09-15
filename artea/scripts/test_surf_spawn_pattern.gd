extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("SURF_SPAWN_PATTERN: " + message)

func _footprint(s: Dictionary) -> Rect2:
	# Conservative world bounds, including the three-metre water blend.
	# A center-distance circle would incorrectly reject long, parallel crests.
	var c := absf(cos(s.angle))
	var d := absf(sin(s.angle))
	var half_width: float = s.width*.5+3.0
	# Include the full 3x wash footprint as well as the displaced water blend.
	var extent := Vector2(c*half_width+d*18.0,d*half_width+c*18.0)
	return Rect2(s.center-extent,extent*2.0)

func _run() -> void:
	var ocean := (load("res://scripts/Water.tscn") as PackedScene).instantiate()
	root.add_child(ocean)
	ocean.set_process(false)
	ocean.configure_harbour(Vector2(38,188.5),20.0)
	var surf: Node3D = ocean.get_node("CurlingSurf")
	var initial_ids := PackedInt64Array()
	for node in surf.get_children():
		initial_ids.append(node.get_instance_id())
	var minimum_gap := INF
	var maximum_gap := 0.0
	var moved_cycles := 0
	var times := PackedFloat64Array()
	for seed_value in [260828,1,73,90210]:
		ocean.wave_seed = seed_value
		var last_start := -INF
		for cycle in 60:
			var count := 0
			for i in 6:
				var start: float = surf.spawn_time(i,cycle)
				_check(start >= cycle*10.0 and start < (cycle+1)*10.0,"six starts stay inside each ten-second block")
				count += 1
				if last_start > -INF:
					minimum_gap = minf(minimum_gap,start-last_start)
					maximum_gap = maxf(maximum_gap,start-last_start)
				last_start = start
				if seed_value == 260828 and cycle == 0:
					times.append(start)
				var s: Dictionary = surf.sample_patch(i,start+.001)
				var previous: Dictionary = surf.sample_patch(i,start-.001)
				_check(s.cycle == cycle and previous.cycle == cycle-1,"slot switches precisely at its seeded spawn time")
				_check(s.envelope < .00001 and previous.envelope < .00001,"position changes only while both crests are faded out")
				var old_anchor: Vector2 = previous.center-Vector2(sin(previous.angle),cos(previous.angle))*(previous.age-.5)*5.0
				var new_anchor: Vector2 = s.center-Vector2(sin(s.angle),cos(s.angle))*(s.age-.5)*5.0
				if old_anchor.distance_to(new_anchor)>2.0:
					moved_cycles += 1
				_check(s.duration>=8.83 and s.duration<=11.17,"random cycle length stays within the pooled lifetime budget")
				_check(s.center.distance_to(Vector2(38,188.5))>85 and absf(s.center.x-38)>s.width*.5+40,"random positions keep berth and sailing approach clear")
				_check(s.height>=1.5 and s.height<=4.5,"new position inherits the 3x depth-based height limit")
				var footprint := _footprint(s)
				_check(footprint.end.x< -2.0 or footprint.position.x>78.0,"entire enlarged wave and blend stay outside the 80m sailing channel")
				_check(Rect2(-500,213.5,1000,286.5).encloses(footprint),"all enlarged wave corners stay offshore and within the water mesh")
				var replay: Dictionary = surf.sample_patch(i,start+.001)
				_check(s == replay,"time seeking and cached sampling reproduce identical event data")
			_check(count == 6,"exactly six scheduled events per ten seconds")
	_check(minimum_gap>=.5-.00001 and maximum_gap<2.84,"starts are staggered without bursts or long lulls")
	_check(maximum_gap-minimum_gap>.5,"spawn gaps are genuinely varied")
	_check(moved_cycles>1300,"successive cycles use visibly different positions")
	ocean.wave_seed = 260828
	for t in range(0,301,2):
		ocean.wave_time = float(t)
		ocean._process(0)
		for i in 6:
			var s: Dictionary = surf.sample_patch(i,float(t))
			var root_node := surf.get_child(i)
			_check(root_node.get_instance_id()==initial_ids[i],"existing meshes are reused instead of allocating at spawn")
			for name in ["BlenderBarrel","LipSpray"]:
				var material := root_node.get_node(name).material_override as ShaderMaterial
				_check(is_equal_approx(material.get_shader_parameter("wave_period"),s.duration) and is_equal_approx(material.get_shader_parameter("wave_age"),s.age),"barrel and spray share the randomized event clock")
			for j in range(i+1,6):
				var other: Dictionary = surf.sample_patch(j,float(t))
				_check(not _footprint(s).intersects(_footprint(other)),"enlarged, rotated wave footprints and water blends never overlap")
	_check(surf.get_child_count()==6,"active wave pool remains capped at six")
	if failures == 0:
		print("SURF_SPAWN_PATTERN: PASS — 4 seeds/240 ten-second blocks, six starts per block, randomized gaps %.2f..%.2fs, new separated positions, pooled meshes and synchronized spray" % [minimum_gap,maximum_gap])
		print("FIRST_10S_SPAWNS: ",times)
	quit(failures)
