extends Area3D

@export var item_data: itemData

var collected = false

func _ready() -> void:
	print("Collectible item ready: ", item_data.name if item_data else "No item data")

func _physics_process(_delta: float) -> void:
	if collected:
		return
		
	# Continuously check for overlapping bodies
	var overlapping_bodies = get_overlapping_bodies()
	
	for body in overlapping_bodies:
		if body.is_in_group("player"):
			print("Player nearby! Attempting to collect...")
			if body.has_method("collect_item"):
				if body.collect_item(item_data):
					# Item was collected successfully
					collected = true
					print("Item collected! Removing from world...")
					queue_free()
					return
				else:
					print("Failed to collect item (inventory full?)")
			else:
				print("Player doesn't have collect_item method!")
