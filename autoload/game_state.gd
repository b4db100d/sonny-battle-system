extends Node
## Holds the current run: player profile, allies, campaign progress, settings.
## Pure data + helpers; persistence lives in SaveManager.

const SAVE_VERSION := 1
const DIFFICULTY_EASY := 0
const DIFFICULTY_NORMAL := 1
const DIFFICULTY_HARD := 2

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
	difficulty = int(data.get("difficulty", DIFFICULTY_NORMAL))
	player = data.get("player", _new_player_profile())
	allies = data.get("allies", [])
	cleared_stage_ids = data.get("cleared_stage_ids", [])
	credits = int(data.get("credits", 0))
