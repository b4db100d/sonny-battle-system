class_name StatusEffectData
extends Resource
## Definition of a buff/debuff. Runtime instances are dictionaries created by
## StatusEngine; this resource is the immutable template.

enum Stacking { REFRESH, STACK, IGNORE }
enum TickTiming { TURN_START, TURN_END }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon_color: Color = Color.WHITE
@export var is_debuff: bool = true

@export var duration_turns: int = 2
@export var stacking: Stacking = Stacking.REFRESH
@export var max_stacks: int = 1

## Damage-over-time (positive) or heal-over-time (negative) per tick, per stack.
@export var tick_timing: TickTiming = TickTiming.TURN_START
@export var tick_power: float = 0.0
## Extra tick amount from the caster's scaling power, snapshotted on application.
@export var tick_scaling_stat: AbilityData.ScalingStat = AbilityData.ScalingStat.NONE
@export var tick_scaling_ratio: float = 0.0

## Multiplier deltas on primary stats while active, e.g. {"speed": -0.3}.
## Applied per stack, additively: speed * (1.0 + delta * stacks).
@export var stat_mods: Dictionary = {}

## Behavior flags: "stun", "taunt", "shield", "undispellable".
@export var flags: Array[String] = []
## Flat damage absorbed while the status lasts (per application, not per stack).
@export var shield_amount: float = 0.0


func has_flag(flag: String) -> bool:
	return flag in flags
