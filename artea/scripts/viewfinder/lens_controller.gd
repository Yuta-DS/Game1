# Player-facing control for the Lens of Seeing.
#
# Three states, matching the original's Polaroid state machine but without its
# animation coupling:
#   DOWN    — lens lowered, ordinary play
#   RAISED  — looking through the lens, ready to capture
#   HOLDING — carrying a seeing, ready to place
#
# Attach as a child of the player, with `camera` pointing at the player's
# Camera3D. Builds its own small HUD so no scene file needs editing — the same
# convention gallery_ceremony.gd and journey_privacy.gd already follow.
extends Node3D

const LensScript := preload("res://scripts/viewfinder/viewfinder_lens.gd")
const LensJourneyScript := preload("res://scripts/viewfinder/lens_journey.gd")
const LensPersistence := preload("res://scripts/viewfinder/lens_persistence.gd")
const PhotoCardScript := preload("res://scripts/viewfinder/lens_photo_card.gd")

enum State { DOWN, RAISED, HOLDING }

# Input is bound at runtime rather than requiring project.godot actions, so
# dropping this node into a scene is all that is needed to play it.
const KEY_TOGGLE := KEY_Q
const KEY_ACT := MOUSE_BUTTON_LEFT
const KEY_CANCEL := KEY_ESCAPE
const KEY_ROTATE := KEY_T

# Depth of field while the lens is raised. Looking through the lens should feel
# like looking THROUGH something — the blur is what separates "framing" from
# "walking around", and it is the cue that the next click will change the
# world.
const DOF_NEAR_DISTANCE := 0.6
const DOF_FAR_DISTANCE := 14.0
const DOF_TRANSITION := 4.0
const DOF_AMOUNT := 0.06

# The frame the player looks through, as a fraction of the screen inset from
# each edge. Derived from LENS_FOV_SCALE rather than picked by eye: the drawn
# frame has to match the cone that is actually cut, or the player is being told
# a lie about what they are about to take.
const FRAME_INSET := Vector2(
	(1.0 - LensScript.LENS_FOV_SCALE) * 0.5,
	(1.0 - LensScript.LENS_FOV_SCALE) * 0.5)

var camera: Camera3D

var _state: int = State.DOWN
var _lens: Node3D
var _journey: Node
var _layer: CanvasLayer
var _frame: Control
var _hint: Label
var _message: Label
var _counter: Label
var _card: Control
var _message_timer := 0.0
# Set while a capture/place/release is being driven from input, so a second
# click arriving in the same frame is dropped here rather than reaching the lens
# mid-surgery. The lens has its own guard (viewfinder_lens.is_busy); this one
# additionally covers the photo-card work that happens either side of the call.
var _acting := false
# The camera attributes owned by this node, so raising the lens does not
# permanently alter whatever the scene had configured.
var _lens_attributes: CameraAttributesPractical
var _previous_attributes: CameraAttributes

# Placed seeings survive a reload by replaying the cut, not by storing meshes
# (ViewFinder.txt §R5). Set `persist` false for a sandbox like the demo room,
# where leftover placements from a previous run would be confusing.
@export var persist := true
# Worlds with their own consolidated controls plaque can suppress the lens's
# duplicate idle reminder. Raised/holding instructions still appear because
# they are contextual and replace the normal movement controls.
@export var show_idle_hint := true
# Story scenes with their own subtitle panel can suppress the LensJourney's
# separate bottom caption while keeping contextual controls and the photo card.
@export var show_narrative_messages := true
var _placements: Array = []
# Where the player stood when the currently-held seeing was taken.
var _pending_origin := Transform3D.IDENTITY


func _ready() -> void:
	if camera == null:
		camera = _find_camera(get_parent())

	# The capture point is this node: held seeings parent here and therefore
	# travel with the player, which is what makes placement exact.
	_lens = LensScript.new()
	_lens.name = "ViewfinderLens"
	_lens.camera = camera
	_lens.capture_point = self
	add_child(_lens)

	_journey = LensJourneyScript.new()
	_journey.name = "LensJourney"
	_journey.lens = _lens
	# A sandbox that does not persist its placements must not write strengths
	# into the player's real journey either.
	_journey.record_to_journey = persist
	add_child(_journey)
	_journey.lens_message.connect(_show_message)
	_lens.seeings_remaining_changed.connect(_on_seeings_changed)
	_lens.seeing_captured.connect(_on_captured)
	_lens.seeing_placed.connect(_on_placed)

	_build_dof()
	_build_hud()
	_refresh()

	if persist:
		# After the scene has finished building, or the props the replay needs
		# to cut may not exist yet.
		call_deferred("_restore_placements")


# The frozen-seeing card. Public so a test can drive its lifecycle without
# synthesising input events, and so the hub can hide it during a cutscene.
func photo_card() -> Control:
	return _card


func _on_captured(_count: int) -> void:
	# Remember where this seeing was taken from, so a later placement can be
	# stored as a replayable pair of poses.
	if camera != null:
		_pending_origin = camera.global_transform


func _on_placed(_count: int) -> void:
	if not persist or camera == null:
		return
	_placements.append(LensPersistence.make_record(
		_pending_origin, camera.global_transform, _lens.roll_steps()))
	LensPersistence.save_placements(_placements)


# Re-cut and re-place everything the player left here last session.
func _restore_placements() -> void:
	var saved := LensPersistence.load_placements()
	if saved.is_empty():
		return

	# Replay drives the same public capture/place API the player does, so the
	# camera has to actually be moved to each recorded pose. Put it back
	# afterwards — the player should not find themselves somewhere else.
	var resume := camera.global_transform if camera != null else Transform3D.IDENTITY
	var mover := func(pose: Transform3D) -> void:
		if camera != null:
			camera.global_transform = pose
		global_transform = pose

	var restored: int = LensPersistence.replay(_lens, saved, mover)

	if camera != null:
		camera.global_transform = resume
	global_transform = resume

	# Keep only what actually came back, so a stale record is not retried and
	# re-failed on every future load.
	_placements = saved.slice(0, restored) if restored < saved.size() else saved
	if restored < saved.size():
		LensPersistence.save_placements(_placements)

	_refresh()


# Depth of field is applied by swapping the camera's attributes while the lens
# is raised, and putting the originals back when it is lowered — the scene's
# own exposure/DOF settings are never overwritten.
func _build_dof() -> void:
	_lens_attributes = CameraAttributesPractical.new()
	# Depth-of-field blur exists only on Forward+/Mobile. The Web export runs
	# gl_compatibility (its template ships no other renderer), where enabling
	# these logs a warning per lens and blurs nothing. Leave the attributes
	# unblurred there so the lens still frames shots without the noise.
	if OS.has_feature("web"):
		return
	_lens_attributes.dof_blur_near_enabled = true
	_lens_attributes.dof_blur_near_distance = DOF_NEAR_DISTANCE
	_lens_attributes.dof_blur_near_transition = DOF_TRANSITION
	_lens_attributes.dof_blur_far_enabled = true
	_lens_attributes.dof_blur_far_distance = DOF_FAR_DISTANCE
	_lens_attributes.dof_blur_far_transition = DOF_TRANSITION
	_lens_attributes.dof_blur_amount = DOF_AMOUNT


func _apply_dof(active: bool) -> void:
	if camera == null or _lens_attributes == null:
		return
	if active:
		if camera.attributes != _lens_attributes:
			_previous_attributes = camera.attributes
		camera.attributes = _lens_attributes
	elif camera.attributes == _lens_attributes:
		camera.attributes = _previous_attributes


func _on_seeings_changed(remaining: int) -> void:
	_update_counter(remaining)


func _update_counter(remaining: int) -> void:
	if _counter == null:
		return
	# Shown only while the lens is up: a resource counter on screen during
	# ordinary play is noise.
	_counter.visible = _state != State.DOWN
	_counter.text = "Seeings: %d / %d" % [remaining, LensScript.MAX_SEEINGS]


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message.text = ""


func _unhandled_input(event: InputEvent) -> void:
	# One gesture at a time. Every branch below either mutates the world or the
	# card that depicts it, and none of them may interleave.
	if _acting:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TOGGLE:
			_toggle_raised()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ROTATE and _state == State.HOLDING:
			# -30 degrees per press, matching the original's turn direction. The
			# card turns with the geometry, so what the player sees on the card
			# stays an honest picture of what they are holding.
			if _lens.rotate_held(-1) and _card != null:
				_card.rotate_card(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_CANCEL and _state != State.DOWN:
			_cancel()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed \
			and event.button_index == KEY_ACT:
		if _state == State.RAISED:
			_do_capture()
			get_viewport().set_input_as_handled()
		elif _state == State.HOLDING:
			_do_place()
			get_viewport().set_input_as_handled()


# TAKE, with the frozen image grabbed first.
#
# Order matters and is the whole reason this is a method rather than two lines
# in the input handler: the capture hides the props the player framed, so the
# image has to be read BEFORE the cut or the card would show the gap instead of
# the thing. A failed freeze is not a failed capture — the card simply appears
# undeveloped.
func _do_capture() -> void:
	if _lens.is_busy():
		return
	_acting = true

	var froze := false
	if _card != null:
		froze = _card.freeze(FRAME_INSET)

	if _lens.capture():
		if _card != null:
			_card.show_card("A seeing" if froze else "A seeing (unseen)")
	elif _card != null:
		# Refused after the image was taken: drop it, or the next successful
		# capture would show a stale picture of somewhere else.
		_card.reset()

	_acting = false
	_refresh()


func _do_place() -> void:
	if _lens.is_busy():
		return
	_acting = true

	if _lens.place():
		if _card != null:
			# Into the world: the card shrinks away as the geometry it depicted
			# becomes real in front of the player.
			_card.hide_card(true)
	_acting = false
	_refresh()


func _toggle_raised() -> void:
	match _state:
		State.DOWN:
			_state = State.RAISED
			# Said once, on first raise: it tells the player what the lens is
			# for without explaining any particular puzzle for them.
			if _journey != null:
				_show_message(_journey.first_look_line())
		State.RAISED:
			_state = State.DOWN
	_refresh()


# Backing out. A held seeing is released rather than kept, so the world always
# returns to intact — the player can never strand themselves mid-operation.
func _cancel() -> void:
	if _lens.is_busy():
		return
	_acting = true
	if _lens.is_holding():
		_lens.release()
		_show_message("You put back what you were carrying.")
	if _card != null:
		_card.hide_card(false)
	_state = State.DOWN
	_acting = false
	_refresh()


func _refresh() -> void:
	if _lens.is_holding():
		_state = State.HOLDING
	elif _state == State.HOLDING:
		_state = State.RAISED

	if _frame != null:
		_frame.visible = _state != State.DOWN

	# Reconcile the card with the truth, whatever route got us here. The lens can
	# be driven directly — persistence replay does exactly that — and a card left
	# showing when nothing is held is a lie about the world.
	if _card != null and _state != State.HOLDING and _card.is_showing():
		_card.hide_card(false)

	_apply_dof(_state != State.DOWN)
	_update_counter(_lens.seeings_left())

	if _hint == null:
		return
	match _state:
		State.DOWN:
			_hint.text = "Q — raise the Lens of Seeing"
			_hint.visible = show_idle_hint
		State.RAISED:
			_hint.text = "Click — take what you see    Q — lower the lens"
			_hint.visible = true
		State.HOLDING:
			_hint.text = "Click — place what you saw    T — turn it    Esc — put it back"
			_hint.visible = true


func _show_message(text: String) -> void:
	if _message == null or not show_narrative_messages:
		return
	_message.text = text
	_message_timer = 4.5


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 11
	add_child(_layer)

	var root_control := Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root_control)

	# The viewfinder frame: four corner brackets rather than a solid border, so
	# the player can still see the world they are framing.
	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.anchor_left = FRAME_INSET.x
	_frame.anchor_right = 1.0 - FRAME_INSET.x
	_frame.anchor_top = FRAME_INSET.y
	_frame.anchor_bottom = 1.0 - FRAME_INSET.y
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.visible = false
	root_control.add_child(_frame)

	for corner in 4:
		_frame.add_child(_corner_bracket(corner))

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -300.0
	_hint.offset_right = 300.0
	_hint.offset_top = -70.0
	_hint.offset_bottom = -46.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80, 0.85))
	root_control.add_child(_hint)

	_counter = Label.new()
	_counter.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_counter.offset_left = -220.0
	_counter.offset_right = -20.0
	_counter.offset_top = 18.0
	_counter.offset_bottom = 44.0
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.add_theme_font_size_override("font_size", 17)
	_counter.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62))
	_counter.visible = false
	root_control.add_child(_counter)

	# The frozen seeing. Added last so it draws over the frame and the hint,
	# which is what makes it read as a card held up in front of the view.
	_card = PhotoCardScript.new()
	_card.name = "PhotoCard"
	root_control.add_child(_card)

	_message = Label.new()
	_message.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message.offset_left = -460.0
	_message.offset_right = 460.0
	_message.offset_top = -120.0
	_message.offset_bottom = -76.0
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_font_size_override("font_size", 19)
	_message.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	root_control.add_child(_message)


func _corner_bracket(corner: int) -> Control:
	var bracket := Control.new()
	bracket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var length := 34.0
	var thickness := 3.0
	var colour := Color(1.0, 0.94, 0.72, 0.9)

	var horizontal := ColorRect.new()
	horizontal.color = colour
	horizontal.size = Vector2(length, thickness)
	var vertical := ColorRect.new()
	vertical.color = colour
	vertical.size = Vector2(thickness, length)

	# corner: 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right
	var right := corner % 2 == 1
	var bottom := corner >= 2

	bracket.set_anchors_preset(Control.PRESET_FULL_RECT)
	horizontal.anchor_left = 1.0 if right else 0.0
	horizontal.anchor_right = horizontal.anchor_left
	horizontal.anchor_top = 1.0 if bottom else 0.0
	horizontal.anchor_bottom = horizontal.anchor_top
	horizontal.offset_left = -length if right else 0.0
	horizontal.offset_right = horizontal.offset_left + length
	horizontal.offset_top = -thickness if bottom else 0.0
	horizontal.offset_bottom = horizontal.offset_top + thickness

	vertical.anchor_left = horizontal.anchor_left
	vertical.anchor_right = vertical.anchor_left
	vertical.anchor_top = horizontal.anchor_top
	vertical.anchor_bottom = vertical.anchor_top
	vertical.offset_left = -thickness if right else 0.0
	vertical.offset_right = vertical.offset_left + thickness
	vertical.offset_top = -length if bottom else 0.0
	vertical.offset_bottom = vertical.offset_top + length

	bracket.add_child(horizontal)
	bracket.add_child(vertical)
	return bracket


static func _find_camera(node: Node) -> Camera3D:
	if node == null:
		return null
	if node is Camera3D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found != null:
			return found
	return null
