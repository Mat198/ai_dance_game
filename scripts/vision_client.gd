extends Node
## Autoload singleton. Receives keypoint datagrams from vision_service.py over UDP
## and exposes the most recent player pose to the rest of the game.
##
## Webcam capture + YOLOv8 inference live in Python because Godot's CameraServer
## has no Linux/Windows desktop backend. This node is the bridge.

signal pose_updated(keypoints: Variant, width: int, height: int)

const BIND_HOST := "127.0.0.1"
const BIND_PORT := 5005

var _udp := PacketPeerUDP.new()

## Dictionary of {part_name: {"x": float, "y": float}} for the latest frame, or null
## when no player was detected.
var keypoints: Variant = null
var source_width: int = 0
var source_height: int = 0
var receiving: bool = false

func _ready() -> void:
	var err := _udp.bind(BIND_PORT, BIND_HOST)
	if err != OK:
		push_error("VisionClient: failed to bind udp://%s:%d (error %d)" % [BIND_HOST, BIND_PORT, err])
	else:
		print("VisionClient: listening on udp://%s:%d" % [BIND_HOST, BIND_PORT])

func _process(_delta: float) -> void:
	# Drain the queue and keep only the most recent packet ("latest wins"), so a
	# slow frame never makes us replay stale poses.
	var latest := PackedByteArray()
	var got := false
	while _udp.get_available_packet_count() > 0:
		latest = _udp.get_packet()
		got = true
	if not got:
		return

	var json := JSON.new()
	if json.parse(latest.get_string_from_utf8()) != OK:
		return
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return

	source_width = int(data.get("width", 0))
	source_height = int(data.get("height", 0))
	keypoints = data.get("keypoints", null)
	receiving = true
	pose_updated.emit(keypoints, source_width, source_height)
