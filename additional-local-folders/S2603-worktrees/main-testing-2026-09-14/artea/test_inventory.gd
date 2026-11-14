extends Node

# Quick test script to verify inventory system
# Attach this to a node and run to test

@export var inventory_data: inventoryData
@export var apple_item: itemData

func _ready():
	print("\n=== INVENTORY SYSTEM TEST ===")
	
	if not inventory_data:
		print("ERROR: No inventory_data assigned!")
		return
	
	if not apple_item:
		print("ERROR: No apple_item assigned!")
		return
	
	print("Inventory slots: ", inventory_data.slot_Data.size())
	print("Apple name: ", apple_item.name)
	print("Apple texture: ", apple_item.texture)
	print("Apple stackable: ", apple_item.stackable)
	
	# Try to add an apple
	print("\nAdding apple to first slot...")
	var new_slot = slotData.new()
	new_slot.item_Data = apple_item
	new_slot.quantity = 1
	inventory_data.slot_Data[0] = new_slot
	
	print("First slot now contains: ", inventory_data.slot_Data[0].item_Data.name)
	print("Quantity: ", inventory_data.slot_Data[0].quantity)
	print("\n=== TEST COMPLETE ===")

