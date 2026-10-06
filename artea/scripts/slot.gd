extends Panel

@onready var item_icon: Sprite2D = $ItemIcon
@onready var quantity_label: Label = $QuantityLabel


func set_slot_data(slot_data: slotData) -> void:
	if slot_data == null or slot_data.item_Data == null:
		item_icon.visible = false
		quantity_label.visible = false
		return
	item_icon.texture = slot_data.item_Data.texture
	item_icon.visible = item_icon.texture != null
	quantity_label.text = str(slot_data.quantity)
	quantity_label.visible = slot_data.item_Data.stackable and slot_data.quantity > 1
