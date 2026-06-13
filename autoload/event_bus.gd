extends Node
## Global signal hub. Keep cross-scene communication here instead of node paths.

signal battle_started(stage_id: String)
signal battle_ended(victory: bool, stage_id: String)
signal stage_cleared(stage_id: String)
signal player_leveled_up(new_level: int)
signal save_completed(slot: int)
