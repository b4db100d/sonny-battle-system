extends Node
## Scene changes with payloads. Godot's change_scene_to_file cannot pass
## arguments, so the payload is stashed here and read by the next scene.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const ZONE_MAP := "res://scenes/ui/zone_map.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const CHARACTER_SHEET := "res://scenes/ui/character_sheet.tscn"

var payload: Dictionary = {}


func goto(scene_path: String, p_payload: Dictionary = {}) -> void:
	payload = p_payload
	get_tree().call_deferred("change_scene_to_file", scene_path)


func take_payload() -> Dictionary:
	var p := payload
	payload = {}
	return p
