extends Node3D
## Bounded static scenery, healing crossings and saved-progress gates.
const Art = preload("res://scripts/heart_melody/heart_art.gd")
const Catalog = preload("res://scripts/heart_melody/heart_melody_chapter_catalog.gd")
var world: Node3D
var gates: Array[Dictionary] = []
var waters: Array[Area3D] = []
var celebrations := 0

func _ready() -> void:
	world = get_parent()
	# Reuse the existing archways without stacking their old sign over the
	# new gate's live requirement/achievement sign.
	for label in world.find_children("BannerText", "Label3D", true, false):
		if label.text in ["River Song / Waterfall Organ", "Harmony Stage · Shared Song"]:
			label.get_parent().hide()
	var fountain := preload("res://scripts/heart_melody/heart_arrival_garden.gd").new()
	fountain.name = "MeadowSingingFountain"
	fountain.fountain_position = Vector3.ZERO
	fountain.position = Vector3(-64, 0.05, 36)
	fountain.scale = Vector3.ONE * 0.23
	add_child(fountain)
	var music := fountain.get_node("MusicalFountain/FountainMusic") as AudioStreamPlayer3D
	music.unit_size = 4
	music.max_distance = 28
	music.volume_db = -12
	music.max_db = -10
	world._object("healing_fountain", 0, Vector3(-61, 1, 32), "Rest at the singing fountain")
	# Water sits below the bridge deck. Its healing mist reaches the walkway,
	# so recovery never requires a jump off an island or an unsafe swim.
	for spec in [[76.0, 8.0, 24.0, 15.0], [106.0, 8.0, 26.0, 17.0], [202.0, -8.0, 36.0, 40.0], [278.0, 8.0, 21.0, 23.0], [290.0, 8.0, 17.0, 22.0], [350.0, 8.0, 12.0, 24.0]]:
		_water(Vector3(spec[0], -2.6, spec[1]), Vector2(spec[2], spec[3]))
	_gate(Vector3(88, 0, 8), 6, 2, "River Song", "Restore the Feeling Garden")
	_gate(Vector3(219, 0, -8), 5.5, 5, "Bell Grove", "Restore the Rain Boat Call Bells")
	_gate(Vector3(294, 0, 8), 7, 6, "Warning Bell Path", "Restore the Harmony Bridge Chimes")
	_gate(Vector3(350, 0, 8), 7, 7, "Harmony Stage", "Complete the Warning Bell Path")
	_gate(Vector3(453, 0, 8), 7, 10, "Jewel Sanctuary", "Complete the Fruit Orchestra")
	var scenery := Node3D.new()
	scenery.name = "DetailedGardenScenery"
	add_child(scenery)
	# Layered rounded canopies, branch silhouettes and planted borders echo
	# World One's richer grounds, with a softer pastel palette of their own.
	for x in [-78.0, -48.0, -18.0, 15.0, 48.0, 126.0, 164.0, 237.0, 330.0, 370.0, 424.0, 472.0]:
		for side in [-1, 1]:
			var z := -22.0 if side < 0 else 38.0
			if x in [126.0, 164.0, 237.0]: z = -16.0 if side < 0 else 25.0
			if x == -78.0 and side > 0: continue
			_tree(scenery, Vector3(x, 0, z), int(absf(x)) % 3)
			for i in 5:
				var point := Vector3(x + i * 0.9 - 2, 0, z + side * 3)
				Art.cone(scenery, point + Vector3.UP * 0.25, 0.65, 0.35, 0.5, Color("709d78"), false, 6)
				Art.cone(scenery, point + Vector3.UP * 0.6, 0.18, 0.1, 0.2, Color("edc78d"), false, 5)
			for i in 3:
				Art.cone(scenery, Vector3(x - 4 + i, 0.35, z + side * 2), 0.6, 0.35, 0.7, Color("a5aea1"), false, 5)

func _tree(parent: Node3D, at: Vector3, variant: int) -> void:
	Art.cone(parent, at + Vector3.UP * 2.7, 0.55, 0.3, 5.4, Color("806554"), false, 7)
	for i in 3:
		var branch := Art.cone(parent, at + Vector3(sin(i * 2.1), 4.2, cos(i * 2.1)), 0.22, 0.1, 2.8, Color("806554"), false, 5)
		branch.rotation = Vector3(cos(i * 2.1) * 0.65, 0, sin(i * 2.1) * 0.65)
		var shape := SphereMesh.new()
		shape.radius = 2.6 - i * 0.25
		shape.height = 4.2
		shape.radial_segments = 8
		shape.rings = 4
		Art.mesh(parent, shape, at + Vector3(sin(i * 2.1) * 1.8, 5.4 + i * 0.6, cos(i * 2.1) * 1.8), Color(["7ba482", "a8bf86", "cca3bd"][(variant + i) % 3]))
	var ring := Art.cone(parent, at + Vector3.UP * 0.12, 3.4, 3.4, 0.24, Color("a6b792"), false, 12)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _water(at: Vector3, span: Vector2) -> void:
	# The lake beneath the islands is the water now; only its healing mist,
	# reaching up to the crossings above, is kept here.
	var area := Area3D.new()
	area.name = "HealingRiverMist"
	area.position = at + Vector3.UP * 2.2
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(span.x, 8, span.y)
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	waters.append(area)

func _gate(at: Vector3, width: float, required: int, title: String, hint: String) -> void:
	var root := Node3D.new()
	root.name = "ProgressGate" + str(required)
	root.position = at
	add_child(root)
	var leaves: Array[Node3D] = []
	for side in [-1, 1]:
		Art.cone(root, Vector3(0, 2.7, side * width * 0.5), 0.38, 0.28, 5.4, Color("e2c891"), true, 8)
		var pivot := Node3D.new()
		pivot.position.z = side * width * 0.5
		root.add_child(pivot)
		leaves.append(pivot)
		for i in 4:
			Art.box(pivot, Vector3(0, 1.9, -side * (i + 0.5) * width / 8), Vector3(0.25, 3.8, 0.13), Color("b7ccae"))
		for y in [0.6, 3.3]: Art.box(pivot, Vector3(0, y, -side * width * 0.25), Vector3(0.28, 0.22, width * 0.5), Color("e2c891"))
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.65, 4.4, width)
	collider.shape = box
	collider.position.y = 2.1
	body.add_child(collider)
	root.add_child(body)
	var sign := Art.banner(root, title + "\n" + hint, Vector3(0, 6.5, 0), 28)
	gates.append({"root": root, "leaves": leaves, "collider": collider, "required": required, "open": false, "sign": sign, "title": title, "hint": hint})

func tick(delta: float) -> void:
	if world.modal_open: return
	for area in waters:
		if area.overlaps_body(world.player):
			world.player.heal(delta * 12)
			world.chapter_world.focus = minf(100, world.chapter_world.focus + delta * 8)
	for gate in gates:
		if gate.open: continue
		var eligible: bool = world.progress.committed.chapter.tasks.size() >= gate.required
		var hint: String = gate.hint
		var completed: int = world.progress.committed.chapter.tasks.size()
		if gate.required == 5 and completed >= 2 and not eligible:
			hint = "River Song: %d / 3 restored\nNext: %s" % [completed - 2, Catalog.TITLES[completed]]
		gate.sign.text = gate.title + "\n" + ("Ready · approach to open" if eligible else hint)
		var local: Vector3 = world.player_local_position()
		if eligible and local.distance_to(gate.root.position) < 13:
			open_gate(gate)

func open_gate(gate: Dictionary) -> void:
	if gate.open: return
	gate.open = true
	gate.collider.set_deferred("disabled", true)
	gate.sign.text = gate.title + "\nCrossing open · well done!"
	var tween := create_tween().set_parallel(true)
	for i in 2: tween.tween_property(gate.leaves[i], "rotation:y", (-1 if i == 0 else 1) * PI * 0.53, 0.8).set_trans(Tween.TRANS_SINE)
	celebrations += 1
	if not world.reduced_motion: _celebrate(gate.root.position)
	world.note(0, 0.25)
	print("HEART GATE OPEN: ", gate.required, " ", gate.title)

func _celebrate(at: Vector3) -> void:
	# One short instanced burst, no permanent per-particle nodes or lights.
	var burst := GPUParticles3D.new()
	burst.name = "GateCelebration"
	burst.position = at + Vector3.UP * 5
	burst.amount = 48
	burst.lifetime = 1.7
	burst.one_shot = true
	burst.explosiveness = 1
	burst.visibility_aabb = AABB(Vector3.ONE * -15, Vector3.ONE * 30)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 160
	process.initial_velocity_min = 4
	process.initial_velocity_max = 9
	process.gravity = Vector3(0, -4, 0)
	process.scale_min = 0.12
	process.scale_max = 0.28
	process.color = Color("f5d888")
	burst.process_material = process
	var star := SphereMesh.new()
	star.radius = 0.5
	star.height = 1
	star.radial_segments = 6
	star.rings = 3
	star.material = Art.material(Color("f8dba5"))
	burst.draw_pass_1 = star
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(2.4).timeout.connect(func(): if is_instance_valid(burst): burst.queue_free())
