class_name TurnQueue
extends RefCounted
## Builds the per-round acting order: living combatants by derived speed
## (descending), seeded-RNG tie-break. Rebuilt every round so speed buffs matter.


static func build(combatants: Array, rng: RngService) -> Array[int]:
	var entries: Array = []
	for c in combatants:
		if (c as CombatantState).is_alive():
			entries.append({"index": c.index, "speed": c.derived()["speed"], "tie": rng.randf()})
	entries.sort_custom(func(a, b):
		if a["speed"] != b["speed"]:
			return a["speed"] > b["speed"]
		return a["tie"] > b["tie"]
	)
	var order: Array[int] = []
	for e in entries:
		order.append(e["index"])
	return order
