extends SceneTree

const BossScene := preload("res://scenes/mind_spark/combat/thought_storm_warden.tscn")


func _init() -> void:
	var boss := BossScene.instantiate() as MindSparkWardenBoss
	assert(boss != null and boss.definition != null and boss.definition.call("is_valid"),
		"the Warden uses a valid external balance resource")
	assert(float(boss.definition.get("max_health")) == 300.0 \
		and int(boss.definition.get("xp_reward")) == 150,
		"the extracted balance preserves the shipped progression contract")
	assert(float(boss.definition.get("telegraph_seconds")) >= 0.75,
		"the boss always gives a fair readable telegraph")
	assert(float(boss.definition.get("recovery_seconds")) \
		> float(boss.definition.get("telegraph_seconds")),
		"the strike window remains longer than the warning")
	boss.free()
	print("MIND_SPARK_COMBAT_BALANCE: PASS — Warden tuning is validated and data-driven")
	quit()
