extends RefCounted
## A constrained fictional test rig, not a general fluid simulation.
const TRIAL_NAMES := ["Restricted line", "Bypass open"]
static func outcome(trial: int) -> Dictionary:
	return {"flow":.25 if trial==0 else 1.0,"shutter_open":trial==1}
static func prediction(model: int, trial: int) -> bool:
	# Model 0: shutter permanently jammed closed; model 2: shutter always open.
	# Model 1 matches
	# this test line only; no model establishes the earlier drift's cause.
	return false if model==0 else (trial==1 if model==1 else true)
