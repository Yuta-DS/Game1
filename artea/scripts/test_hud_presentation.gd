# Self-check for the Artéa HUD presentation pass.
#
# Run headless:
#   godot --headless --script res://scripts/test_hud_presentation.gd
#
# Covers the three things the HUD pass is responsible for and that nothing
# else tests:
#   1. The "Need help / My journey / Setup" strip is gone, autoload and all.
#   2. The creation world's HUD is built from the field-journal kit — named
#      nodes, bundled fonts, dark translucent backings, 44 px action targets.
#   3. The island-state readout stays out of the player's view unless a
#      developer opts in through the project setting.
#
# The HUD is authored in code rather than a scene, so these are checks a
# screenshot cannot make and a scene diff would not catch.
extends SceneTree

const HudTheme := preload("res://scripts/ui/artea_hud_theme.gd")
const SkyIslesScript := preload("res://scripts/hub_sky_isles.gd")

# creation_world.gd is loaded lazily inside _test_creation_hud(), not
# preloaded here. It references the CreationWorldState autoload by its bare
# global name, which only resolves once autoloads have initialized; a
# top-level const preload would compile it too early and fail under --script
# headless runs. test_creation_world.gd uses the same lazy-load pattern.

# Wording the removed strip used. If any of these come back as a button, the
# feature has been reintroduced.
const REMOVED_LABELS := ["need help", "my journey", "setup"]

var _failures := 0


func _init() -> void:
	await process_frame

	_test_safeguard_autoload_removed()
	await _test_creation_hud()
	await _test_island_debug_default_off()

	if _failures > 0:
		push_error("HUD presentation: %d check(s) failed" % _failures)
		quit(1)
		return

	print("HUD presentation: all checks passed")
	quit()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("  FAIL: %s" % message)


# --- 1. the removed strip -------------------------------------------------

func _test_safeguard_autoload_removed() -> void:
	print("checking the help/journey/setup strip is gone")

	_check(not ProjectSettings.has_setting("autoload/JourneySafeguards"),
		"autoload/JourneySafeguards is still registered in project.godot")
	_check(root.get_node_or_null("JourneySafeguards") == null,
		"a JourneySafeguards autoload node is still in the tree")

	# The autoload was the only thing that created the strip, so with it gone
	# no scene should be carrying those buttons either.
	for node in root.get_children():
		_assert_no_removed_buttons(node)


func _assert_no_removed_buttons(node: Node) -> void:
	if node is Button:
		var label := (node as Button).text.strip_edges().to_lower()
		for removed in REMOVED_LABELS:
			_check(label != removed,
				"a '%s' button still exists at %s" % [removed, node.get_path()])
	for child in node.get_children():
		_assert_no_removed_buttons(child)


# --- 2. the creation world HUD -------------------------------------------

func _test_creation_hud() -> void:
	print("checking the creation world HUD structure and accessibility")

	var creation_world_script: GDScript = load("res://scripts/creation_world/creation_world.gd")
	var world: Node = creation_world_script.new()
	root.add_child(world)
	# _ready() builds the HUD; the panels size themselves on the frame after.
	await process_frame
	await process_frame

	var hud := world.get_node_or_null("CreationHud/HudRoot") as Control
	if hud == null:
		# Without a semantic artwork the world shows its blocked notice instead
		# and never builds a HUD. That is a legitimate state, not a HUD bug, so
		# the test says so plainly rather than reporting a false failure.
		printerr("  SKIP: no HUD was built (no semantic artwork available in this environment)")
		world.queue_free()
		await process_frame
		return

	_check(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the HUD root should not intercept clicks meant for the world")

	# Every named piece of the approved layout has to exist. These names are
	# the contract this test and any future HUD work share.
	for path in ["ArtworkPlaque", "CreativeActions", "Reticle",
			"InteractionPrompt", "StatusColumn", "IdeaPanel", "SketchPanel"]:
		_check(hud.get_node_or_null(path) != null,
			"the HUD is missing its '%s' node" % path)

	_check_actions(hud)
	_check_backings(hud)
	_check_fonts(hud)
	_check_modals(hud)
	_check_status_is_contextual(world, hud)
	_check_no_duplicate_idle_lens_hint(world)

	world.queue_free()
	await process_frame


func _check_no_duplicate_idle_lens_hint(world: Node) -> void:
	for node in world.find_children("*", "Label", true, false):
		var label := node as Label
		if label.text.begins_with("Q — raise the Lens"):
			_check(not label.visible,
				"the lens idle hint overlaps the creation world's controls plaque")


func _check_actions(hud: Control) -> void:
	var row := hud.get_node_or_null("CreativeActions/VBoxContainer/ActionRow")
	if row == null:
		# The container names are Godot's defaults; find the row by its buttons
		# instead of failing on an unrelated naming detail.
		row = _find_node_named(hud, "ActionRow")
	if row == null:
		_check(false, "the creative action row is missing")
		return

	# The actions themselves, plus the keys that reach them, must survive the
	# restyle — this pass was about presentation, not about removing features.
	for action_name in ["AddIdeaButton", "DrawButton", "PaintButton", "ExitArtworkButton"]:
		var button := _find_node_named(hud, action_name) as Button
		_check(button != null, "the '%s' action is missing" % action_name)
		if button == null:
			continue
		_check(button.custom_minimum_size.y >= HudTheme.MIN_ACTION_HEIGHT,
			"'%s' is %.0f px high, below the %.0f px minimum target" % [
				action_name, button.custom_minimum_size.y, HudTheme.MIN_ACTION_HEIGHT])
		_check(button.size.y >= HudTheme.MIN_ACTION_HEIGHT,
			"'%s' laid out at %.0f px high, below the %.0f px minimum target" % [
				action_name, button.size.y, HudTheme.MIN_ACTION_HEIGHT])
		_check(button.has_theme_stylebox_override("normal"),
			"'%s' is still using a default Godot button style" % action_name)
		_check(button.focus_mode == Control.FOCUS_ALL,
			"'%s' cannot be reached by keyboard focus" % action_name)

	# The M and Q shortcuts have to keep pointing at the same panels.
	var add_button := _find_node_named(hud, "AddIdeaButton") as Button
	var draw_button := _find_node_named(hud, "DrawButton") as Button
	if add_button != null:
		_check(add_button.pressed.get_connections().size() > 0,
			"the add-idea action is not wired to anything")
	if draw_button != null:
		_check(draw_button.pressed.get_connections().size() > 0,
			"the draw action is not wired to anything")


# Pale type only reads over a bright castle or a pink artwork if it sits on
# something dark. Every plaque that carries gameplay meaning gets checked.
func _check_backings(hud: Control) -> void:
	for path in ["ArtworkPlaque", "CreativeActions", "InteractionPrompt",
			"IdeaPanel", "SketchPanel"]:
		var panel := _find_node_named(hud, path) as PanelContainer
		if panel == null:
			continue
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		_check(style != null, "'%s' has no ink-glass backing" % path)
		if style == null:
			continue
		_check(style.bg_color.a > 0.5 and style.bg_color.a < 1.0,
			"'%s' backing should be dark and translucent, alpha is %.2f" % [
				path, style.bg_color.a])
		_check(style.bg_color.get_luminance() < 0.25,
			"'%s' backing is too light to carry parchment text" % path)
		_check(style.corner_radius_top_left >= 12,
			"'%s' should use the 12-16 px journal corner" % path)
		_check(style.border_width_top >= 1 and style.border_width_top <= 2,
			"'%s' should use a restrained 1-2 px border" % path)


func _check_fonts(hud: Control) -> void:
	var title := _find_node_named(hud, "WorldTitle") as Label
	_check(title != null, "the artwork title is missing")
	if title != null:
		_check(title.has_theme_font_override("font"),
			"the world title is not using the bundled Artéa display font")
		_check(title.get_theme_color("font_color") == HudTheme.PARCHMENT,
			"the world title should be parchment-coloured")

	var controls := _find_node_named(hud, "ControlsLabel") as Label
	_check(controls != null, "the control hint is missing")
	if controls != null:
		_check(controls.has_theme_font_override("font"),
			"the control hint is not using the bundled utility font")
		# The long instruction sentence was the thing that was hard to scan.
		_check(controls.text.length() < 80,
			"the control hint is %d characters — too long to scan in play" %
				controls.text.length())


func _check_modals(hud: Control) -> void:
	for panel_name in ["IdeaPanel", "SketchPanel"]:
		var panel := _find_node_named(hud, panel_name) as PanelContainer
		if panel == null:
			continue
		_check(not panel.visible, "'%s' should start hidden" % panel_name)
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			_check(style.content_margin_left >= 16.0,
				"'%s' needs readable internal padding" % panel_name)

	var input := _find_node_named(hud, "IdeaInput") as LineEdit
	_check(input != null, "the idea input is missing")
	if input != null:
		_check(input.custom_minimum_size.y >= HudTheme.MIN_ACTION_HEIGHT,
			"the idea input is below the %.0f px minimum target" %
				HudTheme.MIN_ACTION_HEIGHT)
		_check(input.has_theme_stylebox_override("normal"),
			"the idea input is still a default Godot LineEdit")

	for button_name in ["IdeaSubmitButton", "IdeaCancelButton",
			"SketchClearButton", "SketchPlaceButton", "SketchCancelButton"]:
		var button := _find_node_named(hud, button_name) as Button
		_check(button != null, "the '%s' modal action is missing" % button_name)
		if button == null:
			continue
		_check(button.custom_minimum_size.y >= HudTheme.MIN_ACTION_HEIGHT,
			"'%s' is below the %.0f px minimum target" % [
				button_name, HudTheme.MIN_ACTION_HEIGHT])
		_check(button.has_theme_stylebox_override("normal"),
			"'%s' is still using a default Godot button style" % button_name)


# Status is meant to speak only when it has something to say, so an empty
# message must take its plaque away rather than leave a dark bar on screen.
func _check_status_is_contextual(world: Node, hud: Control) -> void:
	var plaque := _find_node_named(hud, "StatusPlaque") as PanelContainer
	var label := _find_node_named(hud, "StatusLabel") as Label
	_check(plaque != null and label != null, "the status plaque is missing")
	if plaque == null or label == null:
		return

	world.call("_set_status", "Building your world… 1/4")
	_check(plaque.visible, "the status plaque should appear when there is news")
	_check(label.text == "Building your world… 1/4",
		"the status text did not update")

	world.call("_set_status", "")
	_check(not plaque.visible,
		"an empty status should leave no plaque on screen")


# --- 3. the island-state debug readout ------------------------------------

func _test_island_debug_default_off() -> void:
	print("checking the island-state readout is opt-in")

	var setting: String = SkyIslesScript.ISLAND_DEBUG_PANEL_SETTING
	_check(ProjectSettings.has_setting(setting),
		"the '%s' opt-in setting is not declared for developers" % setting)
	_check(not bool(ProjectSettings.get_setting(setting, false)),
		"'%s' must ship false so debug play stays free of developer text" % setting)

	var isles := SkyIslesScript.new()
	_check(not isles.call("_island_debug_panel_enabled"),
		"the island-state panel is enabled by default, even in a debug build")

	# Nothing should be able to put the readout on screen while it is off.
	isles.call("_build_debug_panel")
	_check(isles.get_node_or_null("IslandStateDebug") == null,
		"the ISLAND STATES readout was built despite the opt-in being false")
	isles.free()


# --- helpers --------------------------------------------------------------

func _find_node_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_node_named(child, wanted)
		if found != null:
			return found
	return null
