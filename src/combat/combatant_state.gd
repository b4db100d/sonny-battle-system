class_name CombatantState
extends RefCounted
## Runtime state of one unit in battle. Pure logic — no Nodes.

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1

var index: int = -1            # position in BattleState.combatants
var display_name: String = ""
var team: int = TEAM_PLAYER
var player_controlled: bool = false
var level: int = 1

## Effective primaries before status mods (base + alloc + equipment).
var primaries: Dictionary = {}
## Flat derived bonuses from equipment ({"max_hp": .., "crit_chance": ..}).
var extra_flat: Dictionary = {}

var hp: float = 1.0
var focus: float = 0.0
## Max-HP scale (enemies only; see EnemyData.hp_mult).
var hp_mult: float = 1.0
var abilities: Array = []        # Array of AbilityData
var cooldowns: Dictionary = {}   # ability_id -> turns remaining
## Active statuses: [{"data": StatusEffectData, "turns_left": int,
##   "stacks": int, "tick_amount": float, "shield_hp": float}]
var statuses: Array = []

var ai_profile: int = EnemyData.AiProfile.BRUTE
## Display hints for the battle scene.
var body_color: Color = Color.WHITE
var body_shape: int = EnemyData.BodyShape.BLOCK
## XP/loot payload (enemies only).
var xp_reward: int = 0
var credit_reward: int = 0
var loot_chance: float = 0.0
var loot_table: Array = []


func is_alive() -> bool:
	return hp > 0.0


## Derived stats including current status multipliers. Recomputed on demand
## so buffs/debuffs always apply immediately.
func derived() -> Dictionary:
	var deltas := {}
	for s in statuses:
		var data: StatusEffectData = s["data"]
		for stat in data.stat_mods:
			deltas[stat] = deltas.get(stat, 0.0) + float(data.stat_mods[stat]) * s["stacks"]
	var effective := StatBlock.effective_primaries(primaries, {}, {}, deltas)
	var d := StatBlock.derive(effective, level, extra_flat)
	d["max_hp"] = maxf(1.0, d["max_hp"] * hp_mult)
	return d


func has_status(status_id: String) -> bool:
	return get_status(status_id) != null


func get_status(status_id: String) -> Variant:
	for s in statuses:
		if (s["data"] as StatusEffectData).id == status_id:
			return s
	return null


func has_status_flag(flag: String) -> bool:
	for s in statuses:
		if (s["data"] as StatusEffectData).has_flag(flag):
			return true
	return false


func total_shield() -> float:
	var total := 0.0
	for s in statuses:
		total += s["shield_hp"]
	return total


func can_use(ability: AbilityData) -> bool:
	return cooldowns.get(ability.id, 0) <= 0 and focus >= ability.focus_cost


## Builds a player-side combatant from a profile dict (player or ally).
static func from_profile(profile: Dictionary, ability_list: Array, equip_items: Array) -> CombatantState:
	var c := CombatantState.new()
	c.display_name = profile.get("name", "Unit")
	c.team = TEAM_PLAYER
	c.player_controlled = true
	c.level = int(profile.get("level", 1))
	var equip_flat := {}
	var extra := {}
	for item in equip_items:
		for stat in (item as ItemData).stat_bonuses:
			var v: float = item.stat_bonuses[stat]
			if stat in StatBlock.PRIMARIES:
				equip_flat[stat] = equip_flat.get(stat, 0.0) + v
			else:
				extra[stat] = extra.get(stat, 0.0) + v
	c.primaries = StatBlock.effective_primaries(
		Leveling.base_primaries(), profile.get("stat_alloc", {}), equip_flat, {})
	c.extra_flat = extra
	c.abilities = ability_list
	c.body_color = profile.get("body_color", Color("3fd0c9"))
	var d := c.derived()
	c.hp = d["max_hp"]
	c.focus = 30.0
	return c


static func from_enemy(data: EnemyData, stat_mult: float = 1.0) -> CombatantState:
	var c := CombatantState.new()
	c.display_name = data.display_name
	c.team = TEAM_ENEMY
	c.player_controlled = false
	c.level = data.level
	c.primaries = {
		"strength": data.strength * stat_mult,
		"instinct": data.instinct * stat_mult,
		"speed": data.speed * stat_mult,
		"vitality": data.vitality * stat_mult,
	}
	c.hp_mult = data.hp_mult
	c.abilities = data.abilities
	c.ai_profile = data.ai_profile
	c.body_color = data.body_color
	c.body_shape = data.body_shape
	c.xp_reward = data.xp_reward
	c.credit_reward = data.credit_reward
	c.loot_chance = data.loot_chance
	c.loot_table = data.loot_table
	var d := c.derived()
	c.hp = d["max_hp"]
	c.focus = 40.0
	return c
