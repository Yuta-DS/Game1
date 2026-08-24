# Visual proof for the Lens of Seeing. Writes to artifacts/.
#
#   Godot --path artea --script res://scripts/capture_lens_demo.gd
#
# Headless asserts cannot see inside-out faces, an unlit cross-section, or a
# fragment that renders as a black hole. This drives the real scene, performs a
# real capture and placement, and writes before/after images to look at.
#
# Not a test — it asserts nothing and is not part of the suite. It is the thing
# to run when the cutter's output looks wrong on screen but every check passes.
extends SceneTree

const DEMO := "res://scenes/viewfinder/lens_demo.tscn"
const OUT_DIR := "res://artifacts"

var _demo: Node3D
var _lens: Node


func _initialize() -> void:
	var packed := load(DEMO) as PackedScene
	if packed == null:
		push_error("capture_lens_demo: could not load %s" % DEMO)
		quit(1)
		return

	_demo = packed.instantiate()
	root.add_child(_demo)

	# The demo captures the mouse for free-look; a headless-style capture run
	# must not leave the pointer trapped.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	await process_frame
	await process_frame

	var controller := _demo.find_child("LensController", true, false)
	if controller == null:
		push_error("capture_lens_demo: no LensController in the demo scene")
		quit(1)
		return
	_lens = controller.find_child("ViewfinderLens", false, false)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	# Stand close enough that the props are within CAPTURE_DISTANCE, and off to
	# one side so the frame holds one shape rather than the whole row — that is
	# the framing the mechanic is built around.
	var camera := _demo.find_child("DemoCamera", true, false) as Camera3D
	if camera != null:
		camera.global_position = Vector3(-4.4, 1.7, 1.6)

	# Raise the lens through the controller rather than calling capture()
	# straight on the lens: the frame, the seeing counter and the depth of
	# field all belong to the raised state, and a capture that skips it would
	# photograph a HUD the player never sees.
	controller._toggle_raised()

	await _settle()
	_shoot("lens_01_intact.png")

	# Frame the props and take a seeing. _refresh() after each action so the
	# HUD shown in the image is the one the player would actually be looking
	# at, not a stale frame from before the state changed.
	if _lens.capture():
		controller._refresh()
		await _settle()
		_shoot("lens_02_after_capture.png")
	else:
		push_warning("capture_lens_demo: nothing was in frame to capture")

	# Move somewhere else entirely, then place it there.
	if camera != null:
		camera.global_position = Vector3(7.0, 1.7, 3.0)
	await _settle()

	if _lens.is_holding() and _lens.place():
		controller._refresh()
		await _settle()
		_shoot("lens_03_after_place.png")

	print("capture_lens_demo: wrote images to %s" % OUT_DIR)
	quit()


# Let the renderer catch up. Freshly cut fragments have no baked lighting, so
# their first frame is not representative.
func _settle() -> void:
	for i in 6:
		await process_frame


func _shoot(filename: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		push_warning("capture_lens_demo: no framebuffer for %s" % filename)
		return
	var path := "%s/%s" % [OUT_DIR, filename]
	image.save_png(path)
	print("  wrote %s" % path)
