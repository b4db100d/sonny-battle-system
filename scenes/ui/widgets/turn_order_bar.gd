class_name TurnOrderBar
extends HBoxContainer
## Top-center chips showing this round's acting order; current actor pulses.

var _chips: Dictionary = {}  # combatant index -> PanelContainer


func rebuild(order: Array, combatants: Array) -> void:
	for child in get_children():
		child.queue_free()
	_chips.clear()
	for idx in order:
		var unit: CombatantState = combatants[idx]
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = unit.body_color.darkened(0.4)
		style.set_corner_radius_all(6)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = unit.display_name
		label.add_theme_font_size_override("font_size", 14)
		chip.add_child(label)
		add_child(chip)
		_chips[idx] = chip


func highlight(actor_index: int, combatants: Array) -> void:
	for idx in _chips:
		var unit: CombatantState = combatants[idx]
		var chip: PanelContainer = _chips[idx]
		chip.modulate = Color(1.6, 1.6, 1.2) if idx == actor_index else Color.WHITE
		chip.modulate.a = 1.0 if unit.is_alive() else 0.35
