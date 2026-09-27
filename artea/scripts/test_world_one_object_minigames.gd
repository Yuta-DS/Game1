extends SceneTree

const Catalog := preload("res://scripts/mind_spark/world_one_object_minigame_catalog.gd")
const WorldScript := preload("res://scripts/mind_spark/mind_spark_world_one.gd")
const PanelScript := preload("res://scripts/mind_spark/world_one_object_minigame_panel.gd")

const EXPECTED_IDS := [
	"world_one.checkpoint.landing", "world_one.path_projector",
	"world_one.spark_socket", "world_one.checkpoint.network", "world_one.focus_bell",
	"world_one.evidence_scanner", "world_one.memory_board", "world_one.logic_gate",
	"world_one.perspective_lens", "world_one.truth_bridge",
	"world_one.warden_anchor.1", "world_one.warden_anchor.2", "world_one.warden_anchor.3",
	"world_one.calm_rain_basin", "world_one.identity_reflection",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists("user://test_world_one_object_minigames.json"):
		DirAccess.remove_absolute("user://test_world_one_object_minigames.json")
	assert(Catalog.ids().size() == 15, "exactly 15 physical quest objects have minigames")
	var islands := {1: 0, 2: 0, 3: 0}
	var modes := {}
	for save_id in EXPECTED_IDS:
		assert(Catalog.has_challenge(save_id), "%s has a playable challenge" % save_id)
		var spec := Catalog.challenge(save_id)
		assert(str(spec.get("title", "")).length() > 4)
		assert(str(spec.get("instruction", "")).length() > 12)
		assert(str(spec.get("mode", "")) in ["align", "route", "rhythm", "catch", "dodge"])
		assert(int(spec.get("goal", 0)) >= 3, "challenge requires several player actions")
		islands[int(spec.island)] += 1
		modes[str(spec.mode)] = true
	assert(islands == {1: 5, 2: 5, 3: 5}, "five minigames belong to each island")
	assert(modes.size() == 5, "the objects use five distinct playable mechanics")

	var world := WorldScript.new()
	world.build_hud = false
	world.object_state_store_path = "user://test_world_one_object_minigames.json"
	get_root().add_child(world)
	await process_frame
	assert(world.get_quest_objects().size() == 15)
	for object in world.get_quest_objects():
		assert(Catalog.has_challenge(object.save_id), "live object opens a minigame")
		assert(object.has_meta("operator_approach_local"), "minigame is reachable from supported ground")
	var projector: QuestObjectBase
	for object in world.get_quest_objects():
		if object.save_id == "world_one.path_projector": projector = object
	assert(projector != null)
	var actor := Node3D.new()
	world.add_child(actor)
	var panel := PanelScript.new()
	panel.name = "QuestStationPanel"
	world.add_child(panel)
	panel.open_object(projector, actor)
	assert(panel.challenge_mode() == "route", "Q opens the object's active game mechanic")
	var reward: Dictionary = panel.complete_for_test()
	assert(bool(reward.accepted) and bool(projector.current_state.guide_enabled),
		"winning a minigame applies the existing quest-object reward")
	panel.free()
	for object in world.get_quest_objects():
		object.interaction_enabled = true
		object.set_meta("available_sparks", object.definition.validated_total())
		var reward_panel := PanelScript.new()
		reward_panel.name = "RewardPanel_%s" % object.save_id.replace(".", "_")
		world.add_child(reward_panel)
		reward_panel.open_object(object, actor)
		var result: Dictionary = reward_panel.complete_for_test()
		assert(bool(result.get("accepted", false)), "%s minigame applies a valid gameplay action" % object.save_id)
		reward_panel.free()
	print("WorldOneObjectMinigames: PASS — 15 objects, 5 per island, 5 active mechanics")
	world.queue_free()
	if FileAccess.file_exists("user://test_world_one_object_minigames.json"):
		DirAccess.remove_absolute("user://test_world_one_object_minigames.json")
	quit()
