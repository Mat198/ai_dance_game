extends Control
## End screen. Shows the final score (1 player) or both scores and the winner
## (2 players), with an option to play again.

# Kept in sync with PoseOverlay.PLAYER_COLORS.
const PLAYER_COLORS := [Color(0.25, 0.70, 1.00), Color(1.00, 0.55, 0.20)]

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	var scores: Array = GameState.scores
	if GameState.player_count >= 2:
		_build_two_player(vbox, scores)
	else:
		_build_single(vbox, scores)

	var again := Button.new()
	again.text = "Dance again"
	again.custom_minimum_size = Vector2(260, 56)
	again.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	vbox.add_child(again)

func _build_single(vbox: VBoxContainer, scores: Array) -> void:
	vbox.add_child(_label("Final Score", 40))
	var value: int = int(scores[0]) if scores.size() > 0 else 0
	vbox.add_child(_label(str(value), 72))

func _build_two_player(vbox: VBoxContainer, scores: Array) -> void:
	var p1: int = scores[0] if scores.size() > 0 else 0
	var p2: int = scores[1] if scores.size() > 1 else 0

	var winner: String
	if p1 > p2:
		winner = "Player 1 wins!"
	elif p2 > p1:
		winner = "Player 2 wins!"
	else:
		winner = "It's a tie!"
	vbox.add_child(_label(winner, 56))

	var p1_label := _label("Player 1: %d" % p1, 36)
	p1_label.modulate = PLAYER_COLORS[0]
	vbox.add_child(p1_label)

	var p2_label := _label("Player 2: %d" % p2, 36)
	p2_label.modulate = PLAYER_COLORS[1]
	vbox.add_child(p2_label)

func _label(text: String, pt: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", pt)
	return lbl
