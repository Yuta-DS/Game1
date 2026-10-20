extends "res://scripts/gallery_piano.gd"

signal note_played(midi: int)
signal playing_changed(active: bool)

const EASY_KEYS := [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K]
const EASY_NOTES := [60, 62, 64, 65, 67, 69, 71, 72]

func _sit_down() -> void:
	super._sit_down()
	if _seated:
		_show_prompt("Click or drag over any key · A S D F G H J K play C–C · Esc to leave")
		playing_changed.emit(true)

func _stand_up() -> void:
	var was_seated := _seated
	super._stand_up()
	if was_seated: playing_changed.emit(false)

func _play_note(midi: int) -> void:
	super._play_note(midi)
	note_played.emit(midi)

func _input(event: InputEvent) -> void:
	if _seated and event is InputEventKey:
		_unhandled_input(event)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _seated and event is InputEventKey and event.pressed and not event.echo:
		var index := EASY_KEYS.find(event.physical_keycode)
		if index >= 0:
			_play_note(EASY_NOTES[index])
			_press_key(EASY_NOTES[index])
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)

func _exit_tree() -> void:
	if _seated:
		_stand_up()
