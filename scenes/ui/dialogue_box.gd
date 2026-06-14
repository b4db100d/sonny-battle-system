extends Control
## Tap-through story dialogue. Loads data/dialogue/<id>.json:
##   {"id": "...", "lines": [{"speaker": "...", "text": "..."}]}
## Payload: {dialogue_id, next_scene, next_payload}.

const Chrome := preload("res://src/ui/chrome.gd")

var _lines: Array = []
var _line_index := 0
var _next_scene := ""
var _next_payload := {}

var _speaker_label: Label
var _text_label: Label
var _progress_label: Label
var _speaker_plate: PanelContainer


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
	_progress_label.text = "%d / %d    TAP TO CONTINUE" % [_line_index + 1, _lines.size()]


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

	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var sky := Chrome.gradient_rect(
		[Color("04070b"), Color("09131a"), Color("0e1a22")],
		Vector2(0.5, 0.0),
		Vector2(0.5, 1.0),
		[0.0, 0.65, 1.0])
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(sky)

	var wash := Chrome.gradient_rect(
		[Color(0.0, 0.0, 0.0, 0.0), Color(0.31, 0.84, 1.0, 0.12), Color(0.0, 0.0, 0.0, 0.0)],
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		[0.0, 0.5, 1.0])
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(wash)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 54
	panel.offset_right = -54
	panel.offset_top = -292
	panel.offset_bottom = -38
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.04, 0.07, 0.1, 0.9), Color("4acaff"), 28, 2, 24, 0.38))
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	_speaker_plate = PanelContainer.new()
	_speaker_plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_speaker_plate.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.18, 0.67, 0.79, 0.18), Color("5fe4ff"), 18, 1, 12, 0.18))
	column.add_child(_speaker_plate)

	_speaker_label = Label.new()
	Chrome.apply_label(_speaker_label, 23, Color("eafcff"), 3)
	_speaker_plate.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 24)
	_text_label.add_theme_color_override("font_color", Color("edf4fb"))
	_text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	_text_label.add_theme_constant_override("outline_size", 2)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text_label)

	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Chrome.apply_label(_progress_label, 14, Color("7c93a7"), 1)
	column.add_child(_progress_label)

	var skip := Button.new()
	skip.text = "Skip"
	Chrome.apply_button(skip, Color("70869c"), 20, Vector2(126, 56), true)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -156
	skip.offset_top = 24
	skip.offset_right = -30
	skip.offset_bottom = 80
	skip.pressed.connect(_finish)
	add_child(skip)
