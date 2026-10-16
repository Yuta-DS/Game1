extends Area3D
const SceneLoader := preload("res://scripts/scene_loader.gd")

const TARGET_SCENE_PATH = "res://scenes/heart_melody/heart_melody_world.tscn"

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		get_node("/root/JourneyCampaign").enter_kingdom("heart")
