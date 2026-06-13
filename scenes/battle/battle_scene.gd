extends Node2D
## View-controller over BattleState: feeds player taps in, animates the event
## lists that come back. All UI is built in code; battle.tscn is minimal.

const CombatantScene := preload("res://scenes/battle/combatant.tscn")

const ALLY_SLOTS := [Vector2(265, 400), Vector2(165, 545), Vector2(380, 555)]
const ENEMY_SLOTS := [Vector2(1015, 400), Vector2(1115, 545), Vector2(900, 555)]

var battle: BattleState
var stage: StageData
var rng: RngService

var _views: Dictionary = {}        # combatant index -> CombatantView
var _frames: Dictionary = {}       # combatant index -> UnitFrame
var _enemy_slot_cursor := 0
var _busy := false
var _selected_ability: AbilityData
var _selectable_targets: Array = []

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

	_build_ui()
	_start_battle()


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
			_views[e["target"]].show_floating_text(text, Color("ffd54f") if e.get("crit") else Color("ef5350"))
			await _views[e["target"]].play_hit()
		"dodge":
			_views[e["target"]].show_floating_text("Dodge", Color("90caf9"))
			await _wait(0.25)
		"heal":
			_views[e["target"]].show_floating_text("+%d" % roundi(e["amount"]), Color("81c784"))
			await _views[e["target"]].play_heal_flash()
		"status_applied":
			var status: StatusEffectData = Db.status(e["status_id"])
			var status_name: String = status.display_name if status != null else e["status_id"]
			_views[e["target"]].show_floating_text(status_name, Color("ce93d8"))
			await _wait(0.3)
		"status_tick":
			if e["amount"] >= 0:
				_views[e["target"]].show_floating_text("-%d" % roundi(e["amount"]), Color("ab47bc"))
			else:
				_views[e["target"]].show_floating_text("+%d" % roundi(-e["amount"]), Color("81c784"))
			await _wait(0.3)
		"shield_absorb":
			_views[e["target"]].show_floating_text("Absorbed", Color("4dd0e1"))
		"death":
			_log("%s is down" % battle.combatants[e["target"]].display_name)
			await _wait(0.3)
		"stunned":
			_views[e["actor"]].show_floating_text("Stunned", Color("ffb74d"))
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
	_show_panel("\n".join(lines), [["Continue", _leave_battle]])


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
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.custom_minimum_size = Vector2(420, 0)
	panel.add_child(column)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)

	for action in actions:
		var button := Button.new()
		button.text = action[0]
		button.custom_minimum_size = Vector2(0, 64)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(action[1])
		column.add_child(button)


## --- UI construction ---

func _build_ui() -> void:
	var bg := ColorRect.new()
	var theme_color: Color = Db.zone(stage.zone_id).theme_color if stage != null and Db.zone(stage.zone_id) != null else Color("16222e")
	bg.color = theme_color.darkened(0.55)
	bg.position = Vector2(-400, -400)
	bg.size = Vector2(2080, 1520)
	bg.z_index = -10
	add_child(bg)

	var floor_line := ColorRect.new()
	floor_line.color = Color(1, 1, 1, 0.06)
	floor_line.position = Vector2(-400, 630)
	floor_line.size = Vector2(2080, 1290)
	floor_line.z_index = -9
	add_child(floor_line)

	_ui = CanvasLayer.new()
	add_child(_ui)

	_turn_bar = TurnOrderBar.new()
	_turn_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_turn_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_turn_bar.offset_top = 12
	_turn_bar.add_theme_constant_override("separation", 8)
	_ui.add_child(_turn_bar)

	_party_frames = VBoxContainer.new()
	_party_frames.position = Vector2(16, 16)
	_party_frames.add_theme_constant_override("separation", 8)
	_ui.add_child(_party_frames)

	var bottom := Control.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -132
	_ui.add_child(bottom)

	_ability_bar = HBoxContainer.new()
	_ability_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ability_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ability_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ability_bar.offset_bottom = -10
	_ability_bar.add_theme_constant_override("separation", 10)
	_ability_bar.visible = false
	bottom.add_child(_ability_bar)

	_pass_button = Button.new()
	_pass_button.text = "Skip"
	_pass_button.custom_minimum_size = Vector2(96, 64)
	_pass_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_pass_button.offset_left = -112
	_pass_button.offset_top = -80
	_pass_button.offset_right = -16
	_pass_button.offset_bottom = -16
	_pass_button.visible = false
	_pass_button.pressed.connect(_on_pass)
	_ui.add_child(_pass_button)

	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_label.offset_top = 56
	_hint_label.add_theme_font_size_override("font_size", 22)
	_hint_label.add_theme_color_override("font_color", Color("ffe082"))
	_hint_label.visible = false
	_ui.add_child(_hint_label)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.custom_minimum_size = Vector2(120, 56)
	_cancel_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_cancel_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cancel_button.offset_top = 96
	_cancel_button.visible = false
	_cancel_button.pressed.connect(_on_cancel)
	_ui.add_child(_cancel_button)

	_log_label = RichTextLabel.new()
	_log_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_log_label.offset_left = -360
	_log_label.offset_top = 12
	_log_label.offset_right = -16
	_log_label.offset_bottom = 110
	_log_label.scroll_active = false
	_log_label.add_theme_font_size_override("normal_font_size", 15)
	_log_label.modulate.a = 0.85
	_ui.add_child(_log_label)


var _log_lines: Array[String] = []


func _log(line: String) -> void:
	_log_lines.append(line)
	if _log_lines.size() > 4:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
