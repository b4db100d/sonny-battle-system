extends "res://tests/test_base.gd"

const Fixtures := preload("res://tests/combat_fixtures.gd")


func test_damage_within_variance_bounds() -> void:
	var rng := RngService.new(42)
	for i in 50:
		var attacker := Fixtures.make_unit(0, 10, 0, 0, 5)  # speed 0 => no crit var? crit base 5%
		var defender := Fixtures.make_unit(1, 0, 0, 0, 10)
		var atk := Fixtures.make_attack("atk", 10.0)
		var start_hp := defender.hp
		AbilityResolver.resolve(attacker, atk, [defender], rng)
		var dealt := start_hp - defender.hp
		# base = 10 + 22 = 32; variance ±10%, possible 1.6x crit (5% base)
		assert_true(dealt >= 32.0 * 0.9 - 0.01 and dealt <= 32.0 * 1.1 * 1.6 + 0.01,
			"damage %f out of bounds" % dealt)


func test_seeded_determinism() -> void:
	var results: Array = []
	for run in 2:
		var rng := RngService.new(1234)
		var attacker := Fixtures.make_unit(0, 10, 0, 10, 5)
		var defender := Fixtures.make_unit(1, 0, 0, 10, 10)
		var atk := Fixtures.make_attack()
		var events: Array = []
		for i in 5:
			events.append_array(AbilityResolver.resolve(attacker, atk, [defender], rng))
		results.append(var_to_str(events))
	assert_eq(results[0], results[1], "same seed must produce identical battles")


func test_heal_caps_at_max_hp() -> void:
	var rng := RngService.new(7)
	var healer := Fixtures.make_unit(0, 0, 10, 0, 5)
	var target := Fixtures.make_unit(0, 0, 0, 0, 5)
	target.hp -= 5.0
	AbilityResolver.resolve(healer, Fixtures.make_heal("h", 100.0), [target], rng)
	assert_almost_eq(target.hp, target.derived()["max_hp"])


func test_focus_cost_and_gain() -> void:
	var rng := RngService.new(7)
	var attacker := Fixtures.make_unit(0, 5, 0, 0, 5)
	var defender := Fixtures.make_unit(1, 0, 0, 0, 5)
	var atk := Fixtures.make_attack("atk", 5.0, 30)
	atk.focus_gain = 10
	attacker.focus = 50.0
	AbilityResolver.resolve(attacker, atk, [defender], rng)
	assert_almost_eq(attacker.focus, 30.0)  # -30 cost +10 gain


func test_cooldown_set_on_use() -> void:
	var rng := RngService.new(7)
	var attacker := Fixtures.make_unit(0, 5, 0, 0, 5)
	var defender := Fixtures.make_unit(1, 0, 0, 0, 5)
	var atk := Fixtures.make_attack()
	atk.cooldown = 2
	AbilityResolver.resolve(attacker, atk, [defender], rng)
	assert_eq(attacker.cooldowns["atk"], 3)  # cooldown + 1, pre-decrement
	assert_false(attacker.can_use(atk))


func test_dodge_negates_hit() -> void:
	var rng := RngService.new(11)
	var attacker := Fixtures.make_unit(0, 10, 0, 0, 5)
	var defender := Fixtures.make_unit(1, 0, 0, 0, 10)
	defender.extra_flat = {"dodge": 1.0}  # clamps to cap 0.35
	var dodges := 0
	var trials := 400
	for i in trials:
		defender.hp = defender.derived()["max_hp"]
		var events := AbilityResolver.resolve(attacker, Fixtures.make_attack(), [defender], rng)
		for e in events:
			if e["type"] == "dodge":
				dodges += 1
	var rate := float(dodges) / trials
	assert_true(rate > 0.25 and rate < 0.45, "dodge rate %f should be near cap 0.35" % rate)


func test_status_applied_with_ability() -> void:
	var rng := RngService.new(7)
	var attacker := Fixtures.make_unit(0, 5, 0, 0, 5)
	var defender := Fixtures.make_unit(1, 0, 0, 0, 5)
	var atk := Fixtures.make_attack()
	atk.applies_status = Fixtures.make_status("weaken")
	atk.status_chance = 1.0
	AbilityResolver.resolve(attacker, atk, [defender], rng)
	assert_true(defender.has_status("weaken"))


func test_multi_hit() -> void:
	var rng := RngService.new(7)
	var attacker := Fixtures.make_unit(0, 10, 0, 0, 5)
	var defender := Fixtures.make_unit(1, 0, 0, 0, 50)
	var atk := Fixtures.make_attack("flurry", 5.0)
	atk.hit_count = 3
	var events := AbilityResolver.resolve(attacker, atk, [defender], rng)
	var hits := events.filter(func(e): return e["type"] == "damage" or e["type"] == "dodge")
	assert_eq(hits.size(), 3)
