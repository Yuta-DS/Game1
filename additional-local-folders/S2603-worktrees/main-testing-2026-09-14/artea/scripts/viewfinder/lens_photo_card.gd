# The frozen seeing the player carries — a Polaroid-like HUD card.
#
# WHAT IT IS AND IS NOT
#
# The card is PRESENTATION ONLY. The seeing the player actually carries is real
# geometry parented to the capture point (viewfinder_lens.gd), and placement is
# exact because of that parenting, not because of anything here. This is a
# picture of that geometry, frozen at the instant of capture, so the player can
# see what they are holding while they walk to where it belongs. If this
# component fails, the mechanic must still work perfectly — every failure path
# below returns quietly rather than refusing a capture.
#
# WHY FREEZE THE IMAGE
#
# Capture hides the source props, so by the time the HUD could draw anything the
# world no longer contains what the player framed. The image therefore has to be
# grabbed BEFORE the cut, which is why `freeze()` is a separate call the
# controller makes ahead of viewfinder_lens.capture() rather than something this
# node does in reaction to a signal.
#
# CROPPING
#
# The card shows exactly the region the on-screen frame brackets, which is the
# region the lens frustum actually cuts (LENS_FOV_SCALE). Showing the whole
# screen would tell the player they took more than they did.
#
# Deliberately a plain Control with no scene file and no camera of its own: the
# thing worth testing is that the lifecycle is safe (freeze/show/hide/clear in
# any order, headless, no framebuffer), so it is testable with no 3D at all.
extends Control

# Fraction of the shorter screen axis the card's image occupies. Big enough to
# read what is in it, small enough to leave the world visible around it.
const CARD_HEIGHT_RATIO := 0.30

# Polaroid proportions: a square image with a wide bottom border.
const BORDER := 14.0
const BOTTOM_BORDER := 44.0

# Where the card sits, as an offset from the bottom-right corner.
const MARGIN := Vector2(30.0, 30.0)

# How long the card takes to appear and to leave. Short: this is feedback, not a
# cutscene, and a child clicking again immediately must not be waiting on it.
const APPEAR_TIME := 0.22
const LEAVE_TIME := 0.16

# Rotation applied per T press, matching viewfinder_lens.rotate_held so the card
# and the geometry it depicts turn together.
const DEGREES_PER_STEP := 30.0

# A held card is tilted slightly, so it reads as a physical object resting
# against the screen rather than a UI panel.
const RESTING_TILT := -3.0

var _frame: Panel
var _image: TextureRect
var _caption: Label
var _tween: Tween
var _roll_steps := 0
var _frozen: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	# Pivot at the centre so the tilt and the T rotation turn the card about
	# itself rather than swinging it off the corner it is anchored to.
	pivot_offset = size * 0.5


# Grab what the lens is looking at, RIGHT NOW, before the world is mutated.
#
# Returns true if an image was captured. False is a normal, non-fatal outcome:
# headless has no framebuffer at all, and a viewport can legitimately have no
# texture on the first frame. The caller must treat false as "no card this
# time", never as a reason to refuse the capture.
func freeze(inset: Vector2 = Vector2.ZERO) -> bool:
	_frozen = null
	if not is_inside_tree():
		return false

	var viewport := get_viewport()
	if viewport == null:
		return false

	# Headless renders nothing, so there is no framebuffer to read back. Checked
	# explicitly rather than discovered by way of a null texture, so the reason
	# is legible in a log.
	if DisplayServer.get_name() == "headless":
		return false

	var texture := viewport.get_texture()
	if texture == null:
		return false

	var full := texture.get_image()
	if full == null or full.is_empty():
		return false

	var cropped := _crop(full, inset)
	if cropped == null:
		return false

	_frozen = ImageTexture.create_from_image(cropped)
	return _frozen != null


# The framed region of the screen, matching the lens frame's inset so the card
# shows what was actually taken.
func _crop(source: Image, inset: Vector2) -> Image:
	var width := source.get_width()
	var height := source.get_height()
	if width <= 0 or height <= 0:
		return null

	# Clamped rather than trusted: an inset of 0.5 or more would ask for a
	# zero-width region and Image.get_region() would fail.
	var clamped := Vector2(clampf(inset.x, 0.0, 0.45), clampf(inset.y, 0.0, 0.45))
	var region := Rect2i(
		int(float(width) * clamped.x),
		int(float(height) * clamped.y),
		maxi(1, int(float(width) * (1.0 - clamped.x * 2.0))),
		maxi(1, int(float(height) * (1.0 - clamped.y * 2.0))))

	var cropped := source.get_region(region)
	if cropped == null or cropped.is_empty():
		return null
	return cropped


# Show the card. Safe with no frozen image: the card still appears, holding a
# plain paper-coloured pane, so the player is never left without an indication
# that they are carrying something.
func show_card(caption: String = "") -> void:
	_roll_steps = 0
	if _image != null:
		_image.texture = _frozen
	if _caption != null:
		_caption.text = caption

	_kill_tween()
	visible = true
	pivot_offset = size * 0.5
	rotation_degrees = RESTING_TILT
	scale = Vector2(0.86, 0.86)
	modulate.a = 0.0

	# Animation is a nicety; if the tree cannot make a tween (a bare test
	# harness, a node outside the tree) the card must simply be there.
	_tween = _make_tween()
	if _tween == null:
		scale = Vector2.ONE
		modulate.a = 1.0
		return
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, APPEAR_TIME)
	_tween.tween_property(self, "scale", Vector2.ONE, APPEAR_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


# Turn the card with the geometry it depicts, in the same 30-degree steps.
func rotate_card(steps: int = -1) -> void:
	if not visible:
		return
	_roll_steps = wrapi(_roll_steps + steps, 0, 12)
	var target := RESTING_TILT + DEGREES_PER_STEP * float(_roll_steps)

	_kill_tween()
	_tween = _make_tween()
	if _tween == null:
		rotation_degrees = target
		return
	_tween.tween_property(self, "rotation_degrees", target, APPEAR_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


# Retire the card. `into_world` is the placement gesture: the card shrinks away
# as the geometry it depicted becomes real. Release just fades it.
func hide_card(into_world: bool = false) -> void:
	_kill_tween()
	if not visible:
		_clear()
		return

	_tween = _make_tween()
	if _tween == null:
		# No tween available: hide immediately rather than leaving a stale card
		# on screen. Correctness over polish, always in that order.
		visible = false
		_clear()
		return

	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, LEAVE_TIME)
	_tween.tween_property(self, "scale",
		Vector2(0.4, 0.4) if into_world else Vector2(0.9, 0.9), LEAVE_TIME)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		_clear())


# Drop the card and its image with no animation at all. Used when state has to
# be made consistent immediately — a failed transaction, or a scene teardown.
func reset() -> void:
	_kill_tween()
	visible = false
	modulate.a = 1.0
	scale = Vector2.ONE
	rotation_degrees = RESTING_TILT
	_clear()


func has_frozen_image() -> bool:
	return _frozen != null


func is_showing() -> bool:
	return visible


func roll_steps() -> int:
	return _roll_steps


func _clear() -> void:
	_frozen = null
	_roll_steps = 0
	if _image != null:
		_image.texture = null


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


# create_tween() throws if the node is not in a tree, which a unit test can
# legitimately arrange. Returning null lets every caller fall back to setting
# the final value directly.
func _make_tween() -> Tween:
	if not is_inside_tree():
		return null
	return create_tween()


func _build() -> void:
	# Sized from the viewport's shorter axis so the card is the same visual
	# weight at any window size.
	var viewport_size := Vector2(1152, 648)
	if is_inside_tree() and get_viewport() != null:
		viewport_size = get_viewport().get_visible_rect().size
	var image_side := maxf(96.0, minf(viewport_size.x, viewport_size.y) * CARD_HEIGHT_RATIO)
	var card_size := Vector2(
		image_side + BORDER * 2.0,
		image_side + BORDER + BOTTOM_BORDER)

	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	size = card_size
	offset_left = -card_size.x - MARGIN.x
	offset_top = -card_size.y - MARGIN.y
	offset_right = -MARGIN.x
	offset_bottom = -MARGIN.y

	_frame = Panel.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.96, 0.90)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(2, 4)
	_frame.add_theme_stylebox_override("panel", style)
	add_child(_frame)

	# The pane behind the image, so a card with no frozen texture still reads as
	# an exposed but undeveloped photo rather than a hole in the card.
	var backing := ColorRect.new()
	backing.color = Color(0.13, 0.14, 0.18)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	backing.offset_left = BORDER
	backing.offset_top = BORDER
	backing.offset_right = -BORDER
	backing.offset_bottom = -BOTTOM_BORDER
	add_child(backing)

	_image = TextureRect.new()
	_image.name = "FrozenSeeing"
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the framed aspect: stretching the crop would misreport the shape of
	# what was taken.
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image.offset_left = BORDER
	_image.offset_top = BORDER
	_image.offset_right = -BORDER
	_image.offset_bottom = -BOTTOM_BORDER
	_image.clip_contents = true
	add_child(_image)

	_caption = Label.new()
	_caption.name = "Caption"
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	_caption.offset_left = BORDER
	_caption.offset_top = -BOTTOM_BORDER + 6.0
	_caption.offset_right = -BORDER
	_caption.offset_bottom = -6.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 14)
	_caption.add_theme_color_override("font_color", Color(0.22, 0.20, 0.24))
	add_child(_caption)
