extends Control
## Campaign hub: zone tabs, stage grid, bottom bar to character sheet/menu.

const Chrome := preload("res://src/ui/chrome.gd")

var _zone_tabs: HBoxContainer
var _stage_grid: GridContainer
var _zone_title: Label
var _zone_blurb: Label
var _selected_zone_id := ""
var _header_shell: PanelContainer
var _grid_shell: PanelContainer


func _ready() -> void:
	if GameState.player.is_empty():
		GameState.new_game()
	_build_ui()
	var zones := _sorted_zones()
	if not zones.is_empty():
		var payload := SceneRouter.take_payload()
		_selected_zone_id = payload.get("zone_id", _default_zone(zones).id)
	_refresh()


func _sorted_zones() -> Array:
	var zones: Array = Db.zones.values()
	zones.sort_custom(func(a, b): return a.order < b.order)
	return zones


## Latest unlocked zone, so returning players land where they left off.
func _default_zone(zones: Array) -> ZoneData:
	var best: ZoneData = zones[0]
	for zone in zones:
		if _zone_unlocked(zone):
			best = zone
	return best


func _zone_unlocked(zone: ZoneData) -> bool:
	if zone.unlocked_by_zone_id == "":
		return true
	var gate: ZoneData = Db.zone(zone.unlocked_by_zone_id)
	if gate == null or gate.stages.is_empty():
		return true
	var boss: StageData = _last_required_stage(gate)
	return boss == null or GameState.is_stage_cleared(boss.id)


func _last_required_stage(zone: ZoneData) -> StageData:
	for i in range(zone.stages.size() - 1, -1, -1):
		if not (zone.stages[i] as StageData).is_training:
			return zone.stages[i]
	return null


func _stage_unlocked(stage: StageData) -> bool:
	return stage.requires_stage_id == "" or GameState.is_stage_cleared(stage.requires_stage_id)


func _refresh() -> void:
	for child in _zone_tabs.get_children():
		child.queue_free()
	for child in _stage_grid.get_children():
		child.queue_free()

	for zone in _sorted_zones():
		var tab := Button.new()
		tab.text = zone.display_name
		var unlocked := _zone_unlocked(zone)
		tab.disabled = not unlocked
		Chrome.apply_button(tab, zone.theme_color, 18, Vector2(210, 60), zone.id != _selected_zone_id)
		if zone.id == _selected_zone_id:
			tab.scale = Vector2(1.03, 1.03)
		if not unlocked:
			tab.text += "  [locked]"
		tab.pressed.connect(func():
			_selected_zone_id = zone.id
			_refresh())
		_zone_tabs.add_child(tab)

	var zone: ZoneData = Db.zone(_selected_zone_id)
	if zone == null:
		_zone_title.text = "No zones authored yet."
		_zone_blurb.text = ""
		return

	var accent := zone.theme_color.lightened(0.4)
	_header_shell.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.05, 0.09, 0.12, 0.88), accent, 24, 2, 22, 0.32))
	_grid_shell.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.04, 0.07, 0.1, 0.78), accent.darkened(0.15), 24, 2, 18, 0.24))

	_zone_title.text = zone.display_name
	_zone_title.add_theme_color_override("font_color", accent.lightened(0.15))
	_zone_blurb.text = zone.description
	_zone_blurb.add_theme_color_override("font_color", Color("9cb0c2"))

	for stage in zone.stages:
		_stage_grid.add_child(_stage_button(stage, accent))


func _stage_button(stage: StageData, accent: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 116)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var cleared := GameState.is_stage_cleared(stage.id)
	var unlocked := _stage_unlocked(stage)
	var prefix := "TRAINING" if stage.is_training else ("CLEARED" if cleared else "MISSION")
	button.text = "%s\n%s\nRecommended Lv %d" % [prefix, stage.display_name, stage.recommended_level]

	if not unlocked:
		button.text = "LOCKED\n%s" % stage.display_name
		button.disabled = true
		Chrome.apply_button(button, Color("5a6672"), 18, Vector2.ZERO, true)
	elif cleared and not stage.is_training:
		Chrome.apply_button(button, accent.lerp(Color("72e4ad"), 0.35), 18, Vector2.ZERO)
	else:
		Chrome.apply_button(button, accent, 18, Vector2.ZERO, true)

	button.pressed.connect(_on_stage_pressed.bind(stage))
	return button


func _on_stage_pressed(stage: StageData) -> void:
	var battle_payload := {"stage_id": stage.id}
	if stage.pre_dialogue_id != "" and not GameState.is_stage_cleared(stage.id):
		SceneRouter.goto("res://scenes/ui/dialogue_box.tscn", {
			"dialogue_id": stage.pre_dialogue_id,
			"next_scene": SceneRouter.BATTLE,
			"next_payload": battle_payload,
		})
	else:
		SceneRouter.goto(SceneRouter.BATTLE, battle_payload)


func _build_ui() -> void:
	_build_backdrop()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	column.add_child(top)

	var title_block := VBoxContainer.new()
	title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_block.add_theme_constant_override("separation", 6)
	top.add_child(title_block)

	var eyebrow := Label.new()
	eyebrow.text = "CAMPAIGN MAP"
	Chrome.apply_label(eyebrow, 16, Color("85dfff"), 2)
	title_block.add_child(eyebrow)

	var title := Label.new()
	title.text = "Choose the next engagement"
	Chrome.apply_label(title, 34, Color("eff9ff"), 4)
	title_block.add_child(title)

	var profile := Label.new()
	profile.text = "Unit S-7   |   Level %d   |   Credits %d" % [GameState.player.get("level", 1), GameState.credits]
	Chrome.apply_label(profile, 18, Color("90a9bd"), 1)
	title_block.add_child(profile)

	var save_chip := Label.new()
	save_chip.text = "Autosaves after battle"
	Chrome.apply_label(save_chip, 16, Color("6f8598"), 1)
	top.add_child(save_chip)

	_zone_tabs = HBoxContainer.new()
	_zone_tabs.add_theme_constant_override("separation", 10)
	column.add_child(_zone_tabs)

	_header_shell = PanelContainer.new()
	_header_shell.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.05, 0.09, 0.12, 0.88), Color("3fd0c9"), 24, 2, 22, 0.32))
	column.add_child(_header_shell)

	var header_col := VBoxContainer.new()
	header_col.add_theme_constant_override("separation", 10)
	_header_shell.add_child(header_col)

	_zone_title = Label.new()
	Chrome.apply_label(_zone_title, 30, Color("eff9ff"), 4)
	header_col.add_child(_zone_title)

	_zone_blurb = Label.new()
	_zone_blurb.add_theme_font_size_override("font_size", 18)
	_zone_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_zone_blurb.add_theme_color_override("font_color", Color("9fb3c8"))
	header_col.add_child(_zone_blurb)

	_grid_shell = PanelContainer.new()
	_grid_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_shell.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.04, 0.07, 0.1, 0.78), Color("2e5f71"), 24, 2, 18, 0.24))
	column.add_child(_grid_shell)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_shell.add_child(scroll)

	_stage_grid = GridContainer.new()
	_stage_grid.columns = 2
	_stage_grid.add_theme_constant_override("h_separation", 16)
	_stage_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_stage_grid)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	column.add_child(bottom)

	var character := Button.new()
	character.text = "Character"
	Chrome.apply_button(character, Color("4bb0ff"), 20, Vector2(220, 64))
	character.pressed.connect(func(): SceneRouter.goto(SceneRouter.CHARACTER_SHEET))
	bottom.add_child(character)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	var diff := Button.new()
	diff.text = "Difficulty: %s" % ["Easy", "Normal", "Hard"][GameState.difficulty]
	Chrome.apply_button(diff, Color("ff9a63"), 20, Vector2(240, 64), true)
	diff.pressed.connect(func():
		GameState.difficulty = (GameState.difficulty + 1) % 3
		diff.text = "Difficulty: %s" % ["Easy", "Normal", "Hard"][GameState.difficulty])
	bottom.add_child(diff)

	var save := Button.new()
	save.text = "Save"
	Chrome.apply_button(save, Color("58d3b2"), 20, Vector2(160, 64), true)
	save.pressed.connect(func():
		SaveManager.save_game()
		save.text = "Saved!"
		get_tree().create_timer(1.0).timeout.connect(func(): save.text = "Save"))
	bottom.add_child(save)

	var menu := Button.new()
	menu.text = "Main Menu"
	Chrome.apply_button(menu, Color("70869c"), 20, Vector2(200, 64), true)
	menu.pressed.connect(func():
		SaveManager.save_game()
		SceneRouter.goto(SceneRouter.MAIN_MENU))
	bottom.add_child(menu)


func _build_backdrop() -> void:
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var sky := Chrome.gradient_rect(
		[Color("03070c"), Color("0a131a"), Color("122332")],
		Vector2(0.5, 0.0),
		Vector2(0.5, 1.0),
		[0.0, 0.6, 1.0])
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(sky)

	var wash := Chrome.gradient_rect(
		[Color(0.0, 0.0, 0.0, 0.0), Color(0.25, 0.9, 0.86, 0.11), Color(0.0, 0.0, 0.0, 0.0)],
		Vector2(0.0, 0.5),
		Vector2(1.0, 0.5),
		[0.0, 0.5, 1.0])
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(wash)

	for i in range(5):
		var plate := Panel.new()
		plate.position = Vector2(-80 + i * 280, 90 + (i % 2) * 54)
		plate.size = Vector2(260, 120)
		plate.rotation_degrees = -8 + i * 4
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_theme_stylebox_override("panel",
			Chrome.panel_style(Color(0.2, 0.86, 0.82, 0.04), Color(0.4, 0.95, 0.92, 0.08), 34, 1, 0, 0.0))
		bg.add_child(plate)

	var floor := ColorRect.new()
	floor.color = Color(0.04, 0.08, 0.11, 0.86)
	floor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	floor.offset_top = -150
	bg.add_child(floor)

	for i in range(7):
		var beam := ColorRect.new()
		beam.color = Color(0.38, 0.91, 0.88, 0.05 if i % 2 == 0 else 0.03)
		beam.position = Vector2(80 + i * 178, 0)
		beam.size = Vector2(1, 720)
		bg.add_child(beam)
