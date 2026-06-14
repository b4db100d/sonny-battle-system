class_name CombatantView
extends Area2D
## Tappable battle unit. All children are built procedurally; the .tscn is
## just the root node + script.

const Chrome := preload("res://src/ui/chrome.gd")

signal tapped(index: int)

const BAR_WIDTH := 118.0
const HITBOX_SIZE := Vector2(182, 224)

var state: CombatantState
var _idle_root: Node2D
var _figure: Node2D
var _shell: Polygon2D
var _inner_shell: Polygon2D
var _core: Polygon2D
var _hp_fill: ColorRect
var _focus_fill: ColorRect
var _status_row: HBoxContainer
var _select_tween: Tween
var _idle_time := 0.0


func setup(p_state: CombatantState) -> void:
	state = p_state
	input_pickable = true
	_build()
	refresh()
	set_process(true)


func _process(delta: float) -> void:
	if not state.is_alive():
		return
	_idle_time += delta
	_idle_root.position.y = sin(_idle_time * 1.6 + float(state.index) * 0.65) * 5.0


func _build() -> void:
	var body_points := _shape_points()

	var shadow := Polygon2D.new()
	shadow.polygon = _ellipse_points(82, 20, 18)
	shadow.position = Vector2(0, 82)
	shadow.color = Color(0, 0, 0, 0.34)
	add_child(shadow)

	var base_ring := Line2D.new()
	base_ring.points = _closed_points(_ellipse_points(76, 16, 24))
	base_ring.position = Vector2(0, 78)
	base_ring.width = 3.0
	base_ring.default_color = state.body_color.lightened(0.16)
	base_ring.modulate.a = 0.42
	add_child(base_ring)

	_idle_root = Node2D.new()
	add_child(_idle_root)

	var aura := Polygon2D.new()
	aura.polygon = _ellipse_points(94, 108, 24)
	aura.position = Vector2(0, -4)
	aura.color = Color(state.body_color.r, state.body_color.g, state.body_color.b, 0.12)
	_idle_root.add_child(aura)

	_figure = Node2D.new()
	_idle_root.add_child(_figure)

	var back_shell := Polygon2D.new()
	back_shell.polygon = _scaled_points(body_points, 1.08)
	back_shell.color = state.body_color.darkened(0.72)
	back_shell.position = Vector2(0, 8)
	_figure.add_child(back_shell)

	_shell = Polygon2D.new()
	_shell.polygon = body_points
	_shell.color = state.body_color.darkened(0.12)
	_figure.add_child(_shell)

	_inner_shell = Polygon2D.new()
	_inner_shell.polygon = _scaled_points(body_points, 0.78, Vector2(0, -8))
	_inner_shell.color = state.body_color.lightened(0.28)
	_figure.add_child(_inner_shell)

	var outline := Line2D.new()
	outline.points = _closed_points(body_points)
	outline.width = 4.0
	outline.default_color = state.body_color.lightened(0.5)
	_figure.add_child(outline)

	var inset := Line2D.new()
	inset.points = _closed_points(_scaled_points(body_points, 0.82, Vector2(0, -6)))
	inset.width = 2.0
	inset.default_color = Color(1, 1, 1, 0.24)
	_figure.add_child(inset)

	_core = Polygon2D.new()
	_core.polygon = PackedVector2Array([
		Vector2(0, -30), Vector2(26, 0), Vector2(0, 34), Vector2(-26, 0),
	])
	_core.color = Color("eafcff")
	_figure.add_child(_core)

	var core_ring := Line2D.new()
	core_ring.points = _closed_points(_ellipse_points(24, 24, 18))
	core_ring.width = 2.0
	core_ring.default_color = state.body_color.lightened(0.35)
	core_ring.position = Vector2.ZERO
	_figure.add_child(core_ring)

	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = HITBOX_SIZE
	collision.shape = rect
	add_child(collision)

	var name_plate := PanelContainer.new()
	name_plate.position = Vector2(-76, -136)
	name_plate.size = Vector2(152, 34)
	name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_plate.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.05, 0.09, 0.12, 0.9), state.body_color.lightened(0.18), 14, 1, 8, 0.18))
	add_child(name_plate)

	var name_label := Label.new()
	name_label.text = state.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Chrome.apply_label(name_label, 15, Color("eef8ff"), 2)
	name_plate.add_child(name_label)

	_hp_fill = _add_bar(-96, Color("da5f63"))
	_focus_fill = _add_bar(-80, Color("53a9ff"))

	_status_row = HBoxContainer.new()
	_status_row.position = Vector2(-BAR_WIDTH / 2, 102)
	_status_row.add_theme_constant_override("separation", 4)
	add_child(_status_row)

	input_event.connect(_on_input_event)


func _add_bar(y: float, color: Color) -> ColorRect:
	var back := Panel.new()
	back.position = Vector2(-BAR_WIDTH / 2, y)
	back.size = Vector2(BAR_WIDTH, 12)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel",
		Chrome.panel_style(Color(0.01, 0.02, 0.04, 0.82), color.darkened(0.42), 7, 1, 0, 0.0))
	add_child(back)

	var fill := ColorRect.new()
	fill.position = Vector2(2, 2)
	fill.size = Vector2(BAR_WIDTH - 4, 8)
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)

	var shine := ColorRect.new()
	shine.position = Vector2(0, 0)
	shine.size = Vector2(BAR_WIDTH - 4, 2)
	shine.color = Color(1, 1, 1, 0.16)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_child(shine)
	return fill


func _shape_points() -> PackedVector2Array:
	if state.team == CombatantState.TEAM_PLAYER:
		return PackedVector2Array([
			Vector2(0, -90), Vector2(48, -62), Vector2(62, -10), Vector2(74, 58),
			Vector2(22, 92), Vector2(-22, 92), Vector2(-74, 58), Vector2(-62, -10),
			Vector2(-48, -62),
		])
	match state.body_shape:
		EnemyData.BodyShape.SPIKE:
			return PackedVector2Array([
				Vector2(0, -96), Vector2(56, -34), Vector2(70, 70), Vector2(0, 92),
				Vector2(-70, 70), Vector2(-56, -34),
			])
		EnemyData.BodyShape.ORB:
			return _ellipse_points(66, 72, 16)
		EnemyData.BodyShape.WIDE:
			return PackedVector2Array([
				Vector2(-94, -46), Vector2(94, -46), Vector2(78, 64), Vector2(0, 90), Vector2(-78, 64),
			])
		EnemyData.BodyShape.TALL:
			return PackedVector2Array([
				Vector2(-42, -100), Vector2(42, -100), Vector2(58, -18), Vector2(50, 88), Vector2(-50, 88), Vector2(-58, -18),
			])
		_:
			return PackedVector2Array([
				Vector2(-58, -78), Vector2(58, -78), Vector2(70, 10), Vector2(52, 82), Vector2(-52, 82), Vector2(-70, 10),
			])


func refresh() -> void:
	var d := state.derived()
	_hp_fill.size.x = (BAR_WIDTH - 4) * clampf(state.hp / d["max_hp"], 0.0, 1.0)
	_focus_fill.size.x = (BAR_WIDTH - 4) * clampf(state.focus / d["max_focus"], 0.0, 1.0)

	for child in _status_row.get_children():
		child.queue_free()
	for s in state.statuses:
		var data: StatusEffectData = s["data"]
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(26, 18)
		chip.add_theme_stylebox_override("panel",
			Chrome.panel_style(data.icon_color.darkened(0.28), data.icon_color.lightened(0.2), 8, 1, 4, 0.0))

		var label := Label.new()
		label.text = data.display_name.substr(0, 1)
		Chrome.apply_label(label, 10, Color("eef8ff"), 1)
		chip.add_child(label)

		if s["stacks"] > 1:
			var count := Label.new()
			count.text = str(s["stacks"])
			count.position = Vector2(14, -2)
			Chrome.apply_label(count, 10, Color("fff7db"), 1)
			chip.add_child(count)
		_status_row.add_child(chip)

	if not state.is_alive():
		modulate = Color(0.36, 0.4, 0.45, 0.42)
		set_selectable(false)
	elif _select_tween == null:
		modulate = Color.WHITE


func set_selectable(on: bool) -> void:
	if _select_tween != null:
		_select_tween.kill()
		_select_tween = null
	if on:
		_select_tween = create_tween().set_loops()
		_select_tween.tween_property(self, "modulate", Color(1.22, 1.16, 0.94), 0.42)
		_select_tween.tween_property(self, "modulate", Color.WHITE, 0.42)
	elif state.is_alive():
		modulate = Color.WHITE


func set_active_turn(on: bool) -> void:
	_idle_root.scale = Vector2(1.08, 1.08) if on else Vector2.ONE


## --- Procedural animations (awaitable) ---

func play_lunge() -> void:
	var dir := -1.0 if state.team == CombatantState.TEAM_ENEMY else 1.0
	var tween := create_tween()
	tween.tween_property(_figure, "position", Vector2(42 * dir, -4), 0.12).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_figure, "position", Vector2.ZERO, 0.16)
	await tween.finished


func play_hit() -> void:
	var dir := 1.0 if state.team == CombatantState.TEAM_ENEMY else -1.0
	var tween := create_tween()
	tween.tween_property(_shell, "modulate", Color(2.1, 2.1, 2.1), 0.06)
	tween.parallel().tween_property(_inner_shell, "modulate", Color(2.2, 2.2, 2.2), 0.06)
	tween.parallel().tween_property(_figure, "position", Vector2(16 * dir, 0), 0.06)
	tween.tween_property(_shell, "modulate", Color.WHITE, 0.12)
	tween.parallel().tween_property(_inner_shell, "modulate", Color.WHITE, 0.12)
	tween.parallel().tween_property(_figure, "position", Vector2.ZERO, 0.1)
	await tween.finished


func play_heal_flash() -> void:
	var tween := create_tween()
	tween.tween_property(_core, "modulate", Color(0.6, 2.1, 1.1), 0.14)
	tween.parallel().tween_property(_inner_shell, "modulate", Color(0.8, 1.4, 1.0), 0.14)
	tween.tween_property(_core, "modulate", Color.WHITE, 0.2)
	tween.parallel().tween_property(_inner_shell, "modulate", Color.WHITE, 0.2)
	await tween.finished


func show_floating_text(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(-56, -166)
	label.custom_minimum_size = Vector2(112, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 10
	Chrome.apply_label(label, 30, color, 6)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 58.0, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.18)
	tween.tween_callback(label.queue_free)


func hit_test(global_point: Vector2) -> bool:
	var local_point := to_local(global_point)
	return Rect2(-HITBOX_SIZE * 0.5, HITBOX_SIZE).has_point(local_point)


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out


func _ellipse_points(rx: float, ry: float, count: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in count:
		var angle := TAU * i / count - PI / 2.0
		pts.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return pts


func _scaled_points(points: PackedVector2Array, factor: float, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	for point in points:
		scaled.append(point * factor + offset)
	return scaled


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		tapped.emit(state.index)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(state.index)
