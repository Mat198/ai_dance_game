extends Node2D
## In-game choreography recorder. Pick a song, press Play with your right hand
## (used as a cursor), get counted in, then your pose is recorded to a timeline at
## res://choreography/dance.csv, synced to the song. Buttons sit on the right edge,
## far from the centre, and need a brief hold to trigger — both to avoid misclicks.

const WINDOW_W := 1280.0
const WINDOW_H := 1440.0
const SONGS_DIR := "res://songs"
const CHOREO_DIR := "res://choreography"

const RECORD_FPS := 15.0
const RECORD_SECONDS := 30.0      # testing cap; Stop ends it early
const COUNTDOWN_SECONDS := 3.0
const HOLD_TIME := 0.7            # the hand must rest on a button this long to trigger
const CURSOR_CONF := 0.3
const WRIST := "right_wrist"

# Faint background avatar so the user can see themselves and aim the cursor.
const BONES := [
	["left_shoulder", "right_shoulder"], ["left_shoulder", "left_elbow"], ["left_elbow", "left_wrist"],
	["right_shoulder", "right_elbow"], ["right_elbow", "right_wrist"],
	["left_shoulder", "left_hip"], ["right_shoulder", "right_hip"], ["left_hip", "right_hip"],
	["left_hip", "left_knee"], ["left_knee", "left_ankle"], ["right_hip", "right_knee"], ["right_knee", "right_ankle"],
]

enum Phase { SELECT, READY, COUNTDOWN, RECORDING, SAVED }

var phase := Phase.SELECT
var songs: Array = []        # [{ "name": String, "path": String }]
var selected := -1
var buttons: Array = []      # [{ "rect": Rect2, "label": String, "id": String }]
var cursor_pos = null        # Vector2 or null
var hover_id := ""
var hold_timer := 0.0
var countdown := COUNTDOWN_SECONDS
var status_text := ""

var audio: AudioStreamPlayer
var frames: Array = []
var last_pose = null
var rec_width := 0
var rec_height := 0

var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	audio = AudioStreamPlayer.new()
	audio.volume_db = linear_to_db(0.7)
	audio.finished.connect(_on_song_finished)
	add_child(audio)
	_load_songs()
	_set_phase(Phase.SELECT)

func _load_songs() -> void:
	songs.clear()
	var dir := DirAccess.open(SONGS_DIR)
	if dir:
		for f in dir.get_files():
			if f.to_lower().ends_with(".mp3"):
				songs.append({"name": f.get_basename(), "path": "%s/%s" % [SONGS_DIR, f]})

func _process(delta: float) -> void:
	cursor_pos = _hand_cursor()
	match phase:
		Phase.COUNTDOWN:
			countdown -= delta
			if countdown <= 0.0:
				_start_recording()
		Phase.RECORDING:
			_update_recording()
		_:
			pass
	if phase != Phase.COUNTDOWN:
		_update_hand_buttons(delta)
	queue_redraw()

# --- phase + buttons ------------------------------------------------------------

func _set_phase(p: Phase) -> void:
	phase = p
	hover_id = ""
	hold_timer = 0.0
	match p:
		Phase.SELECT:
			status_text = "Pick a song" if not songs.is_empty() else "Add .mp3 files to songs/"
		Phase.READY:
			status_text = str(songs[selected]["name"]) if selected >= 0 else ""
		Phase.RECORDING:
			status_text = "Recording…"
		Phase.SAVED:
			pass  # set by _finish_recording
	_build_buttons()

func _build_buttons() -> void:
	buttons.clear()
	var bw := 380.0
	var x := WINDOW_W - bw - 60.0  # right edge, far from the centre
	var back := {"rect": Rect2(WINDOW_W - 300.0, 40.0, 240.0, 80.0), "label": "Back", "id": "menu"}
	match phase:
		Phase.SELECT:
			var y := 240.0
			for i in songs.size():
				buttons.append({"rect": Rect2(x, y, bw, 110.0), "label": str(songs[i]["name"]), "id": "song:%d" % i})
				y += 134.0
			buttons.append(back)
		Phase.READY:
			buttons.append({"rect": Rect2(x, 560.0, bw, 160.0), "label": "Play", "id": "play"})
			buttons.append({"rect": Rect2(x, 760.0, bw, 110.0), "label": "Choose another", "id": "reselect"})
			buttons.append(back)
		Phase.RECORDING:
			buttons.append({"rect": Rect2(WINDOW_W - 300.0, 40.0, 240.0, 90.0), "label": "Stop", "id": "stop"})
		Phase.SAVED:
			buttons.append({"rect": Rect2(x, 520.0, bw, 130.0), "label": "Record again", "id": "again"})
			buttons.append({"rect": Rect2(x, 690.0, bw, 130.0), "label": "Back to menu", "id": "menu"})
		_:
			pass

func _update_hand_buttons(delta: float) -> void:
	var hovered := ""
	if cursor_pos != null:
		for b in buttons:
			if b["rect"].has_point(cursor_pos):
				hovered = b["id"]
				break
	if hovered != "" and hovered == hover_id:
		hold_timer += delta
		if hold_timer >= HOLD_TIME:
			var id := hover_id
			hover_id = ""
			hold_timer = 0.0
			_activate(id)
	else:
		hover_id = hovered
		hold_timer = 0.0

func _activate(id: String) -> void:
	if id == "menu":
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
	elif id == "reselect" or id == "again":
		_set_phase(Phase.SELECT)
	elif id == "play":
		countdown = COUNTDOWN_SECONDS
		_set_phase(Phase.COUNTDOWN)
	elif id == "stop":
		_finish_recording()
	elif id.begins_with("song:"):
		selected = int(id.substr(5))
		_set_phase(Phase.READY)

# --- recording ------------------------------------------------------------------

func _start_recording() -> void:
	frames.clear()
	last_pose = null
	rec_width = VisionClient.source_width
	rec_height = VisionClient.source_height
	audio.stream = load(songs[selected]["path"])
	_set_phase(Phase.RECORDING)
	audio.play()

func _update_recording() -> void:
	if not audio.playing:
		return
	var pos := audio.get_playback_position()
	# Capture frames at a fixed rate keyed to playback position (uniform spacing).
	var target := int(pos * RECORD_FPS)
	while frames.size() < target:
		frames.append(_snapshot_pose())
	if pos >= RECORD_SECONDS:
		_finish_recording()

func _snapshot_pose() -> Dictionary:
	var players: Array = VisionClient.players
	if players.size() > 0 and players[0] != null:
		last_pose = players[0]
		if VisionClient.source_width > 0:
			rec_width = VisionClient.source_width
			rec_height = VisionClient.source_height
	return last_pose if last_pose != null else {}

func _on_song_finished() -> void:
	if phase == Phase.RECORDING:
		_finish_recording()

func _finish_recording() -> void:
	if phase != Phase.RECORDING:
		return
	audio.stop()
	var path := _save_csv()
	status_text = ("Saved %s (%d frames)!" % [path.get_file(), frames.size()]) if path != "" else "Save failed"
	_set_phase(Phase.SAVED)

## Saves to choreography/<song-slug>_N.csv, picking the next free index for the song.
func _save_csv() -> String:
	if frames.is_empty():
		return ""
	var slug := _slugify(str(songs[selected]["name"]))
	if slug == "":
		slug = "dance"
	var path := _next_output_path(slug)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Recorder: cannot write %s" % path)
		return ""
	var w := rec_width if rec_width > 0 else 1280
	var h := rec_height if rec_height > 0 else 720
	f.store_line("# fps=%.2f width=%d height=%d" % [RECORD_FPS, w, h])
	f.store_line("# song=%s" % songs[selected]["path"])
	var header := PackedStringArray()
	for n in Choreography.KEYPOINT_NAMES:
		header.append(n + "_x")
		header.append(n + "_y")
		header.append(n + "_c")
	f.store_line(",".join(header))
	for pose in frames:
		var row := PackedStringArray()
		for n in Choreography.KEYPOINT_NAMES:
			if pose.has(n):
				var kp = pose[n]
				row.append(str(int(kp["x"])))
				row.append(str(int(kp["y"])))
				row.append("%.3f" % float(kp.get("c", 1.0)))
			else:
				row.append("0")
				row.append("0")
				row.append("0")
		f.store_line(",".join(row))
	f.close()
	return path

## Lowercase-safe slug: keep alphanumerics, turn everything else into single "_".
func _slugify(text: String) -> String:
	var out := ""
	for ch in text:
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			out += ch
		else:
			out += "_"
	while out.find("__") != -1:
		out = out.replace("__", "_")
	return out.strip_edges().trim_prefix("_").trim_suffix("_")

## choreography/<slug>_N.csv with N one past the highest existing index for the slug.
func _next_output_path(slug: String) -> String:
	var highest := 0
	var dir := DirAccess.open(CHOREO_DIR)
	if dir:
		var prefix := slug + "_"
		for f in dir.get_files():
			if f.begins_with(prefix) and f.ends_with(".csv"):
				var mid := f.substr(prefix.length(), f.length() - prefix.length() - 4)
				if mid.is_valid_int():
					highest = maxi(highest, int(mid))
	return "%s/%s_%d.csv" % [CHOREO_DIR, slug, highest + 1]

# --- hand cursor / mapping ------------------------------------------------------

func _hand_cursor():
	return _map_part(_player_pose(), WRIST)

func _player_pose():
	var players: Array = VisionClient.players
	if players.is_empty() or players[0] == null:
		return null
	return players[0]

## Map a keypoint into full-screen coords (mirrored), or null if not visible.
func _map_part(pose, part: String):
	if pose == null or not pose.has(part):
		return null
	var p = pose[part]
	if int(p["x"]) == 0 and int(p["y"]) == 0:
		return null
	if p.has("c") and float(p["c"]) < CURSOR_CONF:
		return null
	var sw := float(VisionClient.source_width)
	var sh := float(VisionClient.source_height)
	if sw <= 0.0 or sh <= 0.0:
		return null
	return Vector2(WINDOW_W - float(p["x"]) / sw * WINDOW_W, float(p["y"]) / sh * WINDOW_H)

# --- drawing --------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(0, 0, WINDOW_W, WINDOW_H), Color(0.08, 0.09, 0.13))
	_draw_avatar()
	if status_text != "":
		draw_string(_font, Vector2(0, 130.0), status_text, HORIZONTAL_ALIGNMENT_CENTER, WINDOW_W, 64, Color(1, 1, 1, 0.92))
	if phase == Phase.COUNTDOWN:
		draw_string(_font, Vector2(0, WINDOW_H * 0.5), str(int(ceil(countdown))), HORIZONTAL_ALIGNMENT_CENTER, WINDOW_W, 220, Color(1, 1, 1))
	elif phase == Phase.RECORDING:
		_draw_progress()
	for b in buttons:
		_draw_button(b)
	_draw_cursor()

func _draw_avatar() -> void:
	var pose = _player_pose()
	if pose == null:
		return
	var col := Color(1, 1, 1, 0.18)
	for bone in BONES:
		var a = _map_part(pose, bone[0])
		var b = _map_part(pose, bone[1])
		if a != null and b != null:
			draw_line(a, b, col, 6.0, true)

func _draw_button(b: Dictionary) -> void:
	var rect: Rect2 = b["rect"]
	draw_rect(rect, Color(0.18, 0.36, 0.66, 0.85), true)
	if b["id"] == hover_id and hold_timer > 0.0:
		var frac := clampf(hold_timer / HOLD_TIME, 0.0, 1.0)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * frac, rect.size.y)), Color(0.3, 0.8, 1.0, 0.7), true)
	draw_rect(rect, Color(1, 1, 1, 0.5), false, 2.0)
	var ty := rect.position.y + rect.size.y * 0.5 + 12.0
	draw_string(_font, Vector2(rect.position.x, ty), str(b["label"]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 34, Color(1, 1, 1))

func _draw_progress() -> void:
	var pos := audio.get_playback_position() if audio.playing else 0.0
	var frac := clampf(pos / RECORD_SECONDS, 0.0, 1.0)
	var m := 60.0
	var bar_w := WINDOW_W - m * 2.0
	draw_rect(Rect2(m, 40.0, bar_w, 18.0), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(m, 40.0, bar_w * frac, 18.0), Color(1.0, 0.4, 0.4))

func _draw_cursor() -> void:
	if cursor_pos == null:
		return
	draw_circle(cursor_pos, 26.0, Color(0.3, 0.9, 1.0, 0.5))
	draw_arc(cursor_pos, 30.0, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 3.0, true)
	if hover_id != "" and hold_timer > 0.0:
		var frac := clampf(hold_timer / HOLD_TIME, 0.0, 1.0)
		draw_arc(cursor_pos, 34.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, Color(0.3, 1.0, 0.5), 5.0, true)
