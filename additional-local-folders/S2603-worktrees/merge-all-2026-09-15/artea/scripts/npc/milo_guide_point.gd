class_name MiloGuidePoint
extends Marker3D

@export var guide_point_id: StringName = &"home"
@export var mission_id: StringName = &"artea_journey"
@export_range(0, 4, 1) var required_stage := 0
@export var arrival_animation: StringName = &"Idle"
@export var facing_direction := Vector3.FORWARD
@export_range(1.5, 8.0, 0.1) var minimum_player_distance := 1.5
@export var one_shot := false
@export var enabled := true


func is_available(stage: int) -> bool:
	return enabled and stage >= required_stage
