extends "res://tests/test_base.gd"
## Save/load round-trip through the real autoloads (available in -s runs).

const TEST_SLOT := 3


func test_round_trip_preserves_state() -> void:
	var game_state: Node = Engine.get_main_loop().root.get_node("GameState")
	var save_manager: Node = Engine.get_main_loop().root.get_node("SaveManager")

	game_state.new_game(game_state.DIFFICULTY_HARD)
	game_state.player["level"] = 7
	game_state.player["xp"] = 123
	game_state.player["stat_alloc"]["strength"] = 6
	game_state.player["learned_ability_ids"] = ["rend", "mend"]
	game_state.player["equipped_ability_ids"] = ["strike", "rend"]
	game_state.player["inventory"] = ["rusty_blade"]
	game_state.player["equipped"] = {"weapon": "old_sword"}
	game_state.add_ally("Vela", ["strike"], "c77dff")
	game_state.credits = 99
	game_state.mark_stage_cleared("z1_s1")
	var before: Dictionary = game_state.to_dict()

	assert_true(save_manager.save_game(TEST_SLOT), "save should succeed")
	game_state.new_game()  # wipe in-memory state
	assert_true(save_manager.load_game(TEST_SLOT), "load should succeed")

	var after: Dictionary = game_state.to_dict()
	# JSON round-trips ints as floats; compare via JSON normalization.
	assert_eq(JSON.stringify(after, "", true), JSON.stringify(before, "", true))
	assert_eq(int(game_state.player["level"]), 7)
	assert_eq(game_state.allies.size(), 1)
	assert_true(game_state.is_stage_cleared("z1_s1"))
	assert_eq(int(game_state.difficulty), game_state.DIFFICULTY_HARD)

	save_manager.delete_save(TEST_SLOT)
	assert_false(save_manager.has_save(TEST_SLOT))


func test_load_missing_slot_fails_cleanly() -> void:
	var save_manager: Node = Engine.get_main_loop().root.get_node("SaveManager")
	save_manager.delete_save(TEST_SLOT)
	assert_false(save_manager.load_game(TEST_SLOT))


func test_slot_summary() -> void:
	var game_state: Node = Engine.get_main_loop().root.get_node("GameState")
	var save_manager: Node = Engine.get_main_loop().root.get_node("SaveManager")
	game_state.new_game()
	game_state.player["level"] = 4
	game_state.mark_stage_cleared("a")
	game_state.mark_stage_cleared("b")
	save_manager.save_game(TEST_SLOT)
	var summary: Dictionary = save_manager.slot_summary(TEST_SLOT)
	assert_eq(summary["level"], 4)
	assert_eq(summary["cleared"], 2)
	save_manager.delete_save(TEST_SLOT)
