extends SceneTree

func _init() -> void:
	var mesh := load("res://resources/web_hub_terrain.res") as ArrayMesh
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var side := int(sqrt(float(vertices.size())))
	var spacing := vertices[1].x-vertices[0].x
	print("SEABED_GRID: side=%d origin=%s spacing=%s" % [side,vertices[0],spacing])
	for x in [-100.0,0.0,38.0,100.0]:
		for z in [180.0,220.0,268.0,300.0,360.0,440.0]:
			var ix := clampi(roundi((x-vertices[0].x)/spacing),0,side-1)
			var iz := clampi(roundi((z-vertices[0].z)/spacing),0,side-1)
			print("SEABED: (%s,%s) y=%.3f depth=%.3f" % [x,z,vertices[iz*side+ix].y,.75-vertices[iz*side+ix].y])
	quit()
