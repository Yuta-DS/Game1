extends SceneTree

class MockAmountModifier:
	extends Resource
	var amount := 60500

class MockModifierStack:
	extends Resource
	var stack: Array = []

class MockScatter:
	extends Node3D
	var dbg_disable_thread := false
	var force_rebuild_on_load := false
	var keep_static_colliders := false
	var render_mode := 1
	var modifier_stack: MockModifierStack

class MockScatterItem:
	extends Node3D
	var proportion := 100
	var path := ""
	var override_material: Material
	var source_scale_multiplier := 1.0

class MockTerrain:
	extends Node3D
	var collision_mode := 3
	var material: Material = StandardMaterial3D.new()

var _failures := 0


func _init() -> void:
	var hub := Node3D.new()
	var compat := Node.new()
	compat.name = "WebTerrainCompatibility"
	compat.set_script(load("res://scripts/web_terrain_compat.gd"))
	hub.add_child(compat)

	var environment := Node3D.new()
	environment.name = "Environment"
	hub.add_child(environment)
	var terrain := MockTerrain.new()
	terrain.name = "Terrain3D"
	environment.add_child(terrain)

	var grass := _mock_scatter("Grass", 60500)
	environment.add_child(grass)
	grass.add_child(_mock_item("ScatterItemGrassA", "res://scenes/vegetation/grass_clump_3d.tscn", 0.32))
	grass.add_child(_mock_item("ScatterItemGrassB", "res://scenes/vegetation/grass_clump_3d.tscn", 0.36))
	for color_name in ["Red", "Orange", "Yellow", "Green", "Blue", "Indigo", "Violet"]:
		grass.add_child(_mock_item("ScatterItemFlower%s" % color_name,
			"res://scenes/vegetation/wildflower_%s_3d.tscn" % String(color_name).to_lower(), 0.85))
	grass.add_child(_mock_item("ScatterItemBush", "res://assets3D/trees/tree_1_c_color_12.tscn", 1.0))

	var objects := _mock_scatter("Objects", 188)
	environment.add_child(objects)

	var water := Node3D.new()
	water.name = "Water"
	environment.add_child(water)
	var sea := MeshInstance3D.new()
	sea.name = "MeshInstance3D"
	sea.mesh = PlaneMesh.new()
	water.add_child(sea)
	var torus := MeshInstance3D.new()
	torus.name = "MeshInstance3D2"
	torus.mesh = TorusMesh.new()
	water.add_child(torus)

	compat.call("_disable_native_terrain_material")
	_check(environment.get_node_or_null("Terrain3D") == null,
		"Terrain3D is removed before WebGL can allocate its oversized UBO")
	compat.call("_apply_web_scatter_tuning")
	var distribution = grass.modifier_stack.stack[0]
	_check(distribution.amount == 28000, "Web grass count covers the full landscape")
	_check(grass.get_node("ScatterItemBush").proportion == 0,
		"tree asset is removed from the grass distribution")
	_check(is_equal_approx(grass.get_node("ScatterItemGrassA").source_scale_multiplier, 0.24),
		"Web grass is scaled below player eye level")
	for color_name in ["Red", "Orange", "Yellow", "Green", "Blue", "Indigo", "Violet"]:
		var flower_item := grass.get_node("ScatterItemFlower%s" % color_name) as MockScatterItem
		_check(is_equal_approx(flower_item.source_scale_multiplier, 0.85)
			and flower_item.override_material == null,
			"Web %s flowers preserve their 3D stem, petal, and centre materials" % color_name)

	var terrain_material := compat.call("_make_web_terrain_material") as ShaderMaterial
	_check(terrain_material != null and terrain_material.shader != null
		and terrain_material.shader.resource_path == "res://shaders/web_terrain.gdshader",
		"Web terrain uses its compact detail shader")

	compat.call("_apply_web_water")
	var water_material := sea.material_override as ShaderMaterial
	_check(water_material != null and water_material.shader != null
		and water_material.shader.resource_path == "res://shaders/web_water.gdshader",
		"Web ocean uses the non-discarding compatibility shader")
	_check(not torus.visible, "floating decorative water torus is hidden on Web")

	compat.call("_add_web_sky_dome")
	var dome := compat.get_node_or_null("WebSkyDome") as MeshInstance3D
	_check(dome != null and dome.material_override is ShaderMaterial,
		"Web sky dome uses a spatial compatibility shader")

	hub.free()
	if _failures == 0:
		print("PASS: Web sky, terrain, vegetation, and sea compatibility policy")
	quit(_failures)


func _mock_scatter(node_name: String, amount: int) -> MockScatter:
	var scatter := MockScatter.new()
	scatter.name = node_name
	scatter.modifier_stack = MockModifierStack.new()
	var modifier := MockAmountModifier.new()
	modifier.amount = amount
	scatter.modifier_stack.stack.append(modifier)
	return scatter


func _mock_item(node_name: String, source_path: String, scale_multiplier: float) -> MockScatterItem:
	var item := MockScatterItem.new()
	item.name = node_name
	item.path = source_path
	item.source_scale_multiplier = scale_multiplier
	return item


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: %s" % message)
