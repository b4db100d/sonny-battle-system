class_name AbilityTree
extends RefCounted
## Skill tree rules operating on player profile dictionaries.

const MAX_EQUIPPED := 6


static func points_spent_in_tree(profile: Dictionary, tree: AbilityTreeData) -> int:
	var learned: Array = profile.get("learned_ability_ids", [])
	var spent := 0
	for entry in tree.entries:
		if entry["ability_id"] in learned:
			spent += 1
	return spent


static func is_learned(profile: Dictionary, ability_id: String) -> bool:
	return ability_id in profile.get("learned_ability_ids", [])


static func can_learn(profile: Dictionary, tree: AbilityTreeData, entry: Dictionary) -> bool:
	if is_learned(profile, entry["ability_id"]):
		return false
	if int(profile.get("unspent_skill_points", 0)) < 1:
		return false
	if int(profile.get("level", 1)) < int(entry.get("level_req", 1)):
		return false
	return points_spent_in_tree(profile, tree) >= tree.points_required_for_tier(int(entry.get("tier", 1)))


## Spends one skill point; returns false if requirements fail.
static func learn(profile: Dictionary, tree: AbilityTreeData, entry: Dictionary) -> bool:
	if not can_learn(profile, tree, entry):
		return false
	profile["unspent_skill_points"] = int(profile["unspent_skill_points"]) - 1
	profile["learned_ability_ids"].append(entry["ability_id"])
	return true


## Refunds every spent point and clears learned abilities (free respec).
## Keeps "strike" equipped so the player always has an action.
static func respec(profile: Dictionary) -> void:
	var learned: Array = profile.get("learned_ability_ids", [])
	profile["unspent_skill_points"] = int(profile.get("unspent_skill_points", 0)) + learned.size()
	profile["learned_ability_ids"] = []
	profile["equipped_ability_ids"] = ["strike"]


## Also used for stat respec: returns all allocated stat points to the pool.
static func respec_stats(profile: Dictionary) -> void:
	var alloc: Dictionary = profile.get("stat_alloc", {})
	var total := 0
	for stat in alloc:
		total += int(alloc[stat])
		alloc[stat] = 0
	profile["unspent_stat_points"] = int(profile.get("unspent_stat_points", 0)) + total
