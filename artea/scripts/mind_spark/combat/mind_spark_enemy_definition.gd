class_name MindSparkEnemyDefinition
extends Resource

enum EnemyKind { STATIC_MITE, GLITCH_SPROUT, CIRCUIT_WISP, ROOT_STALKER, BLIGHT_SENTINEL }

@export var enemy_kind := EnemyKind.STATIC_MITE
@export var display_name := "Static Mite"
@export var max_health := 25.0
@export var xp_reward := 10
@export var spark_shard_reward := 6
@export var guaranteed_material_id := "signal_glass"
@export var guaranteed_material_quantity := 1
@export_range(1, 3) var encounter_tier := 1
@export var animation_profile := "ground_small"
@export var resistances: Dictionary = {}
@export var attack_damage := 8.0
@export var attack_range := 4.0
@export var move_speed := 5.0
@export var telegraph_seconds := 0.75
@export var recovery_seconds := 1.25
@export var shell_color := Color("7a59b4")
@export var living_color := Color("55c982")


func validated_telegraph() -> float:
	return maxf(0.75, telegraph_seconds)


func reward_bundle() -> Dictionary:
	var items := {}
	if not guaranteed_material_id.is_empty() and guaranteed_material_quantity > 0:
		items[guaranteed_material_id] = guaranteed_material_quantity
	return {"xp": xp_reward, "spark_shards": spark_shard_reward, "items": items}
