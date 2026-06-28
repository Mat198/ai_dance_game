extends Control
## Lists the available choreographies (recorded timelines + the default poses) and
## lets the player pick one before the game starts. Player count was already chosen
## on the menu and is carried in GameState.

const CHOREO_DIR := "res://choreography"

func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var title := Label.new()
	title.text = "Select a Choreography"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	root.add_child(title)

	var sub := Label.new()
	sub.text = "%d Player%s" % [GameState.player_count, "s" if GameState.player_count > 1 else ""]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.6)
	root.add_child(sub)

	var entries := _list_choreographies()
	if entries.is_empty():
		var none := Label.new()
		none.text = "No choreographies found. Record one from the menu."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(none)
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(560, 760)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		root.add_child(scroll)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 10)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		for e in entries:
			var btn := Button.new()
			btn.text = e["label"]
			btn.custom_minimum_size = Vector2(520, 56)
			btn.pressed.connect(_pick.bind(e["path"]))
			list.add_child(btn)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(200, 48)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	root.add_child(back)

## [{ "label": String, "path": String }] — every .csv timeline, plus dance.json.
func _list_choreographies() -> Array:
	var out := []
	var dir := DirAccess.open(CHOREO_DIR)
	if dir == null:
		return out
	var files := dir.get_files()
	files.sort()
	for f in files:
		if f.ends_with(".csv"):
			out.append({"label": f.get_basename(), "path": "%s/%s" % [CHOREO_DIR, f]})
	if FileAccess.file_exists(CHOREO_DIR + "/dance.json"):
		out.append({"label": "Default poses", "path": CHOREO_DIR + "/dance.json"})
	return out

func _pick(path: String) -> void:
	GameState.choreography_path = path
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
