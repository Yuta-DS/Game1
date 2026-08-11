extends Node3D

@onready var anim_player = $AnimationPlayer
@onready var player = get_node("../NewPlayer")

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


func _ready():
	anim_player.play("Idle_3")
	_build_journey_aura()
	_apply_journey_stage()


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
	anim_player.play("Idle_3")


func _process(delta):
	_apply_journey_stage()
	if aura != null:
		aura.rotate_y(delta * (0.18 + max(journey_stage, 0) * 0.08))

	# ALWAYS face player (inside + outside range)
	look_at_player(delta)

	# OUTSIDE interaction zone: just idle tracking
	if not player_in_range:
		if anim_player.current_animation != "Idle_3":
			anim_player.play("Idle_3")
		return

	# INSIDE interaction zone: waving logic
	if not first_wave:
		anim_player.play("Wave_One_Hand")
		wave_timer = 0.0
		first_wave = true

	wave_timer += delta

	if wave_timer >= 5.0 and not player.interacting:
		anim_player.play("Wave_One_Hand")
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
	if player != null and is_instance_valid(player):
		player.interacting = false


# Milo's glow is evidence of the journey, not a generic NPC highlight. The
# orbital bands pick up the same colour as the castle's current stage, so he
# remains the player's visual companion even before they open the chat.
func _build_journey_aura() -> void:
	aura = Node3D.new()
	aura.name = "JourneyAura"
	aura.position = Vector3(0.0, 2.6, 0.0)
	add_child(aura)

	var halo := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.48
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
	aura_light.position = Vector3(0.0, 0.15, 0.0)
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

	var glow: Color = STAGE_GLOW[journey_stage]
	aura_material.albedo_color = glow
	aura_material.emission = glow
	aura_material.emission_energy_multiplier = STAGE_ENERGY[journey_stage]
	aura_light.light_color = glow
	aura_light.light_energy = STAGE_ENERGY[journey_stage]
	var scale_factor := 0.72 + journey_stage * 0.12
	aura.scale = Vector3.ONE * scale_factor
