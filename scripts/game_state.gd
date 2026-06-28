extends Node
## Autoload singleton: cross-scene state plus a couple of app-wide helpers.

func _ready() -> void:
	# Deployed launcher passes `-- --fullscreen`; the editor (F5) stays windowed.
	if OS.get_cmdline_user_args().has("--fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

## Load an .mp3 from raw bytes so songs dropped into songs/ play without needing the
## Godot editor to import them (works for res:// and absolute paths alike).
func load_mp3(path: String) -> AudioStream:
	var stream := AudioStreamMP3.new()
	stream.data = FileAccess.get_file_as_bytes(path)
	return stream

var player_count: int = 1
## res:// path of the choreography to play (chosen on the song-select screen);
## "" means use the default.
var choreography_path: String = ""
## Per-player final totals, set by the Game scene and read by the Results scene.
var scores: Array = []
