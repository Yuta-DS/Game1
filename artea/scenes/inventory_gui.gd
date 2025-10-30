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
	# Clear existing slots
	for child in grid_container.get_children():
		child.queue_free()
	
	if inventory_data == null:
		return
	
	# Create slot for each slot in inventory
	for slot_data in inventory_data.slot_Data:
		var slot_scene = preload("res://scenes/slot.tscn")
		var slot = slot_scene.instantiate()
		grid_container.add_child(slot)
		slot.set_slot_data(slot_data)

func refresh_slots() -> void:
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
	# Optional: Pause the game when inventory is open
	# Uncomment the line below if you want the game to pause
	# get_tree().paused = true
	
func close():
	visible = false
	isOpen = false
	# Unpause the game when inventory closes
	# Uncomment the line below if you want the game to pause
	# get_tree().paused = false

