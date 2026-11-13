extends Node

const INTRO_SCENE := preload("res://scenes/narrative_package.tscn")
const DIRECTION_SCRIPT := preload("res://scenes/story_direction.gd")


func _ready() -> void:
	_run.call_deferred()


func _fail(message: String) -> void:
	push_error("NARRATIVE_SCROLL_READABILITY_TEST: %s" % message)
	get_tree().quit(1)


func _run() -> void:
	if load("res://scenes/New_Hub_World.tscn") == null:
		_fail("hub scene must load with the updated scroll placement")
		return
	var camera := Camera3D.new()
	get_tree().root.add_child(camera)
	camera.make_current()

	var intro := INTRO_SCENE.instantiate()
	get_tree().root.add_child(intro)
	var scroll := intro.get_node("NarrativeBubble") as Sprite3D
	var direction := Sprite3D.new()
	direction.set_script(DIRECTION_SCRIPT)
	var message := Label3D.new()
	message.name = "Label3D"
	direction.add_child(message)
	var speaker := Label3D.new()
	speaker.name = "CharacterName"
	direction.add_child(speaker)
	get_tree().root.add_child(direction)
	await get_tree().process_frame

	for sign in [scroll, direction]:
		for offset in [Vector3(-8, 2, 0), Vector3(8, 2, 0),
			Vector3(0, 2, -8), Vector3(0, 2, 8)]:
			camera.global_position = sign.global_position + offset
			sign._process(0.016)
			var toward: Vector3 = camera.global_position - sign.global_position
			toward.y = 0.0
			if sign.global_basis.z.normalized().dot(toward.normalized()) <= 0.99:
				_fail("parchment and labels must face the player from every side")
				return
			if not is_equal_approx(sign.scale.x, 0.72):
				_fail("parchment should fit comfortably beside its speaker")
				return
	if not scroll.get_node("Label3D").text.begins_with("Welcome, "):
		_fail("welcome text remains personalized")
		return
	if not direction.get_node("Label3D").text.begins_with("The air feels different"):
		_fail("hub direction text remains personalized")
		return

	intro.queue_free()
	direction.queue_free()
	camera.queue_free()
	await get_tree().process_frame
	print("NARRATIVE_SCROLL_READABILITY_TEST: PASS — both scrolls face the camera from four sides")
	get_tree().quit()
