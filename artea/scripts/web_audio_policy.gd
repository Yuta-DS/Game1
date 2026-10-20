extends Node

## Web's sample backend decodes the entire track to a Web Audio buffer.
## Keep that low-latency path for notes/effects, but stream long soundtracks
## so visiting another world cannot allocate hundreds of megabytes of PCM.
const MAX_SAMPLE_SECONDS := 30.0

func _enter_tree() -> void:
	if OS.has_feature("web"):
		get_tree().node_added.connect(configure_player)

static func configure_player(node: Node, web: bool = OS.has_feature("web")) -> void:
	if not web or not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		return
	var stream := node.get("stream") as AudioStream
	if stream != null and stream.get_length() > MAX_SAMPLE_SECONDS:
		node.set("playback_type", AudioServer.PLAYBACK_TYPE_STREAM)
