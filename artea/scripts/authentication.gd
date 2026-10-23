extends Control
const SceneLoader := preload("res://scripts/scene_loader.gd")

# Every authenticated path begins in the same integrated World One scene used
# by Offline Guest, so account type does not change the player's spawn point.
const WORLD_ONE_SCENE := "res://scenes/art_gallery_3d_inprogress.tscn"
const HUB_SCENE := "res://scenes/New_Hub_World.tscn"


# Called when the node enters the scene tree for the first time.
func _ready():
	Firebase.Auth.login_succeeded.connect(on_login_succeeded)
	Firebase.Auth.signup_succeeded.connect(on_signup_succeeded)
	Firebase.Auth.login_failed.connect(on_login_failed)
	Firebase.Auth.signup_failed.connect(on_signup_failed)
	
	%PasswordLineEdit.secret = true  # Hides password input with bullets/dots
	#if Firebase.Auth.check_auth_file():
		#%StateLabel.text = "Logged in"
		#get_tree().change_scene_to_file("res://Game.tscn")
		
	if OS.get_name() == "Web":
		var provider: AuthProvider = Firebase.Auth.get_GoogleProvider()
		Firebase.Auth.set_redirect_uri(_get_web_redirect_uri())
		var token = Firebase.Auth.get_token_from_url(provider)
		if token:
			Firebase.Auth.login_with_oauth(token, provider)
		else:
			Firebase.Auth.init()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

#when login button is pressed
func _on_login_button_pressed():
	var email = %EmailLineEdit.text
	var password = %PasswordLineEdit.text
	Firebase.Auth.login_with_email_and_password(email, password)
	%StateLabel.text = "Logging in"

#when signup button is pressed
func _on_signup_button_pressed():
	var email = %EmailLineEdit.text
	var password = %PasswordLineEdit.text
	Firebase.Auth.signup_with_email_and_password(email, password)
	%StateLabel.text = "Singing up"

# Called when login is successful
func on_login_succeeded(auth):
	%StateLabel.text = "Login success!"
	Firebase.Auth.save_auth(auth)
	# The hub lives in res://scenes/. The old res://New_Hub_World.tscn does not
	# exist, so logging in dropped the player on a loading screen that never
	# finished — and everything reached through the hub, including the Lens of
	# Seeing, was unreachable from a normal start.
	SceneLoader.change_scene_with_loading(get_tree(), HUB_SCENE)
	#get_tree().change_scene_to_file("res://Game.tscn")
	
# Called when sign up is successful
func on_signup_succeeded(auth):
	%StateLabel.text = "Sign up success!"
	Firebase.Auth.save_auth(auth)
	# change_scene_to_file() loads and builds the hub synchronously on the main
	# thread, so the window sat frozen through shader compilation and grass
	# placement with no feedback. Route through the loading screen like login
	# does, so that cost is hidden behind a progress bar instead.
	SceneLoader.change_scene_with_loading(get_tree(), HUB_SCENE)

# Called if login fails	
func on_login_failed(error_code, message):
	%StateLabel.text = "Login failed. Error: %s" % message

# Called if sign-up fails	
func on_signup_failed(error_code, message):
	%StateLabel.text = "Sign up failed. Error: %s" % message


func _on_sign_in_google_button_pressed():
	var provider: AuthProvider = Firebase.Auth.get_GoogleProvider()
	
	if OS.get_name() == "Web":
		# For web
		Firebase.Auth.set_redirect_uri(_get_web_redirect_uri())
		Firebase.Auth.get_auth_with_redirect(provider)
	else:
		# For desktop
		Firebase.Auth.get_auth_localhost(provider, 8060)

func _get_web_redirect_uri() -> String:
	var redirect_uri = JavaScriptBridge.eval("window.location.origin + window.location.pathname", true)
	if redirect_uri is String and not redirect_uri.is_empty():
		return redirect_uri
	return "http://localhost:8060/index.html"

func _on_d_button_pressed() -> void:
	# Was res://scenes/3DScenes.tscn, which does not exist.
	SceneLoader.change_scene(get_tree(), HUB_SCENE)
	
