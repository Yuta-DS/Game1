extends Control

# Every authenticated path begins in the same integrated World One scene used
# by Offline Guest, so account type does not change the player's spawn point.
const WORLD_ONE_SCENE := "res://scenes/art_gallery_3d_inprogress.tscn"


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
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	# The hub lives in res://scenes/. The old res://New_Hub_World.tscn does not
	# exist, so logging in dropped the player on a loading screen that never
	# finished — and everything reached through the hub, including the Lens of
	# Seeing, was unreachable from a normal start.
	loading_screen.next_scene_path = WORLD_ONE_SCENE
	
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free() 
	#get_tree().change_scene_to_file("res://Game.tscn")
	
# Called when sign up is successful	
func on_signup_succeeded(auth):
	%StateLabel.text = "Sign up success!"
	Firebase.Auth.save_auth(auth)
	# Was res://Game.tscn, which does not exist: a player who registered a new
	# account landed nowhere.
	get_tree().change_scene_to_file(WORLD_ONE_SCENE)

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
	get_tree().change_scene_to_file(WORLD_ONE_SCENE)
	
