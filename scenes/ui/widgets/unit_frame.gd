class_name UnitFrame
extends PanelContainer
## Compact party frame: name + HP/focus bars with numbers.

var _name_label: Label
var _hp_bar: ProgressBar
var _focus_bar: ProgressBar


func setup(unit_name: String, accent: Color) -> void:
	custom_minimum_size = Vector2(220, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)

	_name_label = Label.new()
	_name_label.text = unit_name
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", accent.lightened(0.3))
	column.add_child(_name_label)

	_hp_bar = _bar(Color("e53935"))
	column.add_child(_hp_bar)
	_focus_bar = _bar(Color("1e88e5"))
	column.add_child(_focus_bar)


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 16)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override("background", back)
	return bar


func refresh(state: CombatantState) -> void:
	var d := state.derived()
	_hp_bar.max_value = d["max_hp"]
	_hp_bar.value = state.hp
	_focus_bar.max_value = d["max_focus"]
	_focus_bar.value = state.focus
	modulate.a = 1.0 if state.is_alive() else 0.45
