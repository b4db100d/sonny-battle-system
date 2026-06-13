extends "res://tests/test_base.gd"
## Content integrity: every .tres loads, ids match registries, and every
## cross-reference resolves. Catches authoring/generator mistakes in CI.


func _db() -> Node:
	return Engine.get_main_loop().root.get_node("Db")


func test_registries_populated() -> void:
	var db := _db()
	assert_true(db.abilities.size() >= 30, "abilities: %d" % db.abilities.size())
	assert_true(db.statuses.size() >= 12, "statuses: %d" % db.statuses.size())
	assert_true(db.enemies.size() >= 20, "enemies: %d" % db.enemies.size())
	assert_true(db.items.size() >= 26, "items: %d" % db.items.size())
	assert_true(db.stages.size() == 20, "stages: %d" % db.stages.size())
	assert_true(db.zones.size() == 4, "zones: %d" % db.zones.size())
	assert_true(db.trees.size() == 3, "trees: %d" % db.trees.size())


func test_ability_sanity() -> void:
	for ability in _db().abilities.values():
		var a: AbilityData = ability
		assert_true(a.display_name != "", "%s needs display_name" % a.id)
		assert_true(a.focus_cost >= 0 and a.cooldown >= 0, a.id)
		assert_true(a.hit_count >= 1, a.id)
		assert_true(a.status_chance > 0.0 and a.status_chance <= 1.0, a.id)
		if a.damage_type == AbilityData.DamageType.PHYSICAL or a.damage_type == AbilityData.DamageType.PSY:
			assert_true(a.is_offensive(), "%s deals damage but targets allies" % a.id)
		if a.damage_type == AbilityData.DamageType.HEAL:
			assert_false(a.is_offensive(), "%s heals enemies" % a.id)


func test_enemy_references_resolve() -> void:
	var db := _db()
	for enemy in db.enemies.values():
		var e: EnemyData = enemy
		assert_true(e.abilities.size() > 0, "%s has no abilities" % e.id)
		for a in e.abilities:
			assert_true(a != null and db.abilities.has(a.id), "%s: broken ability ref" % e.id)
		for entry in e.loot_table:
			assert_true(db.items.has(entry["item_id"]), "%s: unknown loot %s" % [e.id, entry["item_id"]])
		assert_true(e.xp_reward > 0, e.id)


func test_stage_references_resolve() -> void:
	var db := _db()
	for stage in db.stages.values():
		var s: StageData = stage
		assert_true(db.zones.has(s.zone_id), "%s: unknown zone %s" % [s.id, s.zone_id])
		assert_true(s.waves.size() >= 1, "%s has no waves" % s.id)
		for wave in s.waves:
			assert_true(wave.size() >= 1 and wave.size() <= 3, "%s: wave size %d" % [s.id, wave.size()])
			for enemy in wave:
				assert_true(enemy != null and db.enemies.has(enemy.id), "%s: broken enemy ref" % s.id)
		if s.requires_stage_id != "":
			assert_true(db.stages.has(s.requires_stage_id), "%s: unknown gate %s" % [s.id, s.requires_stage_id])
		for dialogue_id in [s.pre_dialogue_id, s.post_dialogue_id]:
			if dialogue_id != "":
				assert_true(FileAccess.file_exists("res://data/dialogue/%s.json" % dialogue_id),
					"%s: missing dialogue %s" % [s.id, dialogue_id])
		if s.recruit_ally_id != "":
			var game_state: Node = Engine.get_main_loop().root.get_node("GameState")
			assert_true(game_state.ALLY_DEFS.has(s.recruit_ally_id), "%s: unknown ally" % s.id)


func test_zone_chain_and_stage_membership() -> void:
	var db := _db()
	var start_zones := 0
	for zone in db.zones.values():
		var z: ZoneData = zone
		if z.unlocked_by_zone_id == "":
			start_zones += 1
		else:
			assert_true(db.zones.has(z.unlocked_by_zone_id), "%s: bad gate zone" % z.id)
		assert_eq(z.stages.size(), 5, "%s should have 5 stages" % z.id)
		var has_training := false
		for stage in z.stages:
			assert_eq((stage as StageData).zone_id, z.id, "stage/zone mismatch in %s" % z.id)
			if stage.is_training:
				has_training = true
		assert_true(has_training, "%s needs a training stage" % z.id)
	assert_eq(start_zones, 1, "exactly one starting zone")


func test_tree_references_and_reachability() -> void:
	var db := _db()
	for tree in db.trees.values():
		var t: AbilityTreeData = tree
		assert_eq(t.entries.size(), 6, "%s should have 6 entries" % t.id)
		for entry in t.entries:
			var ability: AbilityData = db.ability(entry["ability_id"])
			assert_true(ability != null, "%s: unknown ability %s" % [t.id, entry["ability_id"]])
			if ability != null:
				assert_eq(ability.tree_id, t.id, "%s listed in wrong tree" % ability.id)
			# Tier must be reachable: enough lower-tier abilities exist.
			var lower := 0
			for other in t.entries:
				if int(other["tier"]) < int(entry["tier"]):
					lower += 1
			assert_true(lower >= t.points_required_for_tier(int(entry["tier"])),
				"%s: tier %d unreachable" % [entry["ability_id"], entry["tier"]])


func test_ally_defs_resolve() -> void:
	var db := _db()
	var game_state: Node = Engine.get_main_loop().root.get_node("GameState")
	for ally_id in game_state.ALLY_DEFS:
		for ability_id in game_state.ALLY_DEFS[ally_id]["abilities"]:
			assert_true(db.abilities.has(ability_id), "ally %s: unknown ability %s" % [ally_id, ability_id])


func test_dialogue_files_parse() -> void:
	var dir := DirAccess.open("res://data/dialogue")
	assert_true(dir != null)
	dir.list_dir_begin()
	var fname := dir.get_next()
	var count := 0
	while fname != "":
		if fname.ends_with(".json"):
			count += 1
			var lines: Array = load("res://scenes/ui/dialogue_box.gd").load_dialogue(fname.get_basename())
			assert_true(lines.size() > 0, "dialogue %s empty/malformed" % fname)
			for line in lines:
				assert_true(line.has("speaker") and line.has("text"), fname)
		fname = dir.get_next()
	dir.list_dir_end()
	assert_true(count >= 10, "expected dialogue beats, found %d" % count)
