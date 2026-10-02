class_name WorldOneProgressionHUD
extends Control

const TABS := ["Equipment", "Materials", "Crafting", "Quest Items", "Collection"]
const EQUIPMENT_SLOTS := ["blade", "shield", "charm", "outfit"]
const RARITY_COLORS := {
	"common": Color("d7d9d1"), "uncommon": Color("79d69c"),
	"rare": Color("69bce8"), "epic": Color("b68cff"),
	"legendary": Color("ffd477"),
}

var progression: Node
var _summary: Label
var _overlay: ColorRect
var _title: Label
var _content: VBoxContainer
var _tab_bar: HBoxContainer
var _active_tab := "Equipment"
var _player: CharacterBody3D


func _ready() -> void:
	add_to_group("world_one_progression_hud")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if progression == null:
		progression = get_node_or_null("/root/WorldOneProgression")
	_build_summary()
	_build_overlay()
	if progression != null:
		progression.xp_changed.connect(_on_progress_changed)
		progression.level_changed.connect(_on_progress_changed)
		progression.currency_changed.connect(_on_progress_changed)
		progression.inventory_changed.connect(_refresh)
		progression.equipment_changed.connect(_on_equipment_changed)
	_refresh()
	call_deferred("_find_player")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_Inventory"):
		set_open(not _overlay.visible)
		get_viewport().set_input_as_handled()
	elif _overlay.visible and event.is_action_pressed("ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()


func set_open(open: bool) -> void:
	_overlay.visible = open
	mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	if _player == null:
		_find_player()
	if _player != null and _player.has_method("set_input_enabled"):
		_player.call("set_input_enabled", not open)
	if open:
		_refresh()
		if _tab_bar.get_child_count() > 0:
			(_tab_bar.get_child(0) as Button).grab_focus()


func is_open() -> bool:
	return _overlay != null and _overlay.visible


func _build_summary() -> void:
	var pill := ColorRect.new()
	pill.name = "ProgressSummary"
	pill.color = Color(0.025, 0.06, 0.12, 0.88)
	pill.position = Vector2(22, 124)
	pill.size = Vector2(320, 42)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pill)
	_summary = Label.new()
	_summary.position = Vector2(12, 5)
	_summary.size = Vector2(296, 32)
	_summary.add_theme_font_size_override("font_size", 17)
	_summary.modulate = Color("d8f8ff")
	pill.add_child(_summary)


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "ProgressionInventory"
	_overlay.color = Color(0.015, 0.025, 0.05, 0.965)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-460, -330)
	panel.size = Vector2(920, 660)
	_overlay.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	_title = Label.new()
	_title.text = "WORLD ONE FIELD KIT"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	body.add_child(_title)
	_tab_bar = HBoxContainer.new()
	_tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_tab_bar)
	for tab_name in TABS:
		var button := Button.new()
		button.text = tab_name
		button.custom_minimum_size = Vector2(150, 42)
		button.pressed.connect(_select_tab.bind(tab_name))
		_tab_bar.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	var footer := Label.new()
	footer.text = "E / Esc • Close     Enter / A • Select     Rewards never affect identity"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.modulate = Color("a9bfd0")
	body.add_child(footer)


func _refresh() -> void:
	if progression == null or _content == null:
		return
	var thresholds: PackedInt32Array = progression.call("get_xp_thresholds")
	var current_level := int(progression.get("level"))
	var current_xp := int(progression.get("xp"))
	var next_xp := thresholds[mini(current_level, thresholds.size() - 1)]
	_summary.text = "LV %d  •  XP %d/%d  •  ✦ %d  •  E: Field Kit" % [
		current_level, current_xp, next_xp, int(progression.get("spark_shards"))]
	for child in _content.get_children():
		child.queue_free()
	match _active_tab:
		"Equipment": _build_equipment_rows()
		"Materials": _build_material_rows()
		"Crafting": _build_crafting_rows()
		"Quest Items": _build_quest_rows()
		_: _build_collection_rows()


func _build_equipment_rows() -> void:
	var equipped: Dictionary = progression.get("equipped")
	for slot in EQUIPMENT_SLOTS:
		_add_heading(str(slot).capitalize() + " • " + _item_name(str(equipped.get(slot, ""))))
		for entry in progression.get("inventory"):
			var definition: Dictionary = progression.call("get_item_definition", str(entry.item_id))
			if str(definition.get("slot", "")) != slot:
				continue
			var row := Button.new()
			row.text = "%s  •  %s  •  Rank %d%s" % [definition.name,
				str(definition.rarity).capitalize(), int(entry.get("upgrade_rank", 0)),
				"  •  EQUIPPED" if str(equipped.get(slot, "")) == str(entry.item_id) else ""]
			row.modulate = RARITY_COLORS.get(str(definition.rarity), Color.WHITE)
			row.tooltip_text = str(definition.get("ability", ""))
			row.pressed.connect(_equip.bind(str(entry.item_id)))
			_content.add_child(row)


func _build_material_rows() -> void:
	var found := false
	for entry in progression.get("inventory"):
		var definition: Dictionary = progression.call("get_item_definition", str(entry.item_id))
		if str(definition.get("category", "")) != "material":
			continue
		found = true
		_add_body("%s   × %d" % [definition.name, int(entry.quantity)],
			RARITY_COLORS.get(str(definition.rarity), Color.WHITE))
	if not found:
		_add_body("Regional materials appear here after quests and encounters.", Color("9fb6c8"))
	var storage: Array = progression.get("checkpoint_storage")
	_add_heading("Checkpoint Storage • %d stacks" % storage.size())


func _build_crafting_rows() -> void:
	_add_body("Upgrade recipes are discovered at island crafting stations.", Color("9fb6c8"))
	for recipe_id in progression.get("unlocked_recipes"):
		var recipe: Dictionary = progression.call("get_recipe_definition", str(recipe_id))
		var item: Dictionary = progression.call("get_item_definition", str(recipe.item_id))
		_add_body("%s • Rank %d • ✦ %d" % [item.name, int(recipe.rank), int(recipe.spark_shards)], Color("d8f8ff"))


func _build_quest_rows() -> void:
	var quest_items: Dictionary = progression.get("quest_items")
	if quest_items.is_empty():
		_add_body("Quest items are stored safely and never consume inventory slots.", Color("9fb6c8"))
	for item_id in quest_items:
		_add_body("%s   × %d" % [_item_name(str(item_id)), int(quest_items[item_id])], Color("fff0b0"))


func _build_collection_rows() -> void:
	var receipts: PackedStringArray = progression.get("reward_receipts")
	var owned_sets := {}
	for entry in progression.get("inventory"):
		var definition: Dictionary = progression.call("get_item_definition", str(entry.item_id))
		if str(definition.get("category", "")) == "equipment":
			owned_sets[str(definition.get("set", ""))] = int(owned_sets.get(str(definition.get("set", "")), 0)) + 1
	for set_id in ["signal", "memory", "stormroot", "crown"]:
		_add_body("%s Set   %d / 4" % [str(set_id).capitalize(), int(owned_sets.get(set_id, 0))], Color("d8f8ff"))
	var first_clear_count := 0
	for receipt in receipts:
		if receipt.begins_with("quest:"):
			first_clear_count += 1
	_add_heading("First-clear rewards • %d / 15" % first_clear_count)


func _select_tab(tab_name: String) -> void:
	_active_tab = tab_name
	_refresh()


func _equip(item_id: String) -> void:
	progression.call("equip_item", item_id)
	_refresh()


func _item_name(item_id: String) -> String:
	if item_id.is_empty():
		return "Empty"
	var definition: Dictionary = progression.call("get_item_definition", item_id)
	return str(definition.get("name", item_id))


func _add_heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Color("7ee7ff")
	_content.add_child(label)


func _add_body(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.modulate = color
	_content.add_child(label)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("Player")
	if not players.is_empty():
		_player = players[0] as CharacterBody3D


func _on_progress_changed(_a = null, _b = null) -> void:
	_refresh()


func _on_equipment_changed(_slot: String, _item_id: String) -> void:
	_refresh()
