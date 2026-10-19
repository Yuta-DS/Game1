class_name HeartMelodyHUD
extends RefCounted
var caption: Label
var journal_button: Button

func build(layer: CanvasLayer, open_journal: Callable) -> Label:
	journal_button = Button.new()
	journal_button.text = "Valley map · fruit · crafting"
	journal_button.position = Vector2(890, 24)
	journal_button.custom_minimum_size = Vector2(310, 52)
	journal_button.pressed.connect(open_journal)
	layer.add_child(journal_button)
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	caption.offset_left = -624
	caption.offset_right = -24
	caption.offset_top = 238
	caption.offset_bottom = 330
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(caption)
	return caption

func update(tasks: int, focus: float, text: String, large_text: bool) -> void:
	if not is_instance_valid(caption): return
	caption.text = "Chapter %d / 10 · Focus %d\n%s" % [tasks, focus, text]
	caption.add_theme_font_size_override("font_size", 28 if large_text else 22)
	caption.custom_minimum_size.x = 600
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
