extends Control
## Campaign hub: zone tabs, stage grid, bottom bar to character sheet/menu.

var _zone_tabs: HBoxContainer
var _stage_grid: GridContainer
var _zone_blurb: Label
var _selected_zone_id := ""


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
	# Unlocks when the gating zone's final (boss) stage is cleared.
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
		tab.custom_minimum_size = Vector2(200, 60)
		tab.add_theme_font_size_override("font_size", 18)
		var unlocked := _zone_unlocked(zone)
		tab.disabled = not unlocked
		if zone.id == _selected_zone_id:
			tab.modulate = zone.theme_color.lightened(0.5)
		if not unlocked:
			tab.text += "  (locked)"
		tab.pressed.connect(func():
			_selected_zone_id = zone.id
			_refresh())
		_zone_tabs.add_child(tab)

	var zone: ZoneData = Db.zone(_selected_zone_id)
	if zone == null:
		_zone_blurb.text = "No zones authored yet."
		return
	_zone_blurb.text = zone.description

	for stage in zone.stages:
		_stage_grid.add_child(_stage_button(stage))


func _stage_button(stage: StageData) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(280, 88)
	button.add_theme_font_size_override("font_size", 18)
	var cleared := GameState.is_stage_cleared(stage.id)
	var unlocked := _stage_unlocked(stage)
	var marker := ""
	if stage.is_training:
		marker = "[Training]  "
	elif cleared:
		marker = "[Cleared]  "
	button.text = "%s%s\nRecommended Lv %d" % [marker, stage.display_name, stage.recommended_level]
	if not unlocked:
		button.disabled = true
		button.text = "Locked\n%s" % stage.display_name
	elif cleared and not stage.is_training:
		button.modulate = Color(0.7, 0.9, 0.75)
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
	var bg := ColorRect.new()
	bg.color = Color("101820")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	_zone_tabs = HBoxContainer.new()
	_zone_tabs.add_theme_constant_override("separation", 10)
	column.add_child(_zone_tabs)

	_zone_blurb = Label.new()
	_zone_blurb.add_theme_font_size_override("font_size", 17)
	_zone_blurb.add_theme_color_override("font_color", Color("9fb3c8"))
	_zone_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_zone_blurb)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_stage_grid = GridContainer.new()
	_stage_grid.columns = 4
	_stage_grid.add_theme_constant_override("h_separation", 14)
	_stage_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_stage_grid)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	column.add_child(bottom)

	var character := Button.new()
	character.text = "Character"
	character.custom_minimum_size = Vector2(220, 64)
	character.add_theme_font_size_override("font_size", 20)
	character.pressed.connect(func(): SceneRouter.goto(SceneRouter.CHARACTER_SHEET))
	bottom.add_child(character)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	var diff := Button.new()
	diff.text = "Difficulty: %s" % ["Easy", "Normal", "Hard"][GameState.difficulty]
	diff.custom_minimum_size = Vector2(220, 64)
	diff.add_theme_font_size_override("font_size", 20)
	diff.pressed.connect(func():
		GameState.difficulty = (GameState.difficulty + 1) % 3
		diff.text = "Difficulty: %s" % ["Easy", "Normal", "Hard"][GameState.difficulty])
	bottom.add_child(diff)

	var save := Button.new()
	save.text = "Save"
	save.custom_minimum_size = Vector2(160, 64)
	save.add_theme_font_size_override("font_size", 20)
	save.pressed.connect(func():
		SaveManager.save_game()
		save.text = "Saved!"
		get_tree().create_timer(1.0).timeout.connect(func(): save.text = "Save"))
	bottom.add_child(save)

	var menu := Button.new()
	menu.text = "Main Menu"
	menu.custom_minimum_size = Vector2(200, 64)
	menu.add_theme_font_size_override("font_size", 20)
	menu.pressed.connect(func():
		SaveManager.save_game()
		SceneRouter.goto(SceneRouter.MAIN_MENU))
	bottom.add_child(menu)
