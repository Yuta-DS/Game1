extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var server := TCPServer.new()
	var port := 19870
	while port<19880 and server.listen(port,"127.0.0.1")!=OK: port+=1
	assert(port<19880,"No fixture port available")
	var listener: Node=load("res://addons/http-sse-client/HTTPSSEClient.gd").new()
	root.add_child(listener)
	var events: Array=[]
	listener.new_sse_event.connect(func(_headers,event,data): events.append({"event":event,"data":data}))
	listener.connect_to_host("http://127.0.0.1","/fixture.json",port)
	var peer: StreamPeerTCP
	var request := ""
	var sent := false
	var deadline := Time.get_ticks_msec()+5000
	while events.is_empty() and Time.get_ticks_msec()<deadline:
		if peer==null and server.is_connection_available(): peer=server.take_connection()
		if peer!=null:
			peer.poll()
			var available := peer.get_available_bytes()
			if available>0:
				var packet := peer.get_data(available)
				request+=(packet[1] as PackedByteArray).get_string_from_utf8()
			if not sent and request.contains("\r\n\r\n"):
				var body := "event: put\ndata: {\"path\":\"/\",\"data\":{\"message\":\"local fixture\"}}\n\n"
				var response := "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nContent-Length: %d\r\n\r\n%s"%[body.to_utf8_buffer().size(),body]
				peer.put_data(response.to_utf8_buffer())
				sent=true
		await process_frame
	var passed := request.begins_with("GET /fixture.json HTTP/1.1") and request.to_lower().contains("accept: text/event-stream") and events.size()==1
	if passed: passed=events[0].data.data.message=="local fixture" and events[0].event=="put"
	listener.queue_free()
	if peer!=null: peer.disconnect_from_host()
	server.stop()
	await process_frame
	if not passed:
		push_error("SSE local read-only handshake/event failed; event count=%d"%events.size())
		quit(1)
		return
	print("FIREBASE_SSE_DEPENDENCY: PASS — localhost GET, event-stream header and Firebase put event; no live database contacted")
	quit()
