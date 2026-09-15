extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var station := load("res://scenes/mind_spark/quest_objects/quest_object_base.tscn").instantiate() as QuestObjectBase
	station.persist_state=false
	station.configure(load("res://resources/mind_spark/quest_objects/01_thought_spark_socket.tres"),"world_one.audio_lifecycle_test")
	var clips: Array[WeakRef]=[]
	for cycle in 3:
		root.add_child(station)
		station.call("_play_tone")
		assert(station.feedback_sound.playing,"Re-entered quest must still provide sound")
		var clip: WeakRef = weakref(station.feedback_sound.stream)
		clips.append(clip)
		root.remove_child(station)
		assert(not station.feedback_sound.playing)
		assert(station.feedback_sound.stream==null)
		# AudioServer consumes queued playback releases asynchronously. Allow a
		# mixer interval before checking lifetime, rather than quitting instantly.
		await create_timer(.2).timeout
	station.free()
	await create_timer(.2).timeout
	for clip in clips:
		assert(clip.get_ref()==null,"Clip remained retained after player destruction and mixer cleanup")
	print("QUEST_AUDIO_LIFECYCLE: PASS — three play/exit/re-entry cycles, playback stopped and WAV released")
	quit()
