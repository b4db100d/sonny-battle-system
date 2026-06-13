extends "res://tests/test_base.gd"


func _profile(level: int = 5, skill_points: int = 3) -> Dictionary:
	return {
		"level": level,
		"xp": 0,
		"stat_alloc": {"strength": 4, "instinct": 2, "speed": 0, "vitality": 0},
		"unspent_stat_points": 2,
		"unspent_skill_points": skill_points,
		"learned_ability_ids": [],
		"equipped_ability_ids": ["strike"],
		"equipped": {},
		"inventory": [],
	}


func _tree() -> AbilityTreeData:
	var tree := AbilityTreeData.new()
	tree.id = "havoc"
	tree.entries = [
		{"ability_id": "rend", "tier": 1, "level_req": 1},
		{"ability_id": "crack", "tier": 1, "level_req": 2},
		{"ability_id": "overload", "tier": 2, "level_req": 4},
		{"ability_id": "executioner", "tier": 3, "level_req": 8},
	]
	return tree


func test_tier_gating() -> void:
	var profile := _profile()
	var tree := _tree()
	assert_true(AbilityTree.can_learn(profile, tree, tree.entries[0]))
	assert_false(AbilityTree.can_learn(profile, tree, tree.entries[2]), "tier 2 needs 2 points spent in tree")
	assert_true(AbilityTree.learn(profile, tree, tree.entries[0]))
	assert_true(AbilityTree.learn(profile, tree, tree.entries[1]))
	assert_true(AbilityTree.can_learn(profile, tree, tree.entries[2]), "tier 2 unlocked after 2 points")


func test_level_req_gating() -> void:
	var profile := _profile(3, 10)
	var tree := _tree()
	AbilityTree.learn(profile, tree, tree.entries[0])
	AbilityTree.learn(profile, tree, tree.entries[1])
	assert_false(AbilityTree.can_learn(profile, tree, tree.entries[2]), "level 3 < level_req 4")


func test_skill_points_spent_and_no_double_learn() -> void:
	var profile := _profile(5, 1)
	var tree := _tree()
	assert_true(AbilityTree.learn(profile, tree, tree.entries[0]))
	assert_eq(profile["unspent_skill_points"], 0)
	assert_false(AbilityTree.learn(profile, tree, tree.entries[0]), "already learned")
	assert_false(AbilityTree.learn(profile, tree, tree.entries[1]), "no points left")


func test_respec_refunds_points() -> void:
	var profile := _profile(5, 2)
	var tree := _tree()
	AbilityTree.learn(profile, tree, tree.entries[0])
	AbilityTree.respec(profile)
	assert_eq(profile["unspent_skill_points"], 2)
	assert_eq(profile["learned_ability_ids"], [])
	assert_eq(profile["equipped_ability_ids"], ["strike"])


func test_respec_stats() -> void:
	var profile := _profile()
	AbilityTree.respec_stats(profile)
	assert_eq(profile["unspent_stat_points"], 8)
	assert_eq(profile["stat_alloc"]["strength"], 0)


func _item(p_id: String, slot: int, level_req: int = 1) -> ItemData:
	var item := ItemData.new()
	item.id = p_id
	item.slot = slot
	item.level_req = level_req
	return item


func test_equip_swaps_with_inventory() -> void:
	var profile := _profile()
	profile["inventory"] = ["sword_a", "sword_b"]
	var sword_a := _item("sword_a", ItemData.Slot.WEAPON)
	var sword_b := _item("sword_b", ItemData.Slot.WEAPON)
	assert_true(Equipment.equip(profile, sword_a))
	assert_eq(profile["equipped"]["weapon"], "sword_a")
	assert_true(Equipment.equip(profile, sword_b))
	assert_eq(profile["equipped"]["weapon"], "sword_b")
	assert_true("sword_a" in profile["inventory"])
	Equipment.unequip(profile, "weapon")
	assert_false(profile["equipped"].has("weapon"))
	assert_true("sword_b" in profile["inventory"])


func test_equip_level_requirement() -> void:
	var profile := _profile(2)
	profile["inventory"] = ["elite_helm"]
	assert_false(Equipment.equip(profile, _item("elite_helm", ItemData.Slot.HEAD, 10)))
	assert_true("elite_helm" in profile["inventory"])


func test_equip_requires_ownership() -> void:
	var profile := _profile()
	assert_false(Equipment.equip(profile, _item("ghost_item", ItemData.Slot.WEAPON)))
