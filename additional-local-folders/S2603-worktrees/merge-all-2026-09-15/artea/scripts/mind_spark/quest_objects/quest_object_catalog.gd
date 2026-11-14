class_name MindSparkQuestObjectCatalog
extends RefCounted

const OBJECT_PATHS := [
	"res://resources/mind_spark/quest_objects/01_thought_spark_socket.tres",
	"res://resources/mind_spark/quest_objects/02_evidence_scanner.tres",
	"res://resources/mind_spark/quest_objects/03_perspective_lens.tres",
	"res://resources/mind_spark/quest_objects/04_memory_constellation.tres",
	"res://resources/mind_spark/quest_objects/05_logic_gate_arch.tres",
	"res://resources/mind_spark/quest_objects/06_truth_bridge_tile.tres",
	"res://resources/mind_spark/quest_objects/07_focus_bell_beacon.tres",
	"res://resources/mind_spark/quest_objects/08_warden_anchor.tres",
	"res://resources/mind_spark/quest_objects/09_calm_rain_basin.tres",
	"res://resources/mind_spark/quest_objects/10_identity_reflection_mirror.tres",
	"res://resources/mind_spark/quest_objects/11_checkpoint_server_root.tres",
	"res://resources/mind_spark/quest_objects/12_clear_path_projector.tres",
]

# Ten story tools repeat across the authored five-quest route. The support-only
# Focus Bell and Clear Path Projector are exposed separately and never solve a
# director step.
const STEP_OBJECT_INDEX := {
	"observatory.scan_signal": 1,
	"observatory.hear_chime": 2,
	"observatory.measure_effect": 1,
	"observatory.light_beacon": 0,
	"forest.trace_echo": 3,
	"forest.grow_counterleaf": 5,
	"forest.align_archive": 2,
	"forest.open_windows": 3,
	"relay.calibrate_beacon": 4,
	"relay.sprout_conduit": 0,
	"relay.route_pulse": 5,
	"relay.weave_bridge": 4,
	"storm.exchange_lenses": 7,
	"storm.scan_distance": 7,
	"storm.raise_shelter": 8,
	"storm.ground_array": 4,
	"storm.bind_welcome_vine": 8,
	"constellation.locate_notice": 3,
	"constellation.name_light": 3,
	"constellation.align_choice": 0,
	"constellation.complete_choice": 9,
}


static func definition_for_step(step_id: String) -> QuestObjectDefinition:
	var index := int(STEP_OBJECT_INDEX.get(step_id, 0))
	return load(OBJECT_PATHS[index]) as QuestObjectDefinition


static func definition_at(index: int) -> QuestObjectDefinition:
	if index < 0 or index >= OBJECT_PATHS.size():
		return null
	return load(OBJECT_PATHS[index]) as QuestObjectDefinition

