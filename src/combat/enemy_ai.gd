class_name EnemyAi
extends RefCounted
## Scores every legal (ability, target) pair and picks among the best.
## Also drives the player side in headless auto-battle simulations.

const PROFILE_MULT := {
	EnemyData.AiProfile.BRUTE: {"damage": 1.3, "heal": 0.6, "buff": 0.8, "debuff": 0.8},
	EnemyData.AiProfile.CASTER: {"damage": 1.1, "heal": 0.7, "buff": 1.0, "debuff": 1.2},
	EnemyData.AiProfile.HEALER: {"damage": 0.7, "heal": 1.6, "buff": 1.2, "debuff": 0.9},
	EnemyData.AiProfile.DISRUPTOR: {"damage": 0.9, "heal": 0.7, "buff": 1.0, "debuff": 1.5},
}


## Returns {"ability": AbilityData, "target": int} or {} if nothing is usable.
## temperature: 0 = always best choice, higher = noisier (easier difficulty).
static func choose(state: RefCounted, actor: CombatantState, rng: RngService, temperature: float = 0.5) -> Dictionary:
	var options: Array = []
	for ability in actor.abilities:
		if not actor.can_use(ability):
			continue
		for target_index in state.legal_targets(actor, ability):
			var score := _score(state, actor, ability, target_index)
			if score > 0.0:
				options.append({"ability": ability, "target": target_index, "weight": score})
	if options.is_empty():
		return {}
	options.sort_custom(func(a, b): return a["weight"] > b["weight"])
	if temperature <= 0.0:
		return options[0]
	# Weighted pick among the top 3 so harder difficulties play tighter.
	var top := options.slice(0, mini(3, options.size()))
	for opt in top:
		opt["weight"] = pow(opt["weight"], 1.0 / temperature)
	return rng.pick_weighted(top)


static func _score(state: RefCounted, actor: CombatantState, ability: AbilityData, target_index: int) -> float:
	var target: CombatantState = state.combatants[target_index]
	var mults: Dictionary = PROFILE_MULT.get(actor.ai_profile, PROFILE_MULT[EnemyData.AiProfile.BRUTE])
	var score: float = ability.ai_weight

	if ability.damage_type == AbilityData.DamageType.HEAL:
		var missing: float = 1.0 - target.hp / target.derived()["max_hp"]
		if missing < 0.15:
			return 0.01
		score *= mults["heal"] * (0.5 + missing * 2.0)
	elif ability.is_offensive():
		score *= mults["damage"]
		var expected := AbilityResolver.expected_damage(actor, ability)
		if expected >= target.hp:
			score *= 2.5  # kill shot
		if ability.target_type == AbilityData.TargetType.ALL_ENEMIES:
			var living := 0
			for c in state.combatants:
				if c.team != actor.team and c.is_alive():
					living += 1
			score *= 0.7 + 0.3 * living
	else:
		score *= mults["buff"]

	var status: StatusEffectData = ability.applies_status
	if status != null:
		# Wasteful to reapply a status that cannot stack further.
		var existing: Variant = target.get_status(status.id)
		if existing != null and (status.stacking != StatusEffectData.Stacking.STACK or existing["stacks"] >= status.max_stacks):
			score *= 0.25
		if status.has_flag("stun"):
			score *= mults["debuff"]
			# Prefer stunning the hardest hitter.
			var target_d := target.derived()
			score *= 1.0 + maxf(target_d["phys_power"], target_d["psy_power"]) / 60.0

	return maxf(score, 0.0)
