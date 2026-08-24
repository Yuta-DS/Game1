class_name QuestObjectDefinition
extends Resource

## Small, data-only description consumed by the one QuestObjectBase scene.
## Object behavior remains bounded by ObjectKind; resources only provide copy,
## progress totals, and visual identity.

enum ObjectKind {
	THOUGHT_SPARK_SOCKET,
	EVIDENCE_SCANNER,
	PERSPECTIVE_LENS,
	MEMORY_CONSTELLATION,
	LOGIC_GATE_ARCH,
	TRUTH_BRIDGE_TILE,
	FOCUS_BELL_BEACON,
	WARDEN_ANCHOR,
	CALM_RAIN_BASIN,
	IDENTITY_REFLECTION_MIRROR,
	CHECKPOINT_SERVER_ROOT,
	CLEAR_PATH_PROJECTOR,
}

@export var object_kind := ObjectKind.THOUGHT_SPARK_SOCKET
@export var display_name := "Thought Spark Socket"
@export_multiline var action_prompt := "PLACE SPARK"
@export_multiline var success_message := "TASK OPEN"
@export var progress_total := 1
@export var accent_color := Color("#72e6ff")
@export var icon_waiting := "◇"
@export var icon_success := "★"
@export var sequence_order: Array[String] = []
@export var identity_evidence_id := ""
@export var linked_task_id := ""


func validated_total() -> int:
	return maxi(1, progress_total)
