extends Control
const TouchDevice := preload("res://scripts/touch_controls.gd")

@onready var grid_container: GridContainer = $NinePatchRect/GridContainer

var inventory_data: inventoryData
var isOpen: bool = false

func _ready() -> void:
	close()
	# Phones and tablets have no E key to put the bag away again.
	if TouchDevice.is_touch_device():
		var close_button := Button.new()
		close_button.name = "CloseButton"
		close_button.text = "X"
		close_button.focus_mode = Control.FOCUS_NONE
		close_button.add_theme_font_size_override("font_size", 64)
		close_button.custom_minimum_size = Vector2(120, 120)
		close_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		close_button.position = Vector2(-170, 40)
		close_button.pressed.connect(close)
		$NinePatchRect.add_child(close_button)
		# Desktop text sizes read at about a third of their size on a phone.
		var title := $NinePatchRect/TitleLabel as Label
		title.add_theme_font_size_override("font_size", 90)
		for slot in grid_container.get_children():
			var quantity := slot.get_node_or_null("QuantityLabel") as Label
			if quantity != null:
				quantity.add_theme_font_size_override("font_size", 40)
				quantity.add_theme_constant_override("outline_size", 8)
				# Grow up and left from the slot's corner, where the number sits.
				quantity.grow_horizontal = Control.GROW_DIRECTION_BEGIN
				quantity.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
func set_inventory_data(data: inventoryData) -> void:
	print("DEBUG: SET INVENTORY DATA CALLED")
	inventory_data = data
	populate_slots()

func populate_slots() -> void:
	print("=== POPULATE SLOTS CALLED ===")
	return # Function has been crashing the game upon spawning
	# Clear existing slots
	for child in grid_container.get_children():
		child.queue_free()
	
	if inventory_data == null:
		print("ERROR: inventory_data is null in populate_slots!")
		return
	
	print("Creating ", inventory_data.slot_Data.size(), " slots")
	
	# Create slot for each slot in inventory
	var slot_scene = preload("res://scenes/slot.tscn")
	for i in range(inventory_data.slot_Data.size()):
		var slot = slot_scene.instantiate()
		grid_container.add_child(slot)
		
		# Wait for slot to be ready
		#await get_tree().process_frame
		
		var slot_data = inventory_data.slot_Data[i]
		if slot_data != null:
			print("Populating slot ", i, " with item: ", slot_data.item_Data.name if slot_data.item_Data else "null")
		else:
			print("Populating slot ", i, " - empty")
		
		slot.set_slot_data(slot_data)
	
	print("=== POPULATE COMPLETE ===")

func refresh_slots() -> void:
	
	if inventory_data == null:
		push_error("refresh_slots called but inventory_data is null")
		return
	
	print("=== REFRESH SLOTS CALLED ===")
	print("Grid container children count: ", grid_container.get_child_count())
	# Crashes the game if object spawned directly under the player:
	#print("Inventory slot_Data size: ", inventory_data.slot_Data.size())
	
	var slots = grid_container.get_children()
	for i in range(slots.size()):
		if i < inventory_data.slot_Data.size():
			slots[i].set_slot_data(inventory_data.slot_Data[i])
		else:
			slots[i].set_slot_data(null)

func toggle_visibility() -> void:
	if isOpen:
		close()
	else:
		open()

func open():
	visible = true
	isOpen = true
	add_to_group("touch_hud_blockers")
	# Refresh slots when opening to show latest inventory state
	if inventory_data:
		print("Opening inventory - refreshing slots")
		refresh_slots()
	else:
		print("ERROR: inventory_data is null when opening inventory!")

func close():
	visible = false
	isOpen = false
	remove_from_group("touch_hud_blockers")
