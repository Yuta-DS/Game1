class_name HeartMelodyQuestDirector
extends RefCounted

signal changed(task_ids: Array)
const Catalog = preload("res://scripts/heart_melody/heart_melody_chapter_catalog.gd")
const Fruit = preload("res://scripts/heart_melody/heart_melody_fruit_catalog.gd")
const State = preload("res://scripts/heart_melody/heart_melody_chapter_state.gd")
var progress: RefCounted

func configure(store: RefCounted) -> void:
	progress = store

func snapshot() -> Dictionary:
	return progress.committed.chapter.duplicate(true)

func _save(chapter: Dictionary) -> bool:
	# A rejected write must not become visible to gameplay or fund another action.
	# Do not overwrite a pending legacy garden/river transaction with an older snapshot.
	if progress.dirty: return false
	var before: Dictionary = progress.data.duplicate(true)
	var candidate: Dictionary = progress.committed.duplicate(true)
	chapter.revision += 1
	candidate.chapter = chapter
	if not State.valid(chapter, candidate): return false
	progress.data = candidate
	if not progress.commit():
		progress.data = before
		progress.dirty = false
		return false
	changed.emit(chapter.tasks.duplicate())
	return true

func harvest_story(fruit_id: String) -> bool:
	if fruit_id not in Fruit.IDS: return false
	var chapter := snapshot()
	var receipt := Fruit.story_location(fruit_id)
	if receipt in chapter.harvest_receipts: return true
	chapter.harvest_receipts.append(receipt)
	chapter.quest_pouch[fruit_id] = Fruit.FRUITS[fruit_id].story_count
	return _save(chapter)

func harvest_material(fruit_id: String, quantity := 1, free_inventory_slots := 1) -> bool:
	if fruit_id not in Fruit.IDS or quantity < 1 or quantity > 99 or free_inventory_slots < 0: return false
	var chapter := snapshot()
	var current := int(chapter.materials.get(fruit_id, 0))
	var accepted := mini(quantity, Fruit.STACK_LIMIT - current) if current > 0 or free_inventory_slots > 0 else 0
	chapter.materials[fruit_id] = current + accepted
	chapter.storage[fruit_id] = int(chapter.storage.get(fruit_id, 0)) + quantity - accepted
	return _save(chapter)

func withdraw(fruit_id: String, free_inventory_slots := 1) -> bool:
	if fruit_id not in Fruit.IDS or free_inventory_slots < 0: return false
	var chapter := snapshot()
	var current := int(chapter.materials.get(fruit_id, 0))
	if current == 0 and free_inventory_slots == 0: return false
	var amount := mini(Fruit.STACK_LIMIT - current, int(chapter.storage.get(fruit_id, 0)))
	if amount == 0: return false
	chapter.materials[fruit_id] = current + amount
	chapter.storage[fruit_id] -= amount
	return _save(chapter)

func craft(recipe_id: String) -> bool:
	if recipe_id not in Fruit.RECIPES: return false
	var chapter := snapshot()
	if Catalog.TASKS[1] not in chapter.tasks: return false
	if recipe_id == "harmony_glaze" and Catalog.TASKS[9] not in chapter.tasks: return false
	var recipe: Dictionary = Fruit.RECIPES[recipe_id]
	if int(chapter.materials.get(recipe.fruit, 0)) < recipe.cost: return false
	if int(chapter.recipes.get(recipe_id, 0)) >= 99: return false
	chapter.materials[recipe.fruit] -= recipe.cost
	chapter.recipes[recipe_id] = int(chapter.recipes.get(recipe_id, 0)) + 1
	return _save(chapter)

func save_challenge(task_id: String, input: Array, failures: int, hint: int) -> bool:
	var chapter := snapshot()
	if not Catalog.available(task_id, chapter.tasks): return false
	chapter.challenges[task_id] = {"input": input.duplicate(), "failures": failures, "hint": hint}
	return _save(chapter)

func save_settings(settings: Dictionary) -> bool:
	var chapter := snapshot()
	chapter.settings = settings.duplicate(true)
	return _save(chapter)

func finish_instrument(index: int, proof: Array) -> bool:
	if index < 2 or index > 9 or proof != Catalog.PATTERNS[index] or progress.dirty: return false
	var chapter := snapshot()
	var task_id: String = Catalog.TASKS[index]
	if task_id in chapter.tasks: return true # Replay cannot issue another receipt.
	if not Catalog.available(task_id, chapter.tasks): return false
	for fruit_id in Catalog.FRUIT_COSTS[index]:
		if chapter.quest_pouch.get(fruit_id, 0) < Catalog.FRUIT_COSTS[index][fruit_id]: return false
	if index == 8 and chapter.anchors.size() != 3: return false
	for fruit_id in Catalog.FRUIT_COSTS[index]:
		chapter.quest_pouch[fruit_id] -= Catalog.FRUIT_COSTS[index][fruit_id]
	chapter.tasks.append(task_id)
	if index == 7: chapter.song = ["drums", "water", "harp", "chimes"]
	if index == 9:
		chapter.reward_receipts = Catalog.REWARDS.keys()
		chapter.checkpoint = "sanctuary"
	var before: Dictionary = progress.data.duplicate(true)
	var candidate: Dictionary = progress.committed.duplicate(true)
	match index:
		2: candidate.river.valves = [0, 1, 2]
		3: candidate.river.bulbs = [0, 1, 2]
		4: candidate.river.boat = true
		5: candidate.river.chimes = [0, 1, 2]
		6: candidate.river.warning = true
	chapter.revision += 1
	candidate.chapter = chapter
	if not State.valid(chapter, candidate): return false
	progress.data = candidate
	if not progress.commit():
		progress.data = before
		progress.dirty = false
		return false
	changed.emit(chapter.tasks.duplicate())
	return true

func complete_anchor(anchor: String, proof: Array) -> bool:
	var targets := {"rhythm": [0, 2, 1], "pitch": [0, 1, 2], "direction": [0, 2, 1, 3]}
	var chapter := snapshot()
	if anchor not in targets or proof != targets[anchor] or Catalog.TASKS[7] not in chapter.tasks: return false
	if anchor in chapter.anchors: return true
	chapter.anchors.append(anchor)
	return _save(chapter)

func consume_recipe(recipe_id: String) -> bool:
	var chapter := snapshot()
	if recipe_id not in Fruit.RECIPES or chapter.recipes.get(recipe_id, 0) < 1: return false
	chapter.recipes[recipe_id] -= 1
	return _save(chapter)

func consume_fruit(fruit_id: String) -> bool:
	if fruit_id not in Fruit.IDS: return false
	var chapter := snapshot()
	if int(chapter.materials.get(fruit_id, 0)) < 1: return false
	chapter.materials[fruit_id] -= 1
	return _save(chapter)

func checkpoint(id: String) -> bool:
	var chapter := snapshot()
	var required := {"arrival": 0, "garden": 1, "restored_garden": 2, "river": 2, "bell_grove": 5, "peace_flower": 7, "stage": 7, "sanctuary": 10}
	if id not in required or chapter.tasks.size() < required[id]: return false
	chapter.checkpoint = id
	return _save(chapter)
