class_name AbilityButton
extends Button
## Touch-sized ability button: color swatch, name, focus cost, cooldown overlay.

signal ability_tapped(ability: AbilityData)

var ability: AbilityData
var _cooldown_overlay: ColorRect
var _cooldown_label: Label
var _cost_label: Label


func setup(p_ability: AbilityData) -> void:
	ability = p_ability
	custom_minimum_size = Vector2(112, 112)

	var swatch := ColorRect.new()
	swatch.color = ability.icon_color
	swatch.set_anchors_preset(Control.PRESET_TOP_WIDE)
	swatch.offset_left = 10
	swatch.offset_right = -10
	swatch.offset_top = 8
	swatch.offset_bottom = 48
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(swatch)

	var name_label := Label.new()
	name_label.text = ability.display_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -56
	name_label.offset_bottom = -34
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 14)
	_cost_label.add_theme_color_override("font_color", Color("64b5f6"))
	_cost_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cost_label.offset_top = -30
	_cost_label.offset_bottom = -8
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.text = "%d focus" % ability.focus_cost if ability.focus_cost > 0 else ""
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cost_label)

	_cooldown_overlay = ColorRect.new()
	_cooldown_overlay.color = Color(0, 0, 0, 0.65)
	_cooldown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cooldown_overlay.visible = false
	_cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cooldown_overlay)

	_cooldown_label = Label.new()
	_cooldown_label.add_theme_font_size_override("font_size", 40)
	_cooldown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown_overlay.add_child(_cooldown_label)

	pressed.connect(func(): ability_tapped.emit(ability))


func refresh(actor: CombatantState) -> void:
	var cd: int = actor.cooldowns.get(ability.id, 0)
	var affordable: bool = actor.focus >= ability.focus_cost
	disabled = cd > 0 or not affordable
	_cooldown_overlay.visible = cd > 0
	if cd > 0:
		_cooldown_label.text = str(cd)
	_cost_label.add_theme_color_override("font_color",
		Color("64b5f6") if affordable else Color("ef5350"))
