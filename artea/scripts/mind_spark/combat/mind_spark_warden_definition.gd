class_name MindSparkWardenDefinition
extends Resource

@export var display_name := "Thought Storm Warden"
@export var max_health := 300.0
@export var xp_reward := 150
@export var spark_shard_reward := 80
@export var guaranteed_material_id := "storm_crystal"
@export var guaranteed_material_quantity := 5
@export var encounter_tier := 3
@export var animation_profile := "thought_storm_warden"
@export var storm_damage := 16.0
@export var storm_radius := 38.0
@export var telegraph_seconds := 1.15
@export var recovery_seconds := 4.0


func is_valid() -> bool:
	return not display_name.strip_edges().is_empty() and max_health > 0.0 \
		and xp_reward >= 0 and storm_damage > 0.0 and storm_radius > 0.0 \
		and telegraph_seconds >= 0.75 and recovery_seconds >= 0.5


func reward_bundle() -> Dictionary:
	return {"xp": xp_reward, "spark_shards": spark_shard_reward,
		"items": {guaranteed_material_id: guaranteed_material_quantity}}
