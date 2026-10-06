class_name HeartInstrumentChallengeController
extends RefCounted

signal feedback(caption: String, note: int)
signal changed
signal completed
var target: Array = []
var input: Array = []
var failures := 0
var hint_level := 0
var generation := 0
var paused := false
var assisted := false
var elapsed := 0.0
var mode := "sequence"
var history: Array = []
var solved := false

func configure(kind: String, phrase: Array, partial: Array = []) -> bool:
	if kind not in ["sequence", "pitch", "aiming", "movement", "timing"] or phrase.is_empty() or phrase.size() > 16: return false
	for note in phrase + partial:
		if not (note is int or note is float) or not is_finite(float(note)) or note != floor(float(note)) or note < 0 or note > 5: return false
	if partial.size() > phrase.size(): return false
	mode = kind
	target = phrase.duplicate()
	input = partial.map(func(note): return int(note))
	failures = 0
	hint_level = 0
	history.clear()
	elapsed = 0.0
	solved = false
	paused = false
	cancel_playback()
	return true

func advance(delta: float) -> void:
	if not paused and is_finite(delta) and delta > 0: elapsed += delta

func enter(note: int) -> bool:
	if paused or solved or note < 0 or note > 5 or input.size() >= target.size(): return false
	history.append(input.duplicate())
	input.append(note)
	feedback.emit("Note %d · step %d of %d" % [note + 1, input.size(), target.size()], note)
	changed.emit()
	return true

func tune(string_index: int, note: int) -> bool:
	if paused or solved or mode != "pitch" or string_index < 0 or string_index >= target.size(): return false
	if note < 0 or note > 5:
		feedback.emit("Ease this string back into its safe range", string_index)
		return false
	history.append(input.duplicate())
	while input.size() < target.size(): input.append(0)
	input[string_index] = note
	feedback.emit("String %d · pitch %d" % [string_index + 1, note + 1], note)
	changed.emit()
	return true

func strike(note: int, beat_period: float, window: float) -> bool:
	if paused or solved or not is_finite(beat_period) or beat_period <= 0 or not is_finite(window) or window < 0: return false
	var phase := fposmod(elapsed, beat_period)
	var distance := minf(phase, beat_period - phase)
	if distance > window * (1.5 if assisted else 1.0):
		feedback.emit("Wait for the petals to meet the beat marker", note)
		return false
	return enter(note)

func undo() -> bool:
	if paused or solved or history.is_empty(): return false
	input = history.pop_back()
	changed.emit()
	return true

func reset() -> void:
	if paused: return
	cancel_playback()
	history.clear()
	input.clear()
	solved = false
	changed.emit()

func submit() -> bool:
	if paused or solved: return false
	if input != target:
		failures = mini(9999, failures + 1)
		feedback.emit("Your notes remain editable. Replay, undo, or try a hint." + (" Assistance is available." if failures >= 2 else ""), -1)
		return false
	solved = true
	completed.emit()
	return true

func hint() -> String:
	hint_level = mini(3, hint_level + 1)
	if hint_level == 1: return "Watch the shape and caption of each note."
	if hint_level == 2: return "The first note is %d." % (int(target[0]) + 1)
	return "Follow these notes: " + str(target.map(func(note): return int(note) + 1))

func cancel_playback() -> void:
	generation += 1

func replay(tree: SceneTree, speed := 1.0) -> void:
	if paused or speed not in [0.5, 0.75, 1.0]: return
	cancel_playback()
	var token := generation
	for note in target:
		if token != generation or paused: return
		feedback.emit("Listen / watch: note %d" % (int(note) + 1), note)
		await tree.create_timer(0.65 / speed, false).timeout
