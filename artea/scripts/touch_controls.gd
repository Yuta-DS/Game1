# touch_controls.gd (autoload)
#
# On-screen controls for phones and tablets. Only switches on when the device
# reports a touchscreen, so desktop play is untouched.
#
# - Left side: a floating joystick that drives the same move_* actions as WASD,
#   so every player script (hub, gallery, castle galaxy, creation world) moves
#   without knowing touch exists.
# - Right side: drag to look. Cameras that support it join the "touch_look"
#   group and expose touch_look(relative). They ignore the mouse motion the
#   browser emulates from touches, which is what used to spin the view on
#   every tap.
# - Buttons: Jump (Space: jump + ui_accept), Sprint (Shift), Use (Q), and
#   Journal (J) wherever the scene offers the quest journal.
extends CanvasLayer

const LOOK_GROUP := "touch_look"
## UI that owns the screen while open: the touch HUD hides so its buttons cannot
## be pressed through it.
const HUD_BLOCKER_GROUPS: Array[String] = ["camera_input_blockers", "touch_hud_blockers"]
## The gallery's "Crown Journey [J]" button. When it exists the journal is
## available, and the touch HUD shows its own, finger-sized Journal button.
const JOURNAL_BUTTON_NAME := "CrownJourneyJournalButton"

## Fraction of the screen width, from the left, where a touch starts the joystick.
const JOYSTICK_ZONE := 0.42
## Turns a finger drag into the same scale as mouse motion for the cameras.
const LOOK_SCALE := 0.6
const JOYSTICK_DEADZONE := 0.15

var _active := false
var _root: Control
var _stick: Control
var _buttons: Array[TouchScreenButton] = []
var _journal_button: TouchScreenButton

var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_vector := Vector2.ZERO
var _look_touch := -1
var _desktop_journal: CanvasItem
var _journal_lookup_cooldown := 0.0


func _ready() -> void:
	layer = 60
	if not is_touch_device():
		set_process(false)
		set_process_unhandled_input(false)
		return
	build()


## True only on phones and tablets. A touchscreen alone is not enough: Windows
## and Linux touch laptops report one too and must keep the desktop HUD. The
## web feature tags come from the browser's user agent. iPadOS Safari reports
## itself as macOS, but Macs have no touchscreen, so macOS + touch is an iPad.
static func is_touch_device() -> bool:
	if OS.has_feature("mobile"): # native Android/iOS exports
		return true
	if not DisplayServer.is_touchscreen_available():
		return false
	return OS.has_feature("web_android") or OS.has_feature("web_ios") \
		or OS.has_feature("web_macos")


## Mouse mode for anywhere a scene would capture the cursor. Capturing hides
## the pointer, which only makes sense with a mouse on a PC; phones and tablets
## (including an iPad with a trackpad) keep it visible. Checked at the source
## because on the web a capture cannot be undone afterwards: the browser grants
## pointer lock a moment later regardless.
static func captured_mode() -> Input.MouseMode:
	return Input.MOUSE_MODE_VISIBLE if is_touch_device() else Input.MOUSE_MODE_CAPTURED


## Screen (CSS) pixels per viewport unit. The game is laid out at 1710x1112 and
## canvas_items stretch shrinks that to the window, so on a phone an 18 px font
## is drawn about 6 px tall. Touch layouts use this to size text for real.
static func css_pixels_per_unit(viewport: Viewport) -> float:
	var units := maxf(viewport.get_visible_rect().size.x, 1.0)
	var pixels := float(DisplayServer.window_get_size().x) / maxf(DisplayServer.screen_get_scale(), 1.0)
	return pixels / units


# Separate from _ready so the headless test can switch the HUD on.
func build() -> void:
	_active = true
	set_process(true)
	set_process_unhandled_input(true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_stick = Control.new()
	_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick.draw.connect(_draw_stick)
	_root.add_child(_stick)
	_buttons.append(_make_button("JUMP", ["jump", "ui_accept"]))
	_buttons.append(_make_button("SPRINT", ["run"]))
	_buttons.append(_make_button("USE", ["interact"]))
	_journal_button = _make_button("JOURNAL", [])
	_journal_button.pressed.connect(_tap_key.bind(KEY_J))
	get_viewport().size_changed.connect(_layout)
	_layout()
	visible = false


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	var wanted := not get_tree().get_nodes_in_group(LOOK_GROUP).is_empty()
	for group in HUD_BLOCKER_GROUPS:
		if not get_tree().get_nodes_in_group(group).is_empty():
			wanted = false
	if wanted != visible:
		visible = wanted
		if not wanted:
			_release_stick()
			_look_touch = -1
	if not wanted:
		return
	# A whole-tree search is too slow for every frame in the castle galaxy.
	_journal_lookup_cooldown -= delta
	if not is_instance_valid(_desktop_journal) and _journal_lookup_cooldown <= 0.0:
		_journal_lookup_cooldown = 1.0
		_desktop_journal = get_tree().root.find_child(JOURNAL_BUTTON_NAME, true, false) as CanvasItem
	var has_journal := is_instance_valid(_desktop_journal)
	_journal_button.visible = has_journal
	if has_journal:
		_desktop_journal.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# Touches that land on a Control (minimap, inventory icon, dialogue) are
	# consumed by the GUI before this, so only touches on the open world arrive.
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _over_button(touch.position):
				return
			if _stick_touch < 0 and touch.position.x < _root.size.x * JOYSTICK_ZONE:
				_stick_touch = touch.index
				_stick_origin = touch.position
				_set_stick(Vector2.ZERO)
			elif _look_touch < 0:
				_look_touch = touch.index
		else:
			if touch.index == _stick_touch:
				_release_stick()
			elif touch.index == _look_touch:
				_look_touch = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_touch:
			_set_stick((drag.position - _stick_origin) / _stick_radius())
		elif drag.index == _look_touch:
			get_tree().call_group(LOOK_GROUP, "touch_look", drag.relative * LOOK_SCALE)


func _set_stick(value: Vector2) -> void:
	_stick_vector = value.limit_length(1.0)
	var v := _stick_vector if _stick_vector.length() > JOYSTICK_DEADZONE else Vector2.ZERO
	_press_axis("move_left", "move_right", v.x)
	_press_axis("move_forward", "move_backward", v.y)
	_stick.queue_redraw()


func _press_axis(negative: String, positive: String, value: float) -> void:
	if value < 0.0:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	elif value > 0.0:
		Input.action_press(positive, value)
		Input.action_release(negative)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


func _release_stick() -> void:
	_stick_touch = -1
	_set_stick(Vector2.ZERO)


func _stick_radius() -> float:
	return _unit() * 1.6


# One HUD unit, sized from the short side so the controls are thumb-sized on a
# phone in either orientation and not oversized on a tablet.
func _unit() -> float:
	var s := get_viewport().get_visible_rect().size
	return minf(s.x, s.y) * 0.075


func _draw_stick() -> void:
	var r := _stick_radius()
	var centre := _stick_origin if _stick_touch >= 0 \
		else Vector2(r * 1.6, _root.size.y - r * 1.6)
	var alpha := 0.55 if _stick_touch >= 0 else 0.28
	_stick.draw_circle(centre, r, Color(0.05, 0.07, 0.12, alpha * 0.6))
	_stick.draw_arc(centre, r, 0.0, TAU, 48, Color(1, 1, 1, alpha), 3.0, true)
	_stick.draw_circle(centre + _stick_vector * r, r * 0.42, Color(1, 1, 1, alpha + 0.15))


func _make_button(label_text: String, actions: Array) -> TouchScreenButton:
	var button := TouchScreenButton.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.45))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	gradient.add_point(0.93, Color(1, 1, 1, 0.3))
	gradient.add_point(0.97, Color(1, 1, 1, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	button.texture_normal = texture
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(128, 128)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	# One callable for all of them: Godot treats _send_action bound to two
	# actions as the same connection and dropped the second (ui_accept).
	button.pressed.connect(func() -> void:
		for action in actions: _send_action(action, true))
	button.released.connect(func() -> void:
		for action in actions: _send_action(action, false))
	_root.add_child(button)
	return button


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var d := _unit() * 2.0 # button diameter
	var s := d / 128.0
	for button: TouchScreenButton in _buttons + [_journal_button]:
		button.scale = Vector2(s, s)
	var margin := d * 0.35
	var corner := Vector2(size.x - margin - d, size.y - margin - d)
	_buttons[0].position = corner                                   # Jump
	_buttons[1].position = corner + Vector2(-d * 1.15, d * 0.1)     # Sprint
	_buttons[2].position = corner + Vector2(d * 0.1, -d * 1.15)     # Use
	# Top right, where the gallery's desktop journal button sits.
	_journal_button.position = Vector2(size.x - margin - d, margin)
	if _stick != null:
		_stick.queue_redraw()


func _over_button(point: Vector2) -> bool:
	for button: TouchScreenButton in _buttons + [_journal_button]:
		if not button.visible:
			continue
		var d := 128.0 * button.scale.x
		if point.distance_to(button.position + Vector2(d, d) * 0.5) <= d * 0.6:
			return true
	return false


func _send_action(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _tap_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)


func _exit_tree() -> void:
	if _active:
		_release_stick()
