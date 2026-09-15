extends SceneTree

const Kit := preload("res://scripts/heart_melody/heart_nature_kit.gd")
const OUTPUT := "res://assets3D/heart_melody/island_one/glb"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var assets := ["faceted_tree", "flower_drum", "feeling_planter", "oval_deck_sector",
		"faceted_cliff_sector", "arch_bay", "square_pier", "cornice_span",
		"gold_rail_span", "gold_rail_post", "root_buttress", "growing_vine_bridge",
		"heart_gate_arch", "heart_route_stone", "feeling_planter_a", "feeling_planter_b",
		"feeling_planter_c", "drum_leaf", "drum_sun", "drum_droplet",
		"listening_blossom", "comfort_lantern", "song_memory_bench", "faceted_tree_a",
		"faceted_tree_b", "flower_cluster", "shrub_cluster", "echo_moth_shell",
		"pulse_slime_shell"]
	for kind in assets:
		var assembly := Node3D.new()
		assembly.name = kind
		root.add_child(assembly)
		_build_asset(assembly, kind)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_scene(assembly,state) == OK)
		assert(document.write_to_filesystem(state,OUTPUT+"/"+kind+".glb") == OK)
		assembly.queue_free()
		await process_frame
	print("HEART_KIT: editable component GLBs exported")
	quit()


func _build_asset(assembly: Node3D, kind: String) -> void:
	if kind in ["faceted_tree", "faceted_tree_a"]:
		Kit.tree(assembly, Vector3.ZERO)
	elif kind == "faceted_tree_b":
		Kit.tree(assembly, Vector3.ZERO, 1.25)
		Kit.branch(assembly, "SideBough", Vector3(0, 4, 0), Vector3(-4, 8, 1), 0.45, "wood")
	elif kind in ["flower_drum", "drum_leaf", "drum_sun", "drum_droplet"]:
		Kit.cylinder(assembly, "LivingBase", Vector3(0, 0.65, 0), 2, 1.3, "leaf", false, 6)
		var drum := Kit.flower(assembly, Vector3(0, 1.4, 0), 1.7,
			"pink" if kind in ["flower_drum", "drum_leaf"] else ("gold" if kind == "drum_sun" else "blue"))
		drum.name = "MovingPetals"
	elif kind.begins_with("feeling_planter"):
		var variant := 0 if kind in ["feeling_planter", "feeling_planter_a"] else (1 if kind.ends_with("b") else 2)
		Kit.cylinder(assembly, "StoneNest", Vector3(0, 0.6, 0), 1.9 + variant * 0.12, 1.2, "rock", false, 8)
		Kit.cylinder(assembly, "Soil", Vector3(0, 1.22, 0), 1.5, 0.06, "soil", false, 8)
		var bloom := Kit.flower(assembly, Vector3(0, 1.7, 0), 1.1 + variant * 0.08)
		bloom.name = "GrowingBloom"
	elif kind == "oval_deck_sector":
		Kit.ellipse_sector(assembly, "IvoryDeckSector", Vector3.ZERO, Vector2(18, 12), 1.0, -PI / 6.0, PI / 6.0, "ivory")
	elif kind == "faceted_cliff_sector":
		Kit.ellipse_sector(assembly, "CliffSector", Vector3(0, -7, 0), Vector2(18, 12), 14.0, -PI / 6.0, PI / 6.0, "stone", false, 0.58, 6)
	elif kind == "arch_bay":
		for x in [-3.0, 3.0]: Kit.box(assembly, "Pier", Vector3(x, 3, 0), Vector3(1.2, 6, 1.4), "ivory")
		Kit.branch(assembly, "ArchCrown", Vector3(-3, 6, 0), Vector3(3, 6, 0), 0.65, "ivory")
	elif kind == "square_pier":
		Kit.box(assembly, "SquarePier", Vector3(0, 3, 0), Vector3(1.5, 6, 1.5), "ivory")
		Kit.box(assembly, "GoldCap", Vector3(0, 6.1, 0), Vector3(1.9, 0.25, 1.9), "gold")
	elif kind == "cornice_span":
		Kit.box(assembly, "IvoryCornice", Vector3.ZERO, Vector3(8, 0.8, 1.3), "ivory")
		Kit.box(assembly, "GoldInlay", Vector3(0, 0.15, -0.68), Vector3(7.4, 0.15, 0.08), "gold")
	elif kind == "gold_rail_span":
		for y in [0.45, 1.2]: Kit.branch(assembly, "GoldRail", Vector3(-4, y, 0), Vector3(4, y, 0), 0.12, "gold")
	elif kind == "gold_rail_post":
		Kit.box(assembly, "IvoryPost", Vector3(0, 0.7, 0), Vector3(0.7, 1.4, 0.7), "ivory")
		Kit.facet(assembly, "GoldFinial", Vector3(0, 1.7, 0), Vector3(0.4, 0.6, 0.4), "gold")
	elif kind == "root_buttress":
		Kit.branch(assembly, "Root", Vector3(0, -8, 0), Vector3(0, 1, 0), 0.9, "wood")
		for side in [-1.0, 1.0]: Kit.branch(assembly, "RootFork", Vector3.ZERO, Vector3(side * 3, 3, 0), 0.5, "wood")
	elif kind == "growing_vine_bridge":
		for index in 6: Kit.box(assembly, "BridgeDeck", Vector3(index * 2.2, 0, 0), Vector3(2.3, 0.45, 6), "ivory")
		for side in [-1.0, 1.0]: Kit.branch(assembly, "VineRail", Vector3(-1, 1.4, side * 2.8), Vector3(12, 1.4, side * 2.8), 0.22, "wood")
	elif kind == "heart_gate_arch":
		for side in [-1.0, 1.0]:
			Kit.box(assembly, "GatePier", Vector3(side * 4, 4, 0), Vector3(1.5, 8, 1.8), "ivory")
			Kit.branch(assembly, "RootArch", Vector3(side * 4, 8, 0), Vector3(0, 12, 0), 0.75, "wood")
	elif kind == "heart_route_stone":
		Kit.facet(assembly, "RouteStone", Vector3(0, 2, 0), Vector3(1.4, 2.1, 0.7), "rock")
		Kit.facet(assembly, "HeartInlay", Vector3(0, 2, -0.72), Vector3(0.5, 0.6, 0.08), "gold")
	elif kind == "listening_blossom":
		Kit.flower(assembly, Vector3(0, 0.8, 0), 2.5, "ivory")
	elif kind == "comfort_lantern":
		Kit.branch(assembly, "LanternStem", Vector3.ZERO, Vector3(0, 4.2, 0), 0.28, "wood")
		Kit.facet(assembly, "SeedpodLight", Vector3(0, 3.5, 0), Vector3(0.8, 1.2, 0.8), "gold")
	elif kind == "song_memory_bench":
		Kit.box(assembly, "BenchSeat", Vector3(0, 1, 0), Vector3(6, 0.55, 2), "wood")
		for side in [-1.0, 1.0]: Kit.box(assembly, "BenchLeg", Vector3(side * 2.1, 0.45, 0), Vector3(0.55, 0.9, 1.4), "stone")
	elif kind == "flower_cluster":
		for index in 5: Kit.flower(assembly, Vector3((index - 2) * 1.4, 0, sin(index) * 1.2), 0.65, "pink" if index % 2 == 0 else "ivory")
	elif kind == "shrub_cluster":
		for index in 4: Kit.facet(assembly, "Shrub", Vector3((index - 1.5) * 1.5, 1, cos(index)), Vector3(1.4, 1.2, 1.3), "leaf_light")
	elif kind == "echo_moth_shell":
		Kit.facet(assembly, "MothShell", Vector3(0, 1.5, 0), Vector3(1.4, 1.2, 0.8), "blight")
		for side in [-1.0, 1.0]: Kit.facet(assembly, "Wing", Vector3(side * 1.5, 1.8, 0), Vector3(1.4, 0.15, 1.2), "blue")
	elif kind == "pulse_slime_shell":
		Kit.facet(assembly, "SlimeShell", Vector3(0, 1.2, 0), Vector3(2.0, 1.5, 2.0), "blight")
		Kit.facet(assembly, "LivingCore", Vector3(0, 1.3, -1.2), Vector3(0.55, 0.65, 0.35), "leaf_light")
