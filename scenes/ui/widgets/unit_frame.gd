class_name UnitFrame
extends PanelContainer
## Compact party frame: name + HP/focus bars with numbers.

const Chrome := preload("res://src/ui/chrome.gd")

var _name_label: Label
var _hp_bar: ProgressBar
var _focus_bar: ProgressBar
var _hp_label: Label
var _focus_label: Label


func setup(unit_name: String, accent: Color) -> void:
	custom_minimum_size = Vector2(248, 0)
	add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.05, 0.08, 0.11, 0.84), accent.lightened(0.2), 20, 2, 14, 0.32))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	_name_label = Label.new()
	_name_label.text = unit_name
	Chrome.apply_label(_name_label, 18, accent.lightened(0.45), 3)
	column.add_child(_name_label)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	column.add_child(hp_row)

	var hp_tag := Label.new()
	hp_tag.text = "HP"
	Chrome.apply_label(hp_tag, 12, Color("f3a6a3"), 2)
	hp_row.add_child(hp_tag)

	_hp_bar = _bar(Color("da5f63"))
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(_hp_bar)

	_hp_label = Label.new()
	Chrome.apply_label(_hp_label, 12, Color("edf5ff"), 2)
	hp_row.add_child(_hp_label)

	var focus_row := HBoxContainer.new()
	focus_row.add_theme_constant_override("separation", 8)
	column.add_child(focus_row)

	var focus_tag := Label.new()
	focus_tag.text = "FOCUS"
	Chrome.apply_label(focus_tag, 12, Color("8fc6ff"), 2)
	focus_row.add_child(focus_tag)

	_focus_bar = _bar(Color("4b9fff"))
	_focus_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_row.add_child(_focus_bar)

	_focus_label = Label.new()
	Chrome.apply_label(_focus_label, 12, Color("edf5ff"), 2)
	focus_row.add_child(_focus_label)


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.45)
	back.set_corner_radius_all(7)
	back.border_color = color.darkened(0.45)
	back.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", back)
	return bar


func refresh(state: CombatantState) -> void:
	var d := state.derived()
	_hp_bar.max_value = d["max_hp"]
	_hp_bar.value = state.hp
	_hp_label.text = "%d/%d" % [roundi(state.hp), roundi(d["max_hp"])]
	_focus_bar.max_value = d["max_focus"]
	_focus_bar.value = state.focus
	_focus_label.text = "%d/%d" % [roundi(state.focus), roundi(d["max_focus"])]
	modulate.a = 1.0 if state.is_alive() else 0.4
