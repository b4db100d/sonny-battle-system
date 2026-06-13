extends "res://tests/test_base.gd"

const Fixtures := preload("res://tests/combat_fixtures.gd")


func test_refresh_stacking_resets_duration() -> void:
	var unit := Fixtures.make_unit(0, 5, 5, 5, 5)
	var status := Fixtures.make_status("slow", true, 3)
	status.stacking = StatusEffectData.Stacking.REFRESH
	var events: Array = []
	StatusEngine.apply(unit, status, null, events)
	unit.get_status("slow")["turns_left"] = 1
	StatusEngine.apply(unit, status, null, events)
	assert_eq(unit.get_status("slow")["turns_left"], 3)
	assert_eq(unit.get_status("slow")["stacks"], 1)


func test_stack_increments_to_max() -> void:
	var unit := Fixtures.make_unit(0, 5, 5, 5, 5)
	var status := Fixtures.make_status("bleed", true, 3)
	status.stacking = StatusEffectData.Stacking.STACK
	status.max_stacks = 2
	var events: Array = []
	for i in 4:
		StatusEngine.apply(unit, status, null, events)
	assert_eq(unit.get_status("bleed")["stacks"], 2)


func test_dot_ticks_and_kills() -> void:
	var unit := Fixtures.make_unit(0, 5, 5, 5, 0)
	unit.hp = 5.0
	var dot := Fixtures.make_status("burn", true, 3)
	dot.tick_power = 10.0
	dot.tick_timing = StatusEffectData.TickTiming.TURN_START
	var events: Array = []
	StatusEngine.apply(unit, dot, null, events)
	StatusEngine.tick(unit, StatusEffectData.TickTiming.TURN_START, events)
	assert_false(unit.is_alive())
	assert_true(events.any(func(e): return e["type"] == "death"))


func test_dot_snapshot_scaling() -> void:
	var caster := Fixtures.make_unit(0, 10, 0, 0, 5)  # phys_power 22
	var unit := Fixtures.make_unit(1, 0, 0, 0, 20)
	var dot := Fixtures.make_status("bleed", true, 3)
	dot.tick_power = 3.0
	dot.tick_scaling_stat = AbilityData.ScalingStat.STRENGTH
	dot.tick_scaling_ratio = 0.5
	var events: Array = []
	StatusEngine.apply(unit, dot, caster, events)
	assert_almost_eq(unit.get_status("bleed")["tick_amount"], 3.0 + 11.0)


func test_expiry_at_turn_end() -> void:
	var unit := Fixtures.make_unit(0, 5, 5, 5, 5)
	var status := Fixtures.make_status("slow", true, 1)
	var events: Array = []
	StatusEngine.apply(unit, status, null, events)
	StatusEngine.expire_turn_end(unit, events)
	assert_false(unit.has_status("slow"))
	assert_true(events.any(func(e): return e["type"] == "status_expired"))


func test_shield_absorbs_damage() -> void:
	var unit := Fixtures.make_unit(0, 5, 5, 5, 5)
	var shield := Fixtures.make_status("barrier", false, 2)
	shield.shield_amount = 25.0
	shield.flags = ["shield"]
	var events: Array = []
	StatusEngine.apply(unit, shield, null, events)
	var start_hp := unit.hp
	var dealt := StatusEngine.deal_raw_damage(unit, 30.0)
	assert_almost_eq(dealt, 5.0)
	assert_almost_eq(unit.hp, start_hp - 5.0)
	assert_almost_eq(unit.total_shield(), 0.0)


func test_dispel_removes_only_matching() -> void:
	var unit := Fixtures.make_unit(0, 5, 5, 5, 5)
	var events: Array = []
	StatusEngine.apply(unit, Fixtures.make_status("debuff_a", true), null, events)
	StatusEngine.apply(unit, Fixtures.make_status("buff_a", false), null, events)
	StatusEngine.dispel(unit, true, 5, events)
	assert_false(unit.has_status("debuff_a"))
	assert_true(unit.has_status("buff_a"))


func test_undispellable_flag() -> void:
	var unit := Fixtures.make_unit(0, 5, 5, 5, 5)
	var status := Fixtures.make_status("core_wound", true)
	status.flags = ["undispellable"]
	var events: Array = []
	StatusEngine.apply(unit, status, null, events)
	StatusEngine.dispel(unit, true, 5, events)
	assert_true(unit.has_status("core_wound"))


func test_stat_mods_affect_derived() -> void:
	var unit := Fixtures.make_unit(0, 10, 5, 10, 5)
	var base_speed: float = unit.derived()["speed"]
	var slow := Fixtures.make_status("slow", true, 2)
	slow.stat_mods = {"speed": -0.5}
	var events: Array = []
	StatusEngine.apply(unit, slow, null, events)
	assert_almost_eq(unit.derived()["speed"], base_speed * 0.5)
