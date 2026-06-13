extends "res://tests/test_base.gd"
## Auto-battle smoke test: AI drives both sides through battles built from the
## shipped .tres fixtures. Catches integration regressions and infinite loops.

const Fixtures := preload("res://tests/combat_fixtures.gd")
const MAX_TURNS := 300


func _auto_play(battle: BattleState, rng: RngService) -> bool:
	battle.start()
	var turns := 0
	while not battle.is_over() and turns < MAX_TURNS:
		turns += 1
		var actor := battle.current_actor()
		var choice := EnemyAi.choose(battle, actor, rng, 0.5)
		if choice.is_empty():
			battle.act_pass()
		else:
			battle.act(choice["ability"].id, choice["target"])
	return battle.is_over()


func test_fixture_content_battle_completes() -> void:
	var drone: EnemyData = load("res://data/enemies/scrap_drone.tres")
	var hound: EnemyData = load("res://data/enemies/rust_hound.tres")
	assert_true(drone != null and hound != null, "fixture enemies must load")

	var abilities: Array = [
		load("res://data/abilities/strike.tres"),
		load("res://data/abilities/rend.tres"),
		load("res://data/abilities/mend.tres"),
	]
	for run_seed in [1, 2, 3, 4, 5]:
		var rng := RngService.new(run_seed)
		var player := Fixtures.make_unit(0, 8, 6, 8, 8, abilities, true)
		var battle := BattleState.new()
		battle.setup([player], [[drone, drone], [hound]], rng)
		assert_true(_auto_play(battle, rng), "battle must terminate (seed %d)" % run_seed)


func test_event_targets_always_valid() -> void:
	var drone: EnemyData = load("res://data/enemies/scrap_drone.tres")
	var rng := RngService.new(77)
	var player := Fixtures.make_unit(0, 8, 6, 8, 8, [load("res://data/abilities/strike.tres")], true)
	var battle := BattleState.new()
	battle.setup([player], [[drone]], rng)
	var events := battle.start()
	while not battle.is_over():
		var choice := EnemyAi.choose(battle, battle.current_actor(), rng, 0.5)
		if choice.is_empty():
			events.append_array(battle.act_pass())
		else:
			events.append_array(battle.act(choice["ability"].id, choice["target"]))
	for e in events:
		if e.has("target"):
			assert_true(e["target"] >= 0 and e["target"] < battle.combatants.size(),
				"event %s has invalid target" % str(e))
