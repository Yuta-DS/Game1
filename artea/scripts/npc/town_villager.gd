class_name TownVillager
extends CharacterBody3D

enum State { IDLE, WALKING, TALKING }

signal greeting_started
signal greeting_finished

@export var villager_name := "Artea Villager"
@export var dialogue_node := "town_villager_greeting"
@export var walk_speed := 1.15
@export var wander_radius := 3.5
@export var wander_enabled := true
@export var idle_min_seconds := 2.5
@export var idle_max_seconds := 5.5
@export var idle_animation: StringName = &"Idle_3"
@export var walk_animation: StringName = &"Walking"

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var prompt: Label3D = $InteractionPrompt

var state := State.IDLE
var _home := Vector3.ZERO
var _walk_target := Vector3.ZERO
var _idle_time := 0.0
var _player: Node3D
var _animation_player: AnimationPlayer

const CIVILIAN_HIDDEN_PROPS := [
	"Knife_Offhand",
	"1H_Crossbow",
	"2H_Crossbow",
	"Knife",
	"Throwable",
]


func _ready() -> void:
	_home = global_position
	_walk_target = _home
	_hide_combat_props()
	_animation_player = _find_animation_player(self)
	prompt.text = "Q  Talk to %s" % villager_name
	prompt.visible = false
	_reset_idle_timer()
	_play_animation(idle_animation)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	if state == State.TALKING:
		_stop_horizontal()
		_face_player(delta)
		move_and_slide()
		return

	if state == State.WALKING:
		_update_walk(delta)
	else:
		_update_idle(delta)
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or state == State.TALKING:
		return
	if event.is_action_pressed("interact"):
		start_dialogue()


func request_walk_to(target: Vector3) -> void:
	_walk_target = target
	navigation_agent.target_position = target
	state = State.WALKING
	_play_animation(walk_animation)


func start_dialogue() -> void:
	if _player == null or dialogue_node.is_empty():
		return
	state = State.TALKING
	_stop_horizontal()
	_play_animation(idle_animation)
	prompt.visible = false
	greeting_started.emit()
	var manager := get_node_or_null("/root/GameManager")
	if manager != null and manager.has_method("start_dialogue"):
		manager.start_dialogue(dialogue_node, self)
	else:
		end_dialogue()


func end_dialogue() -> void:
	state = State.IDLE
	_reset_idle_timer()
	prompt.visible = _player != null
	greeting_finished.emit()


func _update_idle(delta: float) -> void:
	_stop_horizontal()
	_play_animation(idle_animation)
	if not wander_enabled or _player != null:
		return
	_idle_time -= delta
	if _idle_time <= 0.0:
		var angle := randf() * TAU
		var distance := randf_range(wander_radius * 0.35, wander_radius)
		request_walk_to(_home + Vector3(sin(angle), 0.0, cos(angle)) * distance)


func _update_walk(delta: float) -> void:
	if _player != null:
		state = State.IDLE
		_reset_idle_timer()
		return

	var flat_distance := Vector2(
		_walk_target.x - global_position.x,
		_walk_target.z - global_position.z
	).length()
	if flat_distance < 0.35:
		state = State.IDLE
		_reset_idle_timer()
		return

	var next_position := _walk_target
	var navigation_map := navigation_agent.get_navigation_map()
	if navigation_map.is_valid() and NavigationServer3D.map_get_iteration_id(navigation_map) > 0:
		next_position = navigation_agent.get_next_path_position()
	var direction := next_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		state = State.IDLE
		_reset_idle_timer()
		return
	direction = direction.normalized()
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 7.0)
	_play_animation(walk_animation)


func _reset_idle_timer() -> void:
	_idle_time = randf_range(idle_min_seconds, idle_max_seconds)


func _stop_horizontal() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _face_player(delta: float) -> void:
	if _player == null:
		return
	var direction := _player.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 8.0)


func _play_animation(animation_name: StringName) -> void:
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return
	if _animation_player.current_animation != animation_name:
		_animation_player.play(animation_name, 0.18)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _hide_combat_props() -> void:
	for prop_name in CIVILIAN_HIDDEN_PROPS:
		var prop := find_child(prop_name, true, false) as Node3D
		if prop != null:
			prop.visible = false


func _is_player(body: Node) -> bool:
	return body.is_in_group("player") or body.name == "NewPlayer"


func _on_dialogue_area_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player = body
	prompt.visible = state != State.TALKING


func _on_dialogue_area_body_exited(body: Node3D) -> void:
	if body != _player:
		return
	_player = null
	prompt.visible = false
	if state == State.TALKING:
		var manager := get_node_or_null("/root/GameManager")
		if manager != null and manager.has_method("end_dialogue"):
			manager.end_dialogue()
