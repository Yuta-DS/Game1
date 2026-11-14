extends Node2D


# Called every frame. 'delta' is the elapsed time since the previous frame.


@onready var chest_sprite = $AnimatedSprite2D
@onready var animation_player = $AnimationPlayer
var is_opened = false

@onready var sprite = $"Item Sprite"  # or $AnimatedSprite2D
var chest_variants = [
	preload("res://assets/Collectibles/Green leaf.png"),
	preload("res://assets/Collectibles/orb.png"),
	preload("res://assets/Collectibles/purple crystal.png"),
	preload("res://assets/Collectibles/red heart.png"),
	preload("res://assets/Collectibles/trophy.png"),
	preload("res://assets/Collectibles/yellow star.png")
]

func _ready() -> void:
	var random_index = randi() % chest_variants.size()
	sprite.texture = chest_variants[random_index]
	animation_player.play("closed")  # Start in closed state

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not is_opened:
		is_opened = true
		animation_player.play("opened_chest")  # Play the opening animation
		print("Chest is opening...")

func _on_AnimationPlayer_animation_finished(anim_name: String) -> void:
	if anim_name == "opened_chest":
		animation_player.play("opened")  # Switch to the idle 'opened' state
		print("Chest is now opened!")
