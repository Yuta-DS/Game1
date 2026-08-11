extends Node

const ImageSubjectExtractor := preload("res://scripts/creation_world/image_subject_extractor.gd")

signal guide_ready(guide: Dictionary, degraded: bool)
signal world_ready(manifest: Dictionary, degraded: bool)
signal artwork_changed(path: String)

const SAVE_PATH := "user://creation_worlds.json"
const MANIFEST_VERSION := 2

var save_path := SAVE_PATH
var current_artwork_path := ""
var current_title := "My Living Artwork"
var worlds: Dictionary = {}


func _ready() -> void:
	_load_state()


func prepare_artwork(path: String, title: String = "") -> void:
	current_artwork_path = path
	current_title = title.strip_edges()
	if current_title.is_empty():
		current_title = path.get_file().get_basename().replace("_", " ")
	if current_title.is_empty():
		current_title = "My Living Artwork"

	var key := _current_key()
	if not worlds.has(key):
		worlds[key] = {
			"source_path": path,
			"active_path": path,
			"title": current_title,
			"guide": {},
			"manifest": {},
			"variations": [],
			"world_drawings": [],
		}
	else:
		worlds[key]["source_path"] = path
		worlds[key]["title"] = current_title
	_save_state()
	artwork_changed.emit(path)


func has_current_artwork() -> bool:
	return not current_artwork_path.is_empty() and FileAccess.file_exists(current_artwork_path)


func current_record() -> Dictionary:
	var key := _current_key()
	if not worlds.has(key):
		return {}
	return worlds[key]


func active_artwork_path() -> String:
	return str(current_record().get("active_path", current_artwork_path))


func current_guide() -> Dictionary:
	return current_record().get("guide", {})


func current_manifest() -> Dictionary:
	var manifest = current_record().get("manifest", {})
	if not manifest is Dictionary or int(manifest.get("schema_version", 0)) != MANIFEST_VERSION:
		return {}
	return manifest


func current_world_is_semantic() -> bool:
	return _manifest_is_semantic_ready(current_manifest())


func request_creative_guide(prompt: String, callback: Callable) -> void:
	var image := _load_current_image()
	if image == null:
		callback.call(false, {"error": "The artwork could not be opened."})
		return

	if not _can_request_ai():
		var local := _offline_guide()
		_store_guide(local)
		guide_ready.emit(local, true)
		callback.call(true, {"guide": local, "degraded": true, "ai_source": "on-device"})
		return

	APIManager.request_creative_guide(prompt, image, current_title,
		func(ok: bool, response: Dictionary) -> void:
			var guide: Dictionary
			var degraded := true
			if ok and response.get("guide") is Dictionary:
				guide = _normalise_guide(response["guide"])
				degraded = bool(response.get("degraded", false))
			else:
				guide = _offline_guide()
				response = {
					"guide": guide,
					"degraded": true,
					"ai_source": "on-device",
					"recovery_message": str(response.get("error", "The AI guide will retry next time.")),
				}
			_store_guide(guide)
			guide_ready.emit(guide, degraded)
			callback.call(true, response)
	)


func request_world(prompt: String, callback: Callable, update_existing := false) -> void:
	var image := _load_current_image()
	if image == null:
		callback.call(false, {"error": "The artwork could not be opened."})
		return

	var existing := current_manifest() if update_existing else {}
	if not _can_request_ai():
		callback.call(false, _semantic_world_error("The vision server is not available for this session."))
		return

	APIManager.request_world_manifest(
		prompt,
		current_guide(),
		image,
		current_title,
		func(ok: bool, response: Dictionary) -> void:
			var manifest: Dictionary
			var degraded := true
			var ai_source := str(response.get("ai_source", ""))
			if ok and response.get("world_manifest") is Dictionary \
					and ai_source in ["primary", "backup", "cache"]:
				manifest = _normalise_manifest(response["world_manifest"])
				degraded = bool(response.get("degraded", false))
				manifest["semantic_ready"] = _manifest_is_semantic_ready(manifest, true)
				manifest["vision_source"] = ai_source
				if not bool(manifest["semantic_ready"]):
					callback.call(false, _semantic_world_error("Vision could not identify enough separate subjects in this artwork yet."))
					return
			elif update_existing and _manifest_is_semantic_ready(existing):
				# An outage must not replace a previously valid world with fake blocks.
				manifest = existing.duplicate(true)
				manifest["recovery"] = {"mode": "preserved", "retry_automatically": true}
				degraded = true
				response = {
					"world_manifest": manifest,
					"semantic_ready": true,
					"degraded": true,
					"ai_source": "preserved",
					"recovery_message": "Your existing semantic world was preserved while vision reconnects.",
				}
			else:
				callback.call(false, _semantic_world_error(str(response.get(
					"error",
					"Vision is reconnecting. Stay in the gallery and try this artwork again in a moment."
				))))
				return
			_store_manifest(manifest)
			world_ready.emit(manifest, degraded)
			response["world_manifest"] = manifest
			response["semantic_ready"] = true
			callback.call(true, response),
		existing
	)


func select_variation(path: String, style: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var record := current_record()
	record["active_path"] = path
	var variations: Array = record.get("variations", [])
	variations.append({"path": path, "style": style, "created_at": Time.get_unix_time_from_system()})
	record["variations"] = variations
	worlds[_current_key()] = record
	_save_state()
	artwork_changed.emit(path)


func keep_original() -> void:
	var record := current_record()
	record["active_path"] = current_artwork_path
	worlds[_current_key()] = record
	_save_state()
	artwork_changed.emit(current_artwork_path)


func add_local_idea(prompt: String) -> Dictionary:
	var clean := prompt.strip_edges()
	if clean.is_empty():
		clean = "a friendly glowing shape"
	var manifest := _offline_manifest(current_manifest())
	var object_type := _object_type_from_words(clean.to_lower())
	var object_id := "player_idea_%d" % Time.get_ticks_usec()
	var objects: Array = manifest.get("objects", [])
	objects.append({
		"id": object_id,
		"type": object_type,
		"description": clean,
		"position_hint": "near the player",
		"scale_hint": "medium",
		"source": "player_addition",
		"asset_hint": clean,
		"child_editable": true,
	})
	manifest["objects"] = objects
	var animations: Array = manifest.get("animations", [])
	animations.append({
		"object_id": object_id,
		"action": _animation_for_type(object_type),
		"speed": 0.65,
	})
	manifest["animations"] = animations
	var interactions: Array = manifest.get("interactions", [])
	interactions.append({
		"object_id": object_id,
		"action": "touch_react",
		"response": "Your new idea notices you and comes alive.",
	})
	manifest["interactions"] = interactions
	_store_manifest(manifest)
	return manifest


func add_world_drawing(path: String, world_position: Vector3) -> Dictionary:
	var record := current_record()
	var drawings: Array = record.get("world_drawings", [])
	var entry := {
		"path": path,
		"position": [world_position.x, world_position.y, world_position.z],
		"created_at": Time.get_unix_time_from_system(),
	}
	drawings.append(entry)
	record["world_drawings"] = drawings
	worlds[_current_key()] = record
	_save_state()
	return entry


func world_drawings() -> Array:
	return current_record().get("world_drawings", [])


func _store_guide(guide: Dictionary) -> void:
	var record := current_record()
	record["guide"] = _normalise_guide(guide)
	worlds[_current_key()] = record
	_save_state()


func _store_manifest(manifest: Dictionary) -> void:
	var record := current_record()
	record["manifest"] = _normalise_manifest(manifest)
	worlds[_current_key()] = record
	_save_state()


func _normalise_guide(raw: Dictionary) -> Dictionary:
	var guide := raw.duplicate(true)
	guide["title"] = str(guide.get("title", current_title))
	guide["celebration"] = str(guide.get("celebration", "Your artwork already has its own special spark."))
	guide["scene_description"] = str(guide.get("scene_description", "Your marks can become a world with depth, light, and movement."))
	guide["enhancement_prompt"] = str(guide.get("enhancement_prompt", "Preserve every original mark and add only gentle clarity and depth."))
	var styles = guide.get("style_ideas", [])
	if not styles is Array or styles.is_empty():
		styles = ["soft watercolor", "paper collage", "storybook pastel"]
	guide["style_ideas"] = styles.slice(0, 3)
	return guide


func _normalise_manifest(raw: Dictionary) -> Dictionary:
	var manifest := raw.duplicate(true)
	manifest["schema_version"] = MANIFEST_VERSION
	manifest["world_title"] = str(manifest.get("world_title", current_title))
	manifest["visual_style"] = str(manifest.get("visual_style", "child-created storybook world"))
	for key in ["objects", "characters", "animations", "interactions", "zones", "player_edit_options"]:
		if not manifest.has(key) or not manifest.get(key) is Array:
			manifest[key] = []
	if manifest["objects"].is_empty():
		var inventory = current_guide().get("visual_inventory", [])
		if inventory is Array:
			for i in inventory.size():
				var inventory_item = inventory[i]
				if not inventory_item is Dictionary:
					continue
				var subject: Dictionary = inventory_item.duplicate(true)
				subject["id"] = str(subject.get("id", "visual_subject_%02d" % i))
				subject["type"] = str(subject.get("type", "art_shape"))
				subject["description"] = str(subject.get("description", subject.get("label", "A visible subject from the artwork")))
				if subject.has("suggested_motion"):
					manifest["animations"].append({
						"object_id": subject["id"],
						"action": str(subject["suggested_motion"]),
						"speed": 0.55,
					})
				manifest["objects"].append(subject)
	if manifest["objects"].is_empty():
		manifest["objects"] = _default_objects()
	# Stable, unique ids are required for animation, interaction and updates.
	var used_ids := {}
	for collection_key in ["objects", "characters"]:
		var cleaned: Array = []
		for item in manifest[collection_key].slice(0, 48):
			if not item is Dictionary:
				continue
			var subject: Dictionary = item.duplicate(true)
			var fallback_id := "%s_%02d" % [collection_key.trim_suffix("s"), cleaned.size()]
			var subject_id := str(subject.get("id", fallback_id)).validate_node_name()
			if subject_id.is_empty():
				subject_id = fallback_id
			# A vision provider may list the same subject in objects and characters.
			# Keep one physical actor rather than cloning the painted person/animal.
			if used_ids.has(subject_id):
				continue
			subject["id"] = subject_id
			subject["type"] = str(subject.get("type", "art_shape"))
			subject["description"] = str(subject.get("description", subject.get("label", subject["type"])))
			used_ids[subject_id] = true
			cleaned.append(subject)
		manifest[collection_key] = cleaned
	if not manifest.get("palette", []) is Array or manifest.get("palette", []).is_empty():
		manifest["palette"] = _palette_from_current_image()
	# Interaction is part of the contract, not an optional AI flourish. If a
	# provider omits one, add a safe default so every manifested subject in the
	# child's picture still responds inside the mini-world.
	var interactive_ids := {}
	for interaction in manifest["interactions"]:
		if interaction is Dictionary:
			interactive_ids[str(interaction.get("object_id", ""))] = true
	for collection_key in ["objects", "characters"]:
		for item in manifest[collection_key]:
			if not item is Dictionary:
				continue
			var item_id := str(item.get("id", ""))
			if item_id.is_empty() or interactive_ids.has(item_id):
				continue
			manifest["interactions"].append({
				"object_id": item_id,
				"action": "touch_react",
				"response": "%s comes alive when you reach it." % str(item.get("description", item.get("type", "This part of your artwork"))).capitalize(),
			})
			interactive_ids[item_id] = true
	return manifest


func _offline_guide() -> Dictionary:
	return _normalise_guide({
		"title": current_title,
		"celebration": "Your idea already has its own special spark.",
		"scene_description": "Your original artwork can open into a gentle world of layered colour, friendly shapes, and movement.",
		"enhancement_prompt": "Preserve every original mark. Optionally add gentle lighting, clearer depth, and soft texture without changing the artist's idea.",
		"style_ideas": ["soft watercolor", "paper collage", "storybook pastel"],
		"offline": true,
	})


func _offline_manifest(existing: Dictionary = {}) -> Dictionary:
	if not existing.is_empty():
		var preserved := _normalise_manifest(existing)
		preserved["recovery"] = {"mode": "on-device", "retry_automatically": true}
		preserved["semantic_ready"] = bool(existing.get("semantic_ready", false))
		return preserved
	var extracted_objects := ImageSubjectExtractor.extract(_load_current_image())
	if extracted_objects.is_empty():
		extracted_objects = _default_objects()
	var extracted_animations: Array = []
	for subject in extracted_objects:
		extracted_animations.append({
			"object_id": str(subject.get("id", "")),
			"action": "breathe",
			"speed": 0.45,
		})
	var manifest := _normalise_manifest({
		"world_title": current_title,
		"celebration": "Your artwork has opened into a living world.",
		"visual_style": "child-created storybook world",
		"environment": "A bright, calm landscape shaped by the artwork's colours.",
		"palette": _palette_from_current_image(),
		"terrain": {"type": "gentle_meadow", "traversable": true, "max_slope_degrees": 18},
		"objects": extracted_objects,
		"characters": [],
		"animations": extracted_animations,
		"interactions": [],
		"player_edit_options": [{"id": "draw_more", "label": "Draw something new in this world", "available": true}],
		"recovery": {"mode": "on-device", "retry_automatically": true},
	})
	manifest["semantic_ready"] = false
	manifest["vision_source"] = "on-device"
	return manifest


func _default_objects() -> Array:
	return [{
		"id": "complete_artwork_subject",
		"label": "the complete artwork",
		"type": "art_shape",
		"description": "The complete artwork reconstructed as a physical 3D object",
		"bounding_box": {"x": 0.0, "y": 0.0, "width": 1.0, "height": 1.0},
		"normalized_position": {"x": 0.5, "y": 0.5},
		"position_hint": "center",
		"scale_hint": "large",
		"source": "drawing",
		"asset_hint": "extruded original artwork",
		"child_editable": false,
	}]


func _palette_from_current_image() -> Array:
	var image := _load_current_image()
	if image == null:
		return ["#86c5da", "#ffd166", "#8ac926", "#ff99c8"]
	var colours: Array = []
	var size := image.get_size()
	for point in [Vector2(0.2, 0.2), Vector2(0.75, 0.2), Vector2(0.5, 0.5), Vector2(0.2, 0.78), Vector2(0.78, 0.78)]:
		var x := clampi(int(size.x * point.x), 0, size.x - 1)
		var y := clampi(int(size.y * point.y), 0, size.y - 1)
		colours.append("#" + image.get_pixel(x, y).to_html(false))
	return colours


func _load_current_image() -> Image:
	var path := active_artwork_path()
	if path.is_empty():
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return image


func _has_session_token() -> bool:
	if not str(APIManager.auth_token).is_empty():
		return true
	var global := get_node_or_null("/root/Global")
	return global != null and not str(global.get("auth_token")).is_empty() \
		and str(global.get("auth_token")) != "invalid_token"


func _can_request_ai() -> bool:
	# The bundled server permits unsigned requests only from the same machine.
	# Remote deployments still require the player's JWT.
	var base_url := str(APIManager.BASE_URL).to_lower()
	return _has_session_token() or base_url.begins_with("http://127.0.0.1") \
		or base_url.begins_with("http://localhost") or base_url.begins_with("http://[::1]")


func _manifest_is_semantic_ready(manifest: Dictionary, trust_vision_source := false) -> bool:
	if manifest.is_empty() or int(manifest.get("schema_version", 0)) != MANIFEST_VERSION:
		return false
	if not trust_vision_source and not bool(manifest.get("semantic_ready", false)):
		return false
	var generic_types := {
		"": true,
		"art_shape": true,
		"friendly_shape": true,
		"painted_region": true,
		"artwork_portal": true,
		"shape": true,
		"region": true,
		"object": true,
		"unknown": true,
	}
	var described_with_bounds := 0
	for collection_key in ["objects", "characters"]:
		var subjects = manifest.get(collection_key, [])
		if not subjects is Array:
			continue
		for value in subjects:
			if not value is Dictionary:
				continue
			var subject: Dictionary = value
			var type_name := str(subject.get("type", "")).strip_edges().to_lower()
			if not generic_types.has(type_name):
				return true
			if subject.get("bounding_box") is Dictionary \
					and not str(subject.get("description", subject.get("label", ""))).is_empty():
				described_with_bounds += 1
	# Abstract work may not have named real-world objects, but a vision model can
	# still separate multiple meaningful, bounded shapes. The local block fallback
	# is never trusted because callers cannot pass trust_vision_source for it.
	return trust_vision_source and described_with_bounds >= 3


func _semantic_world_error(detail: String) -> Dictionary:
	return {
		"error": detail,
		"semantic_ready": false,
		"degraded": true,
		"ai_source": "unavailable",
		"recovery_message": "No placeholder block world was opened. Your artwork is safe; retry when vision is available.",
	}


func _object_type_from_words(text: String) -> String:
	for type_name in ["bird", "butterfly", "tree", "flower", "castle", "house", "boat", "fish", "cloud", "star", "moon", "river", "bridge", "animal"]:
		if text.contains(type_name):
			return type_name
	return "friendly_shape"


func _animation_for_type(type_name: String) -> String:
	if type_name in ["bird", "butterfly", "cloud"]:
		return "fly"
	if type_name in ["fish", "boat"]:
		return "glide"
	if type_name in ["tree", "flower"]:
		return "sway"
	if type_name in ["star", "moon", "friendly_shape"]:
		return "float"
	return "breathe"


func _current_key() -> String:
	if current_artwork_path.is_empty():
		return "unsaved"
	return current_artwork_path.sha256_text()


func _save_state() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("CreationWorldState: could not write %s" % save_path)
		return
	file.store_string(JSON.stringify({
		"current_artwork_path": current_artwork_path,
		"current_title": current_title,
		"worlds": worlds,
	}))


func _load_state() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	current_artwork_path = str(data.get("current_artwork_path", ""))
	current_title = str(data.get("current_title", "My Living Artwork"))
	worlds = data.get("worlds", {}) if data.get("worlds", {}) is Dictionary else {}
