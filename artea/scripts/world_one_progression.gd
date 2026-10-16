class_name WorldOneProgressionState
extends Node

signal xp_changed(xp: int, level: int)
signal level_changed(level: int, skill_points: int)
signal inventory_changed
signal equipment_changed(slot: String, item_id: String)
signal currency_changed(currency_id: String, amount: int)
signal skill_unlocked(skill_id: String)
signal assist_changed(settings: Dictionary)
signal assistance_suggested(context_id: String, failures: int)

const SAVE_PATH := "user://world_one_progression.json"
const CATALOG_PATH := "res://resources/mind_spark/progression_catalog.json"
const SCHEMA_VERSION := 1
const INVENTORY_CAPACITY := 30
const EQUIPMENT_SLOTS := ["blade", "shield", "charm", "outfit"]
const SKILL_POINT_LEVELS := [2, 4, 6, 8, 10]

var save_path := SAVE_PATH
var xp := 0
var level := 1
var skill_points := 0
var spark_shards := 0
var inventory: Array[Dictionary] = []
var checkpoint_storage: Array[Dictionary] = []
var quest_items: Dictionary = {}
var equipped := {"blade": "", "shield": "", "charm": "", "outfit": ""}
var unlocked_recipes := PackedStringArray()
var unlocked_skills := PackedStringArray()
var reward_receipts := PackedStringArray()
var mastery_records: Dictionary = {}
var failure_counts: Dictionary = {}
var assist_settings := {
	"enabled": false,
	"telegraph_multiplier": 1.0,
	"incoming_damage_multiplier": 1.0,
	"boss_phase_restart": false,
}

var _catalog: Dictionary = {}
var _items: Dictionary = {}
var _recipes: Dictionary = {}
var _skills: Dictionary = {}


func _ready() -> void:
	_load_catalog()
	load_progress()


func configure_save_path(custom_path: String, reload := true) -> void:
	save_path = custom_path
	if reload:
		load_progress()


func reset_new_save(write := false) -> void:
	xp = 0
	level = 1
	skill_points = 0
	spark_shards = 0
	inventory.clear()
	checkpoint_storage.clear()
	quest_items.clear()
	equipped = {"blade": "", "shield": "", "charm": "", "outfit": ""}
	unlocked_recipes = PackedStringArray()
	unlocked_skills = PackedStringArray()
	reward_receipts = PackedStringArray()
	mastery_records.clear()
	failure_counts.clear()
	assist_settings = {
		"enabled": false,
		"telegraph_multiplier": 1.0,
		"incoming_damage_multiplier": 1.0,
		"boss_phase_restart": false,
	}
	if write:
		save_progress()


func get_xp_thresholds() -> PackedInt32Array:
	var values := PackedInt32Array()
	for value in _catalog.get("xp_thresholds", []):
		values.append(int(value))
	return values


func get_item_definition(item_id: String) -> Dictionary:
	return (_items.get(item_id, {}) as Dictionary).duplicate(true)


func get_recipe_definition(recipe_id: String) -> Dictionary:
	return (_recipes.get(recipe_id, {}) as Dictionary).duplicate(true)


func get_skill_definition(skill_id: String) -> Dictionary:
	return (_skills.get(skill_id, {}) as Dictionary).duplicate(true)


func get_all_item_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in _items:
		result.append((_items[item_id] as Dictionary).duplicate(true))
	return result


func get_all_skill_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill_id in _skills:
		result.append((_skills[skill_id] as Dictionary).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("branch", "")) + "%02d" % int(a.get("order", 0)) \
			< str(b.get("branch", "")) + "%02d" % int(b.get("order", 0)))
	return result


func has_receipt(receipt_id: String) -> bool:
	return receipt_id in reward_receipts


func grant_xp(amount: int, receipt_id := "") -> Dictionary:
	if amount <= 0 or (not receipt_id.is_empty() and has_receipt(receipt_id)):
		return {"accepted": false, "reason": "invalid_or_received"}
	var before := snapshot()
	if not receipt_id.is_empty():
		reward_receipts.append(receipt_id)
	var old_level := level
	xp += amount
	_recalculate_level()
	if not save_progress():
		_apply_snapshot(before)
		return {"accepted": false, "reason": "save_failed"}
	xp_changed.emit(xp, level)
	if level != old_level:
		level_changed.emit(level, skill_points)
	return {"accepted": true, "xp": xp, "level": level}


func grant_currency(amount: int, receipt_id := "") -> Dictionary:
	if amount <= 0 or (not receipt_id.is_empty() and has_receipt(receipt_id)):
		return {"accepted": false, "reason": "invalid_or_received"}
	var before := snapshot()
	if not receipt_id.is_empty():
		reward_receipts.append(receipt_id)
	spark_shards += amount
	if not save_progress():
		_apply_snapshot(before)
		return {"accepted": false, "reason": "save_failed"}
	currency_changed.emit("spark_shards", spark_shards)
	return {"accepted": true, "amount": spark_shards}


func grant_item(item_id: String, quantity := 1, receipt_id := "") -> Dictionary:
	var definition := _items.get(item_id, {}) as Dictionary
	if definition.is_empty() or quantity <= 0 \
			or (not receipt_id.is_empty() and has_receipt(receipt_id)):
		return {"accepted": false, "reason": "invalid_or_received"}
	if str(definition.get("category", "")) == "quest":
		quest_items[item_id] = int(quest_items.get(item_id, 0)) + quantity
	else:
		_add_inventory_quantity(item_id, quantity)
	if not receipt_id.is_empty():
		reward_receipts.append(receipt_id)
	if not save_progress():
		load_progress()
		return {"accepted": false, "reason": "save_failed"}
	inventory_changed.emit()
	return {"accepted": true, "item_id": item_id, "quantity": quantity}


func grant_reward_bundle(bundle: Dictionary, receipt_id: String) -> Dictionary:
	if receipt_id.is_empty() or has_receipt(receipt_id):
		return {"accepted": false, "reason": "already_received"}
	var before := snapshot()
	reward_receipts.append(receipt_id)
	xp += maxi(0, int(bundle.get("xp", 0)))
	spark_shards += maxi(0, int(bundle.get("spark_shards", 0)))
	var items := bundle.get("items", {}) as Dictionary
	for item_id in items:
		if _items.has(str(item_id)):
			_add_inventory_quantity(str(item_id), maxi(0, int(items[item_id])))
	var recipes := bundle.get("recipes", []) as Array
	for recipe_id in recipes:
		var valid_recipe_id := str(recipe_id)
		if _recipes.has(valid_recipe_id) and valid_recipe_id not in unlocked_recipes:
			unlocked_recipes.append(valid_recipe_id)
	var old_level := level
	_recalculate_level()
	if not save_progress():
		_apply_snapshot(before)
		return {"accepted": false, "reason": "save_failed"}
	xp_changed.emit(xp, level)
	currency_changed.emit("spark_shards", spark_shards)
	inventory_changed.emit()
	if level != old_level:
		level_changed.emit(level, skill_points)
	return {"accepted": true, "xp": int(bundle.get("xp", 0)),
		"spark_shards": int(bundle.get("spark_shards", 0)), "items": items.duplicate(true),
		"recipes": recipes.duplicate()}


func grant_quest_reward(save_id: String) -> Dictionary:
	var rewards := _catalog.get("quest_rewards", {}) as Dictionary
	if not rewards.has(save_id):
		return {"accepted": false, "reason": "unknown_quest"}
	return grant_reward_bundle(rewards[save_id] as Dictionary, "quest:" + save_id)


func equip_item(item_id: String) -> Dictionary:
	var definition := _items.get(item_id, {}) as Dictionary
	var slot := str(definition.get("slot", ""))
	if slot not in EQUIPMENT_SLOTS or not has_item(item_id):
		return {"accepted": false, "reason": "not_equippable"}
	var previous_item := str(equipped.get(slot, ""))
	equipped[slot] = item_id
	if not save_progress():
		equipped[slot] = previous_item
		return {"accepted": false, "reason": "save_failed"}
	equipment_changed.emit(slot, item_id)
	return {"accepted": true, "slot": slot, "item_id": item_id}


func unlock_skill(skill_id: String) -> Dictionary:
	var definition := _skills.get(skill_id, {}) as Dictionary
	if definition.is_empty() or skill_id in unlocked_skills:
		return {"accepted": false, "reason": "invalid_or_unlocked"}
	var requirement := str(definition.get("requires", ""))
	if not requirement.is_empty() and requirement not in unlocked_skills:
		return {"accepted": false, "reason": "prerequisite"}
	var cost := maxi(1, int(definition.get("cost", 1)))
	if skill_points < cost:
		return {"accepted": false, "reason": "skill_points"}
	skill_points -= cost
	unlocked_skills.append(skill_id)
	if not save_progress():
		unlocked_skills.erase(skill_id)
		skill_points += cost
		return {"accepted": false, "reason": "save_failed"}
	skill_unlocked.emit(skill_id)
	return {"accepted": true, "skill_id": skill_id}


func unlock_recipe(recipe_id: String) -> bool:
	if not _recipes.has(recipe_id):
		return false
	if recipe_id not in unlocked_recipes:
		unlocked_recipes.append(recipe_id)
		if not save_progress():
			unlocked_recipes.erase(recipe_id)
			return false
	return true


func craft_upgrade(recipe_id: String, station_tier: int) -> Dictionary:
	var recipe := _recipes.get(recipe_id, {}) as Dictionary
	if recipe.is_empty() or recipe_id not in unlocked_recipes:
		return {"accepted": false, "reason": "recipe_locked"}
	if station_tier < int(recipe.get("station_tier", 1)):
		return {"accepted": false, "reason": "station_tier"}
	var item_id := str(recipe.get("item_id", ""))
	var entry := _find_item_entry(item_id)
	if entry.is_empty():
		return {"accepted": false, "reason": "missing_item"}
	var target_rank := int(recipe.get("rank", 1))
	if int(entry.get("upgrade_rank", 0)) >= target_rank:
		return {"accepted": false, "reason": "already_upgraded"}
	var cost := int(recipe.get("spark_shards", 0))
	if spark_shards < cost:
		return {"accepted": false, "reason": "spark_shards"}
	var materials := recipe.get("materials", {}) as Dictionary
	for material_id in materials:
		if item_quantity(str(material_id)) < int(materials[material_id]):
			return {"accepted": false, "reason": "materials"}
	var before := snapshot()
	spark_shards -= cost
	for material_id in materials:
		_remove_item_quantity(str(material_id), int(materials[material_id]))
	entry["upgrade_rank"] = target_rank
	if not save_progress():
		_apply_snapshot(before)
		return {"accepted": false, "reason": "save_failed"}
	currency_changed.emit("spark_shards", spark_shards)
	inventory_changed.emit()
	return {"accepted": true, "item_id": item_id, "upgrade_rank": target_rank}


func set_assistance(enabled: bool) -> bool:
	var previous_settings := assist_settings.duplicate(true)
	assist_settings = {
		"enabled": enabled,
		"telegraph_multiplier": 1.25 if enabled else 1.0,
		"incoming_damage_multiplier": 0.85 if enabled else 1.0,
		"boss_phase_restart": enabled,
	}
	if not save_progress():
		assist_settings = previous_settings
		return false
	assist_changed.emit(assist_settings.duplicate(true))
	return true


func record_failed_attempt(context_id: String) -> int:
	var safe_id := context_id.strip_edges()
	if safe_id.is_empty() or safe_id.length() > 120:
		return 0
	var before := snapshot()
	var failures := clampi(int(failure_counts.get(safe_id, 0)) + 1, 1, 99)
	failure_counts[safe_id] = failures
	if not save_progress():
		_apply_snapshot(before)
		return 0
	if failures >= 2 and not bool(assist_settings.get("enabled", false)):
		assistance_suggested.emit(safe_id, failures)
	return failures


func has_item(item_id: String) -> bool:
	return item_quantity(item_id) > 0


func item_quantity(item_id: String) -> int:
	var total := 0
	for entry in inventory:
		if str(entry.get("item_id", "")) == item_id:
			total += int(entry.get("quantity", 0))
	return total


func snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"xp": xp,
		"level": level,
		"skill_points": skill_points,
		"spark_shards": spark_shards,
		"inventory": inventory.duplicate(true),
		"checkpoint_storage": checkpoint_storage.duplicate(true),
		"quest_items": quest_items.duplicate(true),
		"equipped": equipped.duplicate(true),
		"unlocked_recipes": Array(unlocked_recipes),
		"unlocked_skills": Array(unlocked_skills),
		"reward_receipts": Array(reward_receipts),
		"mastery_records": mastery_records.duplicate(true),
		"failure_counts": failure_counts.duplicate(true),
		"assist_settings": assist_settings.duplicate(true),
	}


func save_progress() -> bool:
	var temporary_path := save_path + ".tmp"
	var backup_path := save_path + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(snapshot()))
	file.flush()
	file.close()
	var target_absolute := ProjectSettings.globalize_path(save_path)
	var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_absolute)
	if FileAccess.file_exists(save_path) \
			and DirAccess.rename_absolute(target_absolute, backup_absolute) != OK:
		DirAccess.remove_absolute(temporary_absolute)
		return false
	if DirAccess.rename_absolute(temporary_absolute, target_absolute) == OK:
		return true
	if FileAccess.file_exists(backup_path):
		DirAccess.rename_absolute(backup_absolute, target_absolute)
	return false


func load_progress() -> bool:
	reset_new_save(false)
	var parsed := _read_save(save_path)
	if parsed.is_empty():
		parsed = _read_save(save_path + ".bak")
	if parsed.is_empty():
		return false
	return _apply_snapshot(parsed)


func clear_progress() -> void:
	reset_new_save(false)
	for suffix: String in ["", ".tmp", ".bak"]:
		var candidate: String = save_path + suffix
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))


func _load_catalog() -> void:
	_catalog.clear()
	_items.clear()
	_recipes.clear()
	_skills.clear()
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(CATALOG_PATH)) != OK:
		push_error("World One progression catalog JSON could not be parsed")
		return
	var parsed: Variant = parser.data
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1:
		push_error("World One progression catalog is missing or invalid")
		return
	_catalog = parsed
	for definition in _catalog.get("items", []):
		if definition is Dictionary and not str(definition.get("id", "")).is_empty():
			_items[str(definition.id)] = definition
	for definition in _catalog.get("recipes", []):
		if definition is Dictionary and not str(definition.get("id", "")).is_empty():
			_recipes[str(definition.id)] = definition
	for definition in _catalog.get("skills", []):
		if definition is Dictionary and not str(definition.get("id", "")).is_empty():
			_skills[str(definition.id)] = definition


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != SCHEMA_VERSION:
		return {}
	return parsed


func _apply_snapshot(data: Dictionary) -> bool:
	var loaded_inventory: Variant = data.get("inventory", null)
	var loaded_storage: Variant = data.get("checkpoint_storage", null)
	if not loaded_inventory is Array or not loaded_storage is Array:
		return false
	xp = maxi(0, int(data.get("xp", 0)))
	spark_shards = maxi(0, int(data.get("spark_shards", 0)))
	inventory.clear()
	checkpoint_storage.clear()
	for raw_entry in loaded_inventory:
		_append_valid_entry(inventory, raw_entry)
	for raw_entry in loaded_storage:
		_append_valid_entry(checkpoint_storage, raw_entry)
	quest_items = (data.get("quest_items", {}) as Dictionary).duplicate(true) \
		if data.get("quest_items", {}) is Dictionary else {}
	equipped = {"blade": "", "shield": "", "charm": "", "outfit": ""}
	var loaded_equipped := data.get("equipped", {}) as Dictionary
	for slot in EQUIPMENT_SLOTS:
		var item_id := str(loaded_equipped.get(slot, ""))
		if item_id.is_empty() or (_items.has(item_id) and has_item(item_id) \
				and str((_items[item_id] as Dictionary).get("slot", "")) == slot):
			equipped[slot] = item_id
	unlocked_recipes = _valid_ids(data.get("unlocked_recipes", []), _recipes)
	unlocked_skills = _valid_ids(data.get("unlocked_skills", []), _skills)
	reward_receipts = _valid_receipts(data.get("reward_receipts", []))
	mastery_records = (data.get("mastery_records", {}) as Dictionary).duplicate(true) \
		if data.get("mastery_records", {}) is Dictionary else {}
	failure_counts.clear()
	var loaded_failures := data.get("failure_counts", {}) as Dictionary
	for context_id in loaded_failures:
		var safe_id := str(context_id).strip_edges()
		if not safe_id.is_empty() and safe_id.length() <= 120:
			failure_counts[safe_id] = clampi(int(loaded_failures[context_id]), 0, 99)
	var loaded_assist := data.get("assist_settings", {}) as Dictionary
	set_assistance_fields(bool(loaded_assist.get("enabled", false)))
	_recalculate_level(false)
	# Preserve legitimately unspent points while rejecting impossible inflation.
	var earned := 0
	for milestone in SKILL_POINT_LEVELS:
		if level >= milestone:
			earned += 1
	skill_points = clampi(int(data.get("skill_points", earned - unlocked_skills.size())),
		0, maxi(0, earned - unlocked_skills.size()))
	return true


func set_assistance_fields(enabled: bool) -> void:
	assist_settings = {
		"enabled": enabled,
		"telegraph_multiplier": 1.25 if enabled else 1.0,
		"incoming_damage_multiplier": 0.85 if enabled else 1.0,
		"boss_phase_restart": enabled,
	}


func _append_valid_entry(target: Array[Dictionary], raw_entry: Variant) -> void:
	if not raw_entry is Dictionary:
		return
	var item_id := str(raw_entry.get("item_id", ""))
	if not _items.has(item_id):
		return
	var definition := _items[item_id] as Dictionary
	var quantity := clampi(int(raw_entry.get("quantity", 0)), 1,
		maxi(1, int(definition.get("max_stack", 1))))
	target.append({"item_id": item_id, "quantity": quantity,
		"upgrade_rank": clampi(int(raw_entry.get("upgrade_rank", 0)), 0, 3)})


func _valid_ids(values: Variant, definitions: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	if values is Array:
		for value in values:
			var id := str(value)
			if definitions.has(id) and id not in result:
				result.append(id)
	return result


func _valid_receipts(values: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if values is Array:
		for value in values:
			var receipt := str(value).strip_edges()
			if not receipt.is_empty() and receipt.length() <= 160 and receipt not in result:
				result.append(receipt)
	return result


func _recalculate_level(award_new_points := true) -> void:
	var thresholds := get_xp_thresholds()
	var new_level := 1
	for index in thresholds.size():
		if xp >= thresholds[index]:
			new_level = index + 1
	if award_new_points and new_level > level:
		for milestone in SKILL_POINT_LEVELS:
			if milestone > level and milestone <= new_level:
				skill_points += 1
	level = clampi(new_level, 1, thresholds.size())


func _add_inventory_quantity(item_id: String, quantity: int) -> void:
	if quantity <= 0:
		return
	var definition := _items[item_id] as Dictionary
	var max_stack := maxi(1, int(definition.get("max_stack", 1)))
	if max_stack > 1:
		for entry in inventory:
			if str(entry.get("item_id", "")) != item_id:
				continue
			var room := max_stack - int(entry.get("quantity", 0))
			var added := mini(room, quantity)
			entry["quantity"] = int(entry.get("quantity", 0)) + added
			quantity -= added
			if quantity <= 0:
				return
	while quantity > 0:
		var added := mini(max_stack, quantity)
		var entry := {"item_id": item_id, "quantity": added, "upgrade_rank": 0}
		if inventory.size() < INVENTORY_CAPACITY:
			inventory.append(entry)
		else:
			checkpoint_storage.append(entry)
		quantity -= added


func _remove_item_quantity(item_id: String, quantity: int) -> void:
	for index in range(inventory.size() - 1, -1, -1):
		var entry := inventory[index]
		if str(entry.get("item_id", "")) != item_id:
			continue
		var removed := mini(quantity, int(entry.get("quantity", 0)))
		entry["quantity"] = int(entry.get("quantity", 0)) - removed
		quantity -= removed
		if int(entry.get("quantity", 0)) <= 0:
			inventory.remove_at(index)
		if quantity <= 0:
			return


func _find_item_entry(item_id: String) -> Dictionary:
	for entry in inventory:
		if str(entry.get("item_id", "")) == item_id:
			return entry
	return {}
