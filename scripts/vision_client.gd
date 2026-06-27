extends Node
## Autoload singleton. Receives keypoint datagrams from vision_service.py over UDP
## and exposes the most recent detected players to the rest of the game.
##
## Webcam capture + YOLOv8 inference live in Python because Godot's CameraServer
## has no Linux/Windows desktop backend. This node is the bridge.

signal players_updated(players: Array, width: int, height: int)

const BIND_HOST := "127.0.0.1"
const BIND_PORT := 5005

var _udp := PacketPeerUDP.new()

## Up to MAX_PLAYERS pose dicts for the latest frame, ordered left-to-right by
## image position. Empty when nobody is detected. Each entry is
## {part_name: {"x": float, "y": float, "c": float}}.
var players: Array = []
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
	var incoming = data.get("players", [])
	players = incoming if typeof(incoming) == TYPE_ARRAY else []
	receiving = true
	players_updated.emit(players, source_width, source_height)
