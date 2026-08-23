extends Node

var selected_painting_id: int = -1
# Global variables to store the current user's session
var user_uid: String = ""
var user_email: String = ""
var current_user_name = ""
var auth_token = ""

var painting_to_show: int 

func has_online_session() -> bool:
	return not auth_token.is_empty() and auth_token != "OFFLINE_GUEST_TOKEN" and auth_token != "invalid_token"
