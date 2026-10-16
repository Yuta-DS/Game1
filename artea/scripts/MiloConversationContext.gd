class_name MiloConversationContext
extends RefCounted

# Session-only context for Milo. Nothing in this class writes to user://, logs
# player text, or sends it over the network. The bounded memory exists only for
# the lifetime of the running game.

const SEED_PATH := "res://data/milo_wisdom_seed.json"
const MAX_RECENT_TURNS := 4
const MAX_PHRASE_HISTORY := 12
const MAX_TOPIC_MEMORY := 6
const MAX_PLAYER_EXCERPT := 180
const MAX_MILO_EXCERPT := 240

var personality: Dictionary = {}
var scene_state := {
	"scene": "unknown",
	"stage": 0,
	"audience_mode": "faith",
	"activity": "conversation",
	"danger": false,
}
var relationship_memory := {
	"interaction_count": 0,
	"rapport_stage": "new",
	"familiar_topics": [],
	"last_expressed_state": "",
	"response_preference": "balanced",
}
var recent_turns: Array[Dictionary] = []
var phrase_history: Array[String] = []


func _init() -> void:
	var seed := _read_json(SEED_PATH)
	personality = seed.get("personality", _default_personality()).duplicate(true)


func update_scene(next_scene: String, stage := 0, audience_mode := "faith",
		activity := "conversation", danger := false) -> void:
	scene_state = {
		"scene": _clean_label(next_scene, "unknown"),
		"stage": maxi(0, int(stage)),
		"audience_mode": "universal" if audience_mode == "universal" else "faith",
		"activity": _clean_label(activity, "conversation"),
		"danger": bool(danger),
	}


func observe_player_message(message: String, expressed_state := "",
		topic := "") -> void:
	var lower := message.to_lower()
	if _contains_any(lower, ["be direct", "short answer", "keep it short", "briefly"]):
		relationship_memory["response_preference"] = "concise"
	elif _contains_any(lower, ["explain more", "more detail", "in detail", "go deeper"]):
		relationship_memory["response_preference"] = "detailed"
	elif _contains_any(lower, ["ask me a question", "help me reflect"]):
		relationship_memory["response_preference"] = "reflective"
	if not expressed_state.is_empty() and expressed_state not in ["unclear", "urgent_support"]:
		relationship_memory["last_expressed_state"] = _clean_label(expressed_state, "")
	if not topic.is_empty() and topic not in ["domain_guide", "scripture_reference",
			"scripture_not_found"]:
		_remember_topic(topic)


func choose_intention(category := "", expressed_state := "") -> String:
	if bool(scene_state.get("danger", false)) or expressed_state == "urgent_support":
		return "protect"
	if category in ["scripture_reference", "scripture_not_found"]:
		return "share_knowledge"
	if not category.is_empty() and category != "unclear":
		return "share_knowledge"
	match expressed_state:
		"worried", "stressed", "sad", "lonely":
			return "reassure"
		"frustrated":
			return "guide"
		"proud":
			return "celebrate"
		"unclear":
			return "question"
	return "reflect"


func naturalize_reflection(response: Dictionary, player_message := "") -> String:
	var emotion := str(response.get("emotion", "unclear"))
	var intention := choose_intention("", emotion)
	var opener := choose_phrase("intent:%s" % intention,
			_intent_openers(intention), player_message)
	var validate := _without_robotic_lead(str(response.get("validate", "")))
	var paragraphs := PackedStringArray()
	paragraphs.append("%s %s" % [opener, validate] if not validate.is_empty() else opener)
	for key in ["reflect", "strength"]:
		var value := str(response.get(key, "")).strip_edges()
		if not value.is_empty():
			paragraphs.append(value)
	var guidance := str(response.get("guidance", "")).strip_edges()
	var activity := str(response.get("activity", "")).strip_edges()
	if not guidance.is_empty() and not activity.is_empty():
		paragraphs.append("%s\n%s" % [guidance, activity])
	elif not guidance.is_empty():
		paragraphs.append(guidance)
	elif not activity.is_empty():
		paragraphs.append(activity)
	return "\n\n".join(paragraphs)


func choose_phrase(scope: String, candidates: Array, salt := "") -> String:
	if candidates.is_empty():
		return "Let us look at that together."
	var start := posmod((salt + scope + str(relationship_memory.interaction_count)).hash(),
			candidates.size())
	for offset in range(candidates.size()):
		var candidate := str(candidates[(start + offset) % candidates.size()]).strip_edges()
		if not phrase_history.has(_phrase_key(candidate)):
			remember_phrase(candidate)
			return candidate
	var fallback := str(candidates[start]).strip_edges()
	remember_phrase(fallback)
	return fallback


func record_exchange(player_message: String, milo_response: String,
		intention := "reflect") -> void:
	var player_excerpt := _bounded_excerpt(player_message, MAX_PLAYER_EXCERPT)
	var milo_excerpt := _bounded_excerpt(milo_response, MAX_MILO_EXCERPT)
	if not player_excerpt.is_empty() or not milo_excerpt.is_empty():
		recent_turns.append({
			"player": player_excerpt,
			"milo": milo_excerpt,
			"intention": _clean_label(intention, "reflect"),
		})
		while recent_turns.size() > MAX_RECENT_TURNS:
			recent_turns.pop_front()
	relationship_memory["interaction_count"] = int(
			relationship_memory.get("interaction_count", 0)) + 1
	relationship_memory["rapport_stage"] = _rapport_for_count(int(
			relationship_memory.interaction_count))
	remember_phrase(milo_excerpt.get_slice(".", 0))


func remember_phrase(phrase: String) -> void:
	var key := _phrase_key(phrase)
	if key.is_empty():
		return
	phrase_history.erase(key)
	phrase_history.append(key)
	while phrase_history.size() > MAX_PHRASE_HISTORY:
		phrase_history.pop_front()


func snapshot() -> Dictionary:
	return {
		"personality": personality.duplicate(true),
		"scene_state": scene_state.duplicate(true),
		"relationship_memory": relationship_memory.duplicate(true),
		"recent_turns": recent_turns.duplicate(true),
		"phrase_history": phrase_history.duplicate(),
	}


func build_prompt_context() -> String:
	var presence: Array = personality.get("presence", [])
	var values: Array = personality.get("values", [])
	var lines := PackedStringArray([
		"MILO IDENTITY: %s" % str(personality.get("identity",
				"Artéa's elderly feline scholar and companion")),
		"PERSONALITY: %s" % ", ".join(PackedStringArray(presence)),
		"VALUES: %s" % ", ".join(PackedStringArray(values)),
		"CURRENT SCENE: %s; stage %d; activity %s; mode %s" % [
			str(scene_state.scene), int(scene_state.stage), str(scene_state.activity),
			str(scene_state.audience_mode)],
		"RELATIONSHIP: %s; %d completed exchanges; response preference %s" % [
			str(relationship_memory.rapport_stage),
			int(relationship_memory.interaction_count),
			str(relationship_memory.response_preference)],
	])
	var topics: Array = relationship_memory.get("familiar_topics", [])
	if not topics.is_empty():
		lines.append("EXPLICIT INTERESTS THIS SESSION: %s" % ", ".join(
				PackedStringArray(topics)))
	var state := str(relationship_memory.get("last_expressed_state", ""))
	if not state.is_empty():
		lines.append("LAST EMOTION THE PLAYER'S WORDS MATCHED: %s (do not treat as diagnosis)" % state)
	if not recent_turns.is_empty():
		lines.append("RECENT TURNS (local, shortened):")
		for turn in recent_turns:
			lines.append("- Player: %s" % str(turn.player))
			lines.append("  Milo: %s" % str(turn.milo))
	if not phrase_history.is_empty():
		lines.append("RECENT OPENINGS TO AVOID REPEATING: %s" % "; ".join(
				PackedStringArray(phrase_history.slice(maxi(0, phrase_history.size() - 6)))))
	lines.append("Choose one primary intention. Answer the player's meaning first and do not recite this context.")
	return "\n".join(lines)


func clear_session_memory() -> void:
	relationship_memory = {
		"interaction_count": 0,
		"rapport_stage": "new",
		"familiar_topics": [],
		"last_expressed_state": "",
		"response_preference": "balanced",
	}
	recent_turns.clear()
	phrase_history.clear()


func _intent_openers(intention: String) -> Array:
	var configured: Dictionary = personality.get("intent_openers", {})
	return configured.get(intention, configured.get("reflect", [
		"Let us think about that together.",
	]))


func _remember_topic(topic: String) -> void:
	var topics: Array = relationship_memory.get("familiar_topics", [])
	var clean := _clean_label(topic, "")
	if clean.is_empty():
		return
	topics.erase(clean)
	topics.append(clean)
	while topics.size() > MAX_TOPIC_MEMORY:
		topics.pop_front()
	relationship_memory["familiar_topics"] = topics


func _without_robotic_lead(value: String) -> String:
	var clean := value.strip_edges()
	for lead in ["I hear you. ", "I hear you.\n", "Thank you for sharing that with me. "]:
		if clean.begins_with(lead):
			return clean.trim_prefix(lead).strip_edges()
	return clean


func _rapport_for_count(count: int) -> String:
	if count >= 12:
		return "established"
	if count >= 5:
		return "familiar"
	if count >= 2:
		return "acquainted"
	return "new"


func _bounded_excerpt(value: String, limit: int) -> String:
	var clean := " ".join(value.strip_edges().split(" ", false))
	if clean.length() <= limit:
		return clean
	var excerpt := clean.left(limit - 1)
	var boundary := excerpt.rfind(" ")
	if boundary > limit / 2:
		excerpt = excerpt.left(boundary)
	return excerpt + "…"


func _phrase_key(value: String) -> String:
	return _bounded_excerpt(value.to_lower(), 72).trim_suffix("…").strip_edges()


func _clean_label(value: String, fallback: String) -> String:
	var clean := value.strip_edges().replace("\n", " ")
	return _bounded_excerpt(clean, 80) if not clean.is_empty() else fallback


func _contains_any(message: String, cues: Array) -> bool:
	for cue in cues:
		if message.contains(str(cue)):
			return true
	return false


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _default_personality() -> Dictionary:
	return {
		"identity": "Artéa's elderly feline scholar, guide, and trusted companion",
		"presence": ["warm", "observant", "cultured", "quietly playful"],
		"values": ["curiosity", "kindness", "patience", "courage", "truth"],
		"intent_openers": {
			"reflect": ["Let us think about that together."],
		},
	}
