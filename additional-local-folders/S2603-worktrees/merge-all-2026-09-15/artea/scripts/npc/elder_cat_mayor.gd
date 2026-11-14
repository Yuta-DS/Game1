class_name ElderCatMayor
extends MiloGuide

const ALDER_REMINDERS := [
	&"alder_guide_stage_0",
	&"alder_guide_stage_1",
	&"alder_guide_stage_2",
	&"alder_guide_stage_3",
	&"alder_guide_stage_4",
]
const ALDER_HINTS := [
	&"alder_hint_stage_0",
	&"alder_hint_stage_1",
	&"alder_hint_stage_2",
	&"alder_hint_stage_3",
	&"alder_guide_stage_4",
]
const ALDER_CELEBRATIONS := {
	&"star_of_wisdom": &"alder_celebrate_mind",
	&"harmony_jewel": &"alder_celebrate_heart",
	&"creators_light": &"alder_celebrate_creator",
	&"journey_complete": &"alder_celebrate_complete",
}


func current_reminder_node() -> StringName:
	return ALDER_REMINDERS[_journey_stage]


func give_optional_hint() -> void:
	_pending_hint = true
	hint_requested.emit(current_objective_id())
	if _player_in_range and not _player_busy():
		open_dialogue(ALDER_HINTS[_journey_stage])


func _dialogue_for_interaction() -> StringName:
	if not _pending_celebration_id.is_empty():
		return ALDER_CELEBRATIONS.get(_pending_celebration_id, &"alder_celebrate_progress")
	if _pending_hint:
		return ALDER_HINTS[_journey_stage]
	return current_reminder_node()
