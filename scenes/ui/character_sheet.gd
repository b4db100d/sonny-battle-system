extends Control
## Character sheet: stat allocation, skill trees, equipment. Operates on
## GameState.player; everything rebuilds on change (cheap at this scale).

var _tabs: TabContainer
var _header_label: Label
var _detail_label: Label


func _ready() -> void:
	if GameState.player.is_empty():
		GameState.new_game()
	_build_static_ui()
	_refresh()


func _profile() -> Dictionary:
	return GameState.player


func _build_static_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("101820")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)

	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 24)
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_header_label)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(140, 56)
	back.pressed.connect(_on_back)
	header.add_child(back)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)

	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 16)
	_detail_label.add_theme_color_override("font_color", Color("9fb3c8"))
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size = Vector2(0, 44)
	column.add_child(_detail_label)


func _refresh() -> void:
	var profile := _profile()
	_header_label.text = "%s   —   Level %d   |   XP %d / %d   |   Credits %d" % [
		profile.get("name", "Unit"), profile["level"], profile["xp"],
		Leveling.xp_to_next(profile["level"]), GameState.credits]

	var selected := _tabs.current_tab
	for child in _tabs.get_children():
		child.queue_free()
	_tabs.add_child(_build_stats_tab())
	_tabs.add_child(_build_abilities_tab())
	_tabs.add_child(_build_equipment_tab())
	if selected >= 0 and selected < 3:
		_tabs.current_tab = selected


## --- Stats tab ---

func _build_stats_tab() -> Control:
	var profile := _profile()
	var root := HBoxContainer.new()
	root.name = "Stats"
	root.add_theme_constant_override("separation", 40)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	root.add_child(left)

	var points := Label.new()
	points.text = "Stat points available: %d" % profile["unspent_stat_points"]
	points.add_theme_font_size_override("font_size", 20)
	left.add_child(points)

	var descriptions := {
		"strength": "Physical ability damage",
		"instinct": "Psy damage, healing, focus regen",
		"speed": "Turn order, crit and dodge chance",
		"vitality": "Maximum health",
	}
	for stat in StatBlock.PRIMARIES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		left.add_child(row)

		var name_label := Label.new()
		name_label.text = stat.capitalize()
		name_label.custom_minimum_size = Vector2(130, 0)
		name_label.add_theme_font_size_override("font_size", 20)
		row.add_child(name_label)

		var value_label := Label.new()
		var base: int = Leveling.base_primaries()[stat]
		var alloc: int = profile["stat_alloc"].get(stat, 0)
		value_label.text = "%d" % (base + alloc)
		value_label.custom_minimum_size = Vector2(56, 0)
		value_label.add_theme_font_size_override("font_size", 20)
		row.add_child(value_label)

		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(56, 56)
		plus.disabled = profile["unspent_stat_points"] <= 0
		plus.pressed.connect(_on_stat_plus.bind(stat))
		row.add_child(plus)

		var hint := Label.new()
		hint.text = descriptions[stat]
		hint.add_theme_color_override("font_color", Color("7a8c99"))
		row.add_child(hint)

	var respec := Button.new()
	respec.text = "Reset Stats"
	respec.custom_minimum_size = Vector2(200, 56)
	respec.pressed.connect(func():
		AbilityTree.respec_stats(_profile())
		_refresh())
	left.add_child(respec)

	var derived_panel := VBoxContainer.new()
	root.add_child(derived_panel)
	var unit: CombatantState = GameState.build_party()[0]
	var d := unit.derived()
	var derived_text := Label.new()
	derived_text.text = "Derived (with equipment)\n\nHealth: %d\nFocus regen: %.1f / turn\nPhysical power: %.0f\nPsy power: %.0f\nCrit chance: %d%%\nDodge: %d%%" % [
		d["max_hp"], d["focus_regen"], d["phys_power"], d["psy_power"],
		roundi(d["crit_chance"] * 100), roundi(d["dodge"] * 100)]
	derived_text.add_theme_font_size_override("font_size", 18)
	derived_panel.add_child(derived_text)
	return root


func _on_stat_plus(stat: String) -> void:
	var profile := _profile()
	if profile["unspent_stat_points"] > 0:
		profile["stat_alloc"][stat] = int(profile["stat_alloc"].get(stat, 0)) + 1
		profile["unspent_stat_points"] = int(profile["unspent_stat_points"]) - 1
		_refresh()


## --- Abilities tab ---

func _build_abilities_tab() -> Control:
	var profile := _profile()
	var root := VBoxContainer.new()
	root.name = "Abilities"
	root.add_theme_constant_override("separation", 8)

	var info := Label.new()
	info.text = "Skill points: %d        Equipped: %d / %d (tap a learned ability to equip or bench it)" % [
		profile["unspent_skill_points"],
		profile["equipped_ability_ids"].size(), AbilityTree.MAX_EQUIPPED]
	info.add_theme_font_size_override("font_size", 18)
	root.add_child(info)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)

	var tree_ids: Array = Db.trees.keys()
	tree_ids.sort()
	for tree_id in tree_ids:
		var tree: AbilityTreeData = Db.trees[tree_id]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		columns.add_child(col)

		var title := Label.new()
		title.text = tree.display_name
		title.add_theme_font_size_override("font_size", 20)
		title.add_theme_color_override("font_color", tree.theme_color)
		col.add_child(title)

		for entry in tree.entries:
			col.add_child(_ability_entry_button(tree, entry))

	var respec := Button.new()
	respec.text = "Reset Abilities"
	respec.custom_minimum_size = Vector2(200, 56)
	respec.pressed.connect(func():
		AbilityTree.respec(_profile())
		_refresh())
	root.add_child(respec)
	return root


func _ability_entry_button(tree: AbilityTreeData, entry: Dictionary) -> Button:
	var profile := _profile()
	var ability: AbilityData = Db.ability(entry["ability_id"])
	var ability_name: String = ability.display_name if ability != null else entry["ability_id"]
	var learned := AbilityTree.is_learned(profile, entry["ability_id"])
	var equipped: bool = entry["ability_id"] in profile["equipped_ability_ids"]

	var button := Button.new()
	button.custom_minimum_size = Vector2(250, 52)
	if learned:
		button.text = "%s%s" % [ability_name, "  [equipped]" if equipped else ""]
		button.modulate = Color(0.75, 1.0, 0.8) if equipped else Color.WHITE
		button.pressed.connect(_on_toggle_equip.bind(entry["ability_id"]))
	elif AbilityTree.can_learn(profile, tree, entry):
		button.text = "Learn: %s" % ability_name
		button.modulate = Color(1.0, 0.95, 0.6)
		button.pressed.connect(_on_learn.bind(tree, entry))
	else:
		# Locked: dimmed but still tappable so the description is readable.
		button.text = "%s (T%d, Lv %d)" % [ability_name, entry["tier"], entry["level_req"]]
		button.modulate = Color(0.55, 0.55, 0.6)
		button.pressed.connect(func(): _show_ability_detail(ability))
	return button


func _on_learn(tree: AbilityTreeData, entry: Dictionary) -> void:
	if AbilityTree.learn(_profile(), tree, entry):
		var profile := _profile()
		if profile["equipped_ability_ids"].size() < AbilityTree.MAX_EQUIPPED:
			profile["equipped_ability_ids"].append(entry["ability_id"])
	_show_ability_detail(Db.ability(entry["ability_id"]))
	_refresh()


func _on_toggle_equip(ability_id: String) -> void:
	var profile := _profile()
	var equipped: Array = profile["equipped_ability_ids"]
	if ability_id in equipped:
		if ability_id != "strike":  # always keep the free builder
			equipped.erase(ability_id)
	elif equipped.size() < AbilityTree.MAX_EQUIPPED:
		equipped.append(ability_id)
	_show_ability_detail(Db.ability(ability_id))
	_refresh()


func _show_ability_detail(ability: AbilityData) -> void:
	if ability == null:
		return
	var parts := [ability.description]
	if ability.focus_cost > 0:
		parts.append("Cost: %d focus" % ability.focus_cost)
	if ability.cooldown > 0:
		parts.append("Cooldown: %d turns" % ability.cooldown)
	_detail_label.text = "%s — %s" % [ability.display_name, "   ".join(parts)]


## --- Equipment tab ---

func _build_equipment_tab() -> Control:
	var profile := _profile()
	var root := HBoxContainer.new()
	root.name = "Equipment"
	root.add_theme_constant_override("separation", 40)

	var slots_col := VBoxContainer.new()
	slots_col.add_theme_constant_override("separation", 8)
	root.add_child(slots_col)

	var slots_title := Label.new()
	slots_title.text = "Equipped"
	slots_title.add_theme_font_size_override("font_size", 20)
	slots_col.add_child(slots_title)

	for slot in ItemData.Slot.values():
		var key := Equipment.slot_key(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		slots_col.add_child(row)

		var slot_label := Label.new()
		slot_label.text = ItemData.slot_name(slot)
		slot_label.custom_minimum_size = Vector2(90, 0)
		slot_label.add_theme_color_override("font_color", Color("7a8c99"))
		row.add_child(slot_label)

		var item_id: String = profile["equipped"].get(key, "")
		var item: ItemData = Db.item(item_id) if item_id != "" else null
		var button := Button.new()
		button.custom_minimum_size = Vector2(260, 52)
		if item != null:
			button.text = item.display_name
			button.modulate = item.rarity_color()
			button.pressed.connect(func():
				Equipment.unequip(_profile(), key)
				_show_item_detail(item)
				_refresh())
		else:
			button.text = "— empty —"
			button.disabled = true
		row.add_child(button)

	var inv_col := VBoxContainer.new()
	inv_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_col.add_theme_constant_override("separation", 8)
	root.add_child(inv_col)

	var inv_title := Label.new()
	inv_title.text = "Inventory (tap to equip)"
	inv_title.add_theme_font_size_override("font_size", 20)
	inv_col.add_child(inv_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_col.add_child(scroll)

	var inv_list := VBoxContainer.new()
	inv_list.add_theme_constant_override("separation", 6)
	inv_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inv_list)

	var inventory: Array = profile["inventory"]
	if inventory.is_empty():
		var empty := Label.new()
		empty.text = "Nothing here yet. Win battles to find equipment."
		empty.add_theme_color_override("font_color", Color("7a8c99"))
		inv_list.add_child(empty)
	for item_id in inventory:
		var item: ItemData = Db.item(item_id)
		if item == null:
			continue
		var button := Button.new()
		button.text = "%s  (%s)%s" % [item.display_name, ItemData.slot_name(item.slot),
			"" if Equipment.can_equip(profile, item) else "  [Lv %d]" % item.level_req]
		button.custom_minimum_size = Vector2(0, 52)
		button.modulate = item.rarity_color()
		button.pressed.connect(_on_equip_item.bind(item))
		inv_list.add_child(button)
	return root


func _on_equip_item(item: ItemData) -> void:
	Equipment.equip(_profile(), item)
	_show_item_detail(item)
	_refresh()


func _show_item_detail(item: ItemData) -> void:
	var bonuses := []
	for stat in item.stat_bonuses:
		var v: float = item.stat_bonuses[stat]
		if stat == "crit_chance" or stat == "dodge":
			bonuses.append("+%d%% %s" % [roundi(v * 100), stat.capitalize()])
		else:
			bonuses.append("+%d %s" % [roundi(v), stat.capitalize()])
	_detail_label.text = "%s — %s" % [item.display_name, ", ".join(bonuses) if bonuses else item.description]


func _on_back() -> void:
	SaveManager.save_game()
	var dest := SceneRouter.ZONE_MAP if ResourceLoader.exists(SceneRouter.ZONE_MAP) else SceneRouter.MAIN_MENU
	SceneRouter.goto(dest)
