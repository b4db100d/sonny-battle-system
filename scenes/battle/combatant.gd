class_name CombatantView
extends Area2D
## Tappable battle unit. All children are built procedurally; the .tscn is
## just the root node + script.

signal tapped(index: int)

const BAR_WIDTH := 100.0

var state: CombatantState
var _body: Polygon2D
var _hp_fill: ColorRect
var _focus_fill: ColorRect
var _status_row: HBoxContainer
var _select_tween: Tween


func setup(p_state: CombatantState) -> void:
	state = p_state
	_build()
	refresh()


func _build() -> void:
	_body = Polygon2D.new()
	_body.polygon = _shape_points()
	_body.color = state.body_color
	add_child(_body)

	var outline := Line2D.new()
	var pts := _shape_points()
	pts.append(pts[0])
	outline.points = pts
	outline.width = 3.0
	outline.default_color = state.body_color.lightened(0.4)
	add_child(outline)

	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(150, 190)
	collision.shape = rect
	add_child(collision)

	var name_label := Label.new()
	name_label.text = state.display_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.position = Vector2(-BAR_WIDTH / 2, -118)
	name_label.custom_minimum_size = Vector2(BAR_WIDTH, 0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)

	_hp_fill = _add_bar(-92, Color("e53935"))
	_focus_fill = _add_bar(-80, Color("1e88e5"))

	_status_row = HBoxContainer.new()
	_status_row.position = Vector2(-BAR_WIDTH / 2, 96)
	_status_row.add_theme_constant_override("separation", 4)
	add_child(_status_row)

	input_event.connect(_on_input_event)


func _add_bar(y: float, color: Color) -> ColorRect:
	var back := ColorRect.new()
	back.position = Vector2(-BAR_WIDTH / 2, y)
	back.size = Vector2(BAR_WIDTH, 9)
	back.color = Color(0, 0, 0, 0.55)
	add_child(back)
	var fill := ColorRect.new()
	fill.position = Vector2(1, 1)
	fill.size = Vector2(BAR_WIDTH - 2, 7)
	fill.color = color
	back.add_child(fill)
	return fill


func _shape_points() -> PackedVector2Array:
	if state.team == CombatantState.TEAM_PLAYER:
		# Hexagon for player units.
		var hex := PackedVector2Array()
		for i in 6:
			var angle := TAU * i / 6 - PI / 2
			hex.append(Vector2(cos(angle), sin(angle)) * 72)
		return hex
	match state.body_shape:
		EnemyData.BodyShape.SPIKE:
			return PackedVector2Array([Vector2(0, -85), Vector2(60, 75), Vector2(-60, 75)])
		EnemyData.BodyShape.ORB:
			var pts := PackedVector2Array()
			for i in 12:
				var angle := TAU * i / 12
				pts.append(Vector2(cos(angle), sin(angle)) * 65)
			return pts
		EnemyData.BodyShape.WIDE:
			return PackedVector2Array([Vector2(-80, -45), Vector2(80, -45), Vector2(80, 60), Vector2(-80, 60)])
		EnemyData.BodyShape.TALL:
			return PackedVector2Array([Vector2(-38, -90), Vector2(38, -90), Vector2(38, 80), Vector2(-38, 80)])
		_:
			return PackedVector2Array([Vector2(-50, -65), Vector2(50, -65), Vector2(50, 70), Vector2(-50, 70)])


func refresh() -> void:
	var d := state.derived()
	_hp_fill.size.x = (BAR_WIDTH - 2) * clampf(state.hp / d["max_hp"], 0.0, 1.0)
	_focus_fill.size.x = (BAR_WIDTH - 2) * clampf(state.focus / d["max_focus"], 0.0, 1.0)

	for child in _status_row.get_children():
		child.queue_free()
	for s in state.statuses:
		var data: StatusEffectData = s["data"]
		var chip := ColorRect.new()
		chip.custom_minimum_size = Vector2(16, 16)
		chip.color = data.icon_color
		if s["stacks"] > 1:
			var count := Label.new()
			count.text = str(s["stacks"])
			count.add_theme_font_size_override("font_size", 12)
			count.position = Vector2(3, -2)
			chip.add_child(count)
		_status_row.add_child(chip)

	if not state.is_alive():
		modulate = Color(0.35, 0.35, 0.35, 0.45)
		set_selectable(false)


func set_selectable(on: bool) -> void:
	if _select_tween != null:
		_select_tween.kill()
		_select_tween = null
	if on:
		_select_tween = create_tween().set_loops()
		_select_tween.tween_property(self, "modulate", Color(1.5, 1.5, 0.9), 0.4)
		_select_tween.tween_property(self, "modulate", Color.WHITE, 0.4)
	elif state.is_alive():
		modulate = Color.WHITE


func set_active_turn(on: bool) -> void:
	scale = Vector2(1.12, 1.12) if on else Vector2.ONE


## --- Procedural animations (awaitable) ---

func play_lunge() -> void:
	var dir := -1.0 if state.team == CombatantState.TEAM_ENEMY else 1.0
	var tween := create_tween()
	tween.tween_property(_body, "position", Vector2(40 * dir, 0), 0.12).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_body, "position", Vector2.ZERO, 0.15)
	await tween.finished


func play_hit() -> void:
	var dir := 1.0 if state.team == CombatantState.TEAM_ENEMY else -1.0
	var tween := create_tween()
	tween.tween_property(_body, "modulate", Color(3, 3, 3), 0.06)
	tween.parallel().tween_property(_body, "position", Vector2(14 * dir, 0), 0.06)
	tween.tween_property(_body, "modulate", Color.WHITE, 0.12)
	tween.parallel().tween_property(_body, "position", Vector2.ZERO, 0.1)
	await tween.finished


func play_heal_flash() -> void:
	var tween := create_tween()
	tween.tween_property(_body, "modulate", Color(0.6, 2.0, 0.8), 0.15)
	tween.tween_property(_body, "modulate", Color.WHITE, 0.2)
	await tween.finished


func show_floating_text(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.position = Vector2(-40, -150)
	label.z_index = 10
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 55.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.tween_callback(label.queue_free)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		tapped.emit(state.index)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(state.index)
