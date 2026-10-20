extends Node

#@onready var player = $AudioStreamPlayer2D
@onready var player2: AudioStreamPlayer2D = $AudioStreamPlayer2D

#Aliases
const PEACE_TRACK = preload("res://assets/SFX/Peace - David Lastra.ogg")
const MAGIC_TRACK = preload("res://assets/SFX/Magic in the Garden.ogg")
const PAINT_TRACK = preload("res://assets/SFX/Forest Frolic Loop.ogg")

@export var scene_to_track: Dictionary = {
	"res://scenes/cloud_pop_ui.tscn":	PEACE_TRACK,
	"res://scenes/cloudPopFinish.tscn":	PEACE_TRACK,
	"res://scenes/art_gallery_3d_inprogress.tscn": MAGIC_TRACK,
	"res://scenes/PaintingView.tscn":	MAGIC_TRACK,
	"res://scenes/paint_tool.tscn":		PAINT_TRACK,
}

func _ready():
	# Godot 4: SceneTree no longer emits 'scene_changed'. Prefer 'current_scene_changed' if available.
	if get_tree().has_signal("current_scene_changed"):
		get_tree().connect("current_scene_changed", Callable(self, "_on_scene_changed"))
	else:
		# Fallback: listen to 'tree_changed' and debounce checks
		get_tree().connect("tree_changed", Callable(self, "_on_tree_changed"))
	call_deferred("_check_scene")

func _on_scene_changed(_new_scene):
	call_deferred("_check_scene")

var _tree_changed_pending := false
func _on_tree_changed() -> void:
	if _tree_changed_pending:
		return
	_tree_changed_pending = true
	call_deferred("_debounced_check")

func _debounced_check() -> void:
	_tree_changed_pending = false
	_check_scene()

# start_at: where to begin a newly started track, in seconds. The loading
# screen passes how far its music got, when that's this scene's track.
func _check_scene(start_at := 0.0) -> void:
	await get_tree().process_frame
	
	var cs = get_tree().current_scene
	if cs == null:
		return    # nothing to do yet, wait for a real scene
	# The loading screen calls this again once the world is showing.
	if not get_tree().get_nodes_in_group("loading_screen").is_empty():
		return

	var path = cs.scene_file_path
	
	#var path = get_tree().current_scene.scene_file_path
	var new_track = scene_to_track.get(path, null)

	if new_track:
		# If it’s already playing that very same Resource, do absolutely nothing
		if player2.stream == new_track and player2.playing:
			return

		# If changing to a different track, swap streams and play
		player2.stream = new_track
		player2.playback_type = AudioServer.PLAYBACK_TYPE_DEFAULT
		preload("res://scripts/web_audio_policy.gd").configure_player(player2)
		player2.play(fmod(start_at, new_track.get_length()) if start_at > 0.0 else 0.0)
	else:
		# No mapping means stop any music
		if player2.playing:
			player2.stop()
