extends Node
## Audio stub: safe no-ops until real sounds are added. Centralizing calls now
## means gameplay code never needs to change when audio lands.

var sfx_enabled := true
var music_enabled := true


func play_sfx(_name: String) -> void:
	pass


func play_music(_name: String) -> void:
	pass


func stop_music() -> void:
	pass
