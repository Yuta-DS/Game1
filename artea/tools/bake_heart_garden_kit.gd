extends SceneTree

const Kit := preload("res://scripts/heart_melody/heart_nature_kit.gd")
const OUTPUT := "res://assets3D/heart_melody/island_one/glb"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for kind in ["faceted_tree","flower_drum","feeling_planter"]:
		var assembly := Node3D.new()
		assembly.name = kind
		root.add_child(assembly)
		if kind == "faceted_tree":
			Kit.tree(assembly,Vector3.ZERO)
		elif kind == "flower_drum":
			Kit.cylinder(assembly,"LivingBase",Vector3(0,0.65,0),2,1.3,"leaf",false,6)
			var flower := Kit.flower(assembly,Vector3(0,1.4,0),1.7)
			flower.name = "MovingPetals"
		else:
			Kit.cylinder(assembly,"StoneNest",Vector3(0,0.6,0),1.9,1.2,"rock",false,8)
			Kit.cylinder(assembly,"Soil",Vector3(0,1.22,0),1.5,0.06,"soil",false,8)
			var flower := Kit.flower(assembly,Vector3(0,1.7,0),1.1)
			flower.name = "GrowingBloom"
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_scene(assembly,state) == OK)
		assert(document.write_to_filesystem(state,OUTPUT+"/"+kind+".glb") == OK)
		assembly.queue_free()
		await process_frame
	print("HEART_KIT: editable component GLBs exported")
	quit()
