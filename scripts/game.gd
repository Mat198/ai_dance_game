extends Node2D
## Main gameplay scene. Counts the player in, plays the song, advances choreography
## moves by playback position, scores the player against each move, renders both
## skeletons, and pauses if the player leaves the camera's view.
## Replaces the pygame game loop in main.py.

const PANEL_W := 1280.0
const PANEL_H := 720.0
const MUSIC_PATH := "res://media/Cartoon, Jéja - On & On (feat. Daniel Levi) [NCS Release].mp3"

const COUNTDOWN_SECONDS := 3.0
## Pause after this many consecutive frames with no player detected.
const MISSING_LIMIT := 10

enum State { COUNTDOWN, PLAYING, PAUSED, ENDED }

var choreo: Choreography
var audio: AudioStreamPlayer
var overlay: PoseOverlay
var score_label: Label
var status_label: Label

var state := State.COUNTDOWN
var countdown := COUNTDOWN_SECONDS
var missing_frames := 0
var current_index := -1
var total_score := 0

func _ready() -> void:
	choreo = Choreography.new()
	if not choreo.load_dance():
		push_error("Game: failed to load choreography; returning to menu")
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		return

	# Overlay draws the player skeleton (left) and the reference skeleton (right),
	# the latter rendered directly from the stored choreography keypoints.
	overlay = PoseOverlay.new()
	overlay.choreo = choreo
	add_child(overlay)
	VisionClient.pose_updated.connect(_on_pose_updated)

	# Score readout (top/player panel) and a label for the target pose (bottom panel).
	score_label = Label.new()
	score_label.position = Vector2(12, 8)
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.text = "Score: 0"
	add_child(score_label)

	var target_label := Label.new()
	target_label.position = Vector2(12, PANEL_H + 8)
	target_label.add_theme_font_size_override("font_size", 32)
	target_label.text = "Match this!"
	add_child(target_label)

	# Big centred message used for the countdown and the "step back in" pause,
	# shown over the player (top) panel.
	status_label = Label.new()
	status_label.position = Vector2(0, PANEL_H * 0.5 - 100.0)
	status_label.size = Vector2(PANEL_W, 200)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.add_theme_font_size_override("font_size", 96)
	status_label.text = str(int(COUNTDOWN_SECONDS))
	add_child(status_label)

	# Music (started once the countdown finishes).
	audio = AudioStreamPlayer.new()
	audio.stream = load(MUSIC_PATH)
	audio.volume_db = linear_to_db(0.7)
	audio.finished.connect(_on_song_finished)
	add_child(audio)

	# Show the first reference pose during the countdown so the player can prepare.
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
	var span := choreo.total_time()
	if span <= 0.0:
		return
	# Loop the choreography over the length of the song (matches the Python
	# "reset moves for simplicity" behaviour).
	var elapsed := fmod(audio.get_playback_position(), span)
	var idx := choreo.active_index(elapsed)
	if idx != current_index:
		if current_index >= 0:
			total_score += choreo.score_pose(VisionClient.keypoints, current_index)
			score_label.text = "Score: %d" % total_score
		_set_move(idx)

func _set_move(idx: int) -> void:
	current_index = idx
	overlay.current_index = idx
	overlay.queue_redraw()

func _start_playing() -> void:
	state = State.PLAYING
	status_label.visible = false
	audio.play()

## Tracks player presence and redraws the skeletons on every received frame.
func _on_pose_updated(keypoints, _width: int, _height: int) -> void:
	overlay.queue_redraw()
	if keypoints == null:
		missing_frames += 1
		if missing_frames >= MISSING_LIMIT and state == State.PLAYING:
			_pause_for_detection()
	else:
		missing_frames = 0
		if state == State.PAUSED:
			_resume_after_detection()

func _pause_for_detection() -> void:
	state = State.PAUSED
	audio.stream_paused = true
	status_label.text = "Step back into frame!"
	status_label.visible = true

func _resume_after_detection() -> void:
	state = State.PLAYING
	audio.stream_paused = false
	status_label.visible = false

func _on_song_finished() -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	# Score the final move before leaving.
	if current_index >= 0:
		total_score += choreo.score_pose(VisionClient.keypoints, current_index)
	GameState.final_score = total_score
	get_tree().change_scene_to_file("res://scenes/Results.tscn")
