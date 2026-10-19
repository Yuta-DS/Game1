extends SceneTree
var failures: Array[String] = []
func _init() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	var world = load("res://scenes/heart_melody/heart_melody_world.tscn").instantiate()
	world.test_mode = true
	world.progress.path = "res://../work/heart-feedback-save.json"
	root.add_child(world)
	current_scene = world
	for frame in 8: await physics_frame
	var thin = world.musical_garden.instrument_visuals.harp[0]
	thin.scale = Vector3(0.12, 0.65, 0.08)
	var base: Vector3 = thin.scale
	var drum = world.musical_garden.instrument_visuals.drums[0]
	var drum_scale: Vector3 = drum.scale
	for repeat in 40:
		world.musical_garden.play_note("harp", 0)
		world.musical_garden.play_note("drums", 0)
		world._pulse(thin)
		await physics_frame
		check(thin.scale.is_equal_approx(base) and drum.scale.is_equal_approx(drum_scale), "rapid notes preserve instrument and flower size")
	for frame in 30: await physics_frame
	check(thin.rotation.is_equal_approx(thin.get_meta("note_rotation")), "overlapping feedback returns to the authored pose")
	var item: Dictionary = {}
	for entry in world.interactables:
		if entry.kind == "music_drum" and entry.index == 0: item = entry; break
	check(not item.is_empty(), "flower drum control exists")
	for offset in [Vector3(0, 1, 3), Vector3(0, 1, -3), Vector3(3, 1, 0), Vector3(-3, 1, 0)]:
		world.player.global_position = world.to_global(item.pos + offset)
		await physics_frame
		check(world._interaction_distance(item) < 5 and world._interaction_visible(item), "flower plays from front, back and both sides")
		var previous_feedback = drum.get_meta("note_tween", null)
		world.nearest = world.interactables.find(item)
		world._interact_nearest()
		check(drum.get_meta("note_tween", null) != previous_feedback, "interact actually plays the flower from each side")
	var note_positions := {}
	for entry in world.interactables:
		if entry.kind == "chapter_note": note_positions[str(entry.pos)] = true
	check(note_positions.size() >= 25, "adjacent flower keys keep separate interaction positions")
	var generic := 0
	for entry in world.interactables:
		if entry.kind == "flower": generic += 1
	check(generic > 20, "decorative flowers also have playable controls")
	for entry in world.interactables:
		if entry.kind != "flower": continue
		var was_visible: bool = entry.flower.visible
		entry.flower.hide()
		check(world._interaction_distance(entry) == INF, "hidden restoration flowers do not offer invisible controls")
		entry.flower.visible = was_visible
		break
	for child in world.river.get_children():
		if child is Node3D and child.get_child_count() > 0 and child.get_child(0) is MeshInstance3D:
			if child.get_child(0).mesh is BoxMesh and child.get_child(0).mesh.size.is_equal_approx(Vector3(1.6, 0.18, 1.6)):
				check(child.position.y < 0.3, "organ symbol plaque is grounded beside its flower")
	print("HEART PLAY FEEDBACK: PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
