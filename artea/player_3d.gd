extends CharacterBody3D

const COMBAT_BALANCE_PATH := "res://resources/mind_spark/player_combat_balance.json"

signal health_changed(current: float, maximum: float)
signal focus_changed(current: float, maximum: float)
signal attack_started
signal block_changed(active: bool)
signal dodge_started
signal perfect_blocked
signal combo_changed(stage: int)

@export var speed: float = 10.0
@export var run_speed_multiplier := 1.55
@export var input_enabled: bool = true
@export var ground_acceleration := 70.0
@export var ground_deceleration := 85.0
@export var air_acceleration := 28.0

## Jump height in metres. Stair risers in the hub are 0.42 m, so this only has
## to clear obstacles the step logic cannot.
@export var jump_height: float = 1.4
@export var coyote_time := 0.14
@export var jump_buffer_time := 0.16
@export var max_health := 100.0
@export var attack_damage := 25.0
@export var attack_cooldown := 0.55
@export var attack_active_time := 0.18
@export var block_speed_multiplier := 0.38
@export var blocking_available := true
@export_group("Production combat")
@export var max_focus := 100.0
@export var focus_recovery_per_second := 18.0
@export var focus_recovery_delay := 0.7
@export var dodge_focus_cost := 25.0
@export var block_focus_cost_per_second := 15.0
@export var dodge_duration := 0.28
@export var dodge_invulnerability := 0.22
@export var dodge_speed := 18.0
@export var perfect_block_window := 0.18
@export var combo_window := 0.78
@export var charged_attack_damage_multiplier := 2.15
@export var aerial_attack_damage_multiplier := 1.45
## Enables the production touch HUD on devices that report touch support. Tests
## can force it without changing desktop presentation.
@export var force_touch_controls := false

## The camera the player moves relative to. When unset, the player falls back to
## the viewport's active camera, so the gallery, the hub and any other scene all
## work without needing this wired up by hand.
@export var camera_path: NodePath

# --- Visual & Animation Setup ---
@onready var animation_player: AnimationPlayer = get_node_or_null("FoxVisuals/Fox/AnimationPlayer") as AnimationPlayer
@onready var fox_visuals: Node3D = get_node_or_null("FoxVisuals") as Node3D

const RUNNING_SPEED_THRESHOLD = 0.1 # Minimum speed to trigger the running animation
const ROTATION_SPEED = 10.0 # Speed at which the fox model rotates (adjust as needed)

var _camera: Camera3D
var current_health := 100.0
var is_attacking := false
var is_blocking := false
var _attack_cooldown_remaining := 0.0
var _attack_active_remaining := 0.0
var _attack_area: Area3D
var _attack_collision: CollisionShape3D
var _attack_arc: MeshInstance3D
var _shield_visual: Node3D
var _combat_status: Label3D
var _combat_help_panel: ColorRect
var _combat_help_label: Label
var _input_hint_mode := "keyboard"
var _touch_hud: Control
var _touch_buttons: Dictionary = {}
var _touch_actions_held: Dictionary = {}
var _hit_targets: Dictionary = {}
var _coyote_remaining := 0.0
var _jump_buffer_remaining := 0.0
var _animation_state := "idle"
var _was_grounded := false
var _land_reaction_remaining := 0.0
var _hit_reaction_remaining := 0.0
var _visual_base_position := Vector3.ZERO
var _visual_base_scale := Vector3.ONE
var _train_seated_pose := false
var current_focus := 100.0
var is_dodging := false
var _dodge_remaining := 0.0
var _dodge_cooldown_remaining := 0.0
var _invulnerability_remaining := 0.0
var _dodge_direction := Vector3.ZERO
var _perfect_block_remaining := 0.0
var _counter_ready_remaining := 0.0
var _focus_recovery_delay_remaining := 0.0
var _combo_stage := 0
var _combo_window_remaining := 0.0
var _current_attack_damage := 25.0
var _current_attack_kind := "light"
var _equipment_attack_bonus := 0.0
var _equipment_guard_efficiency := 0.0
var _equipment_counter_bonus := 0.0
var _equipment_focus_bonus := 0.0
var _skill_effects: Dictionary = {}
var _health_bar: ProgressBar
var _focus_bar: ProgressBar
var _combo_label: Label
var _impact_particles: GPUParticles3D
var _combat_balance: Dictionary = {}
var _assist_panel: PanelContainer
var _assist_context := ""
var _input_before_assist := true


func _load_combat_balance() -> void:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(COMBAT_BALANCE_PATH)) != OK \
			or not parser.data is Dictionary:
		push_error("Player combat balance catalog could not be parsed")
		return
	_combat_balance = (parser.data as Dictionary).duplicate(true)
	var focus := _combat_balance.get("focus", {}) as Dictionary
	max_focus = maxf(1.0, float(focus.get("maximum", max_focus)))
	focus_recovery_per_second = maxf(0.0,
		float(focus.get("recovery_per_second", focus_recovery_per_second)))
	focus_recovery_delay = maxf(0.0, float(focus.get("recovery_delay", focus_recovery_delay)))
	dodge_focus_cost = clampf(float(focus.get("dodge_cost", dodge_focus_cost)), 0.0, max_focus)
	block_focus_cost_per_second = maxf(0.0,
		float(focus.get("block_cost_per_second", block_focus_cost_per_second)))
	var dodge := _combat_balance.get("dodge", {}) as Dictionary
	dodge_duration = maxf(0.05, float(dodge.get("duration", dodge_duration)))
	dodge_invulnerability = clampf(float(dodge.get("invulnerability", dodge_invulnerability)),
		0.0, dodge_duration)
	dodge_speed = maxf(1.0, float(dodge.get("speed", dodge_speed)))
	var attack := _combat_balance.get("attack", {}) as Dictionary
	combo_window = maxf(0.1, float(attack.get("combo_window", combo_window)))
	charged_attack_damage_multiplier = maxf(1.0,
		float(attack.get("charged_damage", charged_attack_damage_multiplier)))
	aerial_attack_damage_multiplier = maxf(1.0,
		float(attack.get("aerial_damage", aerial_attack_damage_multiplier)))
	var defense := _combat_balance.get("defense", {}) as Dictionary
	perfect_block_window = clampf(float(defense.get("perfect_block_window",
		perfect_block_window)), 0.05, 0.5)


func _ready() -> void:
	_load_combat_balance()
	# Stairs are built as a stack of boxes (see hub_castle_stairs.gd), so the
	# capsule catches on every riser edge unless the body is allowed to step up
	# over them. 0.6 m clears the 0.42 m risers with margin to spare.
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.6
	floor_stop_on_slope = true
	# Keeps the body glued to the treads on the way down instead of launching off
	# each step and re-entering the air state.
	floor_block_on_wall = true
	max_slides = 8
	safe_margin = 0.04

	if camera_path:
		_camera = get_node_or_null(camera_path) as Camera3D
	current_health = max_health
	current_focus = max_focus
	if fox_visuals != null:
		_visual_base_position = fox_visuals.position
		_visual_base_scale = fox_visuals.scale
	_build_combat_rig()
	_build_combat_help()
	_build_touch_controls()
	_bind_progression()
	_update_combat_hud()
	_update_character_animation(0.0, false)


func _exit_tree() -> void:
	_release_all_touch_actions()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_set_input_hint_mode("controller")
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.35:
		_set_input_hint_mode("controller")
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		# Some hybrid desktop browsers report touch hardware even while their
		# primary pointer is a mouse. Keep the wide desktop view clean initially,
		# then honour an actual touch immediately if capability detection was
		# inconclusive.
		if _touch_hud == null:
			_build_touch_controls(true)
		_set_input_hint_mode("touch")
	elif event is InputEventKey and event.pressed:
		_set_input_hint_mode("keyboard")
	elif event is InputEventMouseButton and event.pressed:
		_set_input_hint_mode("keyboard")


func set_input_enabled(v: bool) -> void:
	input_enabled = v
	if _touch_hud != null:
		_touch_hud.visible = v
	if not v:
		_release_all_touch_actions()
		_set_blocking(false)
		_finish_attack()
		is_dodging = false
		_dodge_remaining = 0.0
		_jump_buffer_remaining = 0.0
		velocity.x = 0.0
		velocity.z = 0.0


func set_train_seated_pose(enabled: bool) -> void:
	_train_seated_pose = enabled
	velocity = Vector3.ZERO
	_update_character_animation(0.0, false)


func is_train_seated_pose() -> bool:
	return _train_seated_pose


# The active camera can be swapped at runtime (the gallery tweens between a
# follow camera and an inspect camera), so this is resolved per frame rather
# than cached once.
func _active_camera() -> Camera3D:
	if _camera and _camera.is_inside_tree():
		return _camera
	return get_viewport().get_camera_3d()


func get_camera_relative_move_direction(input_dir: Vector2) -> Vector3:
	if input_dir.is_zero_approx():
		return Vector3.ZERO
	# Input.get_vector() has already applied the InputMap's circular deadzone and
	# returns a useful 0..1 stick magnitude. Preserve it so a slight analog tilt
	# walks gently instead of snapping to full speed. Keyboard and D-pad vectors
	# still arrive at unit strength, including normalized diagonals.
	var input_strength := minf(input_dir.length(), 1.0)
	var normalized_input := input_dir.normalized()
	var camera := _active_camera()
	if camera:
		var basis := camera.global_transform.basis
		var camera_forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
		var camera_right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
		return (camera_right * normalized_input.x \
			+ camera_forward * -normalized_input.y).normalized() * input_strength
	return Vector3(normalized_input.x, 0.0, normalized_input.y) * input_strength


func _physics_process(delta: float) -> void:
	# The railway owns the seated transform. Sliding against its moving hull
	# displaces the rider between render frames and jolts the follow camera.
	if _train_seated_pose:
		velocity = Vector3.ZERO
		_update_character_animation(delta, false)
		return

	_update_combat(delta)
	var was_grounded := is_on_floor()
	_hit_reaction_remaining = maxf(0.0, _hit_reaction_remaining - delta)
	_land_reaction_remaining = maxf(0.0, _land_reaction_remaining - delta)
	if was_grounded:
		_coyote_remaining = coyote_time
	else:
		_coyote_remaining = maxf(0.0, _coyote_remaining - delta)
	if input_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer_remaining = jump_buffer_time
	else:
		_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)

	# Gravity always runs. Without it move_and_slide() has no downward force to
	# resolve steps against, which is why the stair could not be climbed.
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	# Disable movement if input is locked (e.g. inspecting a painting). Gravity
	# still applies so a locked player cannot hang in mid-air.
	if not input_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()

		_update_character_animation(delta, false)
		_was_grounded = is_on_floor()
		return

	# Godot's canonical four-action vector: W=-Y, S=+Y, A=-X, D=+X.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	# Convert 2D input to a 3D direction in the camera's frame, so "forward" is
	# wherever the player is looking. Previously this used the raw input axes,
	# which meant W always pushed toward world -Z no matter where the view was
	# pointing.
	var move_dir := get_camera_relative_move_direction(input_dir)

	# Apply velocity based on input and speed
	var movement_multiplier := get_input_speed_multiplier()
	if is_attacking:
		movement_multiplier *= 0.28
	var target_velocity := Vector2(move_dir.x, move_dir.z) * speed * movement_multiplier
	if is_dodging:
		target_velocity = Vector2(_dodge_direction.x, _dodge_direction.z) * dodge_speed
	var horizontal := Vector2(velocity.x, velocity.z)
	var acceleration := air_acceleration
	if was_grounded:
		acceleration = ground_acceleration if not target_velocity.is_zero_approx() else ground_deceleration
	horizontal = horizontal.move_toward(target_velocity, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	if _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0 \
			and not is_attacking and not is_blocking:
		velocity.y = sqrt(2.0 * jump_height * absf(get_gravity().y))
		_jump_buffer_remaining = 0.0
		_coyote_remaining = 0.0
		_show_status("JUMP", Color("bdefff"))

	# --- ANIMATION AND ROTATION LOGIC ---
	var current_movement_length = Vector2(velocity.x, velocity.z).length()

	if current_movement_length > RUNNING_SPEED_THRESHOLD and fox_visuals != null:
		# Velocity is world-space, while FoxVisuals.rotation is local to a player
		# root that can itself be rotated. Converting the desired world yaw fixes
		# the 180-degree reversed-facing bug in the Art Gallery scene.
		var world_target_yaw := atan2(velocity.x, velocity.z)
		var local_target_yaw := wrapf(world_target_yaw - global_rotation.y, -PI, PI)
		fox_visuals.rotation.y = rotate_toward(
			fox_visuals.rotation.y, local_target_yaw, ROTATION_SPEED * delta)

	move_and_slide()
	if is_on_floor() and not was_grounded:
		_land_reaction_remaining = 0.16
	_update_character_animation(delta, current_movement_length > RUNNING_SPEED_THRESHOLD)
	_was_grounded = is_on_floor()


func get_input_speed_multiplier() -> float:
	if is_blocking:
		return block_speed_multiplier
	return run_speed_multiplier if Input.is_action_pressed("run") else 1.0


func _update_combat(delta: float) -> void:
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	_dodge_cooldown_remaining = maxf(0.0, _dodge_cooldown_remaining - delta)
	_invulnerability_remaining = maxf(0.0, _invulnerability_remaining - delta)
	_perfect_block_remaining = maxf(0.0, _perfect_block_remaining - delta)
	_counter_ready_remaining = maxf(0.0, _counter_ready_remaining - delta)
	_combo_window_remaining = maxf(0.0, _combo_window_remaining - delta)
	_focus_recovery_delay_remaining = maxf(0.0, _focus_recovery_delay_remaining - delta)
	if _combo_window_remaining <= 0.0 and not is_attacking and _combo_stage != 0:
		_combo_stage = 0
		combo_changed.emit(_combo_stage)

	if not input_enabled:
		_set_blocking(false)
		_finish_attack()
		return

	if is_dodging:
		_dodge_remaining -= delta
		if _dodge_remaining <= 0.0:
			is_dodging = false
			_show_status("", Color.WHITE)
	else:
		if Input.is_action_just_pressed("dodge"):
			_start_dodge()
		if not is_dodging:
			_update_block(delta)
			if Input.is_action_just_pressed("charged_attack") and not is_blocking \
					and _attack_cooldown_remaining <= 0.0:
				_start_attack("charged")
			elif Input.is_action_just_pressed("attack") and not is_blocking \
					and _attack_cooldown_remaining <= 0.0:
				_start_attack("aerial" if not is_on_floor() else "light")

	if not is_blocking and not is_dodging and _focus_recovery_delay_remaining <= 0.0 \
			and current_focus < max_focus:
		var recovery := focus_recovery_per_second * (1.0 + _equipment_focus_bonus \
			+ float(_skill_effects.get("focus_recovery", 0.0)))
		_set_focus(current_focus + recovery * delta)

	if not is_attacking:
		return
	_attack_active_remaining -= delta
	if _attack_arc != null:
		_attack_arc.rotation.z += delta * (15.0 if _current_attack_kind == "charged" else 12.0)
	if _attack_active_remaining > 0.0:
		_apply_attack_hits()
	else:
		_finish_attack()


func _update_block(delta: float) -> void:
	var wants_block := Input.is_action_pressed("block") and not is_attacking
	if wants_block and current_focus > 0.0:
		_set_blocking(true)
		var efficiency := clampf(_equipment_guard_efficiency \
			+ float(_skill_effects.get("guard_cost", 0.0)), 0.0, 0.65)
		_spend_focus(block_focus_cost_per_second * (1.0 - efficiency) * delta)
		if current_focus <= 0.0:
			_set_blocking(false)
	else:
		_set_blocking(false)


func _start_dodge() -> bool:
	if is_attacking or is_blocking or is_dodging or _dodge_cooldown_remaining > 0.0 \
			or current_focus < dodge_focus_cost:
		return false
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	_dodge_direction = get_camera_relative_move_direction(input_dir)
	if _dodge_direction.length_squared() < 0.01:
		var visual_forward := fox_visuals.global_basis.z if fox_visuals != null else global_basis.z
		_dodge_direction = Vector3(visual_forward.x, 0.0, visual_forward.z).normalized()
	_spend_focus(dodge_focus_cost)
	is_dodging = true
	_dodge_remaining = dodge_duration * (1.0 + float(_skill_effects.get("dodge_distance", 0.0)))
	_dodge_cooldown_remaining = float((_combat_balance.get("dodge", {}) as Dictionary).get(
		"cooldown", 0.42))
	_invulnerability_remaining = dodge_invulnerability
	_finish_attack()
	_show_status("DODGE", Color("8eefff"))
	dodge_started.emit()
	return true


func _start_attack(kind := "light") -> void:
	is_attacking = true
	_current_attack_kind = str(kind)
	var damage_multiplier := 1.0
	match _current_attack_kind:
		"charged":
			_combo_stage = 0
			damage_multiplier = charged_attack_damage_multiplier
			_attack_cooldown_remaining = attack_cooldown * 1.55
			_attack_active_remaining = attack_active_time * 1.55
		"aerial":
			_combo_stage = 0
			damage_multiplier = aerial_attack_damage_multiplier \
				* (1.0 + float(_skill_effects.get("aerial_damage", 0.0)))
			_attack_cooldown_remaining = attack_cooldown * 1.15
			_attack_active_remaining = attack_active_time * 1.25
			velocity.y = minf(velocity.y, -4.0)
		_:
			_combo_stage = _combo_stage + 1 if _combo_window_remaining > 0.0 else 1
			_combo_stage = clampi(_combo_stage, 1, 3)
			var attack_config := _combat_balance.get("attack", {}) as Dictionary
			var damage_steps := attack_config.get("combo_damage", [0.82, 1.0, 1.38]) as Array
			var cooldown_steps := attack_config.get("combo_cooldown", [0.72, 0.76, 1.0]) as Array
			var active_steps := attack_config.get("combo_active_time", [0.85, 0.95, 1.2]) as Array
			damage_multiplier = float(damage_steps[_combo_stage - 1])
			_attack_cooldown_remaining = attack_cooldown * float(cooldown_steps[_combo_stage - 1])
			_attack_active_remaining = attack_active_time * float(active_steps[_combo_stage - 1])
			_combo_window_remaining = combo_window
			combo_changed.emit(_combo_stage)
	var counter_multiplier := 1.0
	var used_counter := false
	if _counter_ready_remaining > 0.0:
		used_counter = true
		counter_multiplier = float((_combat_balance.get("attack", {}) as Dictionary).get(
			"counter_damage", 1.6)) + _equipment_counter_bonus \
			+ float(_skill_effects.get("counter_damage", 0.0))
		_counter_ready_remaining = 0.0
		_show_status("COUNTER!", Color("fff19a"))
	_current_attack_damage = (attack_damage + _equipment_attack_bonus) \
		* damage_multiplier * counter_multiplier
	_hit_targets.clear()
	if _attack_collision != null:
		_attack_collision.disabled = false
	if _attack_arc != null:
		_attack_arc.visible = true
	_play_first_available(["Attack", "attack", "Attack1", "SwordAttack", "Idle"])
	if _current_attack_kind == "charged":
		_show_status("CHARGED STRIKE", Color("ffe58a"))
	elif _current_attack_kind == "aerial":
		_show_status("FALLING STRIKE", Color("a8efff"))
	elif not used_counter:
		_show_status("COMBO %d" % _combo_stage, Color("ffd36e"))
	_update_combat_hud()
	attack_started.emit()


func _finish_attack() -> void:
	if not is_attacking:
		return
	is_attacking = false
	_attack_active_remaining = 0.0
	if _attack_collision != null:
		_attack_collision.disabled = true
	if _attack_arc != null:
		_attack_arc.visible = false


func _apply_attack_hits() -> void:
	if _attack_area == null:
		return
	for body in _attack_area.get_overlapping_bodies():
		if body == self or _hit_targets.has(body):
			continue
		if body.has_method("take_damage"):
			var applied := float(body.call("take_damage", _current_attack_damage, self))
			if applied > 0.0:
				_apply_impact_feedback(body)
			_hit_targets[body] = true
	for area in _attack_area.get_overlapping_areas():
		if _hit_targets.has(area):
			continue
		var target := _find_damage_receiver(area)
		if target != null and target != self and target.has_method("take_damage"):
			var applied := float(target.call("take_damage", _current_attack_damage, self))
			if applied > 0.0:
				_apply_impact_feedback(target)
			_hit_targets[area] = true


func _find_damage_receiver(node: Node) -> Node:
	var current := node
	for _depth in 5:
		if current == null:
			return null
		if current.has_method("take_damage"):
			return current
		current = current.get_parent()
	return null


func _set_blocking(active: bool) -> void:
	active = active and blocking_available
	if is_blocking == active:
		return
	is_blocking = active
	if active:
		_perfect_block_remaining = perfect_block_window \
			+ float(_skill_effects.get("perfect_block_window", 0.0))
	if _shield_visual != null:
		_shield_visual.visible = active
	_show_status("SHIELD" if active else "", Color("79e8ff"))
	block_changed.emit(active)


func get_animation_state() -> String:
	return _animation_state


func get_available_character_animations() -> PackedStringArray:
	if animation_player == null:
		return PackedStringArray()
	return animation_player.get_animation_list()


func _update_character_animation(delta: float, moving: bool) -> void:
	if fox_visuals == null:
		_animation_state = "train_seated" if _train_seated_pose else _animation_state
		return
	fox_visuals.position = _visual_base_position
	fox_visuals.scale = _visual_base_scale
	fox_visuals.rotation.x = 0.0
	fox_visuals.rotation.z = 0.0
	if _train_seated_pose:
		# The fox asset has no authored sitting clip. Keep its calm Idle motion,
		# lower the hips onto the cushion and compress the leg silhouette into a
		# stable seated driving posture instead of leaving it standing in the cab.
		_animation_state = "train_seated"
		_play_character_clip(["Idle"], 0.72)
		fox_visuals.position += Vector3(0.0, -0.72, 0.10)
		fox_visuals.scale = _visual_base_scale * Vector3(1.02, 0.72, 1.02)
		fox_visuals.rotation.x = -0.08
		fox_visuals.rotation.y = PI
		return
	if current_health <= 0.0:
		_animation_state = "defeated"
		_play_character_clip(["Death", "Defeat", "Idle"], 0.55)
		fox_visuals.rotation.z = lerpf(fox_visuals.rotation.z, -PI * 0.5, minf(1.0, delta * 8.0))
		return
	if _hit_reaction_remaining > 0.0:
		_animation_state = "hurt"
		_play_character_clip(["Hit", "Hurt", "Idle"], 1.2)
		fox_visuals.rotation.z = sin(_hit_reaction_remaining * 55.0) * 0.13
		return
	if is_attacking:
		_animation_state = "attack"
		_play_character_clip(["Attack", "SwordAttack", "Run"], 1.55)
		var attack_phase := 1.0 - clampf(_attack_active_remaining / maxf(attack_active_time, 0.01), 0.0, 1.0)
		fox_visuals.rotation.z = sin(attack_phase * PI) * -0.32
		return
	if is_blocking:
		_animation_state = "block"
		_play_character_clip(["Block", "Idle"], 0.72)
		fox_visuals.position.y -= 0.12
		fox_visuals.scale = _visual_base_scale * Vector3(1.04, 0.92, 1.04)
		return
	if not is_on_floor():
		if velocity.y > 0.0:
			_animation_state = "jump"
			_play_character_clip(["Jump", "Run"], 1.05)
		else:
			_animation_state = "fall"
			_play_character_clip(["Fall", "Jump"], 0.65)
			fox_visuals.rotation.z = 0.06
		return
	if _land_reaction_remaining > 0.0:
		_animation_state = "land"
		_play_character_clip(["Land", "Jump", "Idle"], 1.45)
		fox_visuals.scale = _visual_base_scale * Vector3(1.06, 0.88, 1.06)
		return
	if moving:
		_animation_state = "run"
		_play_character_clip(["Run", "Walk"], 1.0)
	else:
		_animation_state = "idle"
		_play_character_clip(["Idle"], 1.0)


func _play_character_clip(candidates: Array[String], speed_scale: float) -> void:
	if animation_player == null:
		return
	animation_player.speed_scale = speed_scale
	for candidate in candidates:
		if animation_player.has_animation(candidate):
			if animation_player.current_animation != candidate or not animation_player.is_playing():
				animation_player.play(candidate, 0.10)
			return


# Shared damage contract for enemies, hazards and projectiles. Dodge immunity,
# perfect-block timing, equipment and optional assistance all resolve here so
# every encounter uses one authoritative rule set.
func take_damage(amount: float, _source: Node = null) -> float:
	if amount <= 0.0:
		return 0.0
	if _invulnerability_remaining > 0.0:
		_show_status("EVADE", Color("8eefff"))
		return 0.0
	if is_blocking:
		if _perfect_block_remaining > 0.0:
			var defense := _combat_balance.get("defense", {}) as Dictionary
			_counter_ready_remaining = float(defense.get("counter_window", 1.25))
			_set_focus(current_focus + float(defense.get("perfect_block_focus_refund", 8.0)))
			_show_status("PERFECT • COUNTER READY", Color("fff19a"))
			perfect_blocked.emit()
			Input.start_joy_vibration(0, 0.22, 0.34, 0.09)
		else:
			_show_status("BLOCKED", Color("79e8ff"))
		return 0.0
	var progression := get_node_or_null("/root/WorldOneProgression")
	if progression != null:
		var settings: Dictionary = progression.get("assist_settings")
		amount *= float(settings.get("incoming_damage_multiplier", 1.0))
	var applied := minf(amount, current_health)
	current_health = maxf(0.0, current_health - applied)
	_hit_reaction_remaining = 0.32
	_show_status("-%d HP" % int(applied), Color("ff786f"))
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0 and progression != null \
			and progression.has_method("record_failed_attempt"):
		progression.call("record_failed_attempt", "world_one.combat")
	_update_combat_hud()
	return applied


func heal(amount: float) -> void:
	current_health = clampf(current_health + maxf(amount, 0.0), 0.0, max_health)
	health_changed.emit(current_health, max_health)
	_update_combat_hud()


func _spend_focus(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current_focus + 0.001 < amount:
		_set_focus(0.0)
		_focus_recovery_delay_remaining = focus_recovery_delay
		return false
	_set_focus(current_focus - amount)
	_focus_recovery_delay_remaining = focus_recovery_delay
	return true


func _set_focus(value: float) -> void:
	var next := clampf(value, 0.0, max_focus)
	if is_equal_approx(next, current_focus):
		return
	current_focus = next
	focus_changed.emit(current_focus, max_focus)
	_update_combat_hud()


func _apply_impact_feedback(target: Node) -> void:
	if target.has_method("receive_knockback") and target is Node3D:
		var target_3d := target as Node3D
		var direction: Vector3 = (target_3d.global_position - global_position).normalized()
		target.call("receive_knockback", direction,
			8.5 if _current_attack_kind == "charged" else 4.5)
	if _impact_particles != null:
		_impact_particles.restart()
	Input.start_joy_vibration(0, 0.18, 0.28 if _current_attack_kind == "charged" else 0.18, 0.07)
	var camera := _active_camera()
	if camera != null and not bool(ProjectSettings.get_setting(
			"accessibility/reduced_camera_shake", false)):
		var original := camera.h_offset
		camera.h_offset = original + (0.06 if _current_attack_kind == "charged" else 0.035)
		var tween := create_tween()
		tween.tween_property(camera, "h_offset", original, 0.11)


func _bind_progression() -> void:
	var progression := get_node_or_null("/root/WorldOneProgression")
	if progression == null:
		return
	var loadout_callable := Callable(self, "_on_progression_loadout_changed")
	var skill_callable := Callable(self, "_on_progression_skill_changed")
	var assist_callable := Callable(self, "_on_assistance_suggested")
	if not progression.is_connected("equipment_changed", loadout_callable):
		progression.connect("equipment_changed", loadout_callable)
	if not progression.is_connected("skill_unlocked", skill_callable):
		progression.connect("skill_unlocked", skill_callable)
	if not progression.is_connected("assistance_suggested", assist_callable):
		progression.connect("assistance_suggested", assist_callable)
	_apply_progression_effects()


func _on_progression_loadout_changed(_slot: String, _item_id: String) -> void:
	_apply_progression_effects()


func _on_progression_skill_changed(_skill_id: String) -> void:
	_apply_progression_effects()


func _on_assistance_suggested(context_id: String, _failures: int) -> void:
	_assist_context = context_id
	if _assist_panel != null:
		_input_before_assist = input_enabled
		set_input_enabled(false)
		_assist_panel.visible = true
		var enable := _assist_panel.get_node("Body/Actions/Enable") as Button
		enable.grab_focus()


func _enable_adaptive_assistance() -> void:
	var progression := get_node_or_null("/root/WorldOneProgression")
	if progression != null:
		progression.call("set_assistance", true)
	if _assist_panel != null:
		_assist_panel.visible = false
	set_input_enabled(_input_before_assist)
	_show_status("ASSISTANCE ON • REWARDS UNCHANGED", Color("9ef3c0"))


func _dismiss_assistance_prompt() -> void:
	if _assist_panel != null:
		_assist_panel.visible = false
	set_input_enabled(_input_before_assist)


func _apply_progression_effects() -> void:
	var progression := get_node_or_null("/root/WorldOneProgression")
	if progression == null:
		return
	_equipment_attack_bonus = 0.0
	_equipment_guard_efficiency = 0.0
	_equipment_counter_bonus = 0.0
	_equipment_focus_bonus = 0.0
	var health_bonus := 0.0
	var equipped: Dictionary = progression.get("equipped")
	for slot in equipped:
		var item_id := str(equipped[slot])
		if item_id.is_empty():
			continue
		var definition: Dictionary = progression.call("get_item_definition", item_id)
		var stats := definition.get("stats", {}) as Dictionary
		_equipment_attack_bonus += float(stats.get("attack", 0.0))
		_equipment_guard_efficiency += float(stats.get("guard", 0.0)) / 100.0
		_equipment_counter_bonus += float(stats.get("counter", 0.0)) / 100.0
		_equipment_focus_bonus += float(stats.get("focus_recovery", 0.0)) / 100.0
		health_bonus += float(stats.get("health", 0.0))
	_skill_effects.clear()
	for skill_id in progression.get("unlocked_skills"):
		var skill: Dictionary = progression.call("get_skill_definition", str(skill_id))
		var effect := skill.get("effect", {}) as Dictionary
		for key in effect:
			_skill_effects[key] = float(_skill_effects.get(key, 0.0)) + float(effect[key])
	var old_max := max_health
	max_health = 100.0 + health_bonus + float(_skill_effects.get("health", 0.0))
	if old_max > 0.0:
		current_health = clampf(current_health + (max_health - old_max), 0.0, max_health)
	health_changed.emit(current_health, max_health)
	_update_combat_hud()


func _play_first_available(candidates: Array[String]) -> void:
	if animation_player == null:
		return
	for candidate in candidates:
		if animation_player.has_animation(candidate):
			animation_player.play(candidate)
			return


func _build_combat_rig() -> void:
	var rig_parent: Node3D = fox_visuals if fox_visuals != null else self

	_attack_area = Area3D.new()
	_attack_area.name = "AttackHitbox"
	_attack_area.position = Vector3(0.0, 1.1, 2.5)
	_attack_area.collision_layer = 0
	_attack_area.collision_mask = 1
	_attack_area.monitoring = true
	_attack_collision = CollisionShape3D.new()
	_attack_collision.name = "CollisionShape3D"
	var attack_shape := BoxShape3D.new()
	attack_shape.size = Vector3(3.6, 2.4, 3.5)
	_attack_collision.shape = attack_shape
	_attack_collision.disabled = true
	_attack_area.add_child(_attack_collision)
	rig_parent.add_child(_attack_area)

	_attack_arc = MeshInstance3D.new()
	_attack_arc.name = "AttackArc"
	var arc_mesh := TorusMesh.new()
	arc_mesh.inner_radius = 1.25
	arc_mesh.outer_radius = 1.48
	arc_mesh.rings = 20
	arc_mesh.ring_segments = 5
	_attack_arc.mesh = arc_mesh
	_attack_arc.position = Vector3(0.0, 1.15, 2.8)
	_attack_arc.rotation_degrees.x = 90.0
	_attack_arc.scale = Vector3(1.0, 0.45, 1.0)
	_attack_arc.material_override = _combat_material(Color("ffd164"), 1.5)
	_attack_arc.visible = false
	rig_parent.add_child(_attack_arc)

	_shield_visual = Node3D.new()
	_shield_visual.name = "ShieldBlock"
	_shield_visual.position = Vector3(0.0, 1.25, 1.55)
	var shield := MeshInstance3D.new()
	shield.name = "ShieldDisc"
	var shield_mesh := CylinderMesh.new()
	shield_mesh.top_radius = 0.82
	shield_mesh.bottom_radius = 0.82
	shield_mesh.height = 0.16
	shield_mesh.radial_segments = 12
	shield.mesh = shield_mesh
	shield.rotation_degrees.x = 90.0
	shield.material_override = _combat_material(Color("49dff0"), 1.2)
	_shield_visual.add_child(shield)
	var rune := MeshInstance3D.new()
	rune.name = "ShieldRune"
	var rune_mesh := TorusMesh.new()
	rune_mesh.inner_radius = 0.42
	rune_mesh.outer_radius = 0.55
	rune_mesh.rings = 16
	rune_mesh.ring_segments = 4
	rune.mesh = rune_mesh
	rune.position.z = 0.12
	rune.rotation_degrees.x = 90.0
	rune.material_override = _combat_material(Color("f8dc72"), 1.5)
	_shield_visual.add_child(rune)
	_shield_visual.visible = false
	rig_parent.add_child(_shield_visual)

	_combat_status = Label3D.new()
	_combat_status.name = "CombatStatus"
	_combat_status.position = Vector3(0.0, 3.8, 0.0)
	_combat_status.font_size = 28
	_combat_status.outline_size = 8
	_combat_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_combat_status.no_depth_test = true
	_combat_status.visible = false
	add_child(_combat_status)

	_impact_particles = GPUParticles3D.new()
	_impact_particles.name = "ImpactParticles"
	_impact_particles.amount = 12
	_impact_particles.lifetime = 0.34
	_impact_particles.one_shot = true
	_impact_particles.explosiveness = 0.92
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.055
	particle_mesh.height = 0.11
	particle_mesh.radial_segments = 6
	particle_mesh.rings = 3
	particle_mesh.material = _combat_material(Color("80ecff"), 1.2)
	_impact_particles.draw_pass_1 = particle_mesh
	var particle_process := ParticleProcessMaterial.new()
	particle_process.direction = Vector3(0.0, 1.0, 0.0)
	particle_process.spread = 80.0
	particle_process.initial_velocity_min = 3.5
	particle_process.initial_velocity_max = 7.0
	particle_process.gravity = Vector3(0.0, -9.0, 0.0)
	_impact_particles.process_material = particle_process
	_impact_particles.position = Vector3(0.0, 1.15, 2.8)
	rig_parent.add_child(_impact_particles)


func _build_combat_help() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CombatHelpHUD"
	add_child(layer)
	var vitals := PanelContainer.new()
	vitals.name = "CombatVitals"
	vitals.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.position = Vector2(22.0, -154.0)
	vitals.size = Vector2(276.0, 84.0)
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vitals_body := VBoxContainer.new()
	vitals_body.name = "Bars"
	vitals_body.add_theme_constant_override("separation", 4)
	vitals.add_child(vitals_body)
	_health_bar = _combat_bar("HEALTH", Color("e86d73"))
	_focus_bar = _combat_bar("FOCUS", Color("58ddec"))
	vitals_body.add_child(_health_bar)
	vitals_body.add_child(_focus_bar)
	_combo_label = Label.new()
	_combo_label.text = "COMBO READY"
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.add_theme_font_size_override("font_size", 12)
	_combo_label.modulate = Color("ffe28a")
	vitals_body.add_child(_combo_label)
	layer.add_child(vitals)
	_build_assistance_prompt(layer)
	_combat_help_panel = ColorRect.new()
	_combat_help_panel.name = "CombatHelpPanel"
	_combat_help_panel.color = Color(0.04, 0.04, 0.12, 0.72)
	_combat_help_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_combat_help_panel.position = Vector2(22.0, -74.0)
	_combat_help_panel.size = Vector2(510.0, 50.0)
	layer.add_child(_combat_help_panel)
	_combat_help_label = Label.new()
	_combat_help_label.name = "CombatHelpLabel"
	_combat_help_label.position = Vector2(14.0, 13.0)
	_combat_help_label.add_theme_font_size_override("font_size", 17)
	_combat_help_label.modulate = Color("f3ecff")
	_combat_help_panel.add_child(_combat_help_label)
	_set_input_hint_mode("touch" if _touch_controls_requested() else "keyboard")
	get_viewport().size_changed.connect(func():
		if _combat_help_panel != null:
			_layout_combat_help(get_viewport().get_visible_rect().size))


func _build_assistance_prompt(layer: CanvasLayer) -> void:
	_assist_panel = PanelContainer.new()
	_assist_panel.name = "AdaptiveAssistancePrompt"
	_assist_panel.set_anchors_preset(Control.PRESET_CENTER)
	_assist_panel.position = Vector2(-250.0, -120.0)
	_assist_panel.size = Vector2(500.0, 240.0)
	_assist_panel.visible = false
	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 12)
	_assist_panel.add_child(body)
	var title := Label.new()
	title.text = "TRY ADAPTIVE ASSISTANCE?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color("8eefff")
	body.add_child(title)
	var detail := Label.new()
	detail.text = "Telegraphs last 25% longer and incoming damage is 15% lower.\nStory rewards, equipment, XP and identity evidence stay unchanged."
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 16)
	body.add_child(detail)
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(actions)
	var enable := Button.new()
	enable.name = "Enable"
	enable.text = "ENABLE ASSISTANCE"
	enable.custom_minimum_size = Vector2(210.0, 46.0)
	enable.pressed.connect(_enable_adaptive_assistance)
	actions.add_child(enable)
	var standard := Button.new()
	standard.name = "Standard"
	standard.text = "KEEP STANDARD"
	standard.custom_minimum_size = Vector2(180.0, 46.0)
	standard.pressed.connect(_dismiss_assistance_prompt)
	actions.add_child(standard)
	layer.add_child(_assist_panel)


func _combat_bar(caption: String, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = caption.capitalize() + "Bar"
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = true
	bar.custom_minimum_size = Vector2(260.0, 22.0)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.015, 0.03, 0.06, 0.9)
	background.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	bar.tooltip_text = caption
	return bar


func _update_combat_hud() -> void:
	if _health_bar != null:
		_health_bar.max_value = max_health
		_health_bar.value = current_health
	if _focus_bar != null:
		_focus_bar.max_value = max_focus
		_focus_bar.value = current_focus
	if _combo_label != null:
		if _counter_ready_remaining > 0.0:
			_combo_label.text = "PERFECT COUNTER READY"
		elif _combo_stage > 0 and _combo_window_remaining > 0.0:
			_combo_label.text = "LIGHT COMBO  %d / 3" % _combo_stage
		else:
			_combo_label.text = "COMBO READY"


func _set_input_hint_mode(mode: String) -> void:
	if mode not in ["keyboard", "controller", "touch"]:
		return
	_input_hint_mode = mode
	if _combat_help_label == null or _combat_help_panel == null:
		return
	_layout_combat_help(get_viewport().get_visible_rect().size)


func _layout_combat_help(viewport_size: Vector2) -> void:
	if _combat_help_label == null or _combat_help_panel == null:
		return
	var compact := viewport_size.x < 700.0
	match _input_hint_mode:
		"controller":
			_combat_help_label.text = "LS MOVE  A JUMP  X COMBO  B DODGE" if compact \
				else "LEFT STICK MOVE   A JUMP   X COMBO   RB CHARGE   B DODGE   HOLD LB BLOCK"
		"touch":
			_combat_help_label.text = "MOVE  JUMP  COMBO  DODGE  BLOCK" if compact \
				else "TOUCH MOVE   JUMP   COMBO   CHARGE   DODGE   BLOCK   TALK"
		_:
			_combat_help_label.text = "WASD  SPACE JUMP  F COMBO  C DODGE" if compact \
				else "WASD MOVE   SPACE JUMP   F COMBO   R CHARGE   C DODGE   HOLD G BLOCK"
	_combat_help_panel.position = Vector2(12.0 if compact else 22.0,
		-146.0 if _input_hint_mode == "touch" else -62.0)
	_combat_help_panel.size = Vector2(
		maxf(220.0, viewport_size.x - 24.0) if compact else 610.0,
		38.0 if compact else 50.0)
	_combat_help_label.position = Vector2(9.0 if compact else 14.0,
		8.0 if compact else 13.0)
	_combat_help_label.add_theme_font_size_override("font_size", 13 if compact else 17)


func get_input_hint_mode() -> String:
	return _input_hint_mode


func _touch_controls_requested() -> bool:
	if force_touch_controls:
		return true
	if not DisplayServer.is_touchscreen_available():
		return false
	if not OS.has_feature("web"):
		return true
	var encoded := str(JavaScriptBridge.eval(
		"JSON.stringify([window.matchMedia && window.matchMedia('(pointer: coarse)').matches, navigator.maxTouchPoints || 0, window.innerWidth || 0])",
		true))
	if not encoded.begins_with("["):
		# A Web-feature headless smoke has no DOM. Preserve DisplayServer's answer
		# there; it never becomes player-facing UI.
		return true
	var decoded: Variant = JSON.parse_string(encoded)
	if decoded is not Array or decoded.size() < 3:
		return true
	return _web_touch_interface_likely(bool(decoded[0]), int(decoded[1]),
		float(decoded[2]))


func _web_touch_interface_likely(coarse_pointer: bool, max_touch_points: int,
		physical_width: float) -> bool:
	# Coarse primary pointers are phones/tablets. A narrow hybrid device may
	# expose a fine pointer and touch points together, so retain its controls.
	# Wide fine-pointer laptops reveal the HUD on their first real touch instead
	# of covering the game for mouse and keyboard users.
	return coarse_pointer or (max_touch_points > 0 and physical_width > 0.0 \
		and physical_width <= 1024.0)


func _build_touch_controls(from_touch_event := false) -> void:
	if _touch_hud != null:
		return
	if not from_touch_event and not _touch_controls_requested():
		return
	var layer := CanvasLayer.new()
	layer.name = "TouchControlHUD"
	layer.layer = 35
	add_child(layer)
	_touch_hud = Control.new()
	_touch_hud.name = "TouchControls"
	_touch_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_touch_hud)

	# Use short ASCII labels rather than triangle glyphs. The Web fallback font
	# used by some phones renders those symbols as indistinct boxed characters.
	_add_touch_button("Up", "UP", "move_forward")
	_add_touch_button("Left", "LEFT", "move_left")
	_add_touch_button("Down", "DOWN", "move_backward")
	_add_touch_button("Right", "RIGHT", "move_right")
	_add_touch_button("Jump", "JUMP", "jump")
	_add_touch_button("Attack", "COMBO", "attack")
	_add_touch_button("Charged", "CHARGE", "charged_attack")
	_add_touch_button("Dodge", "DODGE", "dodge")
	_add_touch_button("Block", "HOLD\nSHIELD", "block")
	_add_touch_button("Interact", "TALK", "interact")
	_layout_touch_controls(get_viewport().get_visible_rect().size)
	get_viewport().size_changed.connect(func():
		if _touch_hud != null:
			_layout_touch_controls(get_viewport().get_visible_rect().size))


func _add_touch_button(node_name: String, caption: String, action: StringName) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.clip_text = true
	button.custom_minimum_size = Vector2(52.0, 52.0)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.045, 0.11, 0.78)
	normal.border_color = Color("55dce8")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(14)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.18, 0.55, 0.66, 0.92)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.button_down.connect(func():
		_press_touch_action(action)
		if action == &"interact":
			_press_touch_action(&"talk_to_milo"))
	button.button_up.connect(func():
		_release_touch_action(action)
		if action == &"interact":
			_release_touch_action(&"talk_to_milo"))
	_touch_hud.add_child(button)
	_touch_buttons[node_name] = button


func _press_touch_action(action: StringName) -> void:
	var count := int(_touch_actions_held.get(action, 0)) + 1
	_touch_actions_held[action] = count
	if count == 1:
		Input.action_press(action)
	_set_input_hint_mode("touch")


func _release_touch_action(action: StringName) -> void:
	var count := maxi(0, int(_touch_actions_held.get(action, 0)) - 1)
	if count == 0:
		_touch_actions_held.erase(action)
		Input.action_release(action)
	else:
		_touch_actions_held[action] = count


func _release_all_touch_actions() -> void:
	for action: StringName in _touch_actions_held.keys():
		Input.action_release(action)
	_touch_actions_held.clear()


func _layout_touch_controls(viewport_size: Vector2,
		physical_size: Vector2 = Vector2.ZERO) -> void:
	if _touch_hud == null:
		return
	# canvas_items keeps the authored 1710×1112 coordinate system and expands
	# it to match the device aspect ratio. On a 390 px portrait browser this can
	# make one logical pixel less than a quarter of a screen pixel, so a nominal
	# 52 px button becomes a fingertip-unusable 12 px icon. Lay the controls out
	# in logical coordinates, but derive every size from its real screen-pixel
	# target so portrait and high-DPI Web canvases retain usable controls.
	if physical_size.is_zero_approx():
		physical_size = _touch_physical_size(viewport_size)
	# The headless display server reports a 1×1 placeholder window. Treat that
	# as unavailable rather than magnifying controls hundreds of times in tests
	# and server-side packaged smoke runs.
	if physical_size.x < 240.0 or physical_size.y < 240.0:
		physical_size = viewport_size
	var ui_scale := _touch_interface_scale(viewport_size, physical_size)
	var physical_width := viewport_size.x / ui_scale
	var compact := physical_width < 520.0
	var target_button_pixels := 52.0 if physical_width < 360.0 else (58.0 if compact else 64.0)
	var button_size := Vector2.ONE * target_button_pixels * ui_scale
	var gap := (5.0 if compact else 8.0) * ui_scale
	var margin := (10.0 if physical_width < 360.0 else (12.0 if compact else 18.0)) * ui_scale
	var bottom := viewport_size.y - margin - button_size.y
	var row_above := bottom - button_size.y - gap
	var row_upper := row_above - button_size.y - gap
	var left_x := margin
	var action_x := viewport_size.x - margin - button_size.x * 2.0 - gap
	_set_touch_button_rect("Up", Vector2(left_x + button_size.x + gap, row_above), button_size)
	_set_touch_button_rect("Left", Vector2(left_x, bottom), button_size)
	_set_touch_button_rect("Down", Vector2(left_x + button_size.x + gap, bottom), button_size)
	_set_touch_button_rect("Right", Vector2(left_x + (button_size.x + gap) * 2.0, bottom), button_size)
	_set_touch_button_rect("Charged", Vector2(action_x, row_upper), button_size)
	_set_touch_button_rect("Dodge", Vector2(action_x + button_size.x + gap, row_upper), button_size)
	_set_touch_button_rect("Jump", Vector2(action_x, row_above), button_size)
	_set_touch_button_rect("Attack", Vector2(action_x + button_size.x + gap, row_above), button_size)
	_set_touch_button_rect("Block", Vector2(action_x, bottom), button_size)
	_set_touch_button_rect("Interact", Vector2(action_x + button_size.x + gap, bottom), button_size)
	for button_value in _touch_buttons.values():
		var button := button_value as Button
		button.custom_minimum_size = button_size
		button.add_theme_font_size_override("font_size", roundi((14.0 if compact else 16.0) * ui_scale))
	set_meta("touch_control_physical_button_pixels", target_button_pixels)
	set_meta("touch_control_ui_scale", ui_scale)
	set_meta("touch_control_layout", "screen_pixel_safe_v2")


func _touch_physical_size(viewport_size: Vector2) -> Vector2:
	var display_size := Vector2(DisplayServer.window_get_size())
	var css_size := Vector2.ZERO
	if OS.has_feature("web"):
		# DisplayServer may expose the Web canvas backing-store size, which varies
		# with browser DPR and can change after Godot's first resize signal. CSS
		# viewport pixels are the stable physical target for a fingertip control.
		var encoded := str(JavaScriptBridge.eval(
			"JSON.stringify([window.innerWidth || 0, window.innerHeight || 0])", true))
		# Exported headless smoke carries the Web feature but no DOM. Avoid asking
		# JSON to parse its empty/null bridge response and use DisplayServer below.
		if encoded.begins_with("["):
			var decoded: Variant = JSON.parse_string(encoded)
			if decoded is Array and decoded.size() >= 2:
				css_size = Vector2(float(decoded[0]), float(decoded[1]))
	return _select_touch_physical_size(viewport_size, display_size, css_size)


func _select_touch_physical_size(viewport_size: Vector2, display_size: Vector2,
		css_size: Vector2 = Vector2.ZERO) -> Vector2:
	if css_size.x >= 240.0 and css_size.y >= 240.0:
		return css_size
	if display_size.x >= 240.0 and display_size.y >= 240.0:
		return display_size
	return viewport_size


func _touch_interface_scale(viewport_size: Vector2, physical_size: Vector2) -> float:
	if physical_size.x <= 0.0 or physical_size.y <= 0.0:
		return 1.0
	return maxf(1.0, maxf(viewport_size.x / physical_size.x,
		viewport_size.y / physical_size.y))


func _set_touch_button_rect(node_name: String, position: Vector2, size: Vector2) -> void:
	var button := _touch_buttons.get(node_name) as Button
	if button == null:
		return
	button.custom_minimum_size = Vector2.ZERO
	button.position = position
	button.size = size


func _show_status(text: String, color: Color) -> void:
	if _combat_status == null:
		return
	_combat_status.text = text
	_combat_status.modulate = color
	_combat_status.visible = not text.is_empty()
	if not text.is_empty():
		var tween := create_tween()
		tween.tween_interval(0.45)
		tween.tween_callback(func():
			if _combat_status != null and _combat_status.text == text:
				_combat_status.visible = false)


func _combat_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.2)
	material.metallic = 0.35
	material.roughness = 0.26
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
