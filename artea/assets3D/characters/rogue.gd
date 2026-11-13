extends CharacterBody3D

const speed = 3
var current_state = IDLE
var is_roaming = true
var is_chatting = false
var dir = Vector3.RIGHT
var start_pos

enum {
	IDLE,
	NEW_DIR,
	MOVE
}

var player
var player_in_chat_zone = false

func _ready():
	randomize()
	start_pos = position
	
func _process(delta):
	if current_state == 0 or current_state == 1:
		$AnimationPlayer.play("Idle")
	elif current_state == 2 and !is_chatting:
		$AnimationPlayer.play("Walking_A")
		
	if is_roaming:
		match current_state:
			IDLE: 
				pass
			NEW_DIR:
				dir = choose([Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK])
			MOVE:
				move(delta)
				
func choose(array):
	array.shuffle()
	return array[0]
	
func move(delta):
	if !is_chatting:
		position += dir * speed * delta * 3


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.has_method("NewPlayer"):
		player = body
		player_in_chat_zone = true

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.has_method("NewPlayer"):
		player_in_chat_zone = false

func _on_timer_timeout() -> void:
	$Timer.wait_time = choose ([0.5, 5, 1.5])
	current_state = choose([NEW_DIR, MOVE, IDLE])
