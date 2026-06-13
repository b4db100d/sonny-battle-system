class_name Leveling
extends RefCounted
## XP curve and level-up rewards.

const LEVEL_CAP := 24
const STAT_POINTS_PER_LEVEL := 2
const SKILL_POINTS_PER_LEVEL := 1


static func xp_to_next(level: int) -> int:
	if level >= LEVEL_CAP:
		return 0
	return roundi(60.0 * pow(level, 1.55))


## Applies XP to a profile dict in place; returns the number of levels gained.
static func grant_xp(profile: Dictionary, amount: int) -> int:
	var levels_gained := 0
	profile["xp"] = int(profile.get("xp", 0)) + amount
	while profile["level"] < LEVEL_CAP and profile["xp"] >= xp_to_next(profile["level"]):
		profile["xp"] -= xp_to_next(profile["level"])
		profile["level"] += 1
		profile["unspent_stat_points"] = int(profile.get("unspent_stat_points", 0)) + STAT_POINTS_PER_LEVEL
		profile["unspent_skill_points"] = int(profile.get("unspent_skill_points", 0)) + SKILL_POINTS_PER_LEVEL
		levels_gained += 1
	if profile["level"] >= LEVEL_CAP:
		profile["xp"] = 0
	return levels_gained


## Base primaries every character starts with at level 1.
static func base_primaries() -> Dictionary:
	return {"strength": 5, "instinct": 5, "speed": 5, "vitality": 5}
