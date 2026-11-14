extends SubViewport

var bubble_text = "This is just a test"
var bubble_text_length = 0
var bubble_text_index = 0
var current_text = ""

@onready var lbltext = get_node("VBoxContainer/Label")
@onready var ninerect = get_node("VBoxContainer/Label/NinePatchRect")

@onready var timer = get_node("Timer")

var do_close = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	bubble_text_length = bubble_text.length()
	timer.start(1)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_timer_timeout() -> void:
	if (!do_close):
		current_text += bubble_text[bubble_text_index]
		lbltext.text = current_text
		
		if (bubble_text_index < bubble_text_length - 1):
			timer.start(0.06)
			bubble_text_index += 1
		elif(!do_close):
			do_close = true
			timer.start(1)
	else:
		# Remove characters one by one (closing)
		if current_text.length() > 0:
			current_text = current_text.substr(0, current_text.length() - 1)
			lbltext.text = current_text
			
			# Shrink bubble gradually
			ninerect.size.x = lbltext.size.x + 50
			
			timer.start(0.06)
		else:
			queue_free()
		if current_text.length() == 0:
			get_parent().visible = false
