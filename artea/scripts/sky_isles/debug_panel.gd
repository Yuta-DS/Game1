# Dev debug panel for Sky Isles dormant/vibrant state.
#
# Attached to node "DebugPanel" (a CanvasLayer) under the world root. Small,
# unobtrusive, top-left, unmistakably a dev tool — plain buttons on a dark
# translucent panel, no attempt to look like real UI. Talks only to
# IsleState's public API (set_isle_state / get_isle_state / toggle_isle),
# same arm's-length relationship hub_awakening.gd's dev shortcut has with
# JourneyState.
#
# Keyboard: 1=castle 2=mind 3=heart 4=creator toggle; 0=all dormant;
# 9=all vibrant; H=hide/show panel.
#
# NOTE: keys 1-4 are also dev shortcuts in the EXISTING hub world
# (hub_awakening.gd previews JourneyState stages 0-4 with keys 1-5/0). No
# runtime conflict — these are different scenes and hub_awakening.gd's
# input handling never loads alongside this one.
extends CanvasLayer

const ISLE_IDS := ["castle", "mind", "heart", "creator"]
const ISLE_LABELS := {
	"castle": "Castle",
	"mind": "Mind Spark",
	"heart": "Heart Melody",
	"creator": "Creator's Light",
}
const KEY_TO_ISLE := {
	KEY_1: "castle",
	KEY_2: "mind",
	KEY_3: "heart",
	KEY_4: "creator",
}

var _isle_state: Node = null
var _travel_controller: Node = null

var _panel: Panel = null
var _toggle_buttons: Dictionary = {}   # isle_id -> Button
var _travel_buttons: Dictionary = {}   # isle_id -> Button
var _visible_panel: bool = true


func _ready() -> void:
	layer = 50  # above the 3D viewport, below nothing else exists in this scene

	# Sibling nodes may not have finished attaching yet depending on scene
	# tree build order, and isle_kingdoms.gd/travel_controller.gd are being
	# written by other agents concurrently — both may still be the 5-line
	# placeholders, or the whole node may briefly not exist. Wait a couple
	# of frames and degrade gracefully rather than hard-depending.
	await get_tree().process_frame
	await get_tree().process_frame

	# owner/parent rather than get_tree().current_scene, which is null when
	# the scene is instantiated manually instead of loaded as the main scene.
	var root: Node = owner if owner != null else get_parent()
	if root != null:
		_isle_state = root.get_node_or_null(NodePath("IsleState"))
		var travel := root.get_node_or_null(NodePath("TravelController"))
		# Only wire up travel buttons if travel_to() is a real method, not
		# the placeholder. Guarded, never hard-depended on per instructions.
		if travel != null and travel.has_method("travel_to"):
			_travel_controller = travel

	if _isle_state == null:
		push_warning("debug_panel: IsleState node not found, panel will not function")

	if _isle_state != null and _isle_state.has_signal("isle_state_changed"):
		_isle_state.isle_state_changed.connect(_on_isle_state_changed)

	_build_ui()
	_refresh_all_buttons()


# --- UI construction -------------------------------------------------------

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.position = Vector2(8, 8)
	_panel.size = Vector2(200, 26 + ISLE_IDS.size() * 56 + 40)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.72)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 1.0, 1.0, 0.15)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(8, 6)
	vbox.custom_minimum_size = Vector2(184, 0)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "SKY ISLES — DEBUG (H to hide)"
	title.add_theme_font_size_override("font_size", 11)
	title.modulate = Color(1.0, 1.0, 1.0, 0.65)
	vbox.add_child(title)

	for isle_id in ISLE_IDS:
		var row := HBoxContainer.new()
		vbox.add_child(row)

		var label: String = ISLE_LABELS[isle_id]
		var btn := Button.new()
		btn.text = "%s: dormant" % label
		btn.custom_minimum_size = Vector2(184, 0)
		# Bind isle_id explicitly rather than relying on closure-over-loop-
		# var semantics, which GDScript's for-loop does not guarantee across
		# signal connections the way some languages do.
		btn.pressed.connect(_on_toggle_pressed.bind(isle_id))
		vbox.add_child(btn)
		_toggle_buttons[isle_id] = btn

		# Travel buttons are optional and only appear once a real
		# travel_controller.gd has landed, per instructions — no hard
		# dependency on Agent C's file.
		if _travel_controller != null:
			var travel_btn := Button.new()
			travel_btn.text = "Travel to %s" % label
			travel_btn.custom_minimum_size = Vector2(184, 0)
			travel_btn.pressed.connect(_on_travel_pressed.bind(isle_id))
			vbox.add_child(travel_btn)
			_travel_buttons[isle_id] = travel_btn

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var all_row := HBoxContainer.new()
	vbox.add_child(all_row)

	var dormant_all := Button.new()
	dormant_all.text = "All dormant (0)"
	dormant_all.custom_minimum_size = Vector2(88, 0)
	dormant_all.pressed.connect(_set_all.bind("dormant"))
	all_row.add_child(dormant_all)

	var vibrant_all := Button.new()
	vibrant_all.text = "All vibrant (9)"
	vibrant_all.custom_minimum_size = Vector2(88, 0)
	vibrant_all.pressed.connect(_set_all.bind("vibrant"))
	all_row.add_child(vibrant_all)


# --- input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var key_event := event as InputEventKey

	if key_event.keycode == KEY_H:
		_visible_panel = not _visible_panel
		if _panel != null:
			_panel.visible = _visible_panel
		return

	# Toggle/all-state shortcuts still work while the panel is hidden —
	# hiding is a screenshot/visibility convenience, not a disable switch.
	if KEY_TO_ISLE.has(key_event.keycode):
		var isle_id: String = KEY_TO_ISLE[key_event.keycode]
		_toggle(isle_id)
		return

	match key_event.keycode:
		KEY_0:
			_set_all("dormant")
		KEY_9:
			_set_all("vibrant")


# --- actions -----------------------------------------------------------

func _on_toggle_pressed(isle_id: String) -> void:
	_toggle(isle_id)


func _on_travel_pressed(isle_id: String) -> void:
	if _travel_controller != null and _travel_controller.has_method("travel_to"):
		_travel_controller.travel_to(isle_id)


func _toggle(isle_id: String) -> void:
	if _isle_state != null and _isle_state.has_method("toggle_isle"):
		_isle_state.toggle_isle(isle_id)


func _set_all(state: String) -> void:
	if _isle_state == null or not _isle_state.has_method("set_isle_state"):
		return
	for isle_id in ISLE_IDS:
		_isle_state.set_isle_state(isle_id, state)


# --- button refresh ------------------------------------------------------

func _on_isle_state_changed(isle_id: String, state: String) -> void:
	_refresh_button(isle_id, state)


func _refresh_all_buttons() -> void:
	if _isle_state == null or not _isle_state.has_method("get_isle_state"):
		return
	for isle_id in ISLE_IDS:
		var state: String = _isle_state.get_isle_state(isle_id)
		_refresh_button(isle_id, state)


func _refresh_button(isle_id: String, state: String) -> void:
	if not _toggle_buttons.has(isle_id):
		return
	var btn: Button = _toggle_buttons[isle_id]
	var label: String = ISLE_LABELS[isle_id]
	btn.text = "%s: %s" % [label, state]
	btn.modulate = Color(1.0, 1.0, 1.0) if state == "vibrant" else Color(0.75, 0.75, 0.75)
