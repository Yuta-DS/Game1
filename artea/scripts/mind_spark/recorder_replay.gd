extends RefCounted
## Pure sampled replay: UI, world animation and tests use the same event order.
const STEP_SECONDS := 1.6
const DURATION := STEP_SECONDS * 3
static func order(state: Dictionary) -> Array:
	return state.get("timeline", [0,1,2] if state.get("completed",false) else [2,0,1]).map(func(v): return int(v))
static func sample(timeline: Array, seconds: float) -> Dictionary:
	var slot := clampi(int(maxf(0,seconds) / STEP_SECONDS),0,2)
	var drift := false
	var flow := 1.0
	var shutter := true
	for i in range(slot+1):
		match int(timeline[i]):
			0: drift = true
			1: flow = .25
			2: shutter = false
	return {"slot":slot,"event":int(timeline[slot]),"drift":drift,"flow":flow,"shutter_open":shutter,"finished":seconds>=DURATION}
