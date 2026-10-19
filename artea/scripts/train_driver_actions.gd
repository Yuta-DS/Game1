extends RefCounted
## Game-scale cab procedure, not a physical locomotive simulation.
## Movement and gestures consume the same state so hands cannot select reverse
## while the train is still moving. Releasing W/S applies the existing auto-brake.

var active := false
var phase := "off"
var elapsed := 0.0
var reverser := 0
var throttle := 0.0
var brake := 1.0
var pressure := 0.0
var horn_remaining := 0.0
var selection_time := 0.0
var selected_request := 0
var release_remaining := 0.0

func begin() -> void:
	active = true
	phase = "take_controls"
	elapsed = 0.0
	reverser = 0
	throttle = 0.0
	brake = 1.0
	pressure = 0.0
	horn_remaining = 0.0
	selection_time = 0.0
	selected_request = 0
	release_remaining = 0.0

func end() -> void:
	active = false
	phase = "off"
	reverser = 0
	throttle = 0.0
	brake = 1.0
	horn_remaining = 0.0
	pressure = 0.0

func sound_horn() -> void:
	if active:
		horn_remaining = 0.65

func step(command: float, delta: float, speed: float) -> float:
	if not active:
		return 0.0
	var dt := maxf(delta, 0.0)
	elapsed += dt
	horn_remaining = maxf(0.0, horn_remaining - dt)
	throttle = 0.0
	pressure = clampf((elapsed - 0.9) / 0.9, 0.0, 1.0)
	if elapsed < 1.8:
		phase = "take_controls" if elapsed < 0.4 else (
			"power_on" if elapsed < 0.9 else "check_pressure")
		brake = 1.0
		return 0.0
	command = clampf(command, -1.0, 1.0)
	var requested := 0 if absf(command) < 0.01 else (1 if command > 0.0 else -1)
	if requested == 0 or (requested != reverser and speed > 0.05):
		phase = "braking" if speed > 0.05 else "ready"
		brake = 1.0
		selection_time = 0.0
		selected_request = 0
		return 0.0
	if requested != reverser:
		if selected_request != requested:
			selection_time = 0.0
			selected_request = requested
		selection_time += dt
		phase = "select_direction"
		brake = 1.0
		if selection_time >= 0.45:
			reverser = requested
			selection_time = 0.0
			release_remaining = 0.3
		return 0.0
	if release_remaining > 0.0:
		release_remaining = maxf(0.0, release_remaining - dt)
		phase = "release_brake"
		brake = release_remaining / 0.3
		return 0.0
	phase = "accelerating" if speed < absf(command) * 120.0 - 1.0 else "cruising"
	throttle = absf(command)
	brake = 0.0
	return command

func apply_arrival_brake() -> void:
	phase = "braking"
	throttle = 0.0
	brake = 0.8

func snapshot() -> Dictionary:
	return {"active": active, "phase": phase, "elapsed": elapsed,
		"reverser": reverser, "throttle": throttle, "brake": brake,
		"reverser_target": selected_request if phase == "select_direction" else reverser,
		"pressure": pressure, "horn": horn_remaining > 0.0,
		"ready": active and elapsed >= 1.8}
