class_name TurnOrderBar
extends HBoxContainer
## Top-center chips showing this round's acting order; current actor pulses.

const Chrome := preload("res://src/ui/chrome.gd")

var _chips: Dictionary = {}  # combatant index -> PanelContainer


func rebuild(order: Array, combatants: Array) -> void:
	for child in get_children():
		child.queue_free()
	_chips.clear()
	for idx in order:
		var unit: CombatantState = combatants[idx]
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel",
			Chrome.panel_style(
				unit.body_color.darkened(0.68).lerp(Color("0d141c"), 0.18),
				unit.body_color.lightened(0.22),
				16, 2, 10, 0.24))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		chip.add_child(row)

		var dot := ColorRect.new()
		dot.color = unit.body_color.lightened(0.18)
		dot.custom_minimum_size = Vector2(10, 10)
		row.add_child(dot)

		var label := Label.new()
		label.text = unit.display_name
		Chrome.apply_label(label, 14, Color("eef7ff"), 2)
		row.add_child(label)

		add_child(chip)
		_chips[idx] = chip


func highlight(actor_index: int, combatants: Array) -> void:
	for idx in _chips:
		var unit: CombatantState = combatants[idx]
		var chip: PanelContainer = _chips[idx]
		chip.modulate = Color(1.18, 1.18, 1.08) if idx == actor_index else Color.WHITE
		chip.scale = Vector2(1.05, 1.05) if idx == actor_index else Vector2.ONE
		chip.modulate.a = 1.0 if unit.is_alive() else 0.32
