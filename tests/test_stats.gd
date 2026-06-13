extends "res://tests/test_base.gd"


func test_derive_basics() -> void:
	var d := StatBlock.derive({"strength": 10, "instinct": 5, "speed": 8, "vitality": 6}, 3)
	assert_almost_eq(d["max_hp"], 80.0 + 6 * 9.0 + 3 * 6.0)
	assert_almost_eq(d["phys_power"], 22.0)
	assert_almost_eq(d["psy_power"], 11.0)
	assert_almost_eq(d["focus_regen"], 10.0)
	assert_almost_eq(d["crit_chance"], 0.05 + 8 * 0.004)
	assert_almost_eq(d["dodge"], 8 * 0.003)


func test_derive_caps() -> void:
	var d := StatBlock.derive({"strength": 0, "instinct": 0, "speed": 1000, "vitality": 0}, 1)
	assert_almost_eq(d["crit_chance"], StatBlock.CRIT_CAP)
	assert_almost_eq(d["dodge"], StatBlock.DODGE_CAP)


func test_extra_flat_bonuses() -> void:
	var d := StatBlock.derive({"strength": 5, "instinct": 5, "speed": 5, "vitality": 5}, 1, {"max_hp": 30, "crit_chance": 0.1})
	assert_almost_eq(d["max_hp"], 80.0 + 45.0 + 6.0 + 30.0)
	assert_almost_eq(d["crit_chance"], 0.05 + 0.02 + 0.1)


func test_effective_primaries_combines_sources() -> void:
	var p := StatBlock.effective_primaries(
		{"strength": 5, "instinct": 5, "speed": 10, "vitality": 5},
		{"strength": 3},
		{"strength": 2},
		{"speed": -0.3})
	assert_almost_eq(p["strength"], 10.0)
	assert_almost_eq(p["speed"], 7.0)


func test_effective_primaries_never_negative() -> void:
	var p := StatBlock.effective_primaries({"speed": 10}, {}, {}, {"speed": -2.0})
	assert_almost_eq(p["speed"], 0.0)


func test_xp_curve_monotonic() -> void:
	var prev := 0
	for level in range(1, Leveling.LEVEL_CAP):
		var xp := Leveling.xp_to_next(level)
		assert_true(xp > prev, "xp_to_next must grow (level %d)" % level)
		prev = xp
	assert_eq(Leveling.xp_to_next(Leveling.LEVEL_CAP), 0)


func test_grant_xp_levels_up() -> void:
	var profile := {"level": 1, "xp": 0, "unspent_stat_points": 0, "unspent_skill_points": 0}
	var gained := Leveling.grant_xp(profile, Leveling.xp_to_next(1) + Leveling.xp_to_next(2))
	assert_eq(gained, 2)
	assert_eq(profile["level"], 3)
	assert_eq(profile["unspent_stat_points"], 4)
	assert_eq(profile["unspent_skill_points"], 2)


func test_grant_xp_respects_cap() -> void:
	var profile := {"level": Leveling.LEVEL_CAP, "xp": 0, "unspent_stat_points": 0, "unspent_skill_points": 0}
	Leveling.grant_xp(profile, 999999)
	assert_eq(profile["level"], Leveling.LEVEL_CAP)
	assert_eq(profile["xp"], 0)
