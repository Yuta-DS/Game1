extends Control

@onready var grid_container: GridContainer = $NinePatchRect/GridContainer

var inventory_data: inventoryData
var isOpen: bool = false

func _ready() -> void:
	close()
	
func set_inventory_data(data: inventoryData) -> void:
	inventory_data = data
	populate_slots()

func populate_slots() -> void:
	return # Function has been crashing the game upon spawning
	# Clear existing slots
	for child in grid_container.get_children():
		child.queue_free()

	if inventory_data == null:
		push_error("populate_slots called but inventory_data is null")
		return

	# Create slot for each slot in inventory
	var slot_scene = preload("res://scenes/slot.tscn")
	for i in range(inventory_data.slot_Data.size()):
		var slot = slot_scene.instantiate()
		grid_container.add_child(slot)

		# Wait for slot to be ready
		#await get_tree().process_frame

		var slot_data = inventory_data.slot_Data[i]
		slot.set_slot_data(slot_data)

## Refreshes one slot when changed_index is given, or every slot when it's
## left at -1 (e.g. when the inventory is first opened and the whole grid
## needs to match current data). Avoids re-rendering every slot on every
## single pickup.
func refresh_slots(changed_index: int = -1) -> void:

	if inventory_data == null:
		push_error("refresh_slots called but inventory_data is null")
		return

	# Crashes the game if object spawned directly under the player:
	#print("Inventory slot_Data size: ", inventory_data.slot_Data.size())

	var slots = grid_container.get_children()

	if changed_index >= 0:
		if changed_index < slots.size():
			var data = inventory_data.slot_Data[changed_index] if changed_index < inventory_data.slot_Data.size() else null
			slots[changed_index].set_slot_data(data)
		return

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
	# Refresh slots when opening to show latest inventory state
	if inventory_data:
		refresh_slots()
	else:
		push_error("open: inventory_data is null when opening inventory")

func close():
	visible = false
	isOpen = false
