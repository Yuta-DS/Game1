extends Panel

@onready var item_icon: Sprite2D = $ItemIcon
@onready var quantity_label: Label = $QuantityLabel

func set_slot_data(slot_data: slotData) -> void:
	print(">>> Slot.set_slot_data called")
	
	if slot_data == null or slot_data.item_Data == null:
		# Empty slot
		print(">>> Empty slot - hiding icon and label")
		if item_icon:
			item_icon.visible = false
		if quantity_label:
			quantity_label.visible = false
		return
	
	print(">>> Setting slot with item: ", slot_data.item_Data.name)
	print(">>> Item texture: ", slot_data.item_Data.texture)
	print(">>> Item quantity: ", slot_data.quantity)
	
	# Show item
	if item_icon:
		item_icon.texture = slot_data.item_Data.texture
		item_icon.visible = true
		print(">>> Icon set and made visible")
	else:
		print(">>> ERROR: item_icon is null!")
	
	# Show quantity if stackable
	if quantity_label:
		if slot_data.item_Data.stackable:
			quantity_label.text = str(slot_data.quantity)
			quantity_label.visible = true
			print(">>> Quantity label set to: ", slot_data.quantity)
		else:
			quantity_label.visible = false
	else:
		print(">>> ERROR: quantity_label is null!")

