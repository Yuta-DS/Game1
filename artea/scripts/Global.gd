extends Node

var selected_painting_id: int = -1
# Global variables to store the current user's session
var user_uid: String = ""
var user_email: String = ""
var current_user_name = ""
var auth_token = ""

var painting_to_show: int 

const SERVER_BASE = "http://54.252.162.122"

const LOGIN_URL = SERVER_BASE + "/login"
const REGISTER_URL = SERVER_BASE + "/register"
const MY_ARTWORKS_URL = SERVER_BASE + "/my_artworks"
const UPLOAD_ARTWORK_URL = SERVER_BASE + "/upload_artwork"
