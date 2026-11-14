extends Node

var _grass_materials: Array[ShaderMaterial] = []
var _player: Node3D


func _ready() -> void:
	call_deferred("_discover_grass")


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return
	for material in _grass_materials:
		if is_instance_valid(material):
			material.set_shader_parameter("interracting_object_pos", _player.global_position)


func _discover_grass() -> void:
	var grass := get_node_or_null("../Environment/Grass")
	if grass == null:
		return
	for item in grass.get_children():
		if not ("override_material" in item):
			continue
		var material := item.override_material as ShaderMaterial
		if material != null and material not in _grass_materials:
			_grass_materials.append(material)
