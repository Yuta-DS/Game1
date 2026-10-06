@tool
class_name DesignSupervisorBridge
extends Node

const DEFAULT_PORT := 48231

var _plugin: EditorPlugin
var _server := TCPServer.new()
var _clients: Array[Dictionary] = []
var _token := ""
var _port := DEFAULT_PORT
var _running := false


func configure(plugin: EditorPlugin, port: int = DEFAULT_PORT) -> void:
	_plugin = plugin
	_port = port


func start() -> Dictionary:
	_token = Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(24))
	var error := _server.listen(_port, "127.0.0.1")
	if error != OK:
		return {
			"ok": false, "error": "Could not listen on 127.0.0.1:%d (error %d)." % [_port, error]
		}
	_running = true
	set_process(true)
	return {"ok": true, "port": _port, "token": _token}


func stop() -> void:
	_running = false
	set_process(false)
	for client in _clients:
		var peer: StreamPeerTCP = client.get("peer")
		if is_instance_valid(peer):
			peer.disconnect_from_host()
	_clients.clear()
	_server.stop()


func get_token() -> String:
	return _token


func get_port() -> int:
	return _port


func _process(_delta: float) -> void:
	if not _running:
		return
	while _server.is_connection_available():
		var peer := _server.take_connection()
		_clients.append({"peer": peer, "buffer": PackedByteArray()})

	for index in range(_clients.size() - 1, -1, -1):
		var client := _clients[index]
		var peer: StreamPeerTCP = client["peer"]
		peer.poll()
		var status := peer.get_status()
		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			_clients.remove_at(index)
			continue
		var available := peer.get_available_bytes()
		if available > 0:
			var result := peer.get_data(available)
			if result[0] == OK:
				var buffer: PackedByteArray = client["buffer"]
				buffer.append_array(result[1])
				client["buffer"] = buffer
				_clients[index] = client
		if _request_is_complete(client["buffer"]):
			_handle_request(peer, client["buffer"])
			_clients.remove_at(index)


func _request_is_complete(buffer: PackedByteArray) -> bool:
	var request := buffer.get_string_from_utf8()
	var split_at := request.find("\r\n\r\n")
	if split_at < 0:
		return false
	var content_length := 0
	for header in request.substr(0, split_at).split("\r\n"):
		if header.to_lower().begins_with("content-length:"):
			content_length = int(header.get_slice(":", 1).strip_edges())
	return request.length() >= split_at + 4 + content_length


func _handle_request(peer: StreamPeerTCP, buffer: PackedByteArray) -> void:
	var request := buffer.get_string_from_utf8()
	var split_at := request.find("\r\n\r\n")
	var header_text := request.substr(0, split_at)
	var body := request.substr(split_at + 4)
	var lines := header_text.split("\r\n")
	var request_line := lines[0].split(" ")
	if request_line.size() < 2:
		_send_json(peer, 400, {"ok": false, "error": "Malformed request."})
		return
	var method := String(request_line[0])
	var path := String(request_line[1])
	if method == "OPTIONS":
		_send_json(peer, 200, {"ok": true})
		return
	var authorization := ""
	var origin := ""
	for line in lines.slice(1):
		if String(line).to_lower().begins_with("authorization:"):
			authorization = String(line).get_slice(":", 1).strip_edges()
		if String(line).to_lower().begins_with("origin:"):
			origin = String(line).get_slice(":", 1).strip_edges()

	if method == "GET" and path == "/ready":
		_send_json(peer, 200, {"ok": true, "service": "visual-design-supervisor"})
		return
	if method == "GET" and path == "/panel":
		_send_panel(peer)
		return
	if method == "GET" and path == "/session":
		if not origin.is_empty():
			_send_json(
				peer, 403, {"ok": false, "error": "Browser session discovery is not allowed."}
			)
			return
		_send_json(peer, 200, {"ok": true, "token": _token}, false)
		return
	if authorization != "Bearer %s" % _token:
		_send_json(peer, 401, {"ok": false, "error": "Invalid Design Supervisor connection token."})
		return

	if method == "GET" and path == "/health":
		_send_json(
			peer,
			200,
			{
				"ok": true,
				"service": "visual-design-supervisor",
				"version": "0.1.2",
				"project": ProjectSettings.get_setting("application/config/name", "Godot Project")
			}
		)
		return
	if method != "POST" or path != "/command":
		_send_json(peer, 404, {"ok": false, "error": "Unknown endpoint."})
		return

	var parsed = JSON.parse_string(body)
	if not parsed is Dictionary:
		_send_json(peer, 400, {"ok": false, "error": "Request body must be a JSON object."})
		return
	var action := String(parsed.get("action", ""))
	var arguments: Dictionary = parsed.get("arguments", {})
	var response: Dictionary = _plugin.handle_bridge_action(action, arguments)
	_send_json(peer, 200 if response.get("ok", false) else 422, response)


func _send_panel(peer: StreamPeerTCP) -> void:
	var panel_path := "res://addons/design_supervisor/standalone_panel.html"
	if not FileAccess.file_exists(panel_path):
		_send_json(peer, 500, {"ok": false, "error": "The Design Supervisor panel is missing."})
		return
	var body := FileAccess.get_file_as_string(panel_path).replace("__VDS_TOKEN__", _token)
	var response_template := (
		"HTTP/1.1 200 OK\r\n"
		+ "Content-Type: text/html; charset=utf-8\r\n"
		+ "Cache-Control: no-store\r\n"
		+ "Content-Security-Policy: default-src 'self' 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'\r\n"
		+ "Referrer-Policy: no-referrer\r\n"
		+ "X-Frame-Options: DENY\r\n"
		+ "Content-Length: %d\r\n"
		+ "Connection: close\r\n\r\n%s"
	)
	var response := response_template % [body.to_utf8_buffer().size(), body]
	peer.put_data(response.to_utf8_buffer())
	peer.disconnect_from_host()


func _send_json(
	peer: StreamPeerTCP, status: int, payload: Dictionary, allow_browser_origin: bool = true
) -> void:
	var body := JSON.stringify(payload)
	var label := "OK" if status >= 200 and status < 300 else "Error"
	var cors_headers := ""
	if allow_browser_origin:
		cors_headers = (
			"Access-Control-Allow-Origin: *\r\n"
			+ "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
			+ "Access-Control-Allow-Headers: Authorization, Content-Type\r\n"
			+ "Access-Control-Allow-Private-Network: true\r\n"
		)
	var response_template := (
		"HTTP/1.1 %d %s\r\n"
		+ "Content-Type: application/json\r\n"
		+ "%s"
		+ "Content-Length: %d\r\n"
		+ "Connection: close\r\n\r\n%s"
	)
	var response := (
		response_template % [status, label, cors_headers, body.to_utf8_buffer().size(), body]
	)
	peer.put_data(response.to_utf8_buffer())
	peer.disconnect_from_host()
