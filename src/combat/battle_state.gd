class_name BattleState
extends RefCounted
## The whole battle as pure logic. The battle scene (or a headless simulation)
## drives it through three calls:
##   start() -> events            : begin battle, runs until input is needed
##   act(ability_id, target) -> events : current player unit acts, then runs on
##   act_pass() -> events          : current player unit skips its turn
## Every call returns an ordered event list the view layer animates.
## phase tells the caller what to do next: AWAIT_INPUT, VICTORY, or DEFEAT.

enum Phase { INIT, AWAIT_INPUT, VICTORY, DEFEAT }

var phase: int = Phase.INIT
var combatants: Array = []        # Array of CombatantState (players first)
var round_number: int = 0
var current_actor_index: int = -1
var defeated_enemies: Array = []  # CombatantState corpses for XP/loot payout

var _waves: Array = []            # remaining waves: Array of Array of EnemyData
var _wave_number: int = 0
var _enemy_stat_mult: float = 1.0
var _ai_temperature: float = 0.5
var _rng: RngService
var _queue: Array[int] = []
var _queue_pos: int = 0


func setup(player_units: Array, waves: Array, rng: RngService, enemy_stat_mult: float = 1.0, ai_temperature: float = 0.5) -> void:
	_rng = rng
	_waves = waves.duplicate()
	_enemy_stat_mult = enemy_stat_mult
	_ai_temperature = ai_temperature
	combatants = []
	for unit in player_units:
		_register(unit)


func start() -> Array:
	var events: Array = []
	events.append({"type": "battle_started"})
	_spawn_next_wave(events)
	_advance(events)
	return events


## The current awaiting player unit uses ability_id on target_index.
func act(ability_id: String, target_index: int) -> Array:
	var events: Array = []
	if phase != Phase.AWAIT_INPUT:
		push_error("BattleState.act called outside AWAIT_INPUT")
		return events
	var actor: CombatantState = combatants[current_actor_index]
	var ability: AbilityData = null
	for a in actor.abilities:
		if a.id == ability_id:
			ability = a
			break
	if ability == null or not actor.can_use(ability):
		push_error("BattleState.act: illegal ability %s" % ability_id)
		return events
	var legal := legal_targets(actor, ability)
	if not target_index in legal:
		push_error("BattleState.act: illegal target %d for %s" % [target_index, ability_id])
		return events

	events.append_array(AbilityResolver.resolve(actor, ability, _expand_targets(actor, ability, target_index), _rng))
	_finish_turn(actor, events)
	_advance(events)
	return events


func act_pass() -> Array:
	var events: Array = []
	if phase != Phase.AWAIT_INPUT:
		return events
	var actor: CombatantState = combatants[current_actor_index]
	events.append({"type": "pass", "actor": actor.index})
	_finish_turn(actor, events)
	_advance(events)
	return events


func current_actor() -> CombatantState:
	return combatants[current_actor_index] if current_actor_index >= 0 else null


## Usable abilities for a unit right now (off cooldown + affordable).
func usable_abilities(actor: CombatantState) -> Array:
	return actor.abilities.filter(func(a): return actor.can_use(a))


## Legal target indices for (actor, ability), honoring taunt.
func legal_targets(actor: CombatantState, ability: AbilityData) -> Array:
	var out: Array = []
	match ability.target_type:
		AbilityData.TargetType.SELF:
			out.append(actor.index)
		AbilityData.TargetType.ALLY, AbilityData.TargetType.ALL_ALLIES:
			for c in combatants:
				if c.team == actor.team and c.is_alive():
					out.append(c.index)
		AbilityData.TargetType.ENEMY, AbilityData.TargetType.ALL_ENEMIES:
			var taunters: Array = []
			for c in combatants:
				if c.team != actor.team and c.is_alive():
					out.append(c.index)
					if c.has_status_flag("taunt"):
						taunters.append(c.index)
			if ability.target_type == AbilityData.TargetType.ENEMY and not taunters.is_empty():
				out = taunters
	return out


func living(team: int) -> Array:
	return combatants.filter(func(c): return c.team == team and c.is_alive())


func is_over() -> bool:
	return phase == Phase.VICTORY or phase == Phase.DEFEAT


func _register(unit: CombatantState) -> void:
	unit.index = combatants.size()
	combatants.append(unit)


func _expand_targets(actor: CombatantState, ability: AbilityData, target_index: int) -> Array:
	match ability.target_type:
		AbilityData.TargetType.ALL_ALLIES, AbilityData.TargetType.ALL_ENEMIES:
			return legal_targets(actor, ability).map(func(i): return combatants[i])
		_:
			return [combatants[target_index]]


## Runs automatic steps until player input is required or the battle ends.
func _advance(events: Array) -> void:
	while true:
		if _check_battle_end(events):
			return
		if _queue_pos >= _queue.size():
			_start_round(events)
			continue
		var actor: CombatantState = combatants[_queue[_queue_pos]]
		if not actor.is_alive():
			_queue_pos += 1
			continue

		current_actor_index = actor.index
		events.append({"type": "turn_start", "actor": actor.index})
		_on_turn_start(actor, events)

		if not actor.is_alive():  # DoT killed it before acting
			_finish_turn(actor, events)
			continue
		if actor.has_status_flag("stun"):
			events.append({"type": "stunned", "actor": actor.index})
			_finish_turn(actor, events)
			continue

		if actor.player_controlled:
			phase = Phase.AWAIT_INPUT
			return

		var choice := EnemyAi.choose(self, actor, _rng, _ai_temperature)
		if choice.is_empty():
			events.append({"type": "pass", "actor": actor.index})
		else:
			events.append_array(AbilityResolver.resolve(
				actor, choice["ability"], _expand_targets(actor, choice["ability"], choice["target"]), _rng))
		_finish_turn(actor, events)


func _start_round(events: Array) -> void:
	round_number += 1
	_queue = TurnQueue.build(combatants, _rng)
	_queue_pos = 0
	events.append({"type": "round_start", "round": round_number, "order": _queue.duplicate()})


func _on_turn_start(actor: CombatantState, events: Array) -> void:
	for ability_id in actor.cooldowns:
		actor.cooldowns[ability_id] = maxi(0, actor.cooldowns[ability_id] - 1)
	var d := actor.derived()
	var regen: float = minf(d["focus_regen"], d["max_focus"] - actor.focus)
	if regen > 0.0:
		actor.focus += regen
	StatusEngine.tick(actor, StatusEffectData.TickTiming.TURN_START, events)


func _finish_turn(actor: CombatantState, events: Array) -> void:
	if actor.is_alive():
		StatusEngine.tick(actor, StatusEffectData.TickTiming.TURN_END, events)
	if actor.is_alive():
		StatusEngine.expire_turn_end(actor, events)
	current_actor_index = -1
	_queue_pos += 1
	_collect_defeated()
	# Wave transition: all enemies down but more waves queued.
	if living(CombatantState.TEAM_ENEMY).is_empty() and not _waves.is_empty():
		_spawn_next_wave(events)
		_queue.clear()  # force a fresh round including the new wave
		_queue_pos = 0


func _spawn_next_wave(events: Array) -> void:
	if _waves.is_empty():
		return
	_wave_number += 1
	var wave: Array = _waves.pop_front()
	var spawned: Array = []
	for enemy_data in wave:
		var unit := CombatantState.from_enemy(enemy_data, _enemy_stat_mult)
		_register(unit)
		spawned.append(unit.index)
	events.append({"type": "wave_started", "wave": _wave_number, "spawned": spawned})


func _collect_defeated() -> void:
	for c in combatants:
		if c.team == CombatantState.TEAM_ENEMY and not c.is_alive() and not c in defeated_enemies:
			defeated_enemies.append(c)


func _check_battle_end(events: Array) -> bool:
	if is_over():
		return true
	if living(CombatantState.TEAM_PLAYER).is_empty():
		phase = Phase.DEFEAT
		events.append({"type": "defeat"})
		return true
	if living(CombatantState.TEAM_ENEMY).is_empty() and _waves.is_empty() and round_number > 0:
		_collect_defeated()
		phase = Phase.VICTORY
		events.append({"type": "victory"})
		return true
	return false
