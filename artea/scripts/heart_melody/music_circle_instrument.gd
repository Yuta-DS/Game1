extends Node3D

signal note_played(index: int)
signal playing_changed(active: bool)

const Art = preload("res://scripts/heart_melody/heart_art.gd")
const Sound = preload("res://scripts/heart_melody/music_circle_sound.gd")
const PLAY_KEYS := [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K]
const PICK_LAYER := 1 << 6
var kind := "xylophone"
var title := "Xylophone"
var _player: CharacterBody3D
var _camera: Camera3D
var _active := false
var _nearby := false
var _old_mouse := Input.MOUSE_MODE_CAPTURED
var _prompt: Label
var _panel: PanelContainer
var _voices: Array[AudioStreamPlayer] = []
var _voice_index := 0
var _pads: Array[Node3D] = []
var _pad_tweens: Dictionary = {}
var _buttons: Array[Button] = []
var last_played := -1

func _ready() -> void:
	_build_model()
	var area := Area3D.new()
	area.name = "InteractionArea"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 9.0
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body):
		if body.is_in_group("Player"):
			_player = body
			_nearby = true
			_prompt.visible = not _active)
	area.body_exited.connect(func(body):
		if body == _player:
			_nearby = false
			close_playing()
			_prompt.visible = false)
	for index in 8:
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		voice.volume_db = -10.0
		add_child(voice)
		_voices.append(voice)
	_build_ui()

func pad_labels() -> Array:
	if kind == "guitar": return ["C", "Am", "F", "G"]
	if kind == "drums": return ["Low", "Mid", "High"]
	if kind == "bells": return ["C", "D", "E", "F", "G"]
	return ["C", "D", "E", "F", "G", "A", "B", "C′"]

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	_prompt = Label.new()
	_prompt.text = "Q · Play %s" % title
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -96
	_prompt.offset_bottom = -60
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 5)
	_prompt.visible = false
	layer.add_child(_prompt)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.anchor_left = 0.12
	_panel.anchor_right = 0.88
	_panel.offset_top = -190
	_panel.offset_bottom = -18
	_panel.visible = false
	layer.add_child(_panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var heading := Label.new()
	heading.text = title + " · Click a pad or press its key · Esc to leave"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 20)
	column.add_child(heading)
	var row := HBoxContainer.new()
	column.add_child(row)
	var labels := pad_labels()
	for index in labels.size():
		var button := Button.new()
		button.text = "%s\n%s" % [labels[index], char(PLAY_KEYS[index])]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 62
		button.focus_mode = Control.FOCUS_NONE
		button.button_down.connect(play_pad.bind(index))
		row.add_child(button)
		_buttons.append(button)
	var leave := Button.new()
	leave.text = "Leave instrument"
	leave.focus_mode = Control.FOCUS_NONE
	leave.pressed.connect(close_playing)
	column.add_child(leave)

func open_playing() -> bool:
	if _active or not _nearby or not is_instance_valid(_player): return false
	_camera = get_viewport().get_camera_3d()
	if _camera == null or not _camera.has_method("enter_inspect_framed"): return false
	_active = true
	_old_mouse = Input.mouse_mode
	_player.set_input_enabled(false)
	_camera.enter_inspect_framed(self, Vector3(0, 2.5, 0), Vector3(0, 8, 11))
	_prompt.visible = false
	_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	playing_changed.emit(true)
	return true

func close_playing() -> void:
	if not _active: return
	_active = false
	for voice in _voices: voice.stop()
	if is_instance_valid(_camera): _camera.exit_inspect()
	if is_instance_valid(_player): _player.set_input_enabled(true)
	Input.mouse_mode = _old_mouse
	if is_instance_valid(_panel): _panel.visible = false
	if is_instance_valid(_prompt): _prompt.visible = _nearby
	playing_changed.emit(false)

func _exit_tree() -> void:
	close_playing()

func _input(event: InputEvent) -> void:
	# Capture performance keys before the gallery's J journal shortcut and
	# other world shortcuts; mouse events still reach the clickable UI first.
	if _active and event is InputEventKey:
		_unhandled_input(event)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if not _active:
		if _nearby and event.is_action_pressed("interact") and open_playing():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		close_playing()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		var index := PLAY_KEYS.find(event.physical_keycode)
		if index >= 0 and index < _pads.size():
			play_pad(index)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var origin := _camera.project_ray_origin(event.position)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + _camera.project_ray_normal(event.position) * 100.0, PICK_LAYER)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider.get_meta("instrument", null) == self:
			play_pad(int(hit.collider.get_meta("pad")))
		get_viewport().set_input_as_handled()

func play_pad(index: int) -> void:
	if not _active or index < 0 or index >= _pads.size(): return
	last_played = index
	var voice := _voices[_voice_index]
	_voice_index = (_voice_index + 1) % _voices.size()
	voice.stream = Sound.stream_for(kind, index)
	voice.play()
	note_played.emit(index)
	var pad := _pads[index]
	if _pad_tweens.has(index): _pad_tweens[index].kill()
	pad.rotation.z = 0.0
	var tween := create_tween()
	tween.tween_property(pad, "rotation:z", 0.14 if kind == "bells" else 0.04, 0.045)
	tween.tween_property(pad, "rotation:z", 0.0, 0.16)
	_pad_tweens[index] = tween
	_buttons[index].modulate = Color("ffe0a0")
	var flash := create_tween()
	flash.tween_property(_buttons[index], "modulate", Color.WHITE, 0.22)

func _pad(part: MeshInstance3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = PICK_LAYER
	body.collision_mask = 0
	body.set_meta("instrument", self)
	body.set_meta("pad", _pads.size())
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	part.add_child(body)
	_pads.append(part)

func _build_model() -> void:
	var wood := Color("795746")
	var gold := Color("d6ad62")
	if kind == "xylophone":
		Art.box(self, Vector3(0, 1.0, 0), Vector3(8.5, 2.0, 3.4), wood, true)
		for index in 8:
			var length := 3.2 - float(index) * 0.17
			var bar := Art.box(self, Vector3(float(index) - 3.5, 2.3, 0), Vector3(0.88, 0.35, length), Color.from_hsv(float(index) / 10.0, 0.55, 0.95))
			_pad(bar, Vector3(0.92, 0.45, length))
	elif kind == "drums":
		for index in 3:
			var point := Vector3((float(index) - 1) * 2.6, 0, 0)
			var height := 2.5 + float(index) * 0.35
			Art.cone(self, point + Vector3.UP * height * 0.5, 0.85, 1.2, height, [Color("b85d71"), Color("6c9fa8"), gold][index], true, 12)
			var head := Art.cone(self, point + Vector3.UP * (height + 0.1), 1.23, 1.23, 0.18, Color("ead6aa"), false, 16)
			_pad(head, Vector3(2.5, 0.4, 2.5))
	elif kind == "bells":
		for side in [-1, 1]: Art.box(self, Vector3(side * 3.9, 3.0, 0), Vector3(0.6, 6, 0.6), wood, true)
		Art.box(self, Vector3(0, 6, 0), Vector3(8.4, 0.6, 0.7), wood)
		for index in 5:
			var point := Vector3((float(index) - 2) * 1.45, 4.1, 0)
			Art.box(self, point + Vector3.UP * 1.0, Vector3(0.1, 1.2, 0.1), gold)
			var bell := Art.cone(self, point, 0.70, 0.28, 1.3, gold, false, 12)
			Art.cone(self, point - Vector3.UP * 0.60, 0.76, 0.76, 0.15, gold, false, 12)
			_pad(bell, Vector3(1.45, 1.6, 1.45))
	else:
		Art.box(self, Vector3(0, 0.45, 0), Vector3(3.5, 0.9, 2), wood, true)
		for spec in [[2.8, 1.55], [4.0, 1.15]]:
			var body := Art.cone(self, Vector3(0, spec[0], 0), spec[1], spec[1], 0.65, Color("bd8752"), false, 20)
			body.rotation.x = PI * 0.5
		var hole := Art.cone(self, Vector3(0, 3.4, 0.36), 0.48, 0.48, 0.04, Color("302d35"), false, 16)
		hole.rotation.x = PI * 0.5
		Art.box(self, Vector3(0, 6, 0), Vector3(0.62, 4.5, 0.35), wood)
		Art.box(self, Vector3(0, 8.5, 0), Vector3(0.85, 1.1, 0.4), Color("bd8752"))
		for string_index in 6:
			Art.box(self, Vector3((float(string_index) - 2.5) * 0.075, 5.0, 0.40), Vector3(0.025, 5.6, 0.025), Color("eadac0"))
		for index in 4:
			var pad := Art.box(self, Vector3((float(index) - 1.5) * 1.25, 0.5, 2.4), Vector3(1.0, 0.3, 1.0), gold)
			_pad(pad, Vector3(1.1, 0.5, 1.1))
