extends CharacterBody2D

const SPEED = 150
const JUMP_VELOCITY = -350.0

@onready var anim_player = $AnimatedSprite2D
@onready var animation_player = $AnimationPlayer

var interacting_with: Node2D = null

@onready var actionable_finder: Area2D =$ActionableFinder
@onready var actionable_finderTherapist: Area2D = $ActionableFinder


const PaintingArea = preload("res://scripts/PaintingArea.gd")


var is_attacking = false


func _input(event: InputEvent) -> void:
	
	var current_scene = get_tree().current_scene
	
	if(current_scene.name == "Artea Game"):
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
			var actionables = actionable_finder.get_overlapping_areas()
			if actionables.size()>0:
				actionables[0].action()
				return
	if (current_scene.name == "Game"):
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
			var actionables = actionable_finderTherapist.get_overlapping_areas()
			if actionables.size()>0:
				actionables[0].action()
				return
		
				
func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	# Handle Attack (keep your existing logic)
	if Input.is_action_just_pressed("attack") and not is_attacking:
		anim_player.play("attack1")
		is_attacking = true
		# Fallback timer in case animation_finished signal doesn't work
		get_tree().create_timer(0.5).timeout.connect(_on_attack_timer_timeout)
	
	# Prevent horizontal movement up the wall after jump
	if not is_on_floor() and is_on_wall():
		velocity.x = 0
	

	# Jumping (now supports touchscreen button)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_on_wall():
		jump()

	# Movement (now supports touchscreen + keyboard)
	var direction = 0.0
	if Input.is_action_pressed("move_left"):
		direction -= 1
	if Input.is_action_pressed("move_right"):
		direction += 1

	if direction != 0:

		var current_scene = get_tree()
		if current_scene != null:
			current_scene = current_scene.current_scene

		if current_scene != null and current_scene.name == "Game":
			velocity.x = direction * SPEED * 2.5
		elif current_scene != null:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
		
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	move_and_slide()

	# Animation logic
	if not is_attacking:
		if not is_on_floor():
			anim_player.play("jump")
		else:
			if direction != 0:
				anim_player.play("walk")
				anim_player.flip_h = direction < 0

				if not animation_player.is_playing():
					animation_player.play("player_walk")
			else:
				anim_player.play("idle")

				if animation_player.is_playing():
					animation_player.stop()
	else:
		# When attacking, make sure we're playing the attack animation
		if anim_player.animation != "attack1":
			anim_player.play("attack1")
@onready var footstep_player = $WalkingSoundPlayer

				
func play_footstep():
	if not footstep_player.playing:
		footstep_player.play()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		interacting_with = self
		

# Used in Art Gallery
func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		interacting_with = null
		
func jump():
	velocity.y = JUMP_VELOCITY
	
var interacting_area: PaintingArea = null

		
func _process(_delta):
	 # only react if we're currently in the ArtGallery scene
	var curr = get_tree().current_scene
	if curr and curr.name == "ArtGallery":
		if interacting_area and (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump")):
			Global.painting_to_show = interacting_area.painting_id
			get_tree().change_scene_to_file("res://scenes/PaintingView.tscn")

func _on_attack_animation_finished(anim_name):
	if anim_name == "attack1":
		is_attacking = false
		# Force transition back to idle animation
		anim_player.play("idle")

func _on_attack_timer_timeout():
	# Fallback function in case animation_finished signal doesn't work
	if is_attacking:
		is_attacking = false
		anim_player.play("idle")
