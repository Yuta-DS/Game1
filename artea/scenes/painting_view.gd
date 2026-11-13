extends Node2D
const SceneLoader := preload("res://scripts/scene_loader.gd")



@onready var painting_rect: TextureRect = $ImageDisplay

var painting_paths: Array[String] = [
	"res://assets/ArtGallery/fsfs_4290328292_1363.png",
	"res://assets/ArtGallery/Nature_3976028952_95869.png",
	"res://assets/ArtGallery/PX 2517_2025-05-23T15-47-51.png",
	"res://assets/ArtGallery/Rainbow_3306278596_88715.png",
	"res://assets/ArtGallery/smile_3849499552_29914.png"
]
#Comment categories
var comments = {
	"Click to choose comment Category": [],
	"#creative": [
		"Beautiful use of color and emotion.",
		"Your creativity shines through.",
		"This feels so expressive - thank you for sharing.",
		"Such a hearfelt piece.",
		"Your art speaks volumes without words."
	],
	"#supportive": [
		"You are brave for expressing this.",
		"There is such strength in your vulnerability.",
		"I really felt something when I saw this.",
		"This touched me - thank you.",
		"I see you and your expressions matter."
	],
	"#mindful": [
		"So calming to look at.",
		"There is quiet power in this piece.",
		"This artwork invites me to pause and reflect.",
		"Feels like a breath of fresh air",
		"A gentle reminder that healing is a journey."
	],
	"#empowering": [
		"Keep creating - the world needs your art.",
		"Your voice is important.",
		"Art like this brings light to others.",
		"You inspire me to create too.",
		"Thank you for showing up and expressing yourself."
	]
}

#Ready function
func _ready() -> void:
	# Populate dropdowns
	for category in comments.keys():
		$Control/EncouragementButton.add_item(category)
	
	_on_encouragement_button_item_selected(0)
	$Control/CommentButtonList.visible = false
	
	# Get the painting id
	var id = Global.painting_to_show
	var idx = clamp(id, 0, painting_paths.size() - 1)
	var tex = load(painting_paths[idx])
	

	painting_rect.texture = tex
	
	

#Handle encouragement category selection
func _on_encouragement_button_item_selected(index: int) -> void:
	var selected_category = $Control/EncouragementButton.get_item_text(index)
	$Control/CommentButtonList.visible = true
	#Clear previous buttons
	for child in $Control/CommentButtonList.get_children():
		$Control/CommentButtonList.remove_child(child)
		child.queue_free()
	#Add new buttons
	for comment in comments[selected_category]:
		var btn = Button.new()
		btn.text = comment
		btn.connect("pressed", Callable(self, "_on_comments_pressed").bind(comment))
		$Control/CommentButtonList.add_child(btn)
		
#Handle comment press
func _on_comments_pressed(message: String) -> void:
	var comment_label = Label.new()
	comment_label.text = message + " - " + Global.current_user_name
	$CommentScroll/CommentList.add_child(comment_label)
	show_comment_confirmation("Your encouragement has been shared 💛")
	
#Show confirmation
func show_comment_confirmation(message: String) -> void:
	$Control/CommentConfirmation.text = message
	$Control/CommentConfirmation.visible = true
	await get_tree().create_timer(2.5).timeout
	$Control/CommentConfirmation.visible = false
	
#Handle uplift
func _on_uplift_button_pressed() -> void:
	$UpliftButton.text = "🌱 Uplift sent"
	$UpliftButton.disabled = true
	
	var message = "You uplifted this painting - the artist will be notified!"
	show_comment_confirmation(message)


#Go back button
func _on_back_button_pressed() -> void:
	SceneLoader.change_scene(get_tree(), "res://scenes/ArtGallery.tscn")
