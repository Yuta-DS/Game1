extends Panel

@onready var item_icon: Sprite2D = $ItemIcon
@onready var quantity_label: Label = $QuantityLabel

func set_slot_data(slot_data: slotData) -> void:
	if slot_data == null or slot_data.item_Data == null:
		# Empty slot
		if item_icon:
			item_icon.visible = false
		if quantity_label:
			quantity_label.visible = false
		return
	
	# Show item
	if item_icon:
		item_icon.texture = slot_data.item_Data.texture
		item_icon.visible = true
	
	# Show quantity if stackable
	if quantity_label:
		if slot_data.item_Data.stackable:
			quantity_label.text = str(slot_data.quantity)
			quantity_label.visible = true
		else:
			quantity_label.visible = false

