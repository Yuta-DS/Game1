extends CharacterBody3D

@onready var player = get_node("../NewPlayer")

@export var walk_speed := 1.35
@export var wander_radius := 7.0
@export var minimum_pause := 1.6
@export var maximum_pause := 4.5
@export var initial_greeting_pause := 10.0

const STAGE_GLOW := [
	Color("7896c8"),
	Color("86b7ff"),
	Color("f5a95e"),
	Color("d98cff"),
	Color("ffd66e"),
]
const STAGE_ENERGY := [0.18, 0.55, 0.85, 1.2, 1.65]

var player_in_range := false
var chatbot_ui = null

var wave_timer := 0.0
var first_wave := false
var journey_stage := -1
var aura: Node3D
var aura_light: OmniLight3D
var aura_material: StandardMaterial3D
var anim_player: AnimationPlayer
var _home: Vector3
var _walk_target: Vector3
var _pause_timer := 0.0
var _is_walking := false


func _ready():
	# This nested inherited scene loses its instance origin when the Web hub is
	# assembled. The Artéa sign keeps its authored landmark transform, so use it
	# as Milo's stable anchor. He now works beside the sign instead of waiting at
	# the player's spawn point.
	if player != null:
		var artea_sign := get_node_or_null("../Artéa_Signpost_1027230400_texture") as Node3D
		if artea_sign != null:
			global_position = artea_sign.global_position + Vector3(-7.5, -8.5, -1.5)
		else:
			global_position = Vector3(104.8, 21.0, -7.25)
	anim_player = _find_animation_player(self)
	_home = global_position
	_begin_pause(initial_greeting_pause)
	_play_animation("Idle_3")
	_build_journey_aura()
	_apply_journey_stage()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _play_animation(animation_name: String) -> void:
	if anim_player != null and anim_player.has_animation(animation_name) \
			and anim_player.current_animation != animation_name:
		var playback_speed := 0.62 if animation_name in ["Walk", "Walking"] else 1.0
		if animation_name == "Wave_One_Hand":
			playback_speed = 0.76
		anim_player.play(animation_name, 0.22, playback_speed)


func _begin_pause(duration := -1.0) -> void:
	_is_walking = false
	_pause_timer = duration if duration >= 0.0 else randf_range(minimum_pause, maximum_pause)
	velocity.x = 0.0
	velocity.z = 0.0
	_reset_mayor_arm_pose()
	_play_animation("Idle_3")


func _reset_mayor_arm_pose() -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	for bone_name in ["upperarm.l", "lowerarm.l", "wrist.l", "hand.l",
			"upperarm.r", "lowerarm.r", "wrist.r", "hand.r"]:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0:
			skeleton.reset_bone_pose(bone_index)


func _choose_town_target() -> void:
	var angle := randf() * TAU
	var distance := randf_range(wander_radius * 0.35, wander_radius)
	_walk_target = _home + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	_is_walking = true


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	# Milo stops to greet the player, then resumes his town route after they go.
	if player_in_range:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if not _is_walking:
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_choose_town_target()
	else:
		var to_target := _walk_target - global_position
		to_target.y = 0.0
		if to_target.length() <= 0.45:
			_begin_pause()
		else:
			var direction := to_target.normalized()
			velocity.x = direction.x * walk_speed
			velocity.z = direction.z * walk_speed
			rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 5.5 * delta)
			_play_animation("Walking")

	move_and_slide()


func look_at_player(delta):
	var target_pos = player.global_transform.origin
	var my_pos = global_transform.origin

	var direction = (target_pos - my_pos).normalized()
	var rotation_y = atan2(direction.x, direction.z)

	rotation.y = lerp_angle(rotation.y, rotation_y, 5.0 * delta)


func _on_area_3d_player_entered(body):
	if body == player:
		player_in_range = true


func _on_area_3d_player_exited(body):
	if body == player:
		player_in_range = false
		_reset_npc_state()


func _reset_npc_state():
	# hard reset everything so nothing gets stuck
	wave_timer = 0.0
	first_wave = false
	_begin_pause(1.0)


func _process(delta):
	_apply_journey_stage()
	if aura != null:
		aura.rotate_y(delta * (0.18 + max(journey_stage, 0) * 0.08))

	# Outside the interaction zone, locomotion owns Milo's facing and animation.
	if not player_in_range:
		return

	look_at_player(delta)

	# INSIDE interaction zone: waving logic
	if not first_wave:
		_play_animation("Wave_One_Hand")
		wave_timer = 0.0
		first_wave = true

	wave_timer += delta

	if wave_timer >= 5.0 and not player.interacting:
		_play_animation("Wave_One_Hand")
		wave_timer = 0.0

	# interaction
	if Input.is_action_just_pressed("interact") and player_in_range and !player.interacting:
		print("Interacting with Milo")
		open_chatbot()
		player.interacting = true


func open_chatbot():
	if chatbot_ui != null:
		return

	chatbot_ui = load("res://scenes/chatbot.tscn").instantiate()
	get_tree().current_scene.add_child(chatbot_ui)
	print("Milo opened chat")

	chatbot_ui.user_input.grab_focus()
	chatbot_ui.connect("chat_closed", Callable(self, "close_chatbot"))

	player.interacting = true


func close_chatbot():
	if chatbot_ui != null:
		chatbot_ui.queue_free()
		chatbot_ui = null

	player.interacting = false


func _exit_tree() -> void:
	# Scene changes and parent removal can bypass the chatbot's Close signal.
	# Never carry Milo's movement lock into the surviving player/world.
	if chatbot_ui != null and is_instance_valid(chatbot_ui):
		chatbot_ui.queue_free()
		chatbot_ui = null
	if player != null and is_instance_valid(player) and "interacting" in player:
		player.interacting = false


# Milo's glow is evidence of the journey, not a generic NPC highlight. The
# orbital bands pick up the same colour as the castle's current stage, so he
# remains the player's visual companion even before they open the chat.
func _build_journey_aura() -> void:
	aura = Node3D.new()
	aura.name = "JourneyAura"
	# Keep the journey glow grounded around Milo's feet. A floating ring above
	# his head made the neutral standing pose read like a prototype gizmo.
	aura.position = Vector3(0.0, 0.10, 0.0)
	add_child(aura)

	var halo := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.50
	ring.outer_radius = 0.54
	ring.rings = 16
	ring.ring_segments = 8
	halo.mesh = ring
	aura_material = StandardMaterial3D.new()
	aura_material.emission_enabled = true
	aura_material.metallic = 0.5
	aura_material.roughness = 0.25
	halo.material_override = aura_material
	aura.add_child(halo)

	for i in range(3):
		var star := MeshInstance3D.new()
		var gem := SphereMesh.new()
		gem.radius = 0.075
		gem.height = 0.15
		gem.radial_segments = 6
		gem.rings = 3
		star.mesh = gem
		star.position = Vector3(cos(TAU * i / 3.0) * 0.56, 0.0,
			sin(TAU * i / 3.0) * 0.56)
		star.material_override = aura_material
		aura.add_child(star)

	aura_light = OmniLight3D.new()
	aura_light.position = Vector3(0.0, 0.55, 0.0)
	aura_light.omni_range = 5.5
	aura_light.shadow_enabled = false
	aura.add_child(aura_light)


func _apply_journey_stage() -> void:
	var js := get_node_or_null("/root/JourneyState")
	var next_stage := clampi(js.stage, 0, STAGE_GLOW.size() - 1) if js != null else 0
	if next_stage == journey_stage:
		return

	journey_stage = next_stage
	if aura == null:
		return
	# Let Milo read as a natural character at the opening stage. The evidence
	# aura appears only after the player has actually advanced their journey.
	aura.visible = journey_stage > 0

	var glow: Color = STAGE_GLOW[journey_stage]
	aura_material.albedo_color = glow
	aura_material.emission = glow
	aura_material.emission_energy_multiplier = STAGE_ENERGY[journey_stage]
	aura_light.light_color = glow
	aura_light.light_energy = STAGE_ENERGY[journey_stage]
	var scale_factor := 0.72 + journey_stage * 0.12
	aura.scale = Vector3.ONE * scale_factor
