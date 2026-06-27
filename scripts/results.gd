extends Control
## End screen showing the final score with an option to play again.

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Final Score"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	var score := Label.new()
	score.text = str(GameState.final_score)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 72)
	vbox.add_child(score)

	var again := Button.new()
	again.text = "Dance again"
	again.custom_minimum_size = Vector2(220, 56)
	again.pressed.connect(_on_again_pressed)
	vbox.add_child(again)

func _on_again_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")
