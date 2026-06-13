extends Control
## Tap-through story dialogue. Loads data/dialogue/<id>.json:
##   {"id": "...", "lines": [{"speaker": "...", "text": "..."}]}
## Payload: {dialogue_id, next_scene, next_payload}.

var _lines: Array = []
var _line_index := 0
var _next_scene := ""
var _next_payload := {}

var _speaker_label: Label
var _text_label: Label
var _progress_label: Label


func _ready() -> void:
	var payload := SceneRouter.take_payload()
	_next_scene = payload.get("next_scene", SceneRouter.MAIN_MENU)
	_next_payload = payload.get("next_payload", {})
	_lines = load_dialogue(payload.get("dialogue_id", ""))
	_build_ui()
	if _lines.is_empty():
		_finish()
	else:
		_show_line()


static func load_dialogue(dialogue_id: String) -> Array:
	if dialogue_id == "":
		return []
	var path := "res://data/dialogue/%s.json" % dialogue_id
	if not FileAccess.file_exists(path):
		push_error("DialogueBox: missing dialogue %s" % path)
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DialogueBox: malformed dialogue %s" % path)
		return []
	return parsed.get("lines", [])


func _show_line() -> void:
	var line: Dictionary = _lines[_line_index]
	_speaker_label.text = line.get("speaker", "")
	_text_label.text = line.get("text", "")
	_progress_label.text = "%d / %d  —  tap to continue" % [_line_index + 1, _lines.size()]


func _advance() -> void:
	_line_index += 1
	if _line_index >= _lines.size():
		_finish()
	else:
		_show_line()


func _finish() -> void:
	SceneRouter.goto(_next_scene, _next_payload)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or \
			(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		_advance()


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color("0b1218")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = -260
	panel.offset_bottom = -40
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 24)
	_speaker_label.add_theme_color_override("font_color", Color("3fd0c9"))
	column.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 21)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text_label)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 15)
	_progress_label.add_theme_color_override("font_color", Color("7a8c99"))
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_progress_label)

	var skip := Button.new()
	skip.text = "Skip"
	skip.custom_minimum_size = Vector2(120, 56)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -150
	skip.offset_top = 20
	skip.offset_right = -30
	skip.offset_bottom = 76
	skip.pressed.connect(_finish)
	add_child(skip)
