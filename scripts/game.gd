extends Node2D
## Main gameplay scene. Counts the player(s) in, plays the song, advances the
## choreography by playback position, scores each player against the shared
## reference, renders the figures, shows a progress bar, and ends when the song
## stops (capped at MAX_DURATION for testing). Supports 1 or 2 players.

const MUSIC_PATH := "res://media/Cartoon, Jéja - On & On (feat. Daniel Levi) [NCS Release].mp3"

const COUNTDOWN_SECONDS := 3.0
## Pause after this many consecutive frames with NO player detected.
const MISSING_LIMIT := 10
## Testing cap: end the dance after this many seconds even if the song is longer.
const MAX_DURATION := 30.0
const PROGRESS_MARGIN := 12.0

enum State { COUNTDOWN, PLAYING, PAUSED, ENDED }

var choreo: Choreography
var audio: AudioStreamPlayer
var overlay: PoseOverlay
var status_label: Label
var progress_fill: ColorRect

var player_count := 1
var state := State.COUNTDOWN
var countdown := COUNTDOWN_SECONDS
var missing_frames := 0
var current_index := -1

# Per-player scoring. A move's score is the average match over its frames, so a
# single noisy frame doesn't decide it.
var total_scores: Array = []   # int per player
var move_sums: Array = []      # float per player, reset each move
var move_samples: Array = []   # int per player, reset each move
var score_labels: Array = []   # Label per player

func _ready() -> void:
	player_count = maxi(1, GameState.player_count)

	choreo = Choreography.new()
	if not choreo.load_dance():
		push_error("Game: failed to load choreography; returning to menu")
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		return

	overlay = PoseOverlay.new()
	overlay.choreo = choreo
	overlay.player_count = player_count
	add_child(overlay)
	VisionClient.players_updated.connect(_on_players_updated)

	# Per-player accumulators + score labels (over each player's panel).
	for i in player_count:
		total_scores.append(0)
		move_sums.append(0.0)
		move_samples.append(0)
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
	status_label.text = str(int(COUNTDOWN_SECONDS))
	add_child(status_label)

	_build_progress_bar()

	# Music (started once the countdown finishes).
	audio = AudioStreamPlayer.new()
	audio.stream = load(MUSIC_PATH)
	audio.volume_db = linear_to_db(0.7)
	audio.finished.connect(_end_game)
	add_child(audio)

	# Show the first reference pose during the countdown so players can prepare.
	_set_move(0)

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
	var span := choreo.total_time()
	if span <= 0.0:
		return
	# Loop the choreography over the length of the song.
	var elapsed := fmod(pos, span)
	var idx := choreo.active_index(elapsed)
	if idx != current_index:
		_finalize_move()
		_set_move(idx)

func _set_move(idx: int) -> void:
	current_index = idx
	for i in player_count:
		move_sums[i] = 0.0
		move_samples[i] = 0
	overlay.current_index = idx
	overlay.queue_redraw()

## Bank each player's averaged match for the just-finished move.
func _finalize_move() -> void:
	if current_index < 0:
		return
	for i in player_count:
		if move_samples[i] > 0:
			total_scores[i] += int(round(move_sums[i] / move_samples[i]))
			score_labels[i].text = _score_text(i)

func _start_playing() -> void:
	state = State.PLAYING
	status_label.visible = false
	audio.play()

## Tracks presence, samples each player's match, and redraws on every frame.
func _on_players_updated(players: Array, _width: int, _height: int) -> void:
	overlay.queue_redraw()
	if players.is_empty():
		missing_frames += 1
		if missing_frames >= MISSING_LIMIT and state == State.PLAYING:
			_pause_for_detection()
		return
	missing_frames = 0
	if state == State.PAUSED:
		_resume_after_detection()
	if state == State.PLAYING and current_index >= 0:
		for i in player_count:
			if i < players.size() and players[i] != null:
				var s := choreo.score_pose(players[i], current_index)
				if s >= 0.0:
					move_sums[i] += s
					move_samples[i] += 1

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
	# Bank the final move's averaged scores before leaving.
	_finalize_move()
	GameState.player_count = player_count
	GameState.scores = total_scores.duplicate()
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

func _score_text(i: int) -> String:
	if player_count >= 2:
		return "P%d: %d" % [i + 1, total_scores[i]]
	return "Score: %d" % total_scores[i]
