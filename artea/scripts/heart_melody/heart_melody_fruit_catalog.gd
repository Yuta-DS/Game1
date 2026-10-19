class_name HeartMelodyFruitCatalog
extends RefCounted

const IDS := ["echo_berry", "sun_plum", "dew_pear", "bell_apple", "moon_melon", "harmony_fig"]
const STACK_LIMIT := 99
# Story allotments are separate from renewable crafting harvests.
const FRUITS := {
	"echo_berry": {"label": "Echo Berry", "zone": "quiet_meadow", "shape": "cluster", "icon": "repeat", "leaf": "round", "colour": "cf85b8", "note": 0, "property": "Short repeating note", "story_count": 4},
	"sun_plum": {"label": "Sun Plum", "zone": "feeling_garden", "shape": "oval", "icon": "sun", "leaf": "star", "colour": "efb65b", "note": 1, "property": "Rhythm and tempo", "story_count": 6},
	"dew_pear": {"label": "Dew Pear", "zone": "waterfall_organ_river", "shape": "teardrop", "icon": "droplet", "leaf": "spear", "colour": "8dcdd1", "note": 2, "property": "Pitch and water resonance", "story_count": 4},
	"bell_apple": {"label": "Bell Apple", "zone": "bell_grove", "shape": "bell", "icon": "chime", "leaf": "fork", "colour": "e8b785", "note": 3, "property": "Chime resonance", "story_count": 8},
	"moon_melon": {"label": "Moon Melon", "zone": "bell_grove", "shape": "ribbed_sphere", "icon": "crescent", "leaf": "fan", "colour": "b2a4d6", "note": 4, "property": "Calm sustained tone", "story_count": 4},
	"harmony_fig": {"label": "Harmony Fig", "zone": "harmony_jewel_sanctuary", "shape": "faceted_bud", "icon": "chord", "leaf": "heart", "colour": "b5d69e", "note": 5, "property": "Blended chord", "story_count": 1},
}
const RECIPES := {
	"echo_nectar": {"fruit": "echo_berry", "cost": 1, "effect": "replay"},
	"sunfruit_tonic": {"fruit": "sun_plum", "cost": 2, "effect": "focus"},
	"dew_pear_preserve": {"fruit": "dew_pear", "cost": 2, "effect": "checkpoint_health"},
	"bell_apple_rosin": {"fruit": "bell_apple", "cost": 2, "effect": "timing_window"},
	"moon_melon_tea": {"fruit": "moon_melon", "cost": 1, "effect": "assistance"},
	"harmony_glaze": {"fruit": "harmony_fig", "cost": 3, "effect": "final_upgrade"},
}

static func story_location(fruit_id: String) -> String:
	return "heart_melody.harvest." + fruit_id if fruit_id in IDS else ""
