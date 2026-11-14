extends Node

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


func request_spawn_at(spawn_point: String) -> void:
	pending_spawn_point = spawn_point


# Returns the pending spawn point and clears it, so it applies exactly once.
func consume_spawn_point() -> String:
	var point := pending_spawn_point
	pending_spawn_point = ""
	return point

const SERVER_BASE = "http://54.252.162.122"

const LOGIN_URL = SERVER_BASE + "/login"
const REGISTER_URL = SERVER_BASE + "/register"
const MY_ARTWORKS_URL = SERVER_BASE + "/my_artworks"
const UPLOAD_ARTWORK_URL = SERVER_BASE + "/upload_artwork"
