# Always-available access to the two safeguards the journey design requires:
# the player can see and erase what Artéa remembers, and can reach real crisis
# resources at any moment.
#
# This is an autoload rather than part of a HUD on purpose. Artéa's scenes do
# not share one UI layer — Icons_HUD only reaches the scenes that instance
# Interface.tscn, which excludes the hub world and the gallery the game
# actually loads. A crisis card that is missing from most of the game is not a
# safeguard, so it lives above the scene tree instead and is reachable from
# every scene, at every stage, including with the journey wiped.
#
# Opens from a small always-visible button pair, bottom-right.
#
# Deliberately not bound to Escape: ui_cancel is already used for dialogue
# skipping, closing the chatbot, and cancelling the brush and stamp tools.
extends CanvasLayer

const SupportCard := preload("res://scripts/support_card.gd")
const JourneyPrivacy := preload("res://scripts/journey_privacy.gd")
const FacilitatorSettings := preload("res://scripts/facilitator_settings.gd")

# Above ordinary UI, below the panels themselves (15 and 20).
const BUTTON_LAYER := 12

var _support_card: Node
var _journey_privacy: Node
var _facilitator_settings: Node


func _ready() -> void:
	# Keep working while the game is paused — the moment a player needs the
	# crisis card is not a moment to make them un-pause first.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = BUTTON_LAYER

	_support_card = SupportCard.new()
	add_child(_support_card)

	_journey_privacy = JourneyPrivacy.new()
	add_child(_journey_privacy)

	# Lives here for the same reason as the other two: it must be reachable
	# from the hub and the gallery, which never instance Interface.tscn.
	_facilitator_settings = FacilitatorSettings.new()
	add_child(_facilitator_settings)

	_build_buttons()

# Public so a settings menu, dialogue command, or NPC can open these too.
func show_support() -> void:
	_support_card.show_card()


func show_journey_privacy() -> void:
	_journey_privacy.show_panel()


# Facilitator-facing: chooses faith or universal naming. See
# facilitator_settings.gd for why the modes differ only in register.
func show_facilitator_settings() -> void:
	_facilitator_settings.show_panel()


# The three panels above are only a safeguard if the player can actually reach
# them. Nothing in the game opened them before this: the crisis card existed
# but had no route to it from any scene. These buttons are that route.
#
# Bottom-right, small and quiet — present in every scene without competing
# with the activity the child is doing. Built here rather than in a scene so
# no scene can ship without them.
func _build_buttons() -> void:
	var row := HBoxContainer.new()
	row.name = "SafeguardButtons"
	row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# PRESET_BOTTOM_RIGHT anchors the corner; offset back into the screen.
	row.offset_left = -430.0
	row.offset_top = -52.0
	row.offset_right = -12.0
	row.offset_bottom = -12.0
	row.add_theme_constant_override("separation", 8)

	# "Need help" first: in a moment of distress it must not be the button the
	# player has to hunt for.
	row.add_child(_small_button("Need help", show_support))
	row.add_child(_small_button("My journey", show_journey_privacy))
	row.add_child(_small_button("Setup", show_facilitator_settings))

	var control := Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Only the buttons take clicks — the rest of the layer stays transparent
	# to the game underneath.
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(row)
	add_child(control)


func _small_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(132, 38)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(handler)
	return button
