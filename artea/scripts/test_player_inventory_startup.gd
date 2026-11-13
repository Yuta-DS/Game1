extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := (load("res://scenes/entities/NewPlayer.tscn") as PackedScene).instantiate()
	player.inventory_data = inventoryData.new()
	player.inventory_data.slot_Data.resize(2)
	root.add_child(player)
	var gui := player.get_node("InventoryGUI")
	assert(gui.inventory_data == player.inventory_data, "inventory binds before the first physics frame")
	assert(player.inventory_data.slot_Data.size() == 30 \
		and gui.get_node("NinePatchRect/GridContainer").get_child_count() == 30,
		"the repaired inventory exposes all thirty production slots")
	var item := itemData.new()
	item.name = "Startup collectible"
	item.stackable = true
	assert(player.collect_item(item), "an immediate pickup is accepted")
	var quantity_label := gui.get_node("NinePatchRect/GridContainer/slot/QuantityLabel") as Label
	assert(quantity_label.text == "1" and not quantity_label.visible,
		"a new stack refreshes the visible inventory slot")
	assert(player.collect_item(item), "a repeated pickup stacks")
	assert(player.inventory_data.slot_Data[0].quantity == 2)
	assert(gui.inventory_data.slot_Data[0].quantity == 2, "UI and player share the collected state")
	assert(quantity_label.text == "2" and quantity_label.visible,
		"stacking refreshes the displayed quantity")
	player.queue_free()
	await process_frame
	print("PLAYER_INVENTORY_STARTUP: PASS — immediate pickups and stacking retain bound UI state")
	quit()
