extends Node
## Holds the current run: player profile, allies, campaign progress, settings.
## Pure data + helpers; persistence lives in SaveManager.

const SAVE_VERSION := 1
const DIFFICULTY_EASY := 0
const DIFFICULTY_NORMAL := 1
const DIFFICULTY_HARD := 2

## Recruitable companions with fixed kits (referenced by StageData.recruit_ally_id).
const ALLY_DEFS := {
	"vela": {
		"name": "Vela",
		"abilities": ["strike", "static_bolt", "corrode"],
		"color": "c77dff",
	},
	"brick": {
		"name": "Brick",
		"abilities": ["strike", "provoke", "mend"],
		"color": "f4a261",
	},
}

var slot: int = 1
var difficulty: int = DIFFICULTY_NORMAL
var player: Dictionary = {}
var allies: Array = []  # array of ally profile dicts, in recruit order
var cleared_stage_ids: Array = []
var credits: int = 0


func new_game(p_difficulty: int = DIFFICULTY_NORMAL) -> void:
	difficulty = p_difficulty
	player = _new_player_profile()
	allies = []
	cleared_stage_ids = []
	credits = 0


func _new_player_profile() -> Dictionary:
	return {
		"name": "Unit S-7",
		"level": 1,
		"xp": 0,
		"stat_alloc": {"strength": 0, "instinct": 0, "speed": 0, "vitality": 0},
		"unspent_stat_points": 0,
		"unspent_skill_points": 0,
		"learned_ability_ids": [],
		"equipped_ability_ids": ["strike"],
		"equipped": {},   # slot name -> item id
		"inventory": [],  # item ids
	}


func is_stage_cleared(stage_id: String) -> bool:
	return stage_id in cleared_stage_ids


func mark_stage_cleared(stage_id: String) -> void:
	if not is_stage_cleared(stage_id):
		cleared_stage_ids.append(stage_id)
		EventBus.stage_cleared.emit(stage_id)


## Builds battle-ready CombatantStates for the player + recruited allies.
func build_party() -> Array:
	var party: Array = [_build_unit(player)]
	for ally in allies:
		party.append(_build_unit(ally))
	return party


func _build_unit(profile: Dictionary) -> CombatantState:
	var ability_list: Array = []
	for ability_id in profile.get("equipped_ability_ids", []):
		var ability: Resource = Db.ability(ability_id)
		if ability != null:
			ability_list.append(ability)
	var equip_items: Array = []
	for slot in profile.get("equipped", {}):
		var item: Resource = Db.item(profile["equipped"][slot])
		if item != null:
			equip_items.append(item)
	var unit := CombatantState.from_profile(profile, ability_list, equip_items)
	if profile.has("body_color_html"):
		unit.body_color = Color.from_string(profile["body_color_html"], Color("3fd0c9"))
	return unit


func add_ally(name: String, ability_ids: Array, body_color_html: String) -> void:
	var profile := _new_player_profile()
	profile["name"] = name
	profile["level"] = player["level"]
	profile["equipped_ability_ids"] = ability_ids.duplicate()
	profile["learned_ability_ids"] = ability_ids.duplicate()
	profile["body_color_html"] = body_color_html
	allies.append(profile)


## Applies battle rewards to the whole party; returns a summary for the UI.
func apply_victory_rewards(defeated: Array, stage: StageData, rng: RngService) -> Dictionary:
	var xp := Loot.total_xp(defeated)
	var earned_credits := Loot.total_credits(defeated)
	var drops := Loot.roll_drops(defeated, rng)
	var first_clear := stage != null and not is_stage_cleared(stage.id)
	if first_clear:
		xp += stage.first_clear_xp_bonus
		if stage.first_clear_item != null:
			drops.append(stage.first_clear_item.id)
	var levels := Leveling.grant_xp(player, xp)
	for ally in allies:
		Leveling.grant_xp(ally, xp)
	credits += earned_credits
	for item_id in drops:
		player["inventory"].append(item_id)
	var recruited := ""
	if first_clear and stage.recruit_ally_id != "" and ALLY_DEFS.has(stage.recruit_ally_id):
		var def: Dictionary = ALLY_DEFS[stage.recruit_ally_id]
		add_ally(def["name"], def["abilities"], def["color"])
		recruited = def["name"]
	if stage != null:
		mark_stage_cleared(stage.id)
	if levels > 0:
		EventBus.player_leveled_up.emit(player["level"])
	return {"xp": xp, "credits": earned_credits, "drops": drops, "levels_gained": levels, "first_clear": first_clear, "recruited": recruited}


func enemy_stat_mult() -> float:
	return [0.85, 1.0, 1.25][difficulty]


func ai_temperature() -> float:
	return [1.0, 0.5, 0.15][difficulty]


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"difficulty": difficulty,
		"player": player.duplicate(true),
		"allies": allies.duplicate(true),
		"cleared_stage_ids": cleared_stage_ids.duplicate(),
		"credits": credits,
	}


func from_dict(data: Dictionary) -> void:
	data = _normalize_json(data)
	difficulty = int(data.get("difficulty", DIFFICULTY_NORMAL))
	player = data.get("player", _new_player_profile())
	allies = data.get("allies", [])
	cleared_stage_ids = data.get("cleared_stage_ids", [])
	credits = int(data.get("credits", 0))


## JSON parses every number as float; saves only ever contain integers, so
## whole-number floats are coerced back to int recursively.
static func _normalize_json(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return int(value) if value == floorf(value) else value
		TYPE_DICTIONARY:
			var dict := {}
			for key in value:
				dict[key] = _normalize_json(value[key])
			return dict
		TYPE_ARRAY:
			return value.map(_normalize_json)
		_:
			return value
