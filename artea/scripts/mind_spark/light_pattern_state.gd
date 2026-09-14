extends RefCounted
const Rules := preload("res://scripts/mind_spark/unfinished_light_rules.gd")
static func describe(state: Dictionary) -> Dictionary:
	var approach := clampi(int(state.get("approach",0)),0,2)
	var solved := bool(state.get("completed",false))
	var enabled := state.has("approach") or solved
	var cooling := solved or bool(state.get("cooling_ready",approach!=2))
	var optics: Array=state.get("optics",Rules.TARGETS[approach] if solved else [0,0,0]).map(func(v):return int(v))
	return {"approach":approach,"enabled":enabled,"cooling":cooling,"optics":optics,
		"target":Rules.TARGETS[approach],"held_reference":enabled and approach==1,
		"small_bed":enabled and approach==0,"solved":bool(state.get("completed",false)),
		"beam_enabled":enabled and cooling}
