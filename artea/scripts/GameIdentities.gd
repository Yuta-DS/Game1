extends RefCounted

## The 16 game identities from the story, and the reading that suggests them.
##
## The story is emphatic that the identity is a guide and not a box: no type is
## better than another, the game offers two or three, and the player may pick a
## different one or say they are still discovering. Nothing here ever decides
## for the player — `suggest` only ranks, and the choosing happens elsewhere.

## Each identity carries the child-facing name and purpose from the story, plus
## the MBTI code adult guides can map back to.
const IDENTITIES := {
	"guiding_light": {
		"name": "The Guiding Light",
		"purpose": "To help people grow and believe in themselves.",
		"mbti": "ENFJ",
	},
	"quiet_visionary": {
		"name": "The Quiet Visionary",
		"purpose": "To see hidden meaning and bring deep healing.",
		"mbti": "INFJ",
	},
	"joyful_creator": {
		"name": "The Joyful Creator",
		"purpose": "To use imagination and bring hope to others.",
		"mbti": "ENFP",
	},
	"gentle_peacemaker": {
		"name": "The Gentle Peacemaker",
		"purpose": "To create safe spaces and help dreams grow.",
		"mbti": "INFP",
	},
	"bold_architect": {
		"name": "The Bold Architect",
		"purpose": "To build strong plans and lead people towards a better future.",
		"mbti": "ENTJ",
	},
	"wise_strategist": {
		"name": "The Wise Strategist",
		"purpose": "To understand difficult problems and find a clear path.",
		"mbti": "INTJ",
	},
	"bright_spark": {
		"name": "The Bright Spark",
		"purpose": "To try new ideas and discover clever ways forward.",
		"mbti": "ENTP",
	},
	"deep_thinker": {
		"name": "The Deep Thinker",
		"purpose": "To understand how things work and search for truth.",
		"mbti": "INTP",
	},
	"warm_guardian": {
		"name": "The Warm Guardian",
		"purpose": "To care for people and help them feel they belong.",
		"mbti": "ESFJ",
	},
	"faithful_shield": {
		"name": "The Faithful Shield",
		"purpose": "To protect others and support their hearts.",
		"mbti": "ISFJ",
	},
	"radiant_star": {
		"name": "The Radiant Star",
		"purpose": "To bring joy, colour, and energy into the world.",
		"mbti": "ESFP",
	},
	"silent_artist": {
		"name": "The Silent Artist",
		"purpose": "To create beauty and express feelings through art.",
		"mbti": "ISFP",
	},
	"steadfast_builder": {
		"name": "The Steadfast Builder",
		"purpose": "To bring order, solve problems, and build strong teams.",
		"mbti": "ESTJ",
	},
	"loyal_keeper": {
		"name": "The Loyal Keeper",
		"purpose": "To protect good things and be honest and dependable.",
		"mbti": "ISTJ",
	},
	"fearless_explorer": {
		"name": "The Fearless Explorer",
		"purpose": "To act with courage and help others face challenges.",
		"mbti": "ESTP",
	},
	"calm_craftsman": {
		"name": "The Calm Craftsman",
		"purpose": "To fix problems, make useful things, and stay calm under pressure.",
		"mbti": "ISTP",
	},
}

## Which identities each kind of choice leans towards. A choice never picks an
## identity on its own; it only adds weight, so a player who did a bit of
## everything gets a spread rather than a verdict.
const AFFINITIES := {
	"artwork": ["joyful_creator", "silent_artist", "radiant_star", "gentle_peacemaker"],
	"cleared_thoughts": ["wise_strategist", "deep_thinker", "calm_craftsman", "bold_architect"],
	"feeling": ["guiding_light", "quiet_visionary", "warm_guardian", "faithful_shield"],
	"helped_milo": ["guiding_light", "warm_guardian", "faithful_shield"],
	"explored": ["fearless_explorer", "bright_spark", "radiant_star"],
	"built": ["steadfast_builder", "loyal_keeper", "bold_architect"],
}


static func all_ids() -> Array:
	return IDENTITIES.keys()


static func info(identity_id: String) -> Dictionary:
	return IDENTITIES.get(identity_id, {})


static func display_name(identity_id: String) -> String:
	return IDENTITIES.get(identity_id, {}).get("name", "")


## Reads the journey's choice log and suggests a few identities that fit.
##
## Returns a list of `{id, name, purpose, score}` sorted strongest first. The
## caller shows these as options — never as a result — and always leaves room
## for "I am still discovering".
static func suggest(choice_log: Array, how_many: int = 3) -> Array:
	var scores := {}
	for identity_id in IDENTITIES:
		scores[identity_id] = 0.0

	for entry in choice_log:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var kind: String = str(entry.get("kind", ""))
		if not AFFINITIES.has(kind):
			continue
		# Earlier matches in the affinity list lean a little harder.
		var leaning: Array = AFFINITIES[kind]
		for i in leaning.size():
			var identity_id: String = leaning[i]
			scores[identity_id] = scores[identity_id] + (1.0 - float(i) * 0.15)

	var ranked: Array = []
	for identity_id in scores:
		if scores[identity_id] <= 0.0:
			continue
		ranked.append({
			"id": identity_id,
			"name": IDENTITIES[identity_id]["name"],
			"purpose": IDENTITIES[identity_id]["purpose"],
			"score": scores[identity_id],
		})

	ranked.sort_custom(func(a, b): return a["score"] > b["score"])

	# A player who has barely played gets the gentlest possible spread rather
	# than nothing at all.
	if ranked.is_empty():
		for identity_id in ["joyful_creator", "gentle_peacemaker", "bright_spark"]:
			ranked.append({
				"id": identity_id,
				"name": IDENTITIES[identity_id]["name"],
				"purpose": IDENTITIES[identity_id]["purpose"],
				"score": 0.0,
			})

	return ranked.slice(0, maxi(1, how_many))
