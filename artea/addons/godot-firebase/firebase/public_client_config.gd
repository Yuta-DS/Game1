@tool
extends RefCounted
## Public Firebase identifiers only. Never serialize the SDK's whole config.
const PATH := "res://data/firebase_client_config.json"
const SECTION := "firebase/environment_variables"
const KEYS := ["apiKey", "authDomain", "databaseURL", "projectId", "storageBucket", "messagingSenderId", "appId", "measurementId"]
const REQUIRED := ["apiKey", "authDomain", "projectId"]

static func allowlisted(source: Dictionary) -> Dictionary:
	var result := {}
	for key in KEYS:
		var value: Variant = source.get(key, "")
		if value is String and not value.strip_edges().is_empty():
			result[key] = value.strip_edges()
	return result

static func from_environment(env: ConfigFile) -> Dictionary:
	var source := {}
	for key in KEYS:
		source[key] = env.get_value(SECTION, key, "")
	return allowlisted(source)

static func missing_required(config: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	var safe := allowlisted(config)
	for key in REQUIRED:
		if not safe.has(key):
			missing.append(key)
	return missing

static func read_client_file(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	return allowlisted(parsed)
