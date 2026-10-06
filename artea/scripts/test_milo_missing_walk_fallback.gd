extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var skin := preload("res://scripts/milo_villager_skin.gd").new()
	var animations := AnimationPlayer.new()
	animations.name = "AnimationPlayer"
	animations.add_animation_library("", AnimationLibrary.new())
	skin.add_child(animations)
	root.add_child(skin)
	assert(not animations.has_animation("Milo_Walking"))
	assert(animations.has_animation("Cane_Walk"), "Missing authored clip must use the existing donor fallback")
	assert(animations.get_animation("Cane_Walk").length > 0.0)
	var controller := preload("res://scripts/milo_animations.gd").new()
	var empty_player := AnimationPlayer.new()
	controller.anim_player = empty_player
	for i in 120:
		controller._update_locomotion_playback(2.0, 2.0)
	assert(empty_player.speed_scale == 1.0, "Unavailable locomotion must not freeze unrelated animation")
	controller.free()
	empty_player.free()
	skin.free()
	print("MILO_MISSING_WALK: PASS — donor fallback and silent missing-clip handling")
	quit()
