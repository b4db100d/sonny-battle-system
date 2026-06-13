class_name AbilityResolver
extends RefCounted
## Executes one ability use and returns the resulting event list.
## Pure function of (caster, ability, targets, rng) — no Nodes, no globals.

const VARIANCE := 0.10


static func resolve(caster: CombatantState, ability: AbilityData, targets: Array, rng: RngService) -> Array:
	var events: Array = []
	events.append({
		"type": "ability_used",
		"actor": caster.index,
		"ability_id": ability.id,
		"targets": targets.map(func(t): return t.index),
	})

	caster.focus = maxf(0.0, caster.focus - ability.focus_cost)
	if ability.cooldown > 0:
		# +1 because the caster's own turn-start decrement happens next round.
		caster.cooldowns[ability.id] = ability.cooldown + 1
	if ability.focus_gain != 0:
		caster.focus = clampf(caster.focus + ability.focus_gain, 0.0, caster.derived()["max_focus"])
		events.append({"type": "focus_change", "target": caster.index, "amount": ability.focus_gain})

	for target in targets:
		_resolve_on_target(caster, ability, target, rng, events)

	if ability.status_on_self != null and caster.is_alive():
		StatusEngine.apply(caster, ability.status_on_self, caster, events)

	return events


static func _resolve_on_target(caster: CombatantState, ability: AbilityData, target: CombatantState, rng: RngService, events: Array) -> void:
	var caster_d := caster.derived()

	if ability.damage_type == AbilityData.DamageType.PHYSICAL or ability.damage_type == AbilityData.DamageType.PSY:
		var scaling_power := _scaling_power(caster_d, ability)
		for hit in ability.hit_count:
			if not target.is_alive():
				break
			if rng.chance(target.derived()["dodge"]):
				events.append({"type": "dodge", "target": target.index})
				continue
			var amount: float = (ability.power + scaling_power * ability.scaling_ratio)
			amount *= 1.0 + rng.randf_range(-VARIANCE, VARIANCE)
			var crit: bool = rng.chance(caster_d["crit_chance"])
			if crit:
				amount *= caster_d["crit_mult"]
			var dealt := StatusEngine.deal_raw_damage(target, amount)
			var absorbed: float = amount - dealt
			if absorbed > 0.5:
				events.append({"type": "shield_absorb", "target": target.index, "amount": absorbed})
			events.append({"type": "damage", "target": target.index, "amount": dealt, "crit": crit})
			if not target.is_alive():
				events.append({"type": "death", "target": target.index})
	elif ability.damage_type == AbilityData.DamageType.HEAL:
		if target.is_alive():
			var scaling_power := _scaling_power(caster_d, ability)
			var amount: float = (ability.power + scaling_power * ability.scaling_ratio)
			amount *= 1.0 + rng.randf_range(-VARIANCE, VARIANCE)
			var healed: float = minf(amount, target.derived()["max_hp"] - target.hp)
			target.hp += healed
			events.append({"type": "heal", "target": target.index, "amount": healed})

	if not target.is_alive():
		return

	if ability.target_focus_change != 0:
		target.focus = clampf(target.focus + ability.target_focus_change, 0.0, target.derived()["max_focus"])
		events.append({"type": "focus_change", "target": target.index, "amount": ability.target_focus_change})

	if ability.dispel_count > 0:
		# Cleanse debuffs from allies, strip buffs from enemies.
		var remove_debuffs: bool = target.team == caster.team
		StatusEngine.dispel(target, remove_debuffs, ability.dispel_count, events)

	if ability.applies_status != null and rng.chance(ability.status_chance):
		StatusEngine.apply(target, ability.applies_status, caster, events)


static func _scaling_power(caster_derived: Dictionary, ability: AbilityData) -> float:
	match ability.scaling_stat:
		AbilityData.ScalingStat.STRENGTH:
			return caster_derived["phys_power"]
		AbilityData.ScalingStat.INSTINCT:
			return caster_derived["psy_power"]
		_:
			return 0.0


## Expected damage (no variance/crit/dodge) — used by AI kill-shot heuristics.
static func expected_damage(caster: CombatantState, ability: AbilityData) -> float:
	if ability.damage_type != AbilityData.DamageType.PHYSICAL and ability.damage_type != AbilityData.DamageType.PSY:
		return 0.0
	return (ability.power + _scaling_power(caster.derived(), ability) * ability.scaling_ratio) * ability.hit_count
