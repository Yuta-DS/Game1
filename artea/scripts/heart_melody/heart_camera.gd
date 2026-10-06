extends Camera3D
## Matches the shared SpringArm camera's sensitivity, pivot and zoom range.
## Sweep a volume, not a ray: near-plane corners must also clear scenery.
const MIN_PITCH := -1.18
const MAX_PITCH := 1.05
var yaw := 0.0
var pitch := -0.24
var distance := 9.2
var actual_distance := 9.2
var world: Node3D
var _yaw := 0.0
var _pitch := -0.24
var _touch := -1
var _web_drag := false
var _probe := SphereShape3D.new()

func _ready() -> void:
	world = get_parent()
	near = 0.12
	far = 650.0
	fov = 62
	_probe.radius = 0.32

func active() -> bool:
	return world.player != null and (not world.embedded_in_overworld or world.embedded_active)

func orbit(motion: Vector2) -> void:
	yaw = wrapf(yaw - motion.x, -PI, PI)
	pitch = clampf(pitch - motion.y, MIN_PITCH, MAX_PITCH)

func _unhandled_input(event: InputEvent) -> void:
	if not active(): return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_touch = -1
		_web_drag = false
	if world.modal_open: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: distance = maxf(4.8, distance - 0.7)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: distance = minf(9.2, distance + 0.7)
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if OS.has_feature("web"): _web_drag = event.pressed
			elif event.pressed: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or _web_drag):
		orbit(event.relative * 0.005)
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.5 and _touch < 0:
			_touch = event.index
		elif not event.pressed and event.index == _touch: _touch = -1
	if event is InputEventScreenDrag and event.index == _touch:
		orbit(event.relative * 0.005)

func update_camera(delta: float) -> void:
	if not active(): return
	if world.modal_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_touch = -1
		_web_drag = false
	else:
		var stick := Vector2.ZERO
		for device in Input.get_connected_joypads():
			stick = Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
			if stick.length() > 0.18:
				stick = stick.normalized() * clampf((stick.length() - 0.18) / 0.82, 0, 1)
				break
			stick = Vector2.ZERO
		# Arrows remain movement. I/J/K/L offer keyboard-only camera control.
		stick += Vector2(float(Input.is_physical_key_pressed(KEY_L)) - float(Input.is_physical_key_pressed(KEY_J)), float(Input.is_physical_key_pressed(KEY_K)) - float(Input.is_physical_key_pressed(KEY_I)))
		orbit(stick.limit_length() * delta * 1.8)
	var weight := 1.0 if world.reduced_motion else 1.0 - exp(-20.0 * delta)
	_yaw = lerp_angle(_yaw, yaw, weight)
	_pitch = lerpf(_pitch, pitch, weight)
	var pivot: Vector3 = world.player.global_position + Vector3.UP * 2.05
	var direction := Basis.from_euler(Vector3(_pitch, _yaw, 0)).z
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _probe
	query.transform = Transform3D(Basis.IDENTITY, pivot)
	query.motion = direction * distance
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [world.player.get_rid()]
	var fractions := world.get_world_3d().direct_space_state.cast_motion(query)
	var safe_distance := maxf(0.12, distance * fractions[0] - 0.12)
	# Immediate safety clamp prevents smoothing THROUGH a wall; release is damped.
	actual_distance = minf(safe_distance, lerpf(actual_distance, safe_distance, 1.0 - exp(-5.0 * delta)))
	# Recheck the final volume, including contact at the sweep's start. Small
	# offsets and fast camera turns must not leave a near-plane corner in scenery.
	query.motion = Vector3.ZERO
	query.transform.origin = pivot + direction * actual_distance
	for attempt in 32:
		if world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): break
		actual_distance = maxf(0.14, actual_distance - 0.25)
		query.transform.origin = pivot + direction * actual_distance
	global_position = pivot + direction * actual_distance
	look_at(pivot)
	var avatar: Node3D = world.player.get_node_or_null("FoxVisuals")
	if avatar != null: avatar.visible = actual_distance > 1.25

func _exit_tree() -> void:
	if is_instance_valid(world) and is_instance_valid(world.player):
		var avatar: Node3D = world.player.get_node_or_null("FoxVisuals")
		if avatar != null: avatar.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
