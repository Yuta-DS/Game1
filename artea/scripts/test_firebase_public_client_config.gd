extends SceneTree
const PublicConfig = preload("res://addons/godot-firebase/firebase/public_client_config.gd")
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	var env := ConfigFile.new()
	for key in PublicConfig.KEYS:
		env.set_value(PublicConfig.SECTION, key, "fixture-" + key)
	env.set_value(PublicConfig.SECTION, "clientSecret", "PRIVATE-OAUTH")
	env.set_value(PublicConfig.SECTION, "private_key", "PRIVATE-SERVICE-ACCOUNT")
	env.set_value("firebase/auth_providers", "github_secret", "PRIVATE-PROVIDER")
	var safe: Dictionary = PublicConfig.from_environment(env)
	check(safe.size() == 8, "Expected exactly eight public client fields")
	check(not JSON.stringify(safe).contains("PRIVATE"), "Private fixture values must never be serialized")
	check(PublicConfig.missing_required(safe).is_empty(), "Valid fixture must load")
	check(PublicConfig.missing_required({}).size() == 3, "Empty config must fail validation")
	var malicious := safe.duplicate()
	malicious["apiKey"] = {"secret": "PRIVATE"}
	malicious["auth_providers"] = {"github_secret": "PRIVATE"}
	malicious["clientSecret"] = "PRIVATE"
	check(PublicConfig.missing_required(malicious) == ["apiKey"], "Wrong field types must be rejected")
	check(not JSON.stringify(PublicConfig.allowlisted(malicious)).contains("PRIVATE"), "Runtime reader must also filter unknown fields")
	var path := "user://firebase_public_config_fixture.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(malicious))
	file.close()
	check(PublicConfig.read_client_file(path) == PublicConfig.allowlisted(malicious), "JSON loader must apply same allowlist")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[]")
	file.close()
	check(PublicConfig.read_client_file(path).is_empty(), "Non-object JSON must be rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("PASS Firebase public config: allowlist, secret exclusion, required fields, types and JSON loading")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
