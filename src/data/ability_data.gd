class_name AbilityData
extends Resource
## Definition of an ability (player or enemy). Authored as .tres under
## res://data/abilities/. Resource cross-references use untyped fields where
## arrays are involved to keep hand-written .tres files simple.

enum TargetType { SELF, ALLY, ENEMY, ALL_ALLIES, ALL_ENEMIES }
enum DamageType { PHYSICAL, PSY, HEAL, NONE }
enum ScalingStat { NONE, STRENGTH, INSTINCT }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Ability tree this belongs to ("havoc", "surge", "bastion"); "" for innate/enemy abilities.
@export var tree_id: String = ""
@export var tier: int = 1
@export var icon_color: Color = Color.WHITE

@export var focus_cost: int = 0
@export var cooldown: int = 0
@export var target_type: TargetType = TargetType.ENEMY
@export var damage_type: DamageType = DamageType.PHYSICAL
## Base power before stat scaling. For HEAL this is base healing.
@export var power: float = 0.0
@export var scaling_stat: ScalingStat = ScalingStat.STRENGTH
@export var scaling_ratio: float = 1.0
@export var hit_count: int = 1

## Status applied to the target (StatusEffectData), with a chance per use.
@export var applies_status: StatusEffectData
@export var status_chance: float = 1.0
## Status applied to the caster on use (self-buffs attached to attacks).
@export var status_on_self: StatusEffectData

## Focus the caster gains on use (e.g. builder attacks).
@export var focus_gain: int = 0
## Focus change applied to the target (negative = drain).
@export var target_focus_change: int = 0
## Number of statuses removed: debuffs from allies, buffs from enemies.
@export var dispel_count: int = 0

## Base desirability for AI scoring.
@export var ai_weight: float = 1.0


func is_offensive() -> bool:
	return target_type == TargetType.ENEMY or target_type == TargetType.ALL_ENEMIES
