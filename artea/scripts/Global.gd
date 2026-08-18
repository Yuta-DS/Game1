extends Node

var selected_painting_id: int = -1
# Global variables to store the current user's session
var user_uid: String = ""
var user_email: String = ""
var current_user_name = ""
var auth_token = ""

# True when the player entered via "Play Offline as Guest".
# Guest sessions must never touch the network.
var is_guest: bool = false

# Single source of truth for "can this session make API calls?"
func is_online_session() -> bool:
	return not is_guest and auth_token != "" and auth_token != "invalid_token"

# The nobodywho GDExtension has no web/wasm build, and the .gguf models are
# far too large to ship in a browser bundle. Anything touching the local LLM
# must check this first and degrade gracefully.
func has_local_llm() -> bool:
	return OS.get_name() != "Web" and ClassDB.class_exists("NobodyWhoModel")

var painting_to_show: int 

const SERVER_BASE = "http://54.252.162.122"

const LOGIN_URL = SERVER_BASE + "/login"
const REGISTER_URL = SERVER_BASE + "/register"
const MY_ARTWORKS_URL = SERVER_BASE + "/my_artworks"
const UPLOAD_ARTWORK_URL = SERVER_BASE + "/upload_artwork"
