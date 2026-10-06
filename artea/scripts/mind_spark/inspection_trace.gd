extends RefCounted
## Normalized recorded evidence shared by the physical screen and accessible UI.
const TARGETS := [2, 1, 3]
const TITLES := ["I · Optical record", "II · Cooling record", "III · Bypass test"]
const READINGS := [
	["Plate out of focus", "Partial trace", "Drift precedes Ari's touch", "Plate out of focus"],
	["Frame: shutter already closed", "Frame: flow falls, then shutter closes", "Frame: Ari reaches the control", "Frame: recorder rewinds"],
	["Valve closed · shutter closed", "Low flow · shutter closed", "Flow rising · shutter closed", "Flow restored · shutter released"]]

static func series(channel: int, setting: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 25:
		var t := float(i) / 24.0
		var value := .30
		match channel:
			0: value = .30 + maxf(0, t - .36) * .60
			1:
				# Each detent reveals a different recorder window, not the same
				# line with a different caption. Only window 1 shows both events.
				value = (.75 if t < .42 else .25) if setting == 1 else (.75 if setting == 3 else .25)
			2: value = .12 + float(setting) * .21
		points.append(Vector2(t, value))
	return points

static func clarity(channel: int, setting: int) -> float:
	return 1.0 if channel != 0 else [0.15, 0.55, 1.0, 0.3][setting]

static func event_marker(channel: int, setting: int) -> float:
	if channel == 0: return .72 # Ari touches after drift began.
	if channel == 1 and setting == 1: return .64 # Shutter closes after flow falls.
	return -1.0

static func shutter_open(channel: int, setting: int) -> bool:
	return (channel == 2 and setting == 3) or (channel == 1 and setting == 3)
