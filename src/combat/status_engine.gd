class_name StatusEngine
extends RefCounted
## Applies, ticks, and expires statuses. All functions append event
## dictionaries to the given events array.


## Applies `data` to `target`, snapshotting caster power for DoT scaling.
static func apply(target: CombatantState, data: StatusEffectData, caster: CombatantState, events: Array) -> void:
	var tick_amount := data.tick_power
	if data.tick_scaling_stat != AbilityData.ScalingStat.NONE and caster != null:
		var d := caster.derived()
		var power: float = d["phys_power"] if data.tick_scaling_stat == AbilityData.ScalingStat.STRENGTH else d["psy_power"]
		tick_amount += power * data.tick_scaling_ratio

	var existing: Variant = target.get_status(data.id)
	if existing != null:
		match data.stacking:
			StatusEffectData.Stacking.IGNORE:
				return
			StatusEffectData.Stacking.REFRESH:
				existing["turns_left"] = data.duration_turns
				existing["tick_amount"] = tick_amount
				existing["shield_hp"] = data.shield_amount
			StatusEffectData.Stacking.STACK:
				existing["stacks"] = mini(existing["stacks"] + 1, data.max_stacks)
				existing["turns_left"] = data.duration_turns
				existing["tick_amount"] = tick_amount
		events.append({"type": "status_applied", "target": target.index, "status_id": data.id, "stacks": existing["stacks"]})
		return

	target.statuses.append({
		"data": data,
		"turns_left": data.duration_turns,
		"stacks": 1,
		"tick_amount": tick_amount,
		"shield_hp": data.shield_amount,
	})
	events.append({"type": "status_applied", "target": target.index, "status_id": data.id, "stacks": 1})


## Ticks DoT/HoT effects with the given timing, then handles expiry when
## timing == TURN_END (durations are measured in the holder's own turns).
static func tick(target: CombatantState, timing: int, events: Array) -> void:
	for s in target.statuses:
		var data: StatusEffectData = s["data"]
		if data.tick_timing != timing or s["tick_amount"] == 0.0 or not target.is_alive():
			continue
		var amount: float = s["tick_amount"] * s["stacks"]
		if amount > 0.0:
			var dealt := deal_raw_damage(target, amount)
			events.append({"type": "status_tick", "target": target.index, "status_id": data.id, "amount": dealt})
			if not target.is_alive():
				events.append({"type": "death", "target": target.index})
		else:
			var healed: float = minf(-amount, target.derived()["max_hp"] - target.hp)
			target.hp += healed
			events.append({"type": "status_tick", "target": target.index, "status_id": data.id, "amount": -healed})


## Decrements durations at the holder's turn end; removes expired statuses.
static func expire_turn_end(target: CombatantState, events: Array) -> void:
	var kept: Array = []
	for s in target.statuses:
		s["turns_left"] -= 1
		if s["turns_left"] > 0:
			kept.append(s)
		else:
			events.append({"type": "status_expired", "target": target.index, "status_id": (s["data"] as StatusEffectData).id})
	target.statuses = kept


## Damage that respects shields. Returns HP actually lost.
static func deal_raw_damage(target: CombatantState, amount: float) -> float:
	var remaining := amount
	for s in target.statuses:
		if s["shield_hp"] > 0.0 and remaining > 0.0:
			var absorbed: float = minf(s["shield_hp"], remaining)
			s["shield_hp"] -= absorbed
			remaining -= absorbed
	var lost: float = minf(target.hp, remaining)
	target.hp -= lost
	return lost


## Removes up to `count` statuses matching is_debuff; returns removed ids.
static func dispel(target: CombatantState, remove_debuffs: bool, count: int, events: Array) -> void:
	var removed := 0
	var kept: Array = []
	for s in target.statuses:
		var data: StatusEffectData = s["data"]
		if removed < count and data.is_debuff == remove_debuffs and not data.has_flag("undispellable"):
			removed += 1
			events.append({"type": "status_expired", "target": target.index, "status_id": data.id})
		else:
			kept.append(s)
	target.statuses = kept
