extends Control
## Main menu. UI is built in code to keep the .tscn minimal.

const Chrome := preload("res://src/ui/chrome.gd")


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	_build_backdrop()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 54)
	margin.add_theme_constant_override("margin_right", 54)
	margin.add_theme_constant_override("margin_top", 42)
	margin.add_theme_constant_override("margin_bottom", 42)
	add_child(margin)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 42)
	margin.add_child(layout)

	var hero := VBoxContainer.new()
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_theme_constant_override("separation", 18)
	layout.add_child(hero)

	var eyebrow := Label.new()
	eyebrow.text = "TACTICAL BIOPUNK RPG"
	Chrome.apply_label(eyebrow, 16, Color("8ed9ff"), 3)
	hero.add_child(eyebrow)

	var title := Label.new()
	title.text = "STATIC\nPROTOCOL"
	Chrome.apply_label(title, 76, Color("f3fbff"), 8)
	title.add_theme_constant_override("line_spacing", -10)
	hero.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Rebuild a broken synthetic. Hunt through rust, signal, and machine ruin."
	subtitle.custom_minimum_size = Vector2(520, 0)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Chrome.apply_label(subtitle, 24, Color("a7b9c9"), 2)
	hero.add_child(subtitle)

	var pitch := Label.new()
	pitch.text = "The original Sonny felt dramatic because every screen had atmosphere. This pass leans into cold chrome, chemical haze, and luminous UI framing to give the remake a stronger identity before final art lands."
	pitch.custom_minimum_size = Vector2(560, 0)
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Chrome.apply_label(pitch, 18, Color("6e8192"), 1)
	hero.add_child(pitch)

	var rail := ColorRect.new()
	rail.color = Color("44d2da")
	rail.custom_minimum_size = Vector2(240, 3)
	hero.add_child(rail)

	var menu_shell := PanelContainer.new()
	menu_shell.custom_minimum_size = Vector2(420, 0)
	menu_shell.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.05, 0.08, 0.11, 0.82), Color("3fd0c9"), 28, 2, 26, 0.35))
	layout.add_child(menu_shell)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	menu_shell.add_child(column)

	var menu_title := Label.new()
	menu_title.text = "Wake Sequence"
	Chrome.apply_label(menu_title, 30, Color("ebfbff"), 4)
	column.add_child(menu_title)

	var menu_copy := Label.new()
	menu_copy.text = "Load back into the campaign or restart from the salvage barge."
	menu_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Chrome.apply_label(menu_copy, 18, Color("8ca2b6"), 1)
	column.add_child(menu_copy)

	column.add_child(_menu_button("New Game", _on_new_game))
	var continue_btn := _menu_button("Continue", _on_continue)
	continue_btn.disabled = not SaveManager.has_save(1)
	column.add_child(continue_btn)

	var footer := Label.new()
	footer.text = "Built for landscape touch play. Progress saves automatically after battles."
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Chrome.apply_label(footer, 15, Color("698092"), 1)
	column.add_child(footer)


func _build_backdrop() -> void:
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var sky := Chrome.gradient_rect(
		[Color("04070c"), Color("0a1622"), Color("10202c")],
		Vector2(0.5, 0.0),
		Vector2(0.5, 1.0),
		[0.0, 0.58, 1.0])
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(sky)

	var lower_glow := Chrome.gradient_rect(
		[Color(0.0, 0.0, 0.0, 0.0), Color(0.24, 0.84, 0.79, 0.16), Color(0.0, 0.0, 0.0, 0.0)],
		Vector2(0.5, 0.0),
		Vector2(0.5, 1.0),
		[0.0, 0.55, 1.0])
	lower_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(lower_glow)

	_add_glow_plate(bg, Vector2(-80, 92), Vector2(520, 190), Color(0.2, 0.95, 0.9, 0.11), -12.0)
	_add_glow_plate(bg, Vector2(960, -70), Vector2(420, 160), Color(0.45, 0.72, 1.0, 0.09), 16.0)
	_add_glow_plate(bg, Vector2(830, 420), Vector2(500, 220), Color(1.0, 0.53, 0.34, 0.08), -8.0)

	var skyline_back := Polygon2D.new()
	skyline_back.color = Color(0.03, 0.07, 0.1, 0.92)
	skyline_back.polygon = PackedVector2Array([
		Vector2(0, 520), Vector2(85, 468), Vector2(148, 482), Vector2(230, 414),
		Vector2(310, 446), Vector2(406, 388), Vector2(525, 438), Vector2(630, 360),
		Vector2(725, 418), Vector2(842, 332), Vector2(972, 394), Vector2(1094, 318),
		Vector2(1216, 406), Vector2(1280, 376), Vector2(1280, 720), Vector2(0, 720),
	])
	bg.add_child(skyline_back)

	var skyline_front := Polygon2D.new()
	skyline_front.color = Color(0.04, 0.1, 0.14, 0.96)
	skyline_front.polygon = PackedVector2Array([
		Vector2(0, 592), Vector2(102, 548), Vector2(180, 572), Vector2(275, 512),
		Vector2(344, 548), Vector2(428, 474), Vector2(570, 540), Vector2(670, 468),
		Vector2(768, 516), Vector2(890, 432), Vector2(982, 486), Vector2(1082, 422),
		Vector2(1180, 474), Vector2(1280, 442), Vector2(1280, 720), Vector2(0, 720),
	])
	bg.add_child(skyline_front)

	var floor := ColorRect.new()
	floor.color = Color(0.04, 0.08, 0.11, 0.92)
	floor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	floor.offset_top = -126
	floor.offset_bottom = 0
	bg.add_child(floor)

	for i in range(8):
		var line := ColorRect.new()
		line.color = Color(0.35, 0.87, 0.85, 0.08 if i % 2 == 0 else 0.04)
		line.position = Vector2(120 + i * 146, 0)
		line.size = Vector2(1, 720)
		bg.add_child(line)


func _add_glow_plate(parent: Control, pos: Vector2, size: Vector2, color: Color, angle: float) -> void:
	var plate := Panel.new()
	plate.position = pos
	plate.size = size
	plate.rotation_degrees = angle
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel",
		Chrome.panel_style(color, color.lightened(0.2), 42, 1, 0, 0.0))
	parent.add_child(plate)


func _menu_button(text: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	Chrome.apply_button(btn, Color("3fd0c9"), 28, Vector2(0, 74))
	btn.pressed.connect(handler)
	return btn


func _on_new_game() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.74)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(420, 0)
	shell.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.05, 0.08, 0.11, 0.9), Color("5fb6ff"), 26, 2, 22, 0.38))
	center.add_child(shell)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	shell.add_child(column)

	var title := Label.new()
	title.text = "Select difficulty"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Chrome.apply_label(title, 30, Color("eef8ff"), 4)
	column.add_child(title)

	var prompt := Label.new()
	prompt.text = "Easy is forgiving, Hard assumes tighter builds and cleaner sequencing."
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Chrome.apply_label(prompt, 17, Color("8fa8bc"), 1)
	column.add_child(prompt)

	var options := [
		["Easy", GameState.DIFFICULTY_EASY],
		["Normal", GameState.DIFFICULTY_NORMAL],
		["Hard", GameState.DIFFICULTY_HARD],
	]
	for option in options:
		var btn := _menu_button(option[0], _start_new_game.bind(option[1]))
		column.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	Chrome.apply_button(cancel, Color("6a7a89"), 24, Vector2(0, 62), true)
	cancel.pressed.connect(overlay.queue_free)
	column.add_child(cancel)


func _start_new_game(difficulty: int) -> void:
	GameState.new_game(difficulty)
	SaveManager.save_game()
	if FileAccess.file_exists("res://data/dialogue/intro.json"):
		SceneRouter.goto("res://scenes/ui/dialogue_box.tscn", {
			"dialogue_id": "intro",
			"next_scene": SceneRouter.ZONE_MAP,
		})
	else:
		SceneRouter.goto(SceneRouter.ZONE_MAP)


func _on_continue() -> void:
	if SaveManager.load_game(1):
		SceneRouter.goto(SceneRouter.ZONE_MAP)
