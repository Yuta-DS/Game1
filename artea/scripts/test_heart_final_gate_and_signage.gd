extends SceneTree
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("Final gate test timeout"); quit(1))
	var state = root.get_node("JourneyState")
	state.save_path = "res://../work/heart-final-gate-journey.json"
	var treasures: Dictionary = state.treasures.duplicate(true)
	var heart = load("res://scenes/heart_melody/heart_melody_world.tscn").instantiate()
	heart.test_mode = true
	heart.progress.path = "res://../work/heart-final-gate-save.json"
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(heart.progress.path + suffix))
	root.add_child(heart)
	current_scene = heart
	await physics_frame
	check(heart.progress.plant(0, 6), "partial progress prepared")
	var forbidden := ["Leaf", "Droplet", "Sun", "LEAF", "DROPLET", "SUN", "MOON", "Moth restored", "Slime restored", "COMFORT LANTERN", "SONG MEMORY BENCH", "PEACE FLOWER"]
	var banners := 0
	for text in heart.find_children("*", "Label3D", true, false):
		check(text.text not in forbidden and not text.text.ends_with(" seed"), "small object labels removed: " + text.text)
		if text.name == "BannerText":
			banners += 1
			check(text.get_parent().find_children("*", "CollisionShape3D", true, false).is_empty(), "banner has no player or camera collision")
	check(banners >= 10, "major instruments keep their sign text")
	for banner in heart.find_children("LandmarkBanner", "Node3D", true, false):
		check(not banner.visible, "no floating sign over the island: " + banner.get_node("BannerText").text)
	heart.player.position = Vector3(477, 1.5, 8)
	var returned := false
	for frame in 1800:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/art_gallery_3d_inprogress.tscn": returned = true; break
	check(returned, "last gate returns to actual Art Castle")
	var saved = load("res://scripts/heart_melody/heart_progress.gd").new()
	saved.path = "res://../work/heart-final-gate-save.json"
	saved.load_progress()
	check(saved.committed.planters.has("0") and not saved.committed.complete, "Castle return saves partial chapter")
	check(state.treasures == treasures, "Castle return changes no treasure entitlements")
	print("HEART FINAL GATE AND SIGNAGE: PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
