extends Node2D
## Main gameplay scene. Counts the player(s) in, plays the song, advances the
## choreography by playback position, scores each player against the shared
## reference, renders the figures, shows a progress bar, and ends when the song
## stops (capped at MAX_DURATION for testing). Supports 1 or 2 players.

const DEFAULT_SONG := "res://songs/Cartoon, Jéja - On & On (feat. Daniel Levi) [NCS Release].mp3"

const COUNTDOWN_SECONDS := 3.0
## All required players must be present this many consecutive frames before the
## countdown starts (avoids false starts from a single flickery detection).
const READY_FRAMES := 5
## Pause after this many consecutive frames with NO player detected.
const MISSING_LIMIT := 10
## Testing cap: end the dance after this many seconds even if the song is longer.
const MAX_DURATION := 30.0
const PROGRESS_MARGIN := 12.0

enum State { WAITING, COUNTDOWN, PLAYING, PAUSED, ENDED }

var choreo: Choreography
var audio: AudioStreamPlayer
var overlay: PoseOverlay
var status_label: Label
var progress_fill: ColorRect

var player_count := 1
var state := State.WAITING
var countdown := COUNTDOWN_SECONDS
var ready_frames := 0
var missing_frames := 0
var current_time := 0.0

# Per-player live match: a running average of the (temporal-tolerant) match score,
# shown as a 0-100 percentage. The winner is simply the higher average.
var score_sum: Array = []     # float per player
var score_count: Array = []   # int per player
var score_labels: Array = []  # Label per player

func _ready() -> void:
	player_count = maxi(1, GameState.player_count)

	choreo = Choreography.new()
	if not choreo.load_dance():
		push_error("Game: failed to load choreography; returning to menu")
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		return

	overlay = PoseOverlay.new()
	overlay.player_count = player_count
	overlay.ref_width = choreo.ref_width
	overlay.ref_height = choreo.ref_height
	overlay.reference_pose = choreo.reference_pose_at(0.0)
	add_child(overlay)
	VisionClient.players_updated.connect(_on_players_updated)

	# Per-player score accumulators + labels (over each player's panel).
	for i in player_count:
		score_sum.append(0.0)
		score_count.append(0)
		var lbl := Label.new()
		lbl.position = _score_label_pos(i)
		lbl.add_theme_font_size_override("font_size", 32)
		lbl.modulate = PoseOverlay.PLAYER_COLORS[i % PoseOverlay.PLAYER_COLORS.size()]
		lbl.text = _score_text(i)
		add_child(lbl)
		score_labels.append(lbl)

	# Label over the shared reference panel.
	var target_label := Label.new()
	target_label.position = Vector2(12, PoseOverlay.TOP_MARGIN + PoseOverlay.PLAYER_ROW_H + 8)
	target_label.add_theme_font_size_override("font_size", 32)
	target_label.text = "Match this!"
	add_child(target_label)

	# Big centred message for the countdown and the "step into frame" pause.
	status_label = Label.new()
	status_label.position = Vector2(0, PoseOverlay.TOP_MARGIN + PoseOverlay.PLAYER_ROW_H * 0.5 - 100.0)
	status_label.size = Vector2(PoseOverlay.WINDOW_W, 200)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.add_theme_font_size_override("font_size", 96)
	status_label.text = _waiting_text(0)
	add_child(status_label)

	_build_progress_bar()

	# Music (started once the countdown finishes). Use the song the choreography was
	# recorded to, if it specifies one; otherwise the default.
	var song := DEFAULT_SONG
	if choreo.song_path != "" and FileAccess.file_exists(choreo.song_path):
		song = choreo.song_path
	audio = AudioStreamPlayer.new()
	audio.stream = load(song)
	audio.volume_db = linear_to_db(0.7)
	audio.finished.connect(_end_game)
	add_child(audio)

func _process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			countdown -= delta
			if countdown <= 0.0:
				_start_playing()
			else:
				status_label.text = str(int(ceil(countdown)))
		State.PLAYING:
			_update_gameplay()
		_:
			pass

func _update_gameplay() -> void:
	if not audio.playing:
		return
	var pos := audio.get_playback_position()
	_update_progress(pos)
	if pos >= MAX_DURATION:
		_end_game()
		return
	# Loop the choreography over the length of the song, and show the interpolated
	# reference pose for the current time.
	var dur := choreo.duration()
	current_time = fmod(pos, dur) if dur > 0.0 else pos
	overlay.reference_pose = choreo.reference_pose_at(current_time)
	overlay.queue_redraw()

func _start_playing() -> void:
	state = State.PLAYING
	status_label.visible = false
	audio.play()

## While WAITING: start the countdown once all required players have been present
## for READY_FRAMES consecutive frames.
func _update_waiting(detected: int) -> void:
	status_label.text = _waiting_text(detected)
	if detected >= player_count:
		ready_frames += 1
		if ready_frames >= READY_FRAMES:
			_begin_countdown()
	else:
		ready_frames = 0

func _begin_countdown() -> void:
	state = State.COUNTDOWN
	countdown = COUNTDOWN_SECONDS
	status_label.text = str(int(COUNTDOWN_SECONDS))

func _waiting_text(detected: int) -> String:
	if player_count >= 2:
		return "Waiting for players\n%d / %d ready" % [mini(detected, player_count), player_count]
	return "Step into frame"

## Tracks presence, samples each player's match, and redraws on every frame.
func _on_players_updated(players: Array, _width: int, _height: int) -> void:
	overlay.queue_redraw()
	if state == State.WAITING:
		_update_waiting(players.size())
		return
	if players.is_empty():
		missing_frames += 1
		if missing_frames >= MISSING_LIMIT and state == State.PLAYING:
			_pause_for_detection()
		return
	missing_frames = 0
	if state == State.PAUSED:
		_resume_after_detection()
	if state == State.PLAYING:
		for i in player_count:
			if i < players.size() and players[i] != null:
				var s := choreo.score_at(players[i], current_time)
				if s >= 0.0:
					score_sum[i] += s
					score_count[i] += 1
					score_labels[i].text = _score_text(i)

func _pause_for_detection() -> void:
	state = State.PAUSED
	audio.stream_paused = true
	status_label.text = "Step into frame!"
	status_label.visible = true

func _resume_after_detection() -> void:
	state = State.PLAYING
	audio.stream_paused = false
	status_label.visible = false

func _end_game() -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	var finals := []
	for i in player_count:
		finals.append(_live_score(i))
	GameState.player_count = player_count
	GameState.scores = finals
	get_tree().change_scene_to_file("res://scenes/Results.tscn")

# --- progress bar ---------------------------------------------------------------

func _build_progress_bar() -> void:
	var bar_w := PoseOverlay.WINDOW_W - PROGRESS_MARGIN * 2.0
	var bg := ColorRect.new()
	bg.position = Vector2(PROGRESS_MARGIN, 6.0)
	bg.size = Vector2(bar_w, 16.0)
	bg.color = Color(1, 1, 1, 0.15)
	add_child(bg)

	progress_fill = ColorRect.new()
	progress_fill.position = Vector2(PROGRESS_MARGIN, 6.0)
	progress_fill.size = Vector2(0.0, 16.0)
	progress_fill.color = Color(0.4, 0.9, 1.0, 0.9)
	add_child(progress_fill)

func _update_progress(pos: float) -> void:
	var frac := clampf(pos / MAX_DURATION, 0.0, 1.0)
	progress_fill.size.x = (PoseOverlay.WINDOW_W - PROGRESS_MARGIN * 2.0) * frac

func _score_label_pos(i: int) -> Vector2:
	var y := PoseOverlay.TOP_MARGIN + 8.0
	if player_count >= 2 and i == 1:
		return Vector2(PoseOverlay.WINDOW_W * 0.5 + 12.0, y)
	return Vector2(12.0, y)

## Running-average match (0-100) for player i so far.
func _live_score(i: int) -> int:
	if score_count[i] <= 0:
		return 0
	return int(round(score_sum[i] / score_count[i]))

func _score_text(i: int) -> String:
	if player_count >= 2:
		return "P%d: %d" % [i + 1, _live_score(i)]
	return "Score: %d" % _live_score(i)
