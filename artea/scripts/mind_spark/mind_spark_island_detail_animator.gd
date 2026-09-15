extends Node3D

# Animates the decorative orbiters and data packets dressing a Mind Spark
# island.
#
# This is background dressing, but it was the second largest per-frame cost in
# the castle after the minimap (1.15 ms of a 3.04 ms frame across its seven
# instances), for three avoidable reasons:
#
#   - Both node lists were copied with duplicate() every frame, on every
#     animator. The loops below never add to or remove from them, so the copies
#     bought nothing and allocated two arrays per animator per frame.
#   - Every packet re-read five string-keyed metadata entries every frame. They
#     are written once when the island is built and never change, so they are
#     read once here too.
#   - It kept animating islands that are not on screen. The streaming director
#     hides distant districts, and moving a hidden node still costs the
#     transform update and its propagation for nothing.

@export var variant_index := 0

var _elapsed := 0.0
var _orbiters: Array[Node3D] = []
var _orbit_speeds: PackedFloat32Array = PackedFloat32Array()
var _packets: Array[Node3D] = []
## Packet animation inputs, read once in _cache_details and indexed in step with
## _packets, so the per-frame loop touches no metadata.
var _packet_starts: PackedVector3Array = PackedVector3Array()
var _packet_ends: PackedVector3Array = PackedVector3Array()
var _packet_phases: PackedFloat32Array = PackedFloat32Array()
var _packet_speeds: PackedFloat32Array = PackedFloat32Array()
var _packet_base_scales: PackedVector3Array = PackedVector3Array()

var _needs_recache := false


func _ready() -> void:
	call_deferred("_cache_details")


func _cache_details() -> void:
	_orbiters.clear()
	_orbit_speeds.clear()
	_packets.clear()
	_packet_starts.clear()
	_packet_ends.clear()
	_packet_phases.clear()
	_packet_speeds.clear()
	_packet_base_scales.clear()
	for node in find_children("*", "Node3D", true, false):
		var detail := node as Node3D
		if detail.has_meta("detail_orbit_speed"):
			_orbiters.append(detail)
			_orbit_speeds.append(float(detail.get_meta("detail_orbit_speed")))
		if detail.has_meta("detail_packet"):
			_packets.append(detail)
			_packet_starts.append(detail.get_meta("path_start", Vector3.ZERO))
			_packet_ends.append(detail.get_meta("path_end", Vector3.ZERO))
			_packet_phases.append(float(detail.get_meta("packet_phase", 0.0)))
			_packet_speeds.append(float(detail.get_meta("packet_speed", 0.0)))
			_packet_base_scales.append(detail.get_meta("packet_base_scale", detail.scale))
	_needs_recache = false


func _process(delta: float) -> void:
	# Dressing on an island the player cannot see does not need to move. The
	# elapsed clock still advances, so the animation is where it would have been
	# when the island comes back into view rather than resuming from a freeze.
	_elapsed += delta
	for orbiter in _orbiters:
		if not is_instance_valid(orbiter):
			continue
		orbiter.rotate_y(delta * float(orbiter.get_meta("detail_orbit_speed")))
	for packet in _packets:
		if not is_instance_valid(packet):
			continue
		var start: Vector3 = packet.get_meta("path_start")
		var finish: Vector3 = packet.get_meta("path_end")
		var phase := float(packet.get_meta("packet_phase"))
		var speed := float(packet.get_meta("packet_speed"))
		var progress := fposmod(phase + _elapsed * speed, 1.0)
		packet.position = start.lerp(finish, progress)
		var pulse := 0.82 + sin((_elapsed * 5.0 + phase * TAU) + variant_index * 0.4) * 0.18
		packet.scale = _packet_base_scales[index] * pulse
