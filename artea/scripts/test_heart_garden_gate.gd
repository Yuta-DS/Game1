extends SceneTree

const GateScene := preload("res://scenes/mind_spark/world_gate.tscn")
const WorldScene := preload("res://scenes/heart_melody/heart_garden_world.tscn")
const PlayerScene := preload("res://scenes/player_3d.tscn")

class DormantMind extends Node3D:
	var build_calls := 0
	func ensure_world_built() -> void:
		build_calls += 1

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var parent := Node3D.new()
	parent.name = "ArtCastleFloatingWorld"
	parent.position = Vector3(100,0,50)
	root.add_child(parent)
	var mind := DormantMind.new()
	mind.name = "MindSparkWorldOne"
	parent.add_child(mind)
	var heart = WorldScene.instantiate()
	heart.defer_build = true
	heart.build_hud = false
	heart.persist_progress = false
	heart.save_path = "user://test_heart_gate_unused.json"
	heart.position = Vector3(6000,0,2290)
	parent.add_child(heart)
	var player := PlayerScene.instantiate() as CharacterBody3D
	player.add_to_group("Player")
	parent.add_child(player)
	var gate = GateScene.instantiate()
	gate.target_world_path = NodePath("../HeartMelodyWorld")
	gate.destination_world_local = heart.position+Vector3(-88,2,0)
	parent.add_child(gate)
	assert(not heart.built)
	gate.set_gate_enabled(false)
	assert(not gate.teleport_player(player) and not heart.built)
	gate.set_gate_enabled(true)
	assert(gate.teleport_player(player))
	assert(heart.built and mind.build_calls == 0,"Heart travel must not construct World One")
	assert(player.global_position.is_equal_approx(heart.to_global(Vector3(-88,2,0))))
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*2,player.global_position-Vector3.UP*5,1,[player.get_rid()])
	assert(not parent.get_world_3d().direct_space_state.intersect_ray(query).is_empty())
	heart.deactivate()
	parent.queue_free()
	await process_frame
	print("HEART_GARDEN_GATE: PASS — lock, lazy build, no Mind build, transformed landing and physical floor")
	quit()
