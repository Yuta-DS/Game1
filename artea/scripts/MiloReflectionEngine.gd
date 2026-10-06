class_name MiloReflectionEngine
extends RefCounted

# A deliberately small, local-language matcher. It recognises only words the
# player actually typed and describes every result as a possibility, never as
# a diagnosis or a hidden-emotion claim. Messages have no length limit, so
# urgent cues are found anywhere in what the player typed.

const URGENT_CUES := [
	"kill myself", "suicide", "end my life", "hurt myself", "harm myself",
	"self harm", "self-harm", "want to die", "don't want to live",
	"do not want to live", "not safe", "in immediate danger",
	"someone will hurt me", "someone is hurting me",
]

const EMOTION_PROFILES := [
	{
		"id": "stressed",
		"words": ["stress", "stressed", "overwhelmed", "pressure", "busy", "too much"],
		"validate": "I hear you. It sounds like you may have been carrying a lot.",
		"reflect": "The words you used point to pressure or too many demands at once. Feeling stressed does not mean you are weak.",
		"strength": "Naming the pressure can show honesty, courage, and self-awareness. You are more than this moment.",
		"guidance": "Let's explore this together. Which one thought or responsibility feels heaviest, and what is one smaller next step?",
		"activity": "Would you like to visit the Mind Spark Kingdom and practise a kinder, more useful response to that thought?",
		"activity_id": "mind",
	},
	{
		"id": "worried",
		"words": ["worry", "worried", "anxious", "nervous", "afraid", "scared", "unsure", "uncertain"],
		"validate": "I hear you. Worry or uncertainty can make the next step feel larger.",
		"reflect": "From the words you chose, it sounds like not knowing what comes next may be making this moment harder.",
		"strength": "Putting uncertainty into words can show honesty and courage. You are more than this moment.",
		"guidance": "Let's explore this together. What is one small part you can choose now, and one part you can leave for later?",
		"activity": "Would you like to visit the Mind Spark Kingdom, notice one worried thought, and choose one hopeful response?",
		"activity_id": "mind",
	},
	{
		"id": "sad",
		"words": ["sad", "low", "down", "upset", "cry", "crying", "hurt", "heavy"],
		"validate": "I hear you. Thank you for trusting Milo with words for a difficult moment.",
		"reflect": "The words you chose sound heavy or painful. You do not have to pretend that everything is fine.",
		"strength": "Reaching for a check-in can show self-awareness and courage. You are more than this moment.",
		"guidance": "Let's explore this gently. Would company, rest, music, or talking with a trusted person feel kindest right now?",
		"activity": "Would you like to visit Heart Melody and give this feeling a sound without needing to explain everything?",
		"activity_id": "heart",
	},
	{
		"id": "frustrated",
		"words": ["frustrated", "stuck", "annoyed", "angry", "mad", "hate", "can't", "cannot", "failed"],
		"validate": "I hear you. Feeling blocked or frustrated can be tiring.",
		"reflect": "Your words suggest that something is not moving the way you hoped.",
		"strength": "Staying with a challenge long enough to name it can show persistence and flexibility. You are more than this moment.",
		"guidance": "Let's explore this together. Would a smaller step, a different tool, or asking someone for help make it lighter?",
		"activity": "Would you like to visit Creator's Light and make one mark without needing it to be perfect?",
		"activity_id": "creator",
	},
	{
		"id": "lonely",
		"words": ["lonely", "alone", "left out", "ignored", "no one", "nobody", "miss them", "miss someone"],
		"validate": "I hear you. Feeling alone or left out can hurt.",
		"reflect": "The words you chose suggest that connection may be important in this moment.",
		"strength": "Naming a need for connection can show honesty and self-respect. You are more than this lonely moment.",
		"guidance": "Let's explore this gently. Is there one trusted person you could sit with, message, or ask for company?",
		"activity": "Would you like to visit Heart Melody and make a sound that reminds you of connection?",
		"activity_id": "heart",
	},
	{
		"id": "proud",
		"words": ["proud", "excited", "happy", "great", "did it", "finished", "achieved", "won"],
		"validate": "I hear you. That sounds like a moment worth noticing.",
		"reflect": "Your words carry energy or pride about something that happened.",
		"strength": "Recognising your effort can show confidence and gratitude. You are more than one achievement, and your growth matters.",
		"guidance": "Let's explore this together. Which choice, effort, or support helped create this moment?",
		"activity": "Would you like to visit Creator's Light and make a small celebration mark for the effort you want to remember?",
		"activity_id": "creator",
	},
]

const STRENGTH_CUES := {
	"kept trying": "perseverance",
	"tried again": "perseverance",
	"asked for help": "courage and connection",
	"helped": "kindness",
	"made": "creativity",
	"created": "creativity",
	"practised": "commitment",
	"apologised": "responsibility",
}


func reflect(raw_message: String) -> Dictionary:
	var message := _normalise(raw_message)
	if _needs_urgent_support(message):
		return {
			"urgent": true,
			"emotion": "urgent_support",
			"validate": "I am glad you told me. Your safety matters more than continuing the game.",
			"reflect": "Milo is a game companion and cannot keep you safe in an emergency.",
			"strength": "Telling someone can be a courageous next step, and you deserve real support right now.",
			"guidance": "Please go to a trusted adult or another safe person now and show them this screen. Do not stay alone with immediate danger.",
			"activity": "In Australia, call 000 if there is immediate danger. You can also call Kids Helpline on 1800 55 1800 or Lifeline on 13 11 14. Elsewhere, use your local emergency number or Find a Helpline.",
			"activity_id": "support",
		}
	var profile := _best_profile(message)
	var possible_strength := _find_strength(message)
	if profile.is_empty():
		return {
			"emotion": "unclear",
			"validate": "I hear you. Thank you for sharing that with me.",
			"reflect": "I do not want to guess what you feel. Your words may hold something important that does not have a clear label yet.",
			"strength": "Pausing to put an experience into words can show %s. You are more than this moment." % possible_strength,
			"guidance": "Let's explore this together. Which word feels closest right now: stressed, worried, sad, frustrated, lonely, proud, or something else?",
			"activity": "Would you like to visit Heart Melody and begin with a sound before choosing a feeling word?",
			"activity_id": "heart",
		}
	var result := profile.duplicate(true)
	result.erase("words")
	result["emotion"] = str(result["id"])
	result.erase("id")
	if possible_strength != "self-awareness":
		result["strength"] = "%s I also notice a possible strength in what you described: %s." % [
			str(result["strength"]), possible_strength,
		]
	return result


func _needs_urgent_support(message: String) -> bool:
	for cue in URGENT_CUES:
		if message.contains(cue):
			return true
	return false


func _normalise(raw_message: String) -> String:
	return raw_message.strip_edges().to_lower()


func _best_profile(message: String) -> Dictionary:
	var best: Dictionary = {}
	var best_score := 0
	for profile in EMOTION_PROFILES:
		var score := 0
		for cue in profile["words"]:
			if _contains_cue(message, str(cue)):
				score += 1
		if score > best_score:
			best = profile
			best_score = score
	return best


func _find_strength(message: String) -> String:
	for cue in STRENGTH_CUES:
		if _contains_cue(message, str(cue)):
			return str(STRENGTH_CUES[cue])
	return "self-awareness"


func _contains_cue(message: String, cue: String) -> bool:
	if cue.contains(" ") or cue.contains("'"):
		return message.contains(cue)
	var padded := " %s " % message.replace(".", " ").replace(",", " ") \
		.replace("!", " ").replace("?", " ").replace(";", " ").replace(":", " ")
	return padded.contains(" %s " % cue)
