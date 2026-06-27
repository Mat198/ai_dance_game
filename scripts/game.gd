extends Node2D
## Main gameplay scene. Plays the song, advances choreography moves by playback
## position, scores the player against each move, and renders both skeletons.
## Replaces the pygame game loop in main.py.

const PANEL_W := 640.0
const PANEL_H := 480.0
const MUSIC_PATH := "res://media/Cartoon, Jéja - On & On (feat. Daniel Levi) [NCS Release].mp3"

var choreo: Choreography
var audio: AudioStreamPlayer
var overlay: PoseOverlay
var score_label: Label

var current_index := -1
var total_score := 0
var ended := false

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
	VisionClient.pose_updated.connect(func(_k, _w, _h): overlay.queue_redraw())

	# Score readout (left panel) and a label for the target pose (right panel).
	score_label = Label.new()
	score_label.position = Vector2(12, 8)
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.text = "Score: 0"
	add_child(score_label)

	var target_label := Label.new()
	target_label.position = Vector2(PANEL_W + 12, 8)
	target_label.add_theme_font_size_override("font_size", 28)
	target_label.text = "Match this!"
	add_child(target_label)

	# Music.
	audio = AudioStreamPlayer.new()
	audio.stream = load(MUSIC_PATH)
	audio.volume_db = linear_to_db(0.7)
	audio.finished.connect(_on_song_finished)
	add_child(audio)

	_set_move(0)
	audio.play()

func _process(_delta: float) -> void:
	if ended or not audio.playing:
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

func _on_song_finished() -> void:
	if ended:
		return
	ended = true
	# Score the final move before leaving.
	if current_index >= 0:
		total_score += choreo.score_pose(VisionClient.keypoints, current_index)
	GameState.final_score = total_score
	get_tree().change_scene_to_file("res://scenes/Results.tscn")
