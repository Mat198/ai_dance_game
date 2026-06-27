extends Control
## Start screen — pick the number of players, then start the dance.

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Let's Dance!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	var one_btn := Button.new()
	one_btn.text = "1 Player"
	one_btn.custom_minimum_size = Vector2(260, 60)
	one_btn.pressed.connect(_start.bind(1))
	vbox.add_child(one_btn)

	var two_btn := Button.new()
	two_btn.text = "2 Players"
	two_btn.custom_minimum_size = Vector2(260, 60)
	two_btn.pressed.connect(_start.bind(2))
	vbox.add_child(two_btn)

	var hint := Label.new()
	hint.text = "Make sure vision_service.py is running. For 2 players, stand side by side."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(hint)

func _start(count: int) -> void:
	GameState.player_count = count
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
