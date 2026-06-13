class_name Loot
extends RefCounted
## Loot rolls for defeated enemies.


## defeated: Array of CombatantState. Returns Array of item id Strings.
static func roll_drops(defeated: Array, rng: RngService) -> Array:
	var drops: Array = []
	for unit in defeated:
		if unit.loot_table.is_empty() or not rng.chance(unit.loot_chance):
			continue
		var entry: Variant = rng.pick_weighted(unit.loot_table)
		if entry != null and entry.has("item_id"):
			drops.append(entry["item_id"])
	return drops


static func total_xp(defeated: Array) -> int:
	var total := 0
	for unit in defeated:
		total += unit.xp_reward
	return total


static func total_credits(defeated: Array) -> int:
	var total := 0
	for unit in defeated:
		total += unit.credit_reward
	return total
