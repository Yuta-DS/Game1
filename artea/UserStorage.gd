extends Node

# This dictionary acts as your database
var accounts = {
	"admin": "password123" # A pre-set account for testing
}

func login_user(username, password):
	if accounts.has(username):
		# Checks if the password in the dictionary matches the input
		if accounts[username] == password:
			return "SUCCESS"
		else:
			return "WRONG_PASSWORD"
	else:
		return "USER_NOT_FOUND"

func register_user(username, password):
	# If the name isn't taken, save the password to that name
	if not accounts.has(username):
		accounts[username] = password
		print("Registered new user: ", username)
		return true
	
	return false # Removed the stray period here
