extends Node2D
## View-controller over BattleState: feeds player taps in, animates the event
## lists that come back. All UI is built in code; battle.tscn is minimal.

const CombatantScene := preload("res://scenes/battle/combatant.tscn")
const Chrome := preload("res://src/ui/chrome.gd")

const VIEW_SIZE := Vector2(1280, 720)
const ALLY_SLOTS := [Vector2(272, 390), Vector2(172, 538), Vector2(392, 552)]
const ENEMY_SLOTS := [Vector2(1010, 390), Vector2(1112, 538), Vector2(892, 552)]

var battle: BattleState
var stage: StageData
var rng: RngService

var _views: Dictionary = {}        # combatant index -> CombatantView
var _frames: Dictionary = {}       # combatant index -> UnitFrame
var _enemy_slot_cursor := 0
var _busy := false
var _selected_ability: AbilityData
var _selectable_targets: Array = []
var _theme_color := Color("284353")

var _ui: CanvasLayer
var _turn_bar: TurnOrderBar
var _party_frames: VBoxContainer
var _ability_bar: HBoxContainer
var _hint_label: Label
var _cancel_button: Button
var _pass_button: Button
var _log_label: RichTextLabel
var _overlay: Control


func _ready() -> void:
	var payload := SceneRouter.take_payload()
	if GameState.player.is_empty():
		GameState.new_game()
	stage = Db.stage(payload.get("stage_id", ""))
	rng = RngService.new(payload.get("rng_seed", -1))
	_theme_color = _zone_theme()

	_build_ui()
	_start_battle()


func _input(event: InputEvent) -> void:
	if _busy or _selected_ability == null:
		return
	var pointer_pos := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pointer_pos = event.position
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pointer_pos = event.position
		pressed = true
	if not pressed:
		return
	for idx in _selectable_targets:
		if _views.has(idx) and _views[idx].hit_test(pointer_pos):
			_on_combatant_tapped(idx)
			get_viewport().set_input_as_handled()
			return


func _start_battle() -> void:
	battle = BattleState.new()
	var waves: Array = []
	if stage != null:
		waves = stage.waves
	else:
		# No stage payload (direct scene run): fixture skirmish.
		waves = [[Db.enemy("scrap_drone"), Db.enemy("scrap_drone")], [Db.enemy("rust_hound")]]
	battle.setup(GameState.build_party(), waves, rng, GameState.enemy_stat_mult(), GameState.ai_temperature())

	var party := battle.living(CombatantState.TEAM_PLAYER)
	for i in party.size():
		_spawn_view(party[i], ALLY_SLOTS[mini(i, ALLY_SLOTS.size() - 1)])
		var frame := UnitFrame.new()
		frame.setup(party[i].display_name, party[i].body_color)
		_party_frames.add_child(frame)
		_frames[party[i].index] = frame

	EventBus.battle_started.emit(stage.id if stage != null else "")
	_run(battle.start())


func _spawn_view(unit: CombatantState, pos: Vector2) -> void:
	var view: CombatantView = CombatantScene.instantiate()
	view.position = pos
	add_child(view)
	view.setup(unit)
	view.tapped.connect(_on_combatant_tapped)
	_views[unit.index] = view


## --- Input ---

func _on_ability_tapped(ability: AbilityData) -> void:
	if _busy or battle.phase != BattleState.Phase.AWAIT_INPUT:
		return
	var actor := battle.current_actor()
	if not actor.can_use(ability):
		return
	var legal := battle.legal_targets(actor, ability)
	if legal.is_empty():
		return
	match ability.target_type:
		AbilityData.TargetType.SELF, AbilityData.TargetType.ALL_ALLIES, AbilityData.TargetType.ALL_ENEMIES:
			_clear_selection()
			_run(battle.act(ability.id, legal[0]))
		_:
			_begin_target_selection(ability, legal)


func _begin_target_selection(ability: AbilityData, legal: Array) -> void:
	_clear_selection()
	_selected_ability = ability
	_selectable_targets = legal
	for idx in legal:
		_views[idx].set_selectable(true)
	_hint_label.text = "Select a target for %s" % ability.display_name
	_hint_label.visible = true
	_cancel_button.visible = true


func _on_combatant_tapped(index: int) -> void:
	if _busy or _selected_ability == null or not index in _selectable_targets:
		return
	var ability := _selected_ability
	_clear_selection()
	_run(battle.act(ability.id, index))


func _on_cancel() -> void:
	_clear_selection()


func _on_pass() -> void:
	if _busy or battle.phase != BattleState.Phase.AWAIT_INPUT:
		return
	_clear_selection()
	_run(battle.act_pass())


func _clear_selection() -> void:
	_selected_ability = null
	for idx in _selectable_targets:
		if _views.has(idx):
			_views[idx].set_selectable(false)
	_selectable_targets = []
	_hint_label.visible = false
	_cancel_button.visible = false


## --- Event playback ---

func _run(events: Array) -> void:
	_busy = true
	_set_ability_bar_visible(false)
	_play_events(events)


func _play_events(events: Array) -> void:
	for e in events:
		await _play_event(e)
		_refresh_all()
	_busy = false
	if battle.phase == BattleState.Phase.VICTORY:
		_show_victory()
	elif battle.phase == BattleState.Phase.DEFEAT:
		_show_defeat()
	else:
		_prepare_input()


func _play_event(e: Dictionary) -> void:
	match e["type"]:
		"round_start":
			_turn_bar.rebuild(e["order"], battle.combatants)
		"turn_start":
			for idx in _views:
				_views[idx].set_active_turn(idx == e["actor"])
			_turn_bar.highlight(e["actor"], battle.combatants)
			await _wait(0.18)
		"ability_used":
			var actor: CombatantState = battle.combatants[e["actor"]]
			var ability: AbilityData = Db.ability(e["ability_id"])
			var ability_name: String = ability.display_name if ability != null else e["ability_id"]
			_log("%s used %s" % [actor.display_name, ability_name])
			AudioManager.play_sfx("ability")
			await _views[e["actor"]].play_lunge()
		"damage":
			var text := "-%d" % roundi(e["amount"])
			if e.get("crit", false):
				text += "!"
			_views[e["target"]].show_floating_text(text, Color("ffd87b") if e.get("crit") else Color("ff7569"))
			await _views[e["target"]].play_hit()
		"dodge":
			_views[e["target"]].show_floating_text("Dodge", Color("90caf9"))
			await _wait(0.25)
		"heal":
			_views[e["target"]].show_floating_text("+%d" % roundi(e["amount"]), Color("81f2b5"))
			await _views[e["target"]].play_heal_flash()
		"status_applied":
			var status: StatusEffectData = Db.status(e["status_id"])
			var status_name: String = status.display_name if status != null else e["status_id"]
			_views[e["target"]].show_floating_text(status_name, Color("d6a8ff"))
			await _wait(0.3)
		"status_tick":
			if e["amount"] >= 0:
				_views[e["target"]].show_floating_text("-%d" % roundi(e["amount"]), Color("ab47bc"))
			else:
				_views[e["target"]].show_floating_text("+%d" % roundi(-e["amount"]), Color("81f2b5"))
			await _wait(0.3)
		"shield_absorb":
			_views[e["target"]].show_floating_text("Absorbed", Color("59e1ff"))
		"death":
			_log("%s is down" % battle.combatants[e["target"]].display_name)
			await _wait(0.3)
		"stunned":
			_views[e["actor"]].show_floating_text("Stunned", Color("ffb468"))
			await _wait(0.35)
		"pass":
			_views[e["actor"]].show_floating_text("...", Color.WHITE)
			await _wait(0.2)
		"wave_started":
			if e["wave"] > 1:
				_log("Reinforcements!")
				# Clear the previous wave's corpses to free the slots.
				for idx in _views:
					var unit: CombatantState = battle.combatants[idx]
					if unit.team == CombatantState.TEAM_ENEMY and not unit.is_alive():
						_views[idx].visible = false
			_enemy_slot_cursor = 0
			for idx in e["spawned"]:
				_spawn_view(battle.combatants[idx], ENEMY_SLOTS[mini(_enemy_slot_cursor, ENEMY_SLOTS.size() - 1)])
				_enemy_slot_cursor += 1
			await _wait(0.3)
		_:
			pass


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _refresh_all() -> void:
	for idx in _views:
		_views[idx].refresh()
		if _frames.has(idx):
			_frames[idx].refresh(battle.combatants[idx])


func _prepare_input() -> void:
	var actor := battle.current_actor()
	if actor == null:
		return
	_rebuild_ability_bar(actor)
	_set_ability_bar_visible(true)


func _rebuild_ability_bar(actor: CombatantState) -> void:
	for child in _ability_bar.get_children():
		child.queue_free()
	for ability in actor.abilities:
		var button := AbilityButton.new()
		button.setup(ability)
		button.refresh(actor)
		button.ability_tapped.connect(_on_ability_tapped)
		_ability_bar.add_child(button)


func _set_ability_bar_visible(visible_now: bool) -> void:
	_ability_bar.visible = visible_now
	_pass_button.visible = visible_now


## --- Outcome panels ---

func _show_victory() -> void:
	var summary := {}
	if stage != null:
		summary = GameState.apply_victory_rewards(battle.defeated_enemies, stage, rng)
		SaveManager.save_game()
	else:
		summary = {"xp": Loot.total_xp(battle.defeated_enemies), "credits": 0, "drops": [], "levels_gained": 0}
	EventBus.battle_ended.emit(true, stage.id if stage != null else "")

	var lines := ["VICTORY", "", "XP earned: %d" % summary["xp"]]
	if summary["credits"] > 0:
		lines.append("Credits: %d" % summary["credits"])
	if summary["levels_gained"] > 0:
		lines.append("Level up! Now level %d" % GameState.player["level"])
	if summary.get("recruited", "") != "":
		lines.append("%s joined your team!" % summary["recruited"])
	for item_id in summary["drops"]:
		var item: ItemData = Db.item(item_id)
		lines.append("Loot: %s" % (item.display_name if item != null else item_id))

	var continue_action: Callable = _leave_battle
	if stage != null and summary.get("first_clear", false) and stage.post_dialogue_id != "":
		var dialogue_id: String = stage.post_dialogue_id
		continue_action = func():
			SceneRouter.goto("res://scenes/ui/dialogue_box.tscn", {
				"dialogue_id": dialogue_id,
				"next_scene": SceneRouter.ZONE_MAP,
			})
	_show_panel("\n".join(lines), [["Continue", continue_action]])


func _show_defeat() -> void:
	EventBus.battle_ended.emit(false, stage.id if stage != null else "")
	_show_panel("DEFEAT", [
		["Retry", _retry],
		["Withdraw", _leave_battle],
	])


func _retry() -> void:
	SceneRouter.goto(SceneRouter.BATTLE, {"stage_id": stage.id if stage != null else ""})


func _leave_battle() -> void:
	var dest := SceneRouter.ZONE_MAP if ResourceLoader.exists(SceneRouter.ZONE_MAP) else SceneRouter.MAIN_MENU
	SceneRouter.goto(dest)


func _show_panel(text: String, actions: Array) -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.05, 0.08, 0.11, 0.94), _theme_color.lightened(0.45), 28, 2, 24, 0.42))
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.custom_minimum_size = Vector2(460, 0)
	panel.add_child(column)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Chrome.apply_label(label, 26, Color("eef8ff"), 4)
	column.add_child(label)

	for action in actions:
		var button := Button.new()
		button.text = action[0]
		Chrome.apply_button(button, _theme_color.lightened(0.15), 22, Vector2(0, 64))
		button.pressed.connect(action[1])
		column.add_child(button)


## --- UI construction ---

func _build_ui() -> void:
	_build_backdrop()

	_ui = CanvasLayer.new()
	add_child(_ui)

	var top_shell := PanelContainer.new()
	top_shell.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_shell.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_shell.offset_top = 14
	top_shell.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.04, 0.07, 0.1, 0.82), _theme_color.lightened(0.28), 18, 2, 10, 0.28))
	_ui.add_child(top_shell)

	_turn_bar = TurnOrderBar.new()
	_turn_bar.add_theme_constant_override("separation", 8)
	top_shell.add_child(_turn_bar)

	var left_shell := PanelContainer.new()
	left_shell.position = Vector2(16, 18)
	left_shell.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.04, 0.07, 0.1, 0.82), _theme_color.lightened(0.22), 22, 2, 14, 0.24))
	_ui.add_child(left_shell)

	_party_frames = VBoxContainer.new()
	_party_frames.add_theme_constant_override("separation", 10)
	left_shell.add_child(_party_frames)

	var stage_tag := PanelContainer.new()
	stage_tag.position = Vector2(16, 202)
	stage_tag.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.05, 0.09, 0.12, 0.78), _theme_color.lightened(0.18), 18, 1, 12, 0.18))
	_ui.add_child(stage_tag)

	var stage_label := Label.new()
	stage_label.text = "%s  /  %s" % [_zone_name().to_upper(), _stage_name().to_upper()]
	Chrome.apply_label(stage_label, 15, Color("dceefa"), 2)
	stage_tag.add_child(stage_label)

	var bottom_shell := PanelContainer.new()
	bottom_shell.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_shell.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom_shell.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_shell.offset_bottom = -12
	bottom_shell.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.04, 0.07, 0.1, 0.86), _theme_color.lightened(0.22), 24, 2, 14, 0.28))
	_ui.add_child(bottom_shell)

	var bottom_content := VBoxContainer.new()
	bottom_content.add_theme_constant_override("separation", 8)
	bottom_shell.add_child(bottom_content)

	var ability_prompt := Label.new()
	ability_prompt.text = "EXECUTE ACTION"
	Chrome.apply_label(ability_prompt, 14, _theme_color.lightened(0.48), 2)
	bottom_content.add_child(ability_prompt)

	_ability_bar = HBoxContainer.new()
	_ability_bar.add_theme_constant_override("separation", 10)
	_ability_bar.visible = false
	bottom_content.add_child(_ability_bar)

	_pass_button = Button.new()
	_pass_button.text = "Skip Turn"
	Chrome.apply_button(_pass_button, Color("ff9f68"), 20, Vector2(156, 60), true)
	_pass_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_pass_button.offset_left = -174
	_pass_button.offset_top = -78
	_pass_button.offset_right = -18
	_pass_button.offset_bottom = -18
	_pass_button.visible = false
	_pass_button.pressed.connect(_on_pass)
	_ui.add_child(_pass_button)

	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_label.offset_top = 74
	Chrome.apply_label(_hint_label, 20, Color("ffe082"), 3)
	_hint_label.visible = false
	_ui.add_child(_hint_label)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel Targeting"
	Chrome.apply_button(_cancel_button, Color("70869c"), 18, Vector2(170, 50), true)
	_cancel_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_cancel_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cancel_button.offset_top = 106
	_cancel_button.visible = false
	_cancel_button.pressed.connect(_on_cancel)
	_ui.add_child(_cancel_button)

	var log_shell := PanelContainer.new()
	log_shell.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	log_shell.offset_left = -382
	log_shell.offset_top = 16
	log_shell.offset_right = -16
	log_shell.offset_bottom = 124
	log_shell.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.04, 0.07, 0.1, 0.72), _theme_color.lightened(0.12), 18, 1, 12, 0.16))
	_ui.add_child(log_shell)

	_log_label = RichTextLabel.new()
	_log_label.scroll_active = false
	_log_label.fit_content = true
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.add_theme_font_size_override("normal_font_size", 15)
	_log_label.add_theme_color_override("default_color", Color("d7e6f2"))
	_log_label.modulate.a = 0.92
	log_shell.add_child(_log_label)


func _build_backdrop() -> void:
	var sky := Chrome.gradient_rect(
		[
			_theme_color.darkened(0.9).lerp(Color("020406"), 0.4),
			_theme_color.darkened(0.72),
			_theme_color.darkened(0.48).lerp(Color("183040"), 0.32),
		],
		Vector2(0.5, 0.0),
		Vector2(0.5, 1.0),
		[0.0, 0.62, 1.0])
	sky.position = Vector2.ZERO
	sky.size = VIEW_SIZE
	sky.z_index = -40
	add_child(sky)

	var wash := Chrome.gradient_rect(
		[
			Color(0.0, 0.0, 0.0, 0.0),
			Color(_theme_color.lightened(0.3).r, _theme_color.lightened(0.3).g, _theme_color.lightened(0.3).b, 0.16),
			Color(1.0, 0.57, 0.4, 0.08),
		],
		Vector2(0.12, 0.12),
		Vector2(0.86, 0.92),
		[0.0, 0.52, 1.0])
	wash.position = Vector2.ZERO
	wash.size = VIEW_SIZE
	wash.z_index = -39
	add_child(wash)

	_add_backdrop_plate(Vector2(-72, 58), Vector2(360, 124), Color(0.26, 0.92, 0.88, 0.08), -10.0, -38)
	_add_backdrop_plate(Vector2(974, 84), Vector2(326, 116), Color(0.55, 0.82, 1.0, 0.08), 11.0, -38)
	_add_backdrop_plate(Vector2(414, 438), Vector2(438, 144), Color(1.0, 0.58, 0.36, 0.07), -6.0, -37)

	var skyline_far := Polygon2D.new()
	skyline_far.color = _theme_color.darkened(0.78).lerp(Color("060d12"), 0.2)
	skyline_far.z_index = -37
	skyline_far.polygon = PackedVector2Array([
		Vector2(0, 418), Vector2(96, 374), Vector2(176, 392), Vector2(280, 334),
		Vector2(372, 380), Vector2(474, 312), Vector2(606, 366), Vector2(706, 286),
		Vector2(826, 348), Vector2(930, 278), Vector2(1048, 338), Vector2(1182, 262),
		Vector2(1280, 318), Vector2(1280, 720), Vector2(0, 720),
	])
	add_child(skyline_far)

	var skyline_mid := Polygon2D.new()
	skyline_mid.color = _theme_color.darkened(0.64).lerp(Color("091118"), 0.12)
	skyline_mid.z_index = -36
	skyline_mid.polygon = PackedVector2Array([
		Vector2(0, 516), Vector2(104, 474), Vector2(182, 500), Vector2(282, 438),
		Vector2(374, 488), Vector2(488, 414), Vector2(592, 466), Vector2(704, 392),
		Vector2(824, 458), Vector2(936, 388), Vector2(1056, 446), Vector2(1172, 374),
		Vector2(1280, 426), Vector2(1280, 720), Vector2(0, 720),
	])
	add_child(skyline_mid)

	var floor := Polygon2D.new()
	floor.color = Color(0.04, 0.08, 0.11, 0.95)
	floor.z_index = -35
	floor.polygon = PackedVector2Array([
		Vector2(0, 448), Vector2(1280, 448), Vector2(1280, 720), Vector2(0, 720),
	])
	add_child(floor)

	for i in range(9):
		var x := 72 + i * 142
		var beam := ColorRect.new()
		beam.position = Vector2(x, 0)
		beam.size = Vector2(1, 720)
		beam.color = Color(0.42, 0.9, 0.87, 0.04 if i % 2 == 0 else 0.02)
		beam.z_index = -34
		add_child(beam)

	for i in range(6):
		var line := Line2D.new()
		line.points = PackedVector2Array([
			Vector2(640, 450),
			Vector2(90 + i * 190, 720),
		])
		line.width = 1.0
		line.default_color = Color(0.38, 0.88, 0.85, 0.08)
		line.z_index = -34
		add_child(line)

	var horizon := ColorRect.new()
	horizon.position = Vector2(0, 448)
	horizon.size = Vector2(1280, 2)
	horizon.color = Color(0.52, 0.96, 0.94, 0.12)
	horizon.z_index = -34
	add_child(horizon)


func _add_backdrop_plate(pos: Vector2, size: Vector2, color: Color, angle: float, z: int) -> void:
	var plate := Panel.new()
	plate.position = pos
	plate.size = size
	plate.rotation_degrees = angle
	plate.z_index = z
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel",
		Chrome.panel_style(color, color.lightened(0.18), 42, 1, 0, 0.0))
	add_child(plate)


func _zone_theme() -> Color:
	var zone := Db.zone(stage.zone_id) if stage != null else null
	return zone.theme_color if zone != null else Color("284353")


func _zone_name() -> String:
	var zone := Db.zone(stage.zone_id) if stage != null else null
	return zone.display_name if zone != null else "Sim"


func _stage_name() -> String:
	return stage.display_name if stage != null else "Skirmish"


var _log_lines: Array[String] = []


func _log(line: String) -> void:
	_log_lines.append(line)
	if _log_lines.size() > 4:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
