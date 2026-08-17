extends SceneTree

const BaseScene := preload("res://scenes/mind_spark/quest_objects/quest_object_base.tscn")
const Catalog := preload("res://scripts/mind_spark/quest_objects/quest_object_catalog.gd")
const OUTPUT_DIR := "res://scenes/mind_spark/quest_objects/models"
const MODEL_NAMES := [
	"thought_spark_socket_model",
	"evidence_scanner_model",
	"perspective_lens_model",
	"memory_constellation_board_model",
	"logic_gate_arch_model",
	"truth_bridge_tile_model",
	"focus_bell_beacon_model",
	"warden_anchor_model",
	"calm_rain_basin_model",
	"identity_reflection_mirror_model",
	"checkpoint_server_root_model",
	"clear_path_projector_model",
]


func _init() -> void:
	call_deferred("_bake")


func _bake() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for index in MODEL_NAMES.size():
		var source := BaseScene.instantiate() as QuestObjectBase
		source.name = "BakeSource"
		source.persist_state = false
		source.definition = Catalog.definition_at(index)
		root.add_child(source)
		await process_frame
		await process_frame
		# Runtime loads the last checked-in model. Baking deliberately replaces
		# that instance with the editor-only authored geometry source before pack.
		for existing in source.visual_root.get_children():
			if existing == source.core or existing.name == "Pedestal":
				continue
			source.visual_root.remove_child(existing)
			existing.free()
		source._build_bake_source_visuals()
		source._apply_visual_state(false)

		var model := Node3D.new()
		model.name = str(MODEL_NAMES[index]).to_pascal_case()
		model.set_meta("quest_object_kind", index)
		model.set_meta("authored_model", true)
		for child in source.visual_root.get_children():
			if child.name in [&"Pedestal", &"Core"]:
				continue
			var duplicate := child.duplicate()
			model.add_child(duplicate)
			_set_owner_recursive(duplicate, model)

		var packed := PackedScene.new()
		var pack_error := packed.pack(model)
		if pack_error != OK:
			push_error("Could not pack %s: %s" % [MODEL_NAMES[index], error_string(pack_error)])
			quit(1)
			return
		var path := "%s/%s.tscn" % [OUTPUT_DIR, MODEL_NAMES[index]]
		var save_error := ResourceSaver.save(packed, path)
		if save_error != OK:
			push_error("Could not save %s: %s" % [path, error_string(save_error)])
			quit(1)
			return
		print("BAKED_MODEL: %s" % path)
		model.free()
		source.queue_free()
		await process_frame
	print("MIND_SPARK_QUEST_OBJECT_MODELS: PASS")
	quit()


func _set_owner_recursive(node: Node, scene_owner: Node) -> void:
	node.owner = scene_owner
	for child in node.get_children():
		_set_owner_recursive(child, scene_owner)
