extends Control
## Main menu. UI is built in code to keep the .tscn minimal.


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("101820")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)

	var title := Label.new()
	title.text = "STATIC PROTOCOL"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("3fd0c9"))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A turn-based battle RPG"
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color("7a8c99"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	column.add_child(_menu_button("New Game", _on_new_game))
	var continue_btn := _menu_button("Continue", _on_continue)
	continue_btn.disabled = not SaveManager.has_save(1)
	column.add_child(continue_btn)


func _menu_button(text: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(360, 72)
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(handler)
	return btn


func _on_new_game() -> void:
	GameState.new_game()
	SceneRouter.goto(SceneRouter.ZONE_MAP)


func _on_continue() -> void:
	if SaveManager.load_game(1):
		SceneRouter.goto(SceneRouter.ZONE_MAP)
