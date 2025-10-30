extends Control
@onready var label = $Label

# Dynamic messages after completion
var messages = [
	"You did it! Your mind is now a clear sky.",
	"All your thoughts have floated away—well done!",
	"Peace achieved. You’ve cleared your clouds!",
	"Great work! Your thoughts are now at ease.",
	"You've lightened your mental sky—awesome job!",
	"Your mind is calm. The clouds have passed.",
	"Poof! All your cloudy thoughts are gone!",
	"The sky’s all clear—nice popping!",
	"Great poppin’! Your thoughts are toast!",
	"You've cloud-busted your way to clarity!",
	"Thoughts: released. Sky: cleared!",
	"A gentle stillness remains. Well done.",
	"Your thoughts have drifted away like clouds.",
	"A clear mind, a peaceful heart.",
	"You’ve released what was weighing you down.",
	"You’ve done beautifully—your inner sky shines bright now.",
	"You’ve done beautifully—your inner sky shines bright now.",
	"You let it go—and made space for peace. Well done.",
	"Each pop made room for light. Look how far you've come!",
	"The storm has passed—your calm is here.",
	"Your thoughts have softened and your spirit has lifted.",
	"Great job! You’ve given your mind the gift of stillness.",
	"You've turned turbulence into tranquility—amazing!",
	"A deep breath, a lighter soul. You did it!",
	"Like clouds, your thoughts came and went—and you remained strong.",
	"The sky within you is open and bright. Keep going.",
	"You've made space for hope, joy, and peace to enter.",
	"That was powerful. You’ve taken a brave step toward healing.",
	"You faced your thoughts and released them—what courage!",
	"You’re growing, glowing, and letting go. Keep shining!",
	"What once felt heavy now floats away—amazing release!",
	"You did it. A clearer mind and lighter heart are now yours.",
	"You showed up, let go, and made space for peace—go you!",
	"Those thoughts don’t define you. You just released them. Powerful.",
	"You’ve made space for clarity—your mental sky is wide open now.",
	"Breathe in peace, breathe out release. You're doing great.",
	"You popped the clutter, and now look—calm skies ahead.",
	"Letting go isn’t easy, but you just did it. That’s strength.",
	"Today, you honoured your emotions. That’s a huge win.",
	"You’ve just practiced radical self-care. Be proud of you.",
	"Your thoughts floated away like clouds. You stayed rooted. That’s growth.",
	"Not all storms come to disrupt. Some clear the path. You cleared yours.",
	"What you released today no longer has power over you.",
	"Peace is your birthright. You just reclaimed a piece of it.",
	"You’ve taken a step toward healing. Keep walking—you’re not alone.",
	"The clutter’s gone. What’s left is space for joy, purpose, and peace.",
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	var index = randi() % messages.size()
	label.text = messages[index]

# Play again button
func _on_play_again_pressed() -> void:
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/popThoughtsMenu.tscn"
	
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free() 
	MusicManager._check_scene()

# Return to Hubworld button
func _on_return_to_hubworld_pressed() -> void:
	# Uses load screen scene while loading the scene
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/artea_game.tscn"
	
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free() 
