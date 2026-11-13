extends RefCounted

const TASK_PLANT := "heart_melody.task.plant_feeling_seeds"
const TASK_RHYTHM := "heart_melody.task.restore_garden_rhythm"
const PHRASE := [0, 2, 1]
const SYMBOLS := ["Leaf", "Droplet", "Sun"]
const CHOICES := ["Joy", "Sadness", "Frustration", "Fear", "Peace", "Hope", "Sound"]
const COLOURS := [Color("ffc857"), Color("8abce5"), Color("ef9173"), Color("b59bde"), Color("91cba7"), Color("f2acc9"), Color("e4dbc5")]
const ENEMIES := [
	{"id": "wave1_moth", "kind": "moth", "hp": 40, "damage": 8, "warning": 1.0, "recovery": 1.5, "xp": 12},
	{"id": "wave2_moth", "kind": "moth", "hp": 40, "damage": 8, "warning": 1.0, "recovery": 1.5, "xp": 12},
	{"id": "wave2_slime", "kind": "slime", "hp": 50, "damage": 10, "warning": 1.2, "recovery": 1.8, "xp": 15},
]
