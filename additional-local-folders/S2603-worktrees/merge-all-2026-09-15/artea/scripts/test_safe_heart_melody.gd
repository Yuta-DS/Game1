# Focused no-save check for Heart Melody's curated emotion chooser.
# Run headless:
#   godot --headless --path artea --script res://scripts/test_safe_heart_melody.gd
extends SceneTree

const HEART_SCENE := preload("res://scenes/music_minigame.tscn")


class FakeJourneyState extends Node:
	var thoughts: Array = []
	var emotions: Array = []
	var stage := 0
	var save_calls := 0

	func record_emotion(name: String, colour: Color) -> void:
		emotions.append({"name": name, "colour": colour})

	func advance_to(next_stage: int) -> void:
		stage = max(stage, next_stage)

	func save() -> void:
		save_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/music_minigame.gd")
	var scene_source := FileAccess.get_file_as_string("res://scenes/music_minigame.tscn")

	assert(source.contains("EMOTION_CHOICES"), "Heart Melody has an authored choice catalogue")
	for forbidden in ["NobodyWho", "EmotionInput", "GenerateButton", "load_emotion_prompt", "detect_emotion", ".say("]:
		assert(not source.contains(forbidden), "Heart Melody script does not contain %s" % forbidden)
		assert(not scene_source.contains(forbidden), "Heart Melody scene does not contain %s" % forbidden)

	var heart = HEART_SCENE.instantiate()
	var fake := FakeJourneyState.new()
	heart.journey_state_override = fake
	root.add_child(heart)
	await process_frame

	var choices := heart.get_node_or_null("HBoxContainer/VBoxContainer/EmotionChoices") as GridContainer
	assert(choices != null, "curated emotion container exists")
	assert(choices.get_child_count() == 7, "six feelings plus a skip action are present")
	for expected in ["Joy", "Sadness", "Frustration", "Fear", "Peace", "Hope", "Skip for now"]:
		assert(_has_button(choices, expected), "choice %s is present" % expected)

	var hope_choice = _choice_with_id(heart.EMOTION_CHOICES, "hope")
	heart._choose_emotion(hope_choice)
	assert(heart.music_system_activated, "a deliberate choice activates musical feedback")
	assert(fake.emotions.size() == 1 and fake.emotions[0]["name"] == "hope",
		"the deliberate player choice, not an inference, is recorded")
	assert(fake.stage == 2, "the chosen feeling advances the existing journey link")
	assert(heart.result.text.contains("You chose Hope"), "Milo uses the authored non-diagnostic reply")

	heart._choose_emotion(hope_choice)
	assert(fake.emotions.size() == 1, "replaying one sound does not duplicate the record")
	heart._skip_emotion()
	assert(fake.emotions.size() == 1, "skipping creates no emotion record")
	assert(heart.result.text.contains("Skipping does not change your journey"), "skip stays non-rewarding")
	assert(fake.save_calls == 0, "the focused test never writes a player save")

	heart.queue_free()
	print("safe Heart Melody: all checks passed")
	quit()


func _choice_with_id(catalogue: Array, id: String) -> Dictionary:
	for choice in catalogue:
		if choice.get("id", "") == id:
			return choice
	return {}


func _has_button(container: GridContainer, text: String) -> bool:
	for child in container.get_children():
		if child is Button and child.text == text:
			return true
	return false
