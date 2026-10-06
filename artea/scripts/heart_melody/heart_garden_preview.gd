extends Node3D

@export var campaign_entry := false

func _ready() -> void:
	$Player3D/MeshInstance3D.visible = false
	$Player3D/Camera3D.current = false
	$Camera3D.current = true
	$HeartMelodyWorld.activate($Player3D)
	$HeartMelodyWorld.return_requested.connect(func():
		if campaign_entry:
			var campaign := get_node_or_null("/root/JourneyCampaign")
			if campaign != null: campaign.return_to_campaign()
			return
		$HeartMelodyWorld.activate($Player3D)
		$HeartMelodyWorld._feedback(true,"Standalone preview: Castle return is available in the full game."))

