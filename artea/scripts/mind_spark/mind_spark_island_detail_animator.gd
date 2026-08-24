extends Node3D

@export var variant_index := 0

var _elapsed := 0.0
var _packets: Array[Node3D] = []
var _orbiters: Array[Node3D] = []


func _ready() -> void:
	call_deferred("_cache_details")


func _cache_details() -> void:
	_packets.clear()
	_orbiters.clear()
	for node in find_children("*", "Node3D", true, false):
		var detail := node as Node3D
		if detail.has_meta("detail_packet"):
			_packets.append(detail)
		if detail.has_meta("detail_orbit_speed"):
			_orbiters.append(detail)


func _process(delta: float) -> void:
	_elapsed += delta
	for orbiter in _orbiters:
		orbiter.rotate_y(delta * float(orbiter.get_meta("detail_orbit_speed")))
	for packet in _packets:
		var start: Vector3 = packet.get_meta("path_start")
		var finish: Vector3 = packet.get_meta("path_end")
		var phase := float(packet.get_meta("packet_phase"))
		var speed := float(packet.get_meta("packet_speed"))
		var progress := fposmod(phase + _elapsed * speed, 1.0)
		packet.position = start.lerp(finish, progress)
		var pulse := 0.82 + sin((_elapsed * 5.0 + phase * TAU) + variant_index * 0.4) * 0.18
		var base_scale: Vector3 = packet.get_meta("packet_base_scale", packet.scale)
		packet.scale = base_scale * pulse
