extends "res://tests/test_base.gd"
## Campaign balance simulator: plays the whole campaign headlessly with a
## reasonable build, printing a per-stage win-rate/turn-count table. Doubles
## as the regression test that every stage is beatable at intended levels.

const RUNS_PER_STAGE := 6
const MAX_TURNS := 250
const PLAYER_AI_TEMPERATURE := 0.3

const STAGE_ORDER := [
	"v1", "v2", "v3", "v_boss",
	"r1", "r2", "r3", "r_boss",
	"q1", "q2", "q3", "q_boss",
	"s1", "s2", "s3", "s_boss",
]

## Learning priority for skill points (a havoc/bastion bruiser-medic build).
const LEARN_ORDER := [
	"rend", "mend", "crack", "overload_strike", "barrier_skill", "concuss",
	"provoke", "frenzy_skill", "purge", "rally_skill", "executioner", "second_wind",
]
const EQUIP_PRIORITY := [
	"executioner", "concuss", "overload_strike", "crack", "rend",
	"second_wind", "mend", "frenzy_skill", "barrier_skill", "purge",
]
## Stat point spending cycle.
const STAT_CYCLE := ["strength", "vitality", "strength", "speed"]


func _db() -> Node:
	return Engine.get_main_loop().root.get_node("Db")


func test_campaign_is_beatable() -> void:
	var db := _db()
	var profile := {
		"name": "Sim S-7", "level": 1, "xp": 0,
		"stat_alloc": {"strength": 0, "instinct": 0, "speed": 0, "vitality": 0},
		"unspent_stat_points": 0, "unspent_skill_points": 1,
		"learned_ability_ids": [], "equipped_ability_ids": ["strike"],
		"equipped": {}, "inventory": [],
	}
	var allies: Array = []
	var stat_cursor := 0
	var report: Array[String] = []
	var training_fights := 0

	for stage_id in STAGE_ORDER:
		var stage: StageData = db.stage(stage_id)
		assert_true(stage != null, "missing stage %s" % stage_id)
		if stage == null:
			return

		# Grind the zone's training stage if underleveled (a real player would).
		var guard := 0
		while profile["level"] < stage.recommended_level - 1 and guard < 12:
			guard += 1
			training_fights += 1
			var training := _zone_training_stage(stage.zone_id)
			Leveling.grant_xp(profile, _stage_xp(training, false))
			for ally in allies:
				Leveling.grant_xp(ally, _stage_xp(training, false))
		stat_cursor = _spend_points(profile, stat_cursor)

		var wins := 0
		var total_turns := 0
		var won_any := false
		for run in RUNS_PER_STAGE:
			var rng := RngService.new(1000 + stage_id.hash() % 100000 + run)
			var battle := BattleState.new()
			battle.setup(_build_party(profile, allies), stage.waves, rng, 1.0, 0.5)
			var result := _auto_play(battle, rng)
			if result["won"]:
				wins += 1
				won_any = true
				total_turns += result["turns"]

		var avg_turns := (float(total_turns) / wins) if wins > 0 else 0.0
		report.append("%-12s rec_lv %2d | player lv %2d | wins %d/%d | avg turns %.1f" % [
			stage_id, stage.recommended_level, profile["level"], wins, RUNS_PER_STAGE, avg_turns])
		assert_true(won_any, "stage %s never won at level %d" % [stage_id, profile["level"]])

		# Apply victory progression once.
		Leveling.grant_xp(profile, _stage_xp(stage, true))
		for ally in allies:
			Leveling.grant_xp(ally, _stage_xp(stage, true))
		if stage.first_clear_item != null:
			profile["inventory"].append(stage.first_clear_item.id)
			Equipment.equip(profile, stage.first_clear_item)
		if stage.recruit_ally_id != "":
			allies.append(_make_ally(stage.recruit_ally_id, profile["level"]))
		stat_cursor = _spend_points(profile, stat_cursor)

	print("\n--- Campaign simulation (build: havoc/bastion, normal difficulty) ---")
	for line in report:
		print(line)
	print("Training fights used: %d | final level: %d\n" % [training_fights, profile["level"]])
	assert_true(profile["level"] >= 17, "campaign should end at a high level, got %d" % profile["level"])


func _stage_xp(stage: StageData, first_clear: bool) -> int:
	var xp := 0
	for enemy in stage.all_enemies():
		xp += (enemy as EnemyData).xp_reward
	if first_clear:
		xp += stage.first_clear_xp_bonus
	return xp


func _zone_training_stage(zone_id: String) -> StageData:
	var zone: ZoneData = _db().zone(zone_id)
	for stage in zone.stages:
		if (stage as StageData).is_training:
			return stage
	return zone.stages[0]


func _spend_points(profile: Dictionary, cursor: int) -> int:
	var db := _db()
	while profile["unspent_stat_points"] > 0:
		var stat: String = STAT_CYCLE[cursor % STAT_CYCLE.size()]
		profile["stat_alloc"][stat] = int(profile["stat_alloc"][stat]) + 1
		profile["unspent_stat_points"] = int(profile["unspent_stat_points"]) - 1
		cursor += 1
	var learned_something := true
	while profile["unspent_skill_points"] > 0 and learned_something:
		learned_something = false
		for ability_id in LEARN_ORDER:
			if AbilityTree.is_learned(profile, ability_id):
				continue
			var ability: AbilityData = db.ability(ability_id)
			var tree: AbilityTreeData = db.tree_data(ability.tree_id)
			var entry := {}
			for e in tree.entries:
				if e["ability_id"] == ability_id:
					entry = e
					break
			if AbilityTree.learn(profile, tree, entry):
				learned_something = true
				break
	# Re-derive the equipped bar from priority.
	var equipped: Array = ["strike"]
	for ability_id in EQUIP_PRIORITY:
		if equipped.size() >= AbilityTree.MAX_EQUIPPED:
			break
		if AbilityTree.is_learned(profile, ability_id):
			equipped.append(ability_id)
	profile["equipped_ability_ids"] = equipped
	return cursor


func _make_ally(ally_id: String, level: int) -> Dictionary:
	var game_state: Node = Engine.get_main_loop().root.get_node("GameState")
	var def: Dictionary = game_state.ALLY_DEFS[ally_id]
	return {
		"name": def["name"], "level": level, "xp": 0,
		"stat_alloc": {"strength": 0, "instinct": 0, "speed": 0, "vitality": 0},
		"unspent_stat_points": 0, "unspent_skill_points": 0,
		"learned_ability_ids": def["abilities"].duplicate(),
		"equipped_ability_ids": def["abilities"].duplicate(),
		"equipped": {}, "inventory": [],
	}


func _build_unit(profile: Dictionary) -> CombatantState:
	var db := _db()
	var abilities: Array = []
	for ability_id in profile["equipped_ability_ids"]:
		var a: AbilityData = db.ability(ability_id)
		if a != null:
			abilities.append(a)
	var items: Array = []
	for slot in profile["equipped"]:
		var item: ItemData = db.item(profile["equipped"][slot])
		if item != null:
			items.append(item)
	return CombatantState.from_profile(profile, abilities, items)


func _build_party(profile: Dictionary, allies: Array) -> Array:
	var party: Array = [_build_unit(profile)]
	for ally in allies:
		# Allies auto-spend stat points on a simple bruiser/support split.
		var pts: int = (int(ally["level"]) - 1) * Leveling.STAT_POINTS_PER_LEVEL
		ally["stat_alloc"] = {
			"strength": pts / 4, "instinct": pts / 4,
			"speed": pts / 4, "vitality": pts - 3 * (pts / 4),
		}
		party.append(_build_unit(ally))
	return party


func _auto_play(battle: BattleState, rng: RngService) -> Dictionary:
	battle.start()
	var turns := 0
	while not battle.is_over() and turns < MAX_TURNS:
		turns += 1
		var actor := battle.current_actor()
		var temperature := PLAYER_AI_TEMPERATURE if actor.team == CombatantState.TEAM_PLAYER else 0.5
		var choice := EnemyAi.choose(battle, actor, rng, temperature)
		if choice.is_empty():
			battle.act_pass()
		else:
			battle.act(choice["ability"].id, choice["target"])
	return {"won": battle.phase == BattleState.Phase.VICTORY, "turns": turns}
