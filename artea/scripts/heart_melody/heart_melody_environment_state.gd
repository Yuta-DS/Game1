class_name HeartMelodyEnvironmentState
extends RefCounted
const Catalog = preload("res://scripts/heart_melody/heart_melody_chapter_catalog.gd")

static func zone_state(zone: int, tasks: Array) -> String:
	if tasks.size() == 10: return "restored"
	var local_tasks: Array = []
	for i in Catalog.TASKS.size():
		if Catalog.ZONE_INDEX[i] == zone: local_tasks.append(Catalog.TASKS[i])
	if local_tasks.all(func(id): return id in tasks): return "completed"
	if local_tasks.any(func(id): return Catalog.available(id, tasks)): return "active"
	return "dormant"

static func colour(zone: int, tasks: Array) -> Color:
	match zone_state(zone, tasks):
		"restored": return Color("75aa78")
		"completed": return Color("8db88b")
		"active": return Color("a4b49a")
	return Color("a1a49a")
