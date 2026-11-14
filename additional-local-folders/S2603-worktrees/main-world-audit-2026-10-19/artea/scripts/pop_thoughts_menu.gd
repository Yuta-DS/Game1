# Entry to the connected Mind Spark: The Two Lenses of Wisdom.
extends Control

const SceneLoader := preload("res://scripts/scene_loader.gd")

const TWO_LENSES_SCENE := "res://scenes/mind_spark/mind_spark_chapter_world.tscn"


func _on_play_pressed():
	if not ResourceLoader.exists(TWO_LENSES_SCENE):
		push_error("Mind Spark: Two Lenses scene is unavailable")
		return
	SceneLoader.change_scene(get_tree(), TWO_LENSES_SCENE)
	
func _on_instructions_pressed():
	$CenterContainer.visible = false
	$Panel.visible = true

func _on_return_to_hubworld_pressed():
	_return_to_campaign()


func _return_to_campaign() -> void:
	var campaign := get_node_or_null("/root/JourneyCampaign")
	if campaign != null and campaign.has_method("return_to_campaign"):
		campaign.call("return_to_campaign")
	else:
		SceneLoader.change_scene_with_loading(get_tree(), "res://scenes/art_gallery_3d_inprogress.tscn")
	


const INSTRUCTION_PAGES := [
	"[center][font_size=48]THE TWO LENSES OF WISDOM[/font_size]\n\n[font_size=30]One thought appears in two connected worlds. The Alarm Lens uses celestial technology to notice its signal. The Hope Lens uses nature-magic to grow a truthful next step. Neither side is an enemy.[/font_size][/center]",
	"[center][font_size=42]ALARM LENS • LEFT[/font_size]\n\n[font_size=29]Move: W A S D\nInteract: E\nCompanion Ping: Q\n\nScan the difficult Thought Echo and choose what its signal does: louder, rushed, unclear, or not sure.[/font_size][/center]",
	"[center][font_size=42]HOPE LENS • RIGHT[/font_size]\n\n[font_size=29]Move: Arrow Keys\nInteract: Enter\nCompanion Ping: Right Shift\n\nChoose a grounded response such as taking one step, asking for help, pausing to check, or not knowing yet.[/font_size][/center]",
	"[center][font_size=42]FIVE CONNECTED QUESTS[/font_size]\n\n[font_size=29]Explore the Signal Observatory, Echo Forest, Cross-Seam Relay, Role-Exchange Storm, and Wisdom Constellation. Each action in one world visibly prepares the other Lens's next step.[/font_size][/center]",
	"[center][font_size=42]SOLO AND ACCESSIBILITY[/font_size]\n\n[font_size=29]Solo mode gives you one Lens and a visible, explicitly commanded companion for the other. Swap roles in the storm. Use reduced motion or Accessibility Assist, and return safely to the Castle without fabricating a reward.[/font_size][/center]",
]
var current_index = 0

@onready var texture_rect: TextureRect = $Panel/TextureRect
@onready var instruction_text: RichTextLabel = $Panel/InstructionText
@onready var next_button = $Panel/Next
@onready var prev_button = $Panel/Previous

func _ready():

	texture_rect.hide()
	$Panel.visible = false  # Or replace with actual node path if different
	update_image()

func update_image():
	instruction_text.text = INSTRUCTION_PAGES[current_index]
	prev_button.disabled = current_index == 0
	next_button.disabled = current_index == INSTRUCTION_PAGES.size() - 1

func _on_next_pressed():
	if current_index < INSTRUCTION_PAGES.size() - 1:
		current_index += 1
		update_image()

func _on_previous_pressed():
	if current_index > 0:
		current_index -= 1
		update_image()

func _on_close_pressed():
	$CenterContainer.visible = true
	$Panel.visible = false
