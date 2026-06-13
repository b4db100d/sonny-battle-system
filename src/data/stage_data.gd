class_name StageData
extends Resource
## One battle node on the zone map.

@export var id: String = ""
@export var zone_id: String = ""
@export var display_name: String = ""
@export var recommended_level: int = 1

## Waves of enemies: Array of Array of EnemyData (untyped for .tres authoring).
## Example: [[drone, drone], [hound]] = two waves.
@export var waves: Array = []

## Dialogue ids in data/dialogue/*.json; "" = none.
@export var pre_dialogue_id: String = ""
@export var post_dialogue_id: String = ""

@export var first_clear_xp_bonus: int = 0
@export var first_clear_item: ItemData
## Training stages are re-fightable grind nodes and never gate progression.
@export var is_training: bool = false
## Ally (see GameState.ALLY_DEFS) who joins after first clearing this stage.
@export var recruit_ally_id: String = ""
## Stage that must be cleared before this one unlocks; "" = always available.
@export var requires_stage_id: String = ""


func all_enemies() -> Array:
	var out: Array = []
	for wave in waves:
		out.append_array(wave)
	return out
