class_name HeartMelodyChapterCatalog
extends RefCounted

# Persisted identifiers. Never rename these when changing presentation.
const VERSION := 1
const QUESTS := [
	"heart_melody.quest.wake_feeling_garden",
	"heart_melody.quest.restore_river_song",
	"heart_melody.quest.build_heart_song",
	"heart_melody.quest.free_silent_conductor",
]
const TASKS := [
	"heart_melody.task.plant_feeling_seeds",
	"heart_melody.task.restore_garden_rhythm",
	"heart_melody.task.tune_waterfall_organ",
	"heart_melody.task.release_hush_vines",
	"heart_melody.task.call_rain_boat",
	"heart_melody.task.restore_bridge_chimes",
	"heart_melody.task.cross_warning_bells",
	"heart_melody.task.assemble_heart_song",
	"heart_melody.task.join_beat_anchors",
	"heart_melody.task.free_silent_conductor",
]
const TITLES := ["Feeling Seed Celesta", "Echo Drum Garden", "Waterfall Organ",
	"Hush Vine String Harp", "Rain Boat Call Bells", "Harmony Bridge Chimes",
	"Fear Warning Bell Path", "Heart Song Loom", "Conductor Beat Anchors", "Harmony Fruit Orchestra"]
const QUEST_INDEX := [0, 0, 1, 1, 1, 2, 2, 2, 3, 3]
const ZONES := ["quiet_meadow", "feeling_garden", "waterfall_organ_river",
	"bell_grove", "harmony_stage", "harmony_jewel_sanctuary"]
const ZONE_INDEX := [0, 1, 2, 2, 2, 3, 3, 4, 4, 5]
const REGIONS := ["first_breath", "first_breath", "river_voice", "river_voice", "shared_song", "shared_song"]
const CHECKPOINTS := ["arrival", "garden", "restored_garden", "river", "bell_grove", "peace_flower", "stage", "sanctuary"]
const REWARDS := {"harmony_jewel": TASKS[9], "harmony_shield": TASKS[9], "creators_light": TASKS[9]}
const PATTERNS := [[0, 1, 2], [0, 2, 1], [2, 0, 1], [0, 1, 2, 3, 4],
	[0, 2, 1, 3], [0, 1, 2], [0, 2, 1], [0, 1, 2, 3], [0, 2, 1], [0, 1, 2, 3, 4, 5, 0, 1, 2, 3]]
const FRUIT_COSTS := [{"echo_berry": 3}, {}, {"dew_pear": 3}, {"sun_plum": 5},
	{"bell_apple": 4}, {"bell_apple": 3}, {"moon_melon": 3}, {}, {},
	{"echo_berry": 1, "sun_plum": 1, "dew_pear": 1, "bell_apple": 1, "moon_melon": 1, "harmony_fig": 1}]

static func prerequisite(task_id: String) -> String:
	var index := TASKS.find(task_id)
	return TASKS[index - 1] if index > 0 else ""

static func available(task_id: String, completed: Array) -> bool:
	return task_id in TASKS and (prerequisite(task_id).is_empty() or prerequisite(task_id) in completed)

static func next_task(completed: Array) -> String:
	for task_id in TASKS:
		if task_id not in completed: return task_id
	return ""
