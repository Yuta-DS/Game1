extends Area2D

@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = ""
const HubWorldBalloon = preload("res://dialogue/HubworldBalloon.tscn")
const TherapistBalloon = preload("res://dialogue/therapistBalloon.tscn")

var player_in_range := false
var current_balloon: Node = null

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		player_in_range = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		player_in_range = false
		close_dialogue()

func action() -> void:
	var current_scene = get_tree().current_scene
	# print("Current scene is: ", current_scene.name) #debug purposes
	if (current_scene.name == "Artea Game"):
		if current_balloon == null and player_in_range:
			current_balloon = HubWorldBalloon.instantiate()
			get_tree().current_scene.add_child(current_balloon)
			current_balloon.start(dialogue_resource, dialogue_start)
	else:
		if current_balloon == null and player_in_range:
			current_balloon = TherapistBalloon.instantiate()
			get_tree().current_scene.add_child(current_balloon)
			current_balloon.start(dialogue_resource,"start")

func close_dialogue() -> void:
	if current_balloon:
		current_balloon.queue_free()
		current_balloon = null
