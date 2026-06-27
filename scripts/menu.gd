extends Control
## Start screen. Replaces the "click to start" handling in main.py.

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

	var start_btn := Button.new()
	start_btn.text = "Click to start!"
	start_btn.custom_minimum_size = Vector2(240, 60)
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)

	var hint := Label.new()
	hint.text = "Make sure vision_service.py is running and you're in frame."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(hint)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
