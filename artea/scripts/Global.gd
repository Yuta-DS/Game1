extends Node

const SceneLoader := preload("res://scripts/scene_loader.gd")

# Kept so the page's handle on the callback stays valid.
var _js_go: JavaScriptObject

var selected_painting_id: int = -1
# Global variables to store the current user's session
var user_uid: String = ""
var user_email: String = ""
var current_user_name = ""
var auth_token = ""

var painting_to_show: int

# --- Scene-to-scene spawn handoff -------------------------------------
#
# change_scene_to_file rebuilds the target scene from disk, so the player is
# always placed wherever the .tscn authored them. Leaving the Art Castle that
# way dropped the player back at the hub's default start point, a long walk
# from the castle they had just stepped out of.
#
# A scene that sends the player somewhere sets pending_spawn_point to a named
# arrival marker; the receiving scene consumes it once and places the player
# there. Consuming clears it, so a later normal entry into the same scene still
# uses the authored start position.
var pending_spawn_point: String = ""


# The web smoke test (tools/web-smoke.js) moves between areas through this:
# window.arteaGo("res://scenes/...") takes the route a teleporter or the
# journey takes - SceneLoader, the loading screen and any Pack downloads -
# without walking the player to every door.
func _ready() -> void:
	if OS.has_feature("web"):
		_js_go = JavaScriptBridge.create_callback(func(args):
			SceneLoader.change_scene_with_loading(get_tree(), str(args[0])))
		JavaScriptBridge.get_interface("window").arteaGo = _js_go


func request_spawn_at(spawn_point: String) -> void:
	pending_spawn_point = spawn_point


# Returns the pending spawn point and clears it, so it applies exactly once.
func consume_spawn_point() -> String:
	var point := pending_spawn_point
	pending_spawn_point = ""
	return point

var SERVER_BASE: String:
	get: return APIManager.BASE_URL
var LOGIN_URL: String:
	get: return APIManager.LOGIN_URL
var REGISTER_URL: String:
	get: return APIManager.REGISTER_URL
var MY_ARTWORKS_URL: String:
	get: return APIManager.MY_ARTWORKS_URL
var UPLOAD_ARTWORK_URL: String:
	get: return APIManager.UPLOAD_ARTWORK_URL
