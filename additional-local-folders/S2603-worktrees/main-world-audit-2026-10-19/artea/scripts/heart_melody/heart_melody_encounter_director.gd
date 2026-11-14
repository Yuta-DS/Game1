class_name HeartMelodyEncounterDirector
extends RefCounted
const MAX_ENEMIES := 4
var time := 0.0
var assistance := false
var failures := 0
var active := false
var phase := "warning"
var struck := false

func advance(delta: float, paused: bool) -> void:
	if not active or paused: return
	time += delta
	var warning := 2.4 if assistance else 1.5
	var recovery := 7.0 if assistance else 5.0
	if time < warning: phase = "warning"
	elif time < warning + 0.6: phase = "wave"
	elif time < warning + 0.6 + recovery: phase = "recovery"
	else:
		time = 0.0
		phase = "warning"
		struck = false

func retry() -> void:
	failures += 1
	time = 0.0
	phase = "warning"
	struck = false
