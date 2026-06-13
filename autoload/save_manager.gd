extends Node
## JSON save slots under user://saves/. Stores ids only; Db rehydrates content.

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 3


func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func save_game(slot: int = GameState.slot) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open %s for writing" % _slot_path(slot))
		return false
	file.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	file.close()
	EventBus.save_completed.emit(slot)
	return true


func load_game(slot: int = GameState.slot) -> bool:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: corrupt save in slot %d" % slot)
		return false
	GameState.slot = slot
	GameState.from_dict(parsed)
	return true


func delete_save(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_slot_path(slot))


func slot_summary(slot: int) -> Dictionary:
	## Lightweight peek for the save-slot picker; {} if empty/corrupt.
	if not has_save(slot):
		return {}
	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var player: Dictionary = parsed.get("player", {})
	return {
		"level": int(player.get("level", 1)),
		"cleared": (parsed.get("cleared_stage_ids", []) as Array).size(),
		"difficulty": int(parsed.get("difficulty", 1)),
	}
