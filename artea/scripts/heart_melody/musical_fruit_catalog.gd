extends RefCounted

# Pitch belongs to an instrument slot. Fruit only changes timbre and appearance.
const FRUIT_ORDER := ["bell_apple", "marimba_pear", "shaker_berry", "bass_melon"]
const FRUITS := {
	"bell_apple": {
		"name": "Bell Apple", "symbol": "APPLE / STAR", "timbre": 1,
		"colour": Color("e85d5d"), "role": "bright bell shimmer",
	},
	"marimba_pear": {
		"name": "Marimba Pear", "symbol": "PEAR / LEAF", "timbre": 3,
		"colour": Color("65c6a3"), "role": "warm wooden resonance",
	},
	"shaker_berry": {
		"name": "Shaker Berry", "symbol": "BERRY / DOTS", "timbre": 6,
		"colour": Color("b56cce"), "role": "soft rhythmic rattle",
	},
	"bass_melon": {
		"name": "Bass Melon", "symbol": "MELON / WAVES", "timbre": 8,
		"colour": Color("7fbd68"), "role": "gentle low foundation",
	},
}

const INSTRUMENTS := {
	"drums": {"name": "Flower Drums", "slots": 4, "notes": 4},
	"marimba": {"name": "Fruit Marimba", "slots": 5, "notes": 5},
	"harp": {"name": "Vine Harp", "slots": 3, "notes": 5},
	"bells": {"name": "Hanging Bell Garden", "slots": 4, "notes": 5},
}

const ACTIVITY_ORCHARD := "orchard_voices"
const ACTIVITY_FLOWERS := "answer_flowers"
const ACTIVITY_MARIMBA := "fruit_melody"
const ACTIVITY_BELLS := "wake_bell_grove"
const ACTIVITY_ENSEMBLE := "garden_ensemble"
const ACTIVITY_ORDER := [ACTIVITY_ORCHARD, ACTIVITY_FLOWERS, ACTIVITY_MARIMBA, ACTIVITY_BELLS, ACTIVITY_ENSEMBLE]

const FLOWER_PHRASE := [0, 2, 1]
const MARIMBA_PHRASE := [0, 2, 4]
const HARP_PHRASE := [0, 2, 4]
const BELL_VISIBLE_PHRASE := [0, 1, -1, 3, 4]
const BELL_MISSING_NOTE := 2
const MAX_RECORDED_EVENTS := 24

static func fruit_name(id: String) -> String:
	return str(FRUITS.get(id, {}).get("name", id))

static func fruit_symbol(id: String) -> String:
	return str(FRUITS.get(id, {}).get("symbol", "NEUTRAL / CIRCLE"))

static func timbre(id: String) -> int:
	return int(FRUITS.get(id, {}).get("timbre", 0))

static func instrument_name(id: String) -> String:
	return str(INSTRUMENTS.get(id, {}).get("name", id))

static func activity_label(id: String) -> String:
	return {
		ACTIVITY_ORCHARD: "Find the Orchard's Voices",
		ACTIVITY_FLOWERS: "Answer the Flowers",
		ACTIVITY_MARIMBA: "Build a Fruit Melody",
		ACTIVITY_BELLS: "Wake the Bell Grove",
		ACTIVITY_ENSEMBLE: "The Garden Ensemble",
	}.get(id, id)
