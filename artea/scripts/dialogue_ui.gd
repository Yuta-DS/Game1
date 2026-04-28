extends CanvasLayer

@onready var text_box = $Panel/RichTextLabel
@onready var speaker_label = $Panel/SpeakerLabel

func show_text(text: String):
	text_box.text = text

func show_line(speaker: String, text: String):
	speaker_label.text = speaker
	text_box.text = text
	
func show_choice(text: String, target: String):
	var btn = Button.new()
	btn.text = text

	btn.pressed.connect(func():
		GameManager.start_dialogue(target)
	)

	$Panel/ChoicesContainer.add_child(btn)
	
func type_text(text: String):
	text_box.text = ""

	for i in text.length():
		text_box.text = text.substr(0, i)
		await get_tree().create_timer(0.02).timeout
