extends CanvasLayer

@onready var text_box = $Panel/RichTextLabel
@onready var speaker_label = $Panel/SpeakerLabel

func _input(event):
	if event.is_action_pressed("ui_accept"):
		if not GameManager.waiting_for_choice:
			GameManager.process_next_line()

func show_text(text: String):
	text_box.text = text

func show_line(speaker: String, text: String):
	# Clear choices when new dialogue appears
	for child in $Panel/ChoicesContainer.get_children():
		child.queue_free()

	speaker_label.text = speaker
	text_box.text = text
	
var choice_buttons = []

func show_choices(choices: Array):
	# Clear old buttons
	for child in $Panel/ChoicesContainer.get_children():
		child.queue_free()

	choice_buttons.clear()

	# Create new buttons
	for i in range(choices.size()):
		var btn = Button.new()
		btn.text = choices[i]["text"]

		var index = i  # IMPORTANT (captures correct value)

		btn.pressed.connect(func():
			GameManager.choose(index)
		)

		$Panel/ChoicesContainer.add_child(btn)
		choice_buttons.append(btn)
	
func type_text(text: String):
	text_box.text = ""

	for i in text.length():
		text_box.text = text.substr(0, i)
		await get_tree().create_timer(0.02).timeout
