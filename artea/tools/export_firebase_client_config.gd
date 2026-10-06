extends SceneTree
const PublicConfig = preload("res://addons/godot-firebase/firebase/public_client_config.gd")

func _initialize() -> void:
	var env := ConfigFile.new()
	if env.load("res://addons/godot-firebase/.env") != OK:
		push_error("Web export requires the local Firebase configuration; no values logged.")
		quit(1)
		return
	var safe: Dictionary = PublicConfig.from_environment(env)
	var missing: Array[String] = PublicConfig.missing_required(safe)
	if not missing.is_empty():
		push_error("Firebase client configuration is missing fields: " + ", ".join(missing))
		quit(1)
		return
	var output := FileAccess.open(PublicConfig.PATH, FileAccess.WRITE)
	if output == null:
		push_error("Cannot write Firebase public client configuration.")
		quit(1)
		return
	output.store_string(JSON.stringify(safe, "\t") + "\n")
	output.close()
	print("Firebase Web configuration generated: public allowlisted fields only.")
	quit(0)
