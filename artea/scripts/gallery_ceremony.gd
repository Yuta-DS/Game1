# The Crown of Life — stage 4 of the journey.
#
# Milo names what the player has become, using only what they actually did.
# Every line is backed by a count from JourneyState, so the game can say it
# because the player earned it — not as generic encouragement.
#
# Builds its own UI at runtime rather than editing the gallery .tscn, so the
# scene file stays untouched and this can be removed cleanly.
extends Node

# Each strength is claimed only if its evidence exists. The %d is the count
# of things the player actually did.
# Singular and plural, because "you looked at 1 thoughts" undercuts the
# one line that is supposed to land.
const EVIDENCE := {
	"courage": [
		"You have courage — you looked at a thought that scared you.",
		"You have courage — you looked at %d thoughts that scared you.",
	],
	"emotional-awareness": [
		"You have emotional awareness — you sat with a feeling instead of running.",
		"You have emotional awareness — you sat with %d feelings instead of running.",
	],
	"creativity": [
		"You have creativity — you made something that did not exist before.",
		"You have creativity — you made %d things that did not exist before.",
	],
	# Earned with the Lens of Seeing (viewfinder/lens_journey.gd). Optional:
	# a player who never finds the lens is still crowned, so this line simply
	# does not appear for them.
	"perception": [
		"You have perception — you saw what was missing and carried it there yourself.",
		"You have perception — %d times you saw what was missing and carried it there.",
	],
}

const OPENING := "Milo: You came here not knowing who you were.\nLet me tell you what I have seen."

# Shown when the player reaches the gallery without a journey behind them.
# No fake praise — an honest invitation instead.
const NO_JOURNEY := "Milo: Your story here has not started yet.\nWander, feel, make something. I will be watching."

var _panel: PanelContainer
var _label: RichTextLabel


func _ready() -> void:
	# Let the gallery finish building its own UI first.
	await get_tree().process_frame

	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return

	# Keep the gallery view clear during exploration. The long evidence speech
	# belongs in the Crown Journey journal/finale and must not open as a full
	# screen banner every time the gallery scene loads.
	if js.has_all_treasures():
		js.advance_to(4)
		_build_finale(js)


# Milo's speech, assembled from evidence.
func _compose(js) -> String:
	if not js.has_journey():
		return NO_JOURNEY

	var lines := [OPENING, ""]

	var counts := {
		"courage": js.popped_count(),
		"emotional-awareness": js.emotions.size(),
		"creativity": js.creations.size(),
		"perception": js.bridgings_count(),
	}

	# Only claim a strength the player actually demonstrated. strengths[] is
	# granted by the acts themselves, so this never invents anything.
	for strength in js.strengths:
		if not EVIDENCE.has(strength):
			continue
		var n: int = counts.get(strength, 0)
		if n <= 0:
			continue
		var forms: Array = EVIDENCE[strength]
		lines.append(forms[0] if n == 1 else forms[1] % n)

	# Every completed world awards one named treasure.
	lines.append("")
	if js.has_treasure("star_of_wisdom"):
		lines.append("[color=#ffd966]*[/color] Star of Wisdom — you understand yourself.")
	if js.has_treasure("harmony_jewel"):
		lines.append("[color=#8fd3ff]*[/color] Harmony Jewel — you honour your heart.")
	if js.has_treasure("creators_light"):
		lines.append("[color=#ffb3d9]*[/color] Creator's Light — you express your truth.")

	lines.append("")
	if js.has_all_treasures():
		lines.append("[color=#fff2a8]The three treasures become the Light of Identity.[/color]")
		lines.append(_closing(js))
	else:
		lines.append("The Crown of Life is still forming: %d of 3 treasures discovered." % js.treasure_count())
		lines.append(_next_world(js))

	return "\n".join(lines)


func _closing(js) -> String:
	var who: String = ""
	var global_node := get_node_or_null("/root/Global")
	if global_node != null:
		who = str(global_node.current_user_name).strip_edges()

	var named := "The sky over Artéa knows your name now%s." % (
		"" if who.is_empty() else ", %s" % who)
	if js.audience_mode == "faith":
		return "The Maker: You are known. You are loved. You have been uniquely created with gifts and purpose.\n%s\nYour light has a place in this universe." % named
	return "Milo: You are known. You are valued. Your gifts, purpose, and story are uniquely yours.\n%s\nYour light has a place in this universe." % named


func _next_world(js) -> String:
	if not js.has_treasure("star_of_wisdom"):
		return "Next: visit Mind Spark and discover the courage to choose hope."
	if not js.has_treasure("harmony_jewel"):
		return "Next: visit Heart Melody and give your feelings a voice."
	return "Next: visit Creator's Light and make something only you can share."


# Physical finale: the crown follows the player, their named star joins the
# galaxy, and one train becomes the rainbow celebration train.
func _build_finale(js) -> void:
	var gallery := get_parent() as Node3D
	var identity_name := _finalize_identity_name()
	var player := gallery.get_node_or_null("Player3D") as Node3D
	if player != null and player.get_node_or_null("CrownOfLife") == null:
		var crown := Node3D.new()
		crown.name = "CrownOfLife"
		crown.position = Vector3(0.0, 2.2, 0.0)
		player.add_child(crown)
		var gold := _finale_material(Color("ffd76a"), 1.1)
		var rim := MeshInstance3D.new()
		var rim_mesh := TorusMesh.new()
		rim_mesh.inner_radius = 0.40
		rim_mesh.outer_radius = 0.52
		rim_mesh.rings = 16
		rim_mesh.ring_segments = 6
		rim.mesh = rim_mesh
		rim.material_override = gold
		crown.add_child(rim)
		var jewel_colors := [Color("ffd966"), Color("8fd3ff"), Color("ff8fcf")]
		for i in 7:
			var point := MeshInstance3D.new()
			var point_mesh := CylinderMesh.new()
			point_mesh.top_radius = 0.0
			point_mesh.bottom_radius = 0.10
			point_mesh.height = 0.42 + 0.10 * float(i % 2)
			point_mesh.radial_segments = 5
			point.mesh = point_mesh
			var angle := TAU * float(i) / 7.0
			point.position = Vector3(cos(angle) * 0.46, 0.24, sin(angle) * 0.46)
			point.material_override = _finale_material(jewel_colors[i % 3], 1.8)
			crown.add_child(point)

	var star := Node3D.new()
	star.name = "IdentityStar"
	star.position = Vector3(-8.0, 15.0, -4.0)
	gallery.add_child(star)
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.7
	core_mesh.height = 1.4
	core.mesh = core_mesh
	core.material_override = _finale_material(Color("fff3a1"), 2.5)
	star.add_child(core)
	var star_label := Label3D.new()
	var who := "YOUR"
	var global_node := get_node_or_null("/root/Global")
	if global_node != null and not str(global_node.current_user_name).strip_edges().is_empty():
		who = str(global_node.current_user_name).strip_edges().to_upper() + "'S"
	star_label.text = "%s STAR\nYOUR STORY MATTERS" % who
	if not identity_name.is_empty():
		star_label.text += "\n%s" % identity_name
	star_label.position.y = 1.6
	star_label.font_size = 34
	star_label.outline_size = 10
	star_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	star.add_child(star_label)

	# Rails author themselves a couple of frames after the gallery opens.
	for _i in 4:
		await get_tree().process_frame
	var rail := gallery.get_node_or_null("SkyRail")
	if rail != null:
		var trains := rail.find_children("Train_*", "Node3D", true, false)
		if not trains.is_empty():
			var parade := trains[0] as Node3D
			parade.name = "RainbowGalaxyTrain"
			var rainbow := [Color("ff5f6d"), Color("ffd166"), Color("55e6c1"), Color("62a8ff"), Color("c77dff")]
			var parts := parade.find_children("*", "MeshInstance3D", true, false)
			for i in parts.size():
				(parts[i] as MeshInstance3D).material_override = _finale_material(rainbow[i % rainbow.size()], 1.35)


func _finalize_identity_name() -> String:
	var tracker := get_node_or_null("/root/PlayerIdentityTracker")
	if tracker == null or not tracker.has_method("finalize_identity"):
		return ""
	var code := str(tracker.call("finalize_identity"))
	var friendly_name := str(tracker.call("friendly_identity_name", code))
	if not friendly_name.is_empty():
		tracker.call("mark_reveal_seen")
	return friendly_name


func _finale_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.55
	material.roughness = 0.22
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.position = Vector2(-380, 40)
	_panel.custom_minimum_size = Vector2(760, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.12, 0.82)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(22)
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.85, 0.3, 0.55)
	_panel.add_theme_stylebox_override("panel", style)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.custom_minimum_size = Vector2(716, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("normal_font_size", 20)

	_panel.add_child(_label)
	layer.add_child(_panel)

	# Fade in — the ceremony should arrive, not blink into being.
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 1.2)
