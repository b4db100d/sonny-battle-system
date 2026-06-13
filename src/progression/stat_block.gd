class_name StatBlock
extends RefCounted
## Pure stat math: primaries -> derived combat stats. Used identically by the
## character sheet, the battle engine, and headless tests.

const PRIMARIES := ["strength", "instinct", "speed", "vitality"]

const CRIT_CAP := 0.5
const DODGE_CAP := 0.35
const CRIT_MULT := 1.6


## primaries: {"strength": x, "instinct": x, "speed": x, "vitality": x}
## (already including allocations, equipment flat primaries, and status
## multipliers — see effective_primaries()).
## extra_flat: flat derived bonuses from equipment, e.g. {"max_hp": 30}.
static func derive(primaries: Dictionary, level: int, extra_flat: Dictionary = {}) -> Dictionary:
	var strength: float = primaries.get("strength", 0)
	var instinct: float = primaries.get("instinct", 0)
	var speed: float = primaries.get("speed", 0)
	var vitality: float = primaries.get("vitality", 0)
	return {
		"max_hp": maxf(1.0, 80.0 + vitality * 9.0 + level * 6.0 + extra_flat.get("max_hp", 0)),
		"max_focus": 100.0,
		"focus_regen": 8.0 + instinct * 0.4 + extra_flat.get("focus_regen", 0),
		"phys_power": maxf(0.0, strength * 2.2),
		"psy_power": maxf(0.0, instinct * 2.2),
		"crit_chance": clampf(0.05 + speed * 0.004 + extra_flat.get("crit_chance", 0), 0.0, CRIT_CAP),
		"crit_mult": CRIT_MULT,
		"dodge": clampf(speed * 0.003 + extra_flat.get("dodge", 0), 0.0, DODGE_CAP),
		"speed": maxf(0.0, speed),
	}


## Combines base primaries + allocations + equipment flat primaries, then
## applies status multiplier deltas (additive per stack: stat * (1 + sum)).
static func effective_primaries(
	base: Dictionary,
	alloc: Dictionary,
	equip_flat: Dictionary,
	status_mult_deltas: Dictionary
) -> Dictionary:
	var out := {}
	for stat in PRIMARIES:
		var value: float = float(base.get(stat, 0)) + float(alloc.get(stat, 0)) + float(equip_flat.get(stat, 0))
		var delta: float = status_mult_deltas.get(stat, 0.0)
		out[stat] = maxf(0.0, value * (1.0 + delta))
	return out
