extends RefCounted
## Reusable non-interactive botanical bed. Structural collision stays inside
## the original 15 x 9 footprint; small leaves share one instanced mesh.
const Bricks = preload("res://scripts/altar/AltarParts.gd")
const Mount = preload("res://scripts/mind_spark/research_bay_mount.gd")

static func build(world: Node3D, parent: Node3D, at: Vector3, index: int, mats: Dictionary) -> Node3D:
	var bed := Node3D.new()
	bed.name = "ResearchPlanter_%02d" % index
	bed.position = at
	bed.set_meta("assembly_role", "rooted botanical specimens with service irrigation")
	bed.set_meta("collision_policy", "solid retaining shell; foliage contained inside footprint")
	parent.add_child(bed)
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color("4d5140")
	soil.roughness = .95
	var leaf_dark := StandardMaterial3D.new()
	leaf_dark.albedo_color = Color("365e49")
	leaf_dark.roughness = .85
	for spec in [
		["Foundation", Vector3(0,.25,0), Vector3(14.8,.5,8.8), mats.sanctum_ivory],
		["WestWall", Vector3(-7.05,1.1,0), Vector3(.9,1.2,8.4), mats.sanctum_ivory],
		["EastWall", Vector3(7.05,1.1,0), Vector3(.9,1.2,8.4), mats.sanctum_ivory],
		["FrontWall", Vector3(0,1.1,3.75), Vector3(13.2,1.2,.9), mats.sanctum_ivory],
		["RearWall", Vector3(0,1.1,-3.75), Vector3(13.2,1.2,.9), mats.sanctum_ivory],
		["Soil", Vector3(0,1.62,0), Vector3(13.2,.28,6.6), soil],
		["WestCap", Vector3(-7.05,1.85,0), Vector3(.9,.3,9), mats.sanctum_ivory],
		["EastCap", Vector3(7.05,1.85,0), Vector3(.9,.3,9), mats.sanctum_ivory],
		["FrontCap", Vector3(0,1.85,4.05), Vector3(13.2,.3,.9), mats.sanctum_ivory],
		["RearCap", Vector3(0,1.85,-4.05), Vector3(13.2,.3,.9), mats.sanctum_ivory],
	]:
		world.call("_add_brick",bed,spec[0],spec[1],Bricks.build_bevel_box(spec[2],.08),spec[3])
	Mount._solid(bed,"RetainingShellSolid",Vector3(0,1,0),Vector3(15,2,9))
	var leaf_mesh := _leaf_mesh()
	var foliage := MultiMeshInstance3D.new()
	foliage.name = "RootedSageRosettes"
	foliage.multimesh = MultiMesh.new()
	foliage.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	foliage.multimesh.mesh = leaf_mesh
	foliage.multimesh.instance_count = 40
	foliage.material_override = mats.garden_foliage
	bed.add_child(foliage)
	for plant in 5:
		var root_at := Vector3(-5.2+plant*2.6,1.72,.5 if plant%2 else -.5)
		world.call("_add_cylinder",bed,"RootCollar%d"%plant,root_at+Vector3.UP*.16,.22,.4,leaf_dark,false,8)
		for leaf in 8:
			foliage.multimesh.set_instance_transform(plant*8+leaf,leaf_transform(plant,leaf))
		var feed := Vector3(root_at.x,1.83,-2.7)
		world.call("_add_cable_between",bed,"DripBranch%d"%plant,feed,root_at+Vector3(0,.11,-.25),.065,.065,mats.astral_brass,8)
	world.call("_add_cable_between",bed,"IrrigationHeader",Vector3(-5.5,1.83,-2.7),Vector3(5.5,1.83,-2.7),.10,.10,mats.astral_brass,8)
	world.call("_add_cable_between",bed,"ServiceRiser",Vector3(-5.5,.6,-2.7),Vector3(-5.5,1.83,-2.7),.10,.10,mats.astral_brass,8)
	world.call("_add_brick",bed,"ServiceHousing",Vector3(-5.5,.65,-2.7),Bricks.build_bevel_box(Vector3(.8,.6,.8),.08),mats.bio_gunmetal)
	return bed

static func leaf_transform(plant: int, leaf: int) -> Transform3D:
	var angle := TAU*float(leaf)/8.0+plant*.4
	var basis := Basis(Vector3.UP,angle).scaled(Vector3(.8,1.0+float((leaf+plant)%3)*.17,.8))
	return Transform3D(basis,Vector3(-5.2+plant*2.6,1.72,.5 if plant%2 else -.5))

static func _leaf_mesh() -> ArrayMesh:
	# Thick folded lanceolate leaf: a raised midrib, tapered tip and dark-facing
	# underside give a readable low-poly silhouette without a sphere placeholder.
	var root := Vector3.ZERO
	var left := Vector3(-.46,.58,.67)
	var right := Vector3(.46,.58,.67)
	var ridge := Vector3(0,.85,.72)
	var underside := Vector3(0,.52,.72)
	var tip := Vector3(0,1.02,1.4)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in [[root,left,ridge],[root,ridge,right],[left,tip,ridge],[ridge,tip,right],
		[root,underside,left],[root,right,underside],[left,underside,tip],[underside,right,tip]]:
		for vertex in triangle: surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()
