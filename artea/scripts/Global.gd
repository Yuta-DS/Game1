extends Node

var selected_painting_id: int = -1
# Global variables to store the current user's session
var user_uid: String = ""
var user_email: String = ""
var current_user_name = ""
var auth_token = ""

var painting_to_show: int 

var SERVER_BASE := "http://54.252.162.122"
var LOGIN_URL := SERVER_BASE + "/login"
var REGISTER_URL := SERVER_BASE + "/register"
var MY_ARTWORKS_URL := SERVER_BASE + "/my_artworks"
var UPLOAD_ARTWORK_URL := SERVER_BASE + "/upload_artwork"

func _ready() -> void:
	call_deferred("_sync_api_urls")

func _sync_api_urls() -> void:
	SERVER_BASE = APIManager.BASE_URL
	LOGIN_URL = APIManager.LOGIN_URL
	REGISTER_URL = APIManager.REGISTER_URL
	MY_ARTWORKS_URL = APIManager.MY_ARTWORKS_URL
	UPLOAD_ARTWORK_URL = APIManager.UPLOAD_ARTWORK_URL
