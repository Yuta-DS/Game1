extends Node

const BASE_URL = "http://54.252.162.122"
const LOGIN_URL = BASE_URL + "/login"
const REGISTER_URL = BASE_URL + "/register"

const UPLOAD_ARTWORK_URL = BASE_URL + "/upload_artwork"
const MY_ARTWORKS_URL = BASE_URL + "/my_artworks"

var auth_token = ""

# =========================
# LOGIN
# =========================

func login(username: String, password: String, callback: Callable):

	var http = HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(
		func(result, response_code, headers, body):

			var json = JSON.parse_string(body.get_string_from_utf8())

			if response_code == 200:

				auth_token = json["token"]

				callback.call(true, json)

			else:

				callback.call(false, json)

			http.queue_free()
	)

	var body_data = {
		"username": username,
		"password": password
	}

	var json_body = JSON.stringify(body_data)

	var headers = [
		"Content-Type: application/json"
	]

	http.request(
		BASE_URL + "/login",
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)

# =========================
# REGISTER
# =========================

func register(username: String, password: String, callback: Callable):

	var http = HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(
		func(result, response_code, headers, body):

			var json = JSON.parse_string(body.get_string_from_utf8())

			if response_code == 201:

				callback.call(true, json)

			else:

				callback.call(false, json)

			http.queue_free()
	)

	var body_data = {
		"username": username,
		"password": password
	}

	var json_body = JSON.stringify(body_data)

	var headers = [
		"Content-Type: application/json"
	]

	http.request(
		BASE_URL + "/register",
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)
