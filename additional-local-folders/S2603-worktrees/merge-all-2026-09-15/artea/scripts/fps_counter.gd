extends Node
## Always-on FPS counter, top-left corner.

var _label: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_label)


func _process(_delta: float) -> void:
	_label.text = "FPS: %d" % Performance.get_monitor(Performance.TIME_FPS)
