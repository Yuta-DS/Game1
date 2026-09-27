class_name WorldOneObjectMinigameCatalog
extends RefCounted

## Every physical quest object owns a playable challenge.  The panel consumes
## this data, while the quest object remains the authority for saves/rewards.
const CHALLENGES := {
	"world_one.checkpoint.landing": {
		"title": "ROOT PULSE CALIBRATION", "mode": "align", "island": 1,
		"instruction": "Steer the green pulse into each gold root ring, then lock it.",
		"targets": [0.18, 0.52, 0.82], "speed": 0.62, "goal": 3,
		"accent": Color("72e6c5"),
	},
	"world_one.path_projector": {
		"title": "STAR-PATH ROUTER", "mode": "route", "island": 1,
		"instruction": "Guide the light through the numbered stars. Avoid storm cells.",
		"route": [Vector2i(0, 2), Vector2i(1, 1), Vector2i(2, 0)],
		"hazards": [Vector2i(0, 1), Vector2i(2, 1)], "goal": 3,
		"accent": Color("8fe8ff"),
	},
	"world_one.spark_socket": {
		"title": "THOUGHT-SPARK CATCH", "mode": "catch", "island": 1,
		"instruction": "Move the receiver under bright Sparks. Let dark static pass.",
		"goal": 4, "speed": 0.48, "accent": Color("ffd66b"),
	},
	"world_one.checkpoint.network": {
		"title": "NETWORK ROOT SYNCHRONISER", "mode": "align", "island": 1,
		"instruction": "Match the living network's three signal bands and lock each pulse.",
		"targets": [0.72, 0.28, 0.58], "speed": 0.72, "goal": 3,
		"accent": Color("68e2a2"),
	},
	"world_one.focus_bell": {
		"title": "FOCUS BELL RHYTHM", "mode": "rhythm", "island": 1,
		"instruction": "Repeat the arrow rhythm to ring a clear guidance tone.",
		"sequence": ["left", "up", "right", "up"], "goal": 4,
		"accent": Color("f7ca68"),
	},
	"world_one.evidence_scanner": {
		"title": "EVIDENCE BEAM SCAN", "mode": "catch", "island": 2,
		"instruction": "Track the glowing evidence fragments. Avoid fear-static fragments.",
		"goal": 5, "speed": 0.58, "accent": Color("78ddd2"),
	},
	"world_one.memory_board": {
		"title": "MEMORY CONSTELLATION", "mode": "route", "island": 2,
		"instruction": "Walk the constellation from Notice to Name to Choose.",
		"route": [Vector2i(0, 2), Vector2i(1, 1), Vector2i(2, 0)],
		"hazards": [Vector2i(2, 2), Vector2i(0, 0)], "goal": 3,
		"accent": Color("b999ff"),
	},
	"world_one.logic_gate": {
		"title": "LOGIC CIRCUIT RHYTHM", "mode": "rhythm", "island": 2,
		"instruction": "Repeat the circuit directions to verify both event plates.",
		"sequence": ["up", "right", "down", "left", "up"], "goal": 5,
		"accent": Color("81e6a8"),
	},
	"world_one.perspective_lens": {
		"title": "THREE-VIEW LENS", "mode": "align", "island": 2,
		"instruction": "Align close, pattern, and forward viewpoints with the lens rings.",
		"targets": [0.22, 0.78, 0.48], "speed": 0.66, "goal": 3,
		"accent": Color("80d8ff"),
	},
	"world_one.truth_bridge": {
		"title": "TRUTH-TILE CROSSING", "mode": "route", "island": 2,
		"instruction": "Cross the supported tiles to materialise grounded hope.",
		"route": [Vector2i(1, 2), Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 1)],
		"hazards": [Vector2i(0, 2), Vector2i(2, 2)], "goal": 4,
		"accent": Color("efc866"),
	},
	"world_one.warden_anchor.1": {
		"title": "ANCHOR I • WIDE STORM", "mode": "dodge", "island": 3,
		"instruction": "Dodge the falling storm lines. Strike when the shield opens.",
		"goal": 4, "speed": 0.62, "pattern": 0, "accent": Color("ff817a"),
	},
	"world_one.warden_anchor.2": {
		"title": "ANCHOR II • CROSS STORM", "mode": "dodge", "island": 3,
		"instruction": "Read the crossing pattern, keep moving, then strike the open ring.",
		"goal": 5, "speed": 0.72, "pattern": 1, "accent": Color("ff9b72"),
	},
	"world_one.warden_anchor.3": {
		"title": "ANCHOR III • FAST STORM", "mode": "dodge", "island": 3,
		"instruction": "Survive the quick storm rhythm and strike its exposed crystal.",
		"goal": 6, "speed": 0.82, "pattern": 2, "accent": Color("ff6f91"),
	},
	"world_one.calm_rain_basin": {
		"title": "CALM-RAIN BALANCE", "mode": "align", "island": 3,
		"instruction": "Keep the rain seed inside each calm band and seal the pattern.",
		"targets": [0.5, 0.34, 0.66, 0.5], "speed": 0.78, "goal": 4,
		"accent": Color("74cfff"),
	},
	"world_one.identity_reflection": {
		"title": "REFLECTION LIGHT MAZE", "mode": "route", "island": 3,
		"instruction": "Carry your reflection through the quiet stars. Your final side records the path you chose.",
		"route": [Vector2i(1, 2), Vector2i(1, 1), Vector2i(0, 0)],
		"hazards": [Vector2i(0, 1), Vector2i(2, 1)], "goal": 3,
		"accent": Color("ddb7ff"),
	},
}


static func has_challenge(save_id: String) -> bool:
	return CHALLENGES.has(save_id)


static func challenge(save_id: String) -> Dictionary:
	return (CHALLENGES.get(save_id, {}) as Dictionary).duplicate(true)


static func ids() -> PackedStringArray:
	return PackedStringArray(CHALLENGES.keys())
