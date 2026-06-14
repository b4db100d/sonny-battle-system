class_name AbilityButton
extends Button
## Touch-sized ability button: color swatch, name, focus cost, cooldown overlay.

const Chrome := preload("res://src/ui/chrome.gd")

signal ability_tapped(ability: AbilityData)

var ability: AbilityData
var _cooldown_overlay: ColorRect
var _cooldown_label: Label
var _cost_label: Label
var _name_label: Label
var _swatch: Panel


func setup(p_ability: AbilityData) -> void:
	ability = p_ability
	text = ""
	custom_minimum_size = Vector2(148, 132)
	Chrome.apply_button(self, ability.icon_color, 18, custom_minimum_size, true)

	_swatch = Panel.new()
	_swatch.position = Vector2(10, 10)
	_swatch.size = Vector2(128, 56)
	_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swatch.add_theme_stylebox_override("panel",
		Chrome.panel_style(ability.icon_color.darkened(0.18), ability.icon_color.lightened(0.28), 14, 1, 0, 0.18))
	add_child(_swatch)

	var shine := ColorRect.new()
	shine.color = Color(1, 1, 1, 0.09)
	shine.position = Vector2(0, 0)
	shine.size = Vector2(128, 18)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swatch.add_child(shine)

	_name_label = Label.new()
	_name_label.text = ability.display_name.to_upper()
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_name_label.offset_left = 10
	_name_label.offset_right = -10
	_name_label.offset_top = -56
	_name_label.offset_bottom = -30
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Chrome.apply_label(_name_label, 14, Color("edf7ff"), 3)
	add_child(_name_label)

	_cost_label = Label.new()
	_cost_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cost_label.offset_left = 12
	_cost_label.offset_right = -12
	_cost_label.offset_top = -28
	_cost_label.offset_bottom = -8
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_label.text = "%d focus" % ability.focus_cost if ability.focus_cost > 0 else "builder"
	Chrome.apply_label(_cost_label, 14, Color("64b5f6"), 2)
	add_child(_cost_label)

	_cooldown_overlay = ColorRect.new()
	_cooldown_overlay.color = Color(0.02, 0.03, 0.05, 0.82)
	_cooldown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cooldown_overlay.visible = false
	_cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cooldown_overlay)

	_cooldown_label = Label.new()
	_cooldown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Chrome.apply_label(_cooldown_label, 42, Color("e8f7ff"), 5)
	_cooldown_overlay.add_child(_cooldown_label)

	pressed.connect(func(): ability_tapped.emit(ability))


func refresh(actor: CombatantState) -> void:
	var cd: int = actor.cooldowns.get(ability.id, 0)
	var affordable: bool = actor.focus >= ability.focus_cost
	disabled = cd > 0 or not affordable
	_cooldown_overlay.visible = cd > 0
	if cd > 0:
		_cooldown_label.text = str(cd)
	_cost_label.text = "%d focus" % ability.focus_cost if ability.focus_cost > 0 else "builder"
	_cost_label.add_theme_color_override("font_color",
		Color("64b5f6") if affordable else Color("ef8c7d"))
	_swatch.modulate = Color(1.0, 1.0, 1.0, 0.35 if disabled else 1.0)
