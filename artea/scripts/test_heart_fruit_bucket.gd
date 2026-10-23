extends SceneTree
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func run() -> void:
	var heart = load("res://scenes/heart_melody/heart_melody_world.tscn").instantiate()
	heart.test_mode = true
	heart.progress.path = "res://../work/fruit-bucket-test.json"
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(heart.progress.path + suffix))
	root.add_child(heart)
	current_scene = heart
	await process_frame
	var chapter = heart.chapter_world
	var id: String = chapter.Fruit.IDS[0]
	check(chapter.director.harvest_story(id), "story fruit harvested")
	check(chapter.director.harvest_material(id, 2), "edible fruit harvested")
	var pouch: Dictionary = chapter.director.snapshot().quest_pouch.duplicate(true)
	heart.player.current_health = 40
	chapter.focus = 40
	chapter.fruit_bucket()
	check(chapter.eat_fruit(id), "eat from bucket")
	check(heart.player.current_health == 60 and chapter.focus == 60, "fruit restores health and focus")
	check(chapter.director.snapshot().materials[id] == 1, "eating consumes exactly one fruit")
	check(chapter.director.snapshot().quest_pouch == pouch, "story allotment protected")
	var orchard: String = heart.musical_garden.Catalog.FRUIT_ORDER[0]
	check(heart.progress.discover_fruit(orchard), "orchard harvest")
	check(heart.progress.eat_orchard_fruit(orchard), "orchard fruit eaten")
	check(not heart.progress.eat_orchard_fruit(orchard), "empty bucket cannot be eaten twice")
	heart.musical_garden.refresh()
	check(not heart.musical_garden.basket_fruit[orchard].visible and heart.musical_garden.fruit_visuals[orchard].visible, "bucket empties and orchard regrows")
	check(heart.progress.data.music.discovered.has(orchard), "musical voice retained")
	check(heart.progress.discover_fruit(orchard), "fruit can be harvested again")
	var saved_path: String = heart.progress.path
	heart.progress.path = "res://missing-directory/fruit.json"
	check(not chapter.director.consume_fruit(id), "failed save rejects consumption")
	check(chapter.director.snapshot().materials[id] == 1, "failed save preserves fruit")
	heart.progress.path = saved_path
	heart.progress.load_progress()
	check(chapter.director.snapshot().materials[id] == 1, "consumed count survives reload")
	for label in heart.find_children("BannerText", "Label3D", true, false):
		label.get_parent()._process(0)
		check(label.position.z > 0 and label.billboard == BaseMaterial3D.BILLBOARD_DISABLED, "banner text separated from backing")
		check(label.get_parent().get_child(0).mesh.size.y >= label.get_aabb().size.y + 0.59, "banner accommodates wrapped text")
	print("HEART FRUIT BUCKET: PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
