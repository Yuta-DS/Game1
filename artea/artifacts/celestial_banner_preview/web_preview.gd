extends Node
## Isolated verification harness. Does not simulate actual train travel.
const UI := preload("res://scripts/train_passenger_journey_ui.gd")
const Hud := preload("res://scripts/ui/artea_hud_theme.gd")
var banner: CanvasLayer
var status: Label

func _ready() -> void:
	banner = UI.new()
	add_child(banner)
	var controls := CanvasLayer.new()
	controls.layer = 120
	add_child(controls)
	var box := VBoxContainer.new()
	box.position = Vector2(16, 12)
	controls.add_child(box)
	status = Label.new()
	status.text = "BANNER WEB PREVIEW · not the full game"
	Hud.style_body(status, 14)
	box.add_child(status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for mode in ["Arrival", "Locked route", "Travelling"]:
		var button := Button.new()
		button.text = mode
		Hud.style_action_button(button, Hud.PARCHMENT)
		# Harness controls must not steal keyboard focus from the UI under test.
		button.focus_mode = Control.FOCUS_NONE
		row.add_child(button)
		button.pressed.connect(func() -> void: _show(mode))
	banner.get_off_requested.connect(func() -> void:
		banner.close_journey()
		status.text = "Get off requested — preview signal received"
		print("BANNER_WEB: GET_OFF"))
	banner.continue_requested.connect(func() -> void:
		banner.show_travel("Heart Melody", 1)
		status.text = "Continue requested — preview signal received"
		print("BANNER_WEB: CONTINUE"))
	_show("Arrival")
	print("BANNER_WEB: READY compatibility renderer; standalone UI only")

func _show(mode: String) -> void:
	status.text = "BANNER WEB PREVIEW · " + mode
	match mode:
		"Locked route":
			banner.show_arrival("Mind Spark", "Heart Melody", "Earn the Star of Wisdom in Mind Spark to unlock Heart Melody.")
		"Travelling":
			banner.show_travel("Heart Melody", 1)
		_:
			banner.show_arrival("Mind Spark", "Heart Melody", "")
	print("BANNER_WEB: STATE " + mode)
