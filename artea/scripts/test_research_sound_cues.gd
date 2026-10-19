extends SceneTree
const Cues := preload("res://scripts/mind_spark/research_sound_cues.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	var signatures := {}
	for cue in Cues.DURATIONS:
		var stream := Cues.make(cue)
		assert(stream.mix_rate==22050 and not stream.stereo)
		assert(stream.data.size()>1000)
		for i in range(0,stream.data.size(),2):
			assert(absi(stream.data.decode_s16(i))<=7210,"Cue exceeds intended peak bound")
		var signature := hash(stream.data)
		assert(not signatures.has(signature),"Different cues must have different samples")
		signatures[signature]=true
		assert(stream.data==Cues.make(cue).data,"Cues must be deterministic")
	assert(Cues.select(&"trial",true,false)==&"flow")
	assert(Cues.select(&"replay",true,false)==&"replay")
	assert(Cues.select(&"project",false,false)==&"revise")
	assert(Cues.select(&"project",true,true)==&"complete")
	var station := load("res://scenes/mind_spark/quest_objects/quest_object_base.tscn").instantiate() as QuestObjectBase
	station.persist_state=false
	station.configure(load("res://resources/mind_spark/quest_objects/02_evidence_scanner.tres"),"world_one.evidence_scanner")
	station.set_meta("unfinished_light",true)
	root.add_child(station)
	station.feedback_sound.volume_db=-80
	assert(station.interact(&"adjust",0).accepted)
	assert(station.get_meta("last_sound_cue")==&"detent")
	assert(not station.interact(&"capture",0).accepted)
	assert(station.get_meta("last_sound_cue")==&"revise")
	assert(not str(station.current_state.garden_feedback).is_empty(),"Muted attempts still need visible feedback")
	station.interact(&"adjust",0)
	assert(station.interact(&"capture",0).accepted)
	assert(station.get_meta("last_sound_cue")==&"record")
	assert(station.current_state.observations[0],"Sound must not change observation progress")
	station.queue_free()
	await create_timer(.2).timeout
	print("RESEARCH_SOUND_CUES: PASS — seven deterministic bounded clips, action mapping, muted scanner feedback and progress")
	quit()
