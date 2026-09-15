extends CharacterBody3D

const MindSparkFoley := preload("res://scripts/mind_spark/mind_spark_foley.gd")

signal health_changed(current: float, maximum: float)
signal attack_started
signal block_changed(active: bool)

@export var speed: float = 10.0
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


func _ready() -> void:
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
	# Crown Line cars are synchronized AnimatableBody3D platforms on layer 1.
	# Track their floor and wall velocity so the player can walk and jump aboard
	# without the moving train sliding out from underneath the capsule.
	platform_floor_layers = 1
	platform_wall_layers = 1
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_UPWARD_VELOCITY

	if camera_path:
		_camera = get_node_or_null(camera_path) as Camera3D
	current_health = max_health
	if fox_visuals != null:
		_visual_base_position = fox_visuals.position
		_visual_base_scale = fox_visuals.scale
	_build_combat_rig()
	_build_combat_audio()
	_build_combat_help()
	_update_character_animation(0.0, false)


func set_input_enabled(v: bool) -> void:
	input_enabled = v
	if not v:
		_set_blocking(false)
		_finish_attack()
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
	var normalized_input := input_dir.normalized()
	var camera := _active_camera()
	if camera:
		var basis := camera.global_transform.basis
		var camera_forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
		var camera_right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
		return (camera_right * normalized_input.x + camera_forward * -normalized_input.y).normalized()
	return Vector3(normalized_input.x, 0.0, normalized_input.y)


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
	var movement_multiplier := block_speed_multiplier if is_blocking else 1.0
	if is_attacking:
		movement_multiplier *= 0.28
	var target_velocity := Vector2(move_dir.x, move_dir.z) * speed * movement_multiplier
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


func _update_combat(delta: float) -> void:
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	if not input_enabled:
		_set_blocking(false)
		_finish_attack()
		return

	_set_blocking(blocking_available and Input.is_action_pressed("block") and not is_attacking)
	if Input.is_action_just_pressed("attack") and not is_blocking \
			and _attack_cooldown_remaining <= 0.0:
		_start_attack()

	if not is_attacking:
		return
	_attack_active_remaining -= delta
	if _attack_arc != null:
		_attack_arc.rotation.z += delta * 12.0
	if _attack_active_remaining > 0.0:
		_apply_attack_hits()
	else:
		_finish_attack()


func _start_attack() -> void:
	is_attacking = true
	_attack_cooldown_remaining = attack_cooldown
	_attack_active_remaining = attack_active_time
	_hit_targets.clear()
	if _attack_collision != null:
		_attack_collision.disabled = false
	if _attack_arc != null:
		_attack_arc.visible = true
	_play_first_available(["Attack", "attack", "Attack1", "SwordAttack", "Idle"])
	_show_status("ATTACK", Color("ffd36e"))
	_play_combat_sound(&"player_swing")
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
			body.call("take_damage", attack_damage, self)
			_hit_targets[body] = true
	for area in _attack_area.get_overlapping_areas():
		if _hit_targets.has(area):
			continue
		var target := _find_damage_receiver(area)
		if target != null and target != self and target.has_method("take_damage"):
			target.call("take_damage", attack_damage, self)
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


# Shared damage contract for future enemies, hazards and projectiles. A held
# shield fully absorbs the hit; otherwise health is reduced and emitted.
func take_damage(amount: float, _source: Node = null) -> float:
	if amount <= 0.0:
		return 0.0
	if is_blocking:
		_show_status("BLOCKED!", Color("79e8ff"))
		_play_combat_sound(&"player_block")
		return 0.0
	var applied := minf(amount, current_health)
	current_health = maxf(0.0, current_health - applied)
	_hit_reaction_remaining = 0.32
	_show_status("-%d HP" % int(applied), Color("ff786f"))
	_play_combat_sound(&"player_hurt")
	health_changed.emit(current_health, max_health)
	return applied


func heal(amount: float) -> void:
	current_health = clampf(current_health + maxf(amount, 0.0), 0.0, max_health)
	health_changed.emit(current_health, max_health)


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


func _build_combat_help() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CombatHelpHUD"
	add_child(layer)
	var panel := ColorRect.new()
	panel.name = "CombatHelpPanel"
	panel.color = Color(0.04, 0.04, 0.12, 0.72)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(22.0, -74.0)
	panel.size = Vector2(405.0, 50.0)
	layer.add_child(panel)
	var label := Label.new()
	label.name = "CombatHelpLabel"
	label.text = "SPACE  JUMP     F  ATTACK     HOLD G  SHIELD"
	label.position = Vector2(14.0, 13.0)
	label.add_theme_font_size_override("font_size", 17)
	label.modulate = Color("f3ecff")
	panel.add_child(label)


func _build_combat_audio() -> void:
	_combat_audio = AudioStreamPlayer3D.new()
	_combat_audio.name = "PlayerCombatFoley3D"
	_combat_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_combat_audio.unit_size = 2.4
	_combat_audio.max_distance = 34.0
	_combat_audio.volume_db = -5.0
	_combat_audio.panning_strength = 1.0
	_combat_audio.bus = &"SFX"
	add_child(_combat_audio)


func _play_combat_sound(event: StringName) -> void:
	if _combat_audio == null:
		return
	_combat_audio.stream = MindSparkFoley.make_combat_event(event)
	_combat_audio.play()


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
