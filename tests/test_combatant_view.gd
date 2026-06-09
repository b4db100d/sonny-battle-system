extends "res://tests/test_base.gd"

const Fixtures := preload("res://tests/combat_fixtures.gd")
const CombatantView := preload("res://scenes/battle/combatant.gd")


func test_combatant_view_is_input_pickable_after_setup() -> void:
	var unit := Fixtures.make_unit(CombatantState.TEAM_PLAYER, 10, 5, 10, 10, [], true)
	var view := CombatantView.new()
	view.setup(unit)
	assert_true(view.input_pickable, "combatants must accept pointer input for target selection")
	view.free()


func test_combatant_view_hit_test_uses_combatant_bounds() -> void:
	var unit := Fixtures.make_unit(CombatantState.TEAM_PLAYER, 10, 5, 10, 10, [], true)
	var view := CombatantView.new()
	view.setup(unit)
	view.global_position = Vector2(400, 300)
	assert_true(view.hit_test(Vector2(400, 300)), "center point should hit the combatant")
	assert_false(view.hit_test(Vector2(700, 300)), "far-away point should miss the combatant")
	view.free()
