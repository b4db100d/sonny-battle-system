extends RefCounted
## Shared helpers for combat tests: build units and abilities in code so unit
## tests don't depend on content files.


static func make_unit(team: int, strength: int, instinct: int, speed: int, vitality: int, abilities: Array = [], player_controlled: bool = false) -> CombatantState:
	var c := CombatantState.new()
	c.display_name = "Test-%d" % team
	c.team = team
	c.player_controlled = player_controlled
	c.level = 1
	c.primaries = {"strength": strength, "instinct": instinct, "speed": speed, "vitality": vitality}
	c.abilities = abilities
	c.hp = c.derived()["max_hp"]
	c.focus = 50.0
	return c


static func make_attack(p_id: String = "atk", power: float = 10.0, focus_cost: int = 0) -> AbilityData:
	var a := AbilityData.new()
	a.id = p_id
	a.display_name = p_id
	a.target_type = AbilityData.TargetType.ENEMY
	a.damage_type = AbilityData.DamageType.PHYSICAL
	a.power = power
	a.scaling_stat = AbilityData.ScalingStat.STRENGTH
	a.scaling_ratio = 1.0
	a.focus_cost = focus_cost
	return a


static func make_heal(p_id: String = "heal", power: float = 20.0) -> AbilityData:
	var a := AbilityData.new()
	a.id = p_id
	a.display_name = p_id
	a.target_type = AbilityData.TargetType.ALLY
	a.damage_type = AbilityData.DamageType.HEAL
	a.power = power
	a.scaling_stat = AbilityData.ScalingStat.INSTINCT
	a.scaling_ratio = 1.0
	return a


static func make_status(p_id: String, is_debuff: bool = true, duration: int = 2) -> StatusEffectData:
	var s := StatusEffectData.new()
	s.id = p_id
	s.display_name = p_id
	s.is_debuff = is_debuff
	s.duration_turns = duration
	return s
