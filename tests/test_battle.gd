extends "res://tests/test_base.gd"

const Fixtures := preload("res://tests/combat_fixtures.gd")


func _basic_battle(player_speed: int = 20, enemy_speed: int = 5) -> BattleState:
	var player := Fixtures.make_unit(0, 10, 5, player_speed, 10, [Fixtures.make_attack()], true)
	var enemy_data := _enemy_data(5, enemy_speed)
	var battle := BattleState.new()
	battle.setup([player], [[enemy_data]], RngService.new(99))
	return battle


func _enemy_data(strength: int, speed: int, vitality: int = 5) -> EnemyData:
	var e := EnemyData.new()
	e.id = "test_enemy"
	e.display_name = "Test Enemy"
	e.strength = strength
	e.speed = speed
	e.vitality = vitality
	e.abilities = [Fixtures.make_attack("enemy_atk", 5.0)]
	e.xp_reward = 10
	return e


func test_turn_order_by_speed() -> void:
	var battle := _basic_battle(20, 5)
	var events := battle.start()
	var round_event: Dictionary = events.filter(func(e): return e["type"] == "round_start")[0]
	assert_eq(round_event["order"][0], 0, "faster player should act first")
	assert_eq(battle.phase, BattleState.Phase.AWAIT_INPUT)
	assert_eq(battle.current_actor().index, 0)


func test_enemy_acts_first_when_faster() -> void:
	var battle := _basic_battle(5, 20)
	var events := battle.start()
	# Enemy acted before input was requested.
	assert_true(events.any(func(e): return e["type"] == "ability_used" and e["actor"] == 1))
	assert_eq(battle.phase, BattleState.Phase.AWAIT_INPUT)


func test_player_attack_resolves_and_battle_completes() -> void:
	var battle := _basic_battle()
	battle.start()
	var safety := 0
	while not battle.is_over() and safety < 200:
		safety += 1
		var actor := battle.current_actor()
		var usable := battle.usable_abilities(actor)
		if usable.is_empty():
			battle.act_pass()
			continue
		var targets := battle.legal_targets(actor, usable[0])
		battle.act(usable[0].id, targets[0])
	assert_true(battle.is_over(), "battle should finish")
	assert_eq(battle.phase, BattleState.Phase.VICTORY, "player should beat a weak enemy")
	assert_eq(battle.defeated_enemies.size(), 1)


func test_illegal_target_rejected() -> void:
	var battle := _basic_battle()
	battle.start()
	var actor := battle.current_actor()
	var atk: AbilityData = actor.abilities[0]
	var events := battle.act(atk.id, 0)  # targeting self with an ENEMY ability
	assert_eq(events.size(), 0)
	assert_eq(battle.phase, BattleState.Phase.AWAIT_INPUT, "state unchanged after illegal act")


func test_taunt_restricts_targets() -> void:
	var player := Fixtures.make_unit(0, 10, 5, 20, 10, [Fixtures.make_attack()], true)
	var battle := BattleState.new()
	battle.setup([player], [[_enemy_data(5, 5), _enemy_data(5, 4)]], RngService.new(5))
	battle.start()
	var taunt := Fixtures.make_status("taunt_up", false, 2)
	taunt.flags = ["taunt"]
	var events: Array = []
	StatusEngine.apply(battle.combatants[2], taunt, null, events)
	var legal := battle.legal_targets(player, player.abilities[0])
	assert_eq(legal, [2], "only the taunting enemy is targetable")


func test_stunned_unit_skips_turn() -> void:
	var player := Fixtures.make_unit(0, 10, 5, 20, 10, [Fixtures.make_attack()], true)
	var battle := BattleState.new()
	battle.setup([player], [[_enemy_data(5, 5, 50)]], RngService.new(5))
	battle.start()
	var stun := Fixtures.make_status("stunned", true, 2)
	stun.flags = ["stun"]
	var events: Array = []
	StatusEngine.apply(battle.combatants[1], stun, null, events)
	# Player passes; the enemy's turn should be skipped with a "stunned" event.
	var turn_events := battle.act_pass()
	assert_true(turn_events.any(func(e): return e["type"] == "stunned" and e["actor"] == 1))
	assert_false(turn_events.any(func(e): return e["type"] == "ability_used" and e["actor"] == 1))


func test_multi_wave_spawns() -> void:
	var player := Fixtures.make_unit(0, 30, 5, 20, 30, [Fixtures.make_attack("smash", 200.0)], true)
	var battle := BattleState.new()
	battle.setup([player], [[_enemy_data(2, 5)], [_enemy_data(2, 5)]], RngService.new(5))
	battle.start()
	# Kill wave 1.
	var events := battle.act("smash", 1)
	assert_true(events.any(func(e): return e["type"] == "wave_started" and e["wave"] == 2))
	assert_false(battle.is_over())
	# Kill wave 2.
	events = battle.act("smash", 2)
	assert_eq(battle.phase, BattleState.Phase.VICTORY)
	assert_eq(battle.defeated_enemies.size(), 2)


func test_defeat_when_players_dead() -> void:
	var player := Fixtures.make_unit(0, 1, 1, 1, 0, [Fixtures.make_attack("weak", 0.1)], true)
	player.hp = 1.0
	var battle := BattleState.new()
	battle.setup([player], [[_enemy_data(50, 20, 50)]], RngService.new(5))
	var events := battle.start()
	assert_eq(battle.phase, BattleState.Phase.DEFEAT)
	assert_true(events.any(func(e): return e["type"] == "defeat"))


func test_focus_regen_at_turn_start() -> void:
	var battle := _basic_battle()
	var player: CombatantState = battle.combatants[0]
	player.focus = 0.0
	battle.start()
	assert_true(player.focus > 0.0, "player should regen focus at turn start")
