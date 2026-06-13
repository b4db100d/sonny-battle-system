#!/usr/bin/env python3
"""Generates the game's .tres content files from the declarative spec below.

Run from the repo root:  python3 tools/gen_content.py
Existing files under data/ are overwritten. The spec is the single source of
truth for balance numbers; tweak here, regenerate, re-run the simulator.
"""
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")

# Enum mirrors of src/data/*.gd
TT_SELF, TT_ALLY, TT_ENEMY, TT_ALL_ALLIES, TT_ALL_ENEMIES = range(5)
DT_PHYS, DT_PSY, DT_HEAL, DT_NONE = range(4)
SS_NONE, SS_STR, SS_INS = range(3)
ST_REFRESH, ST_STACK, ST_IGNORE = range(3)
TK_TURN_START, TK_TURN_END = range(2)
AI_BRUTE, AI_CASTER, AI_HEALER, AI_DISRUPTOR = range(4)
SH_BLOCK, SH_SPIKE, SH_ORB, SH_WIDE, SH_TALL = range(5)
SL_WEAPON, SL_HEAD, SL_BODY, SL_LEGS, SL_HANDS, SL_TRINKET = range(6)
RA_COMMON, RA_UNCOMMON, RA_RARE = range(3)


class Ref:
    """Reference to another generated resource: Ref('statuses', 'bleed')."""
    def __init__(self, kind, rid):
        self.kind = kind
        self.rid = rid


class Color:
    def __init__(self, hexcode):
        h = hexcode.lstrip("#")
        self.r = int(h[0:2], 16) / 255.0
        self.g = int(h[2:4], 16) / 255.0
        self.b = int(h[4:6], 16) / 255.0


# ---------------------------------------------------------------- statuses
STATUSES = {
    "bleed": dict(display_name="Bleed", icon_color=Color("d92626"), is_debuff=True,
                  duration_turns=3, stacking=ST_STACK, max_stacks=3,
                  tick_timing=TK_TURN_START, tick_power=3.0,
                  tick_scaling_stat=SS_STR, tick_scaling_ratio=0.25,
                  description="Takes physical damage each turn. Stacks up to 3 times."),
    "corrosion": dict(display_name="Corrosion", icon_color=Color("9ccc65"), is_debuff=True,
                      duration_turns=3, stacking=ST_STACK, max_stacks=3,
                      tick_timing=TK_TURN_START, tick_power=4.0,
                      tick_scaling_stat=SS_INS, tick_scaling_ratio=0.3,
                      description="Acid eats armor plating each turn. Stacks up to 3 times."),
    "venom": dict(display_name="Venom", icon_color=Color("4caf50"), is_debuff=True,
                  duration_turns=3, tick_timing=TK_TURN_START, tick_power=5.0,
                  tick_scaling_stat=SS_INS, tick_scaling_ratio=0.2,
                  description="Poisoned: takes damage at the start of each turn."),
    "stunned": dict(display_name="Stunned", icon_color=Color("ffb74d"), is_debuff=True,
                    duration_turns=1, flags=["stun"],
                    description="Cannot act this turn."),
    "dazed": dict(display_name="Dazed", icon_color=Color("ffd180"), is_debuff=True,
                  duration_turns=1, flags=["stun"],
                  description="Reeling: loses its next turn."),
    "frenzy": dict(display_name="Frenzy", icon_color=Color("ff7043"), is_debuff=False,
                   duration_turns=3, stat_mods={"strength": 0.35},
                   description="+35% Strength."),
    "barrier": dict(display_name="Barrier", icon_color=Color("4dd0e1"), is_debuff=False,
                    duration_turns=2, shield_amount=35.0, flags=["shield"],
                    description="A shield absorbs the next 35 damage."),
    "bulwark": dict(display_name="Bulwark", icon_color=Color("90a4ae"), is_debuff=False,
                    duration_turns=2, shield_amount=20.0, flags=["taunt", "shield"],
                    description="Taunts enemies and absorbs 20 damage."),
    "rally": dict(display_name="Rally", icon_color=Color("ffe082"), is_debuff=False,
                  duration_turns=2, stat_mods={"strength": 0.15, "instinct": 0.15},
                  description="+15% Strength and Instinct."),
    "slow": dict(display_name="Slowed", icon_color=Color("81d4fa"), is_debuff=True,
                 duration_turns=2, stat_mods={"speed": -0.3},
                 description="-30% Speed."),
    "weaken": dict(display_name="Weakened", icon_color=Color("bcaaa4"), is_debuff=True,
                   duration_turns=2, stat_mods={"strength": -0.25},
                   description="-25% Strength."),
    "fray": dict(display_name="Frayed", icon_color=Color("ce93d8"), is_debuff=True,
                 duration_turns=2, stat_mods={"strength": -0.15, "instinct": -0.25},
                 description="Mind static: -15% Strength, -25% Instinct."),
}

# ---------------------------------------------------------------- abilities
ABILITIES = {
    # Innate
    "strike": dict(display_name="Strike", tree_id="", tier=1, icon_color=Color("bfbfc7"),
                   focus_cost=0, cooldown=0, target_type=TT_ENEMY, damage_type=DT_PHYS,
                   power=6.0, scaling_stat=SS_STR, scaling_ratio=1.0, focus_gain=10,
                   description="A reliable blow that builds 10 focus."),
    # Havoc (physical)
    "rend": dict(display_name="Rend", tree_id="havoc", tier=1, icon_color=Color("d94c33"),
                 focus_cost=15, cooldown=1, target_type=TT_ENEMY, damage_type=DT_PHYS,
                 power=10.0, scaling_stat=SS_STR, scaling_ratio=1.2,
                 applies_status=Ref("statuses", "bleed"), ai_weight=1.2,
                 description="Tears into the target and causes bleeding."),
    "crack": dict(display_name="Crack", tree_id="havoc", tier=1, icon_color=Color("e57341"),
                  focus_cost=12, cooldown=1, target_type=TT_ENEMY, damage_type=DT_PHYS,
                  power=14.0, scaling_stat=SS_STR, scaling_ratio=1.3, ai_weight=1.1,
                  description="A heavy, armor-cracking hit."),
    "overload_strike": dict(display_name="Overload Strike", tree_id="havoc", tier=2,
                            icon_color=Color("ef5350"), focus_cost=22, cooldown=2,
                            target_type=TT_ENEMY, damage_type=DT_PHYS, power=9.0,
                            scaling_stat=SS_STR, scaling_ratio=0.85, hit_count=2, ai_weight=1.2,
                            description="Two rapid strikes in one action."),
    "concuss": dict(display_name="Concuss", tree_id="havoc", tier=2, icon_color=Color("ffb74d"),
                    focus_cost=30, cooldown=3, target_type=TT_ENEMY, damage_type=DT_PHYS,
                    power=8.0, scaling_stat=SS_STR, scaling_ratio=0.8,
                    applies_status=Ref("statuses", "stunned"), status_chance=0.8, ai_weight=1.3,
                    description="A skull-ringing blow with an 80% chance to stun."),
    "frenzy_skill": dict(display_name="Frenzy", tree_id="havoc", tier=3, icon_color=Color("ff7043"),
                         focus_cost=20, cooldown=4, target_type=TT_SELF, damage_type=DT_NONE,
                         power=0.0, scaling_stat=SS_NONE,
                         applies_status=Ref("statuses", "frenzy"),
                         description="Overdrive servos: +35% Strength for 3 turns."),
    "executioner": dict(display_name="Executioner", tree_id="havoc", tier=4, icon_color=Color("b71c1c"),
                        focus_cost=40, cooldown=4, target_type=TT_ENEMY, damage_type=DT_PHYS,
                        power=30.0, scaling_stat=SS_STR, scaling_ratio=1.8, ai_weight=1.5,
                        description="A devastating finishing blow."),
    # Surge (psy)
    "static_bolt": dict(display_name="Static Bolt", tree_id="surge", tier=1, icon_color=Color("64b5f6"),
                        focus_cost=10, cooldown=0, target_type=TT_ENEMY, damage_type=DT_PSY,
                        power=12.0, scaling_stat=SS_INS, scaling_ratio=1.2,
                        description="A crackling lance of charge."),
    "corrode": dict(display_name="Corrode", tree_id="surge", tier=1, icon_color=Color("9ccc65"),
                    focus_cost=15, cooldown=1, target_type=TT_ENEMY, damage_type=DT_PSY,
                    power=6.0, scaling_stat=SS_INS, scaling_ratio=0.6,
                    applies_status=Ref("statuses", "corrosion"), ai_weight=1.1,
                    description="Sprays reactive acid that keeps burning."),
    "drain_pulse": dict(display_name="Drain Pulse", tree_id="surge", tier=2, icon_color=Color("4db6ac"),
                        focus_cost=5, cooldown=2, target_type=TT_ENEMY, damage_type=DT_PSY,
                        power=10.0, scaling_stat=SS_INS, scaling_ratio=0.9,
                        target_focus_change=-20, focus_gain=15,
                        description="Steals the target's focus."),
    "chain_arc": dict(display_name="Chain Arc", tree_id="surge", tier=2, icon_color=Color("4fc3f7"),
                      focus_cost=30, cooldown=3, target_type=TT_ALL_ENEMIES, damage_type=DT_PSY,
                      power=9.0, scaling_stat=SS_INS, scaling_ratio=0.7, ai_weight=1.2,
                      description="Lightning leaps to every enemy."),
    "mind_spike": dict(display_name="Mind Spike", tree_id="surge", tier=3, icon_color=Color("ce93d8"),
                       focus_cost=25, cooldown=2, target_type=TT_ENEMY, damage_type=DT_PSY,
                       power=18.0, scaling_stat=SS_INS, scaling_ratio=1.4,
                       applies_status=Ref("statuses", "fray"), ai_weight=1.3,
                       description="Pierces the target's processes and frays them."),
    "cascade": dict(display_name="Cascade", tree_id="surge", tier=4, icon_color=Color("7e57c2"),
                    focus_cost=45, cooldown=4, target_type=TT_ALL_ENEMIES, damage_type=DT_PSY,
                    power=16.0, scaling_stat=SS_INS, scaling_ratio=1.1, ai_weight=1.4,
                    description="A rolling storm of charge engulfs the field."),
    # Bastion (support)
    "mend": dict(display_name="Mend", tree_id="bastion", tier=1, icon_color=Color("66bb6a"),
                 focus_cost=20, cooldown=1, target_type=TT_ALLY, damage_type=DT_HEAL,
                 power=18.0, scaling_stat=SS_INS, scaling_ratio=1.5, ai_weight=1.4,
                 description="Repairs an ally, restoring health."),
    "barrier_skill": dict(display_name="Barrier", tree_id="bastion", tier=1, icon_color=Color("4dd0e1"),
                          focus_cost=20, cooldown=2, target_type=TT_ALLY, damage_type=DT_NONE,
                          power=0.0, scaling_stat=SS_NONE,
                          applies_status=Ref("statuses", "barrier"), ai_weight=1.1,
                          description="Projects a shield that absorbs 35 damage."),
    "provoke": dict(display_name="Provoke", tree_id="bastion", tier=2, icon_color=Color("90a4ae"),
                    focus_cost=15, cooldown=3, target_type=TT_SELF, damage_type=DT_NONE,
                    power=0.0, scaling_stat=SS_NONE,
                    applies_status=Ref("statuses", "bulwark"), ai_weight=1.1,
                    description="Taunts enemies into attacking you and raises a small shield."),
    "purge": dict(display_name="Purge", tree_id="bastion", tier=3, icon_color=Color("b2dfdb"),
                  focus_cost=20, cooldown=2, target_type=TT_ALLY, damage_type=DT_HEAL,
                  power=10.0, scaling_stat=SS_INS, scaling_ratio=0.5, dispel_count=2,
                  description="Cleanses two debuffs and lightly heals an ally."),
    "rally_skill": dict(display_name="Rally", tree_id="bastion", tier=3, icon_color=Color("ffe082"),
                        focus_cost=35, cooldown=4, target_type=TT_ALL_ALLIES, damage_type=DT_NONE,
                        power=0.0, scaling_stat=SS_NONE,
                        applies_status=Ref("statuses", "rally"), ai_weight=1.2,
                        description="Rallies the team: +15% Strength and Instinct."),
    "second_wind": dict(display_name="Second Wind", tree_id="bastion", tier=4, icon_color=Color("a5d6a7"),
                        focus_cost=35, cooldown=3, target_type=TT_ALLY, damage_type=DT_HEAL,
                        power=40.0, scaling_stat=SS_INS, scaling_ratio=2.2, ai_weight=1.5,
                        description="A massive surge of repairs."),
    # Enemy abilities
    "claw": dict(display_name="Claw", tree_id="", icon_color=Color("99774d"),
                 target_type=TT_ENEMY, damage_type=DT_PHYS, power=5.0,
                 scaling_stat=SS_STR, scaling_ratio=1.0, focus_gain=8,
                 description="A basic enemy swipe."),
    "bite": dict(display_name="Bite", tree_id="", icon_color=Color("8d6e63"),
                 target_type=TT_ENEMY, damage_type=DT_PHYS, power=8.0,
                 scaling_stat=SS_STR, scaling_ratio=1.1, focus_gain=6,
                 description="Snapping jaws."),
    "venom_spit": dict(display_name="Venom Spit", tree_id="", icon_color=Color("4caf50"),
                       focus_cost=10, cooldown=1, target_type=TT_ENEMY, damage_type=DT_PSY,
                       power=4.0, scaling_stat=SS_INS, scaling_ratio=0.8,
                       applies_status=Ref("statuses", "venom"), ai_weight=1.2,
                       description="A glob of caustic venom."),
    "weld_beam": dict(display_name="Weld Beam", tree_id="", icon_color=Color("ffa726"),
                      focus_cost=12, cooldown=1, target_type=TT_ENEMY, damage_type=DT_PSY,
                      power=10.0, scaling_stat=SS_INS, scaling_ratio=1.2, ai_weight=1.1,
                      description="A cutting torch turned weapon."),
    "patch_up": dict(display_name="Patch Up", tree_id="", icon_color=Color("66bb6a"),
                     focus_cost=20, cooldown=2, target_type=TT_ALLY, damage_type=DT_HEAL,
                     power=12.0, scaling_stat=SS_INS, scaling_ratio=1.0, ai_weight=1.5,
                     description="Field repairs."),
    "shield_wall": dict(display_name="Shield Wall", tree_id="", icon_color=Color("4dd0e1"),
                        focus_cost=15, cooldown=3, target_type=TT_ALLY, damage_type=DT_NONE,
                        power=0.0, scaling_stat=SS_NONE,
                        applies_status=Ref("statuses", "barrier"), ai_weight=1.1,
                        description="Raises a barrier on an ally."),
    "war_howl": dict(display_name="War Howl", tree_id="", icon_color=Color("ffe082"),
                     focus_cost=20, cooldown=4, target_type=TT_ALL_ALLIES, damage_type=DT_NONE,
                     power=0.0, scaling_stat=SS_NONE,
                     applies_status=Ref("statuses", "rally"), ai_weight=1.1,
                     description="A rallying cry."),
    "slam": dict(display_name="Slam", tree_id="", icon_color=Color("a1887f"),
                 focus_cost=18, cooldown=2, target_type=TT_ENEMY, damage_type=DT_PHYS,
                 power=16.0, scaling_stat=SS_STR, scaling_ratio=1.4, ai_weight=1.3,
                 description="A crushing overhead blow."),
    "zap": dict(display_name="Zap", tree_id="", icon_color=Color("64b5f6"),
                target_type=TT_ENEMY, damage_type=DT_PSY, power=9.0,
                scaling_stat=SS_INS, scaling_ratio=1.0, focus_gain=5,
                description="A quick discharge."),
    "suppress": dict(display_name="Suppress", tree_id="", icon_color=Color("81d4fa"),
                     focus_cost=12, cooldown=2, target_type=TT_ENEMY, damage_type=DT_PSY,
                     power=5.0, scaling_stat=SS_INS, scaling_ratio=0.6,
                     applies_status=Ref("statuses", "slow"), ai_weight=1.2,
                     description="Dampening fields slow the target."),
    "gut_punch": dict(display_name="Gut Punch", tree_id="", icon_color=Color("bcaaa4"),
                      focus_cost=10, cooldown=2, target_type=TT_ENEMY, damage_type=DT_PHYS,
                      power=7.0, scaling_stat=SS_STR, scaling_ratio=0.9,
                      applies_status=Ref("statuses", "weaken"), ai_weight=1.2,
                      description="A winding blow that saps strength."),
    "jolt": dict(display_name="Jolt", tree_id="", icon_color=Color("ffd180"),
                 focus_cost=20, cooldown=3, target_type=TT_ENEMY, damage_type=DT_PSY,
                 power=6.0, scaling_stat=SS_INS, scaling_ratio=0.8,
                 applies_status=Ref("statuses", "dazed"), status_chance=0.6, ai_weight=1.3,
                 description="A paralytic shock with a 60% chance to daze."),
    "siphon": dict(display_name="Siphon", tree_id="", icon_color=Color("4db6ac"),
                   focus_cost=5, cooldown=2, target_type=TT_ENEMY, damage_type=DT_PSY,
                   power=8.0, scaling_stat=SS_INS, scaling_ratio=0.9,
                   target_focus_change=-15, focus_gain=15, ai_weight=1.1,
                   description="Drinks the target's focus."),
}

# ---------------------------------------------------------------- items
ITEMS = {
    "rusty_blade": dict(display_name="Rusty Blade", slot=SL_WEAPON, rarity=RA_COMMON, level_req=1,
                        stat_bonuses={"strength": 3}, description="Better than fists. Barely."),
    "shock_baton": dict(display_name="Shock Baton", slot=SL_WEAPON, rarity=RA_COMMON, level_req=3,
                        stat_bonuses={"strength": 4, "speed": 2}, description="Standard deck-crew sidearm."),
    "focus_rod": dict(display_name="Focus Rod", slot=SL_WEAPON, rarity=RA_COMMON, level_req=2,
                      stat_bonuses={"instinct": 5}, description="Channels stray charge into intent."),
    "arc_projector": dict(display_name="Arc Projector", slot=SL_WEAPON, rarity=RA_UNCOMMON, level_req=10,
                          stat_bonuses={"instinct": 9}, description="Industrial lightning, weaponized."),
    "breaker_maul": dict(display_name="Breaker Maul", slot=SL_WEAPON, rarity=RA_RARE, level_req=13,
                         stat_bonuses={"strength": 11}, description="Made for hull plate. Works on hulls of all kinds."),
    "conduit_blade": dict(display_name="Conduit Blade", slot=SL_WEAPON, rarity=RA_RARE, level_req=16,
                          stat_bonuses={"strength": 8, "speed": 5}, description="Hums at the same pitch as the Spire."),
    "scrap_visor": dict(display_name="Scrap Visor", slot=SL_HEAD, rarity=RA_COMMON, level_req=1,
                        stat_bonuses={"instinct": 2}, description="Cracked lens, decent readouts."),
    "ceramic_helm": dict(display_name="Ceramic Helm", slot=SL_HEAD, rarity=RA_COMMON, level_req=3,
                         stat_bonuses={"vitality": 3}, description="Heavy, but it keeps your head on."),
    "targeting_visor": dict(display_name="Targeting Visor", slot=SL_HEAD, rarity=RA_UNCOMMON, level_req=6,
                            stat_bonuses={"speed": 4, "crit_chance": 0.03}, description="Paints weak points in amber."),
    "neural_crown": dict(display_name="Neural Crown", slot=SL_HEAD, rarity=RA_RARE, level_req=14,
                         stat_bonuses={"instinct": 8}, description="Whispers in frequencies you almost remember."),
    "plate_vest": dict(display_name="Plate Vest", slot=SL_BODY, rarity=RA_COMMON, level_req=2,
                       stat_bonuses={"vitality": 4}, description="Salvaged hull plating, crew-fitted."),
    "insulated_suit": dict(display_name="Insulated Suit", slot=SL_BODY, rarity=RA_UNCOMMON, level_req=5,
                           stat_bonuses={"vitality": 3, "instinct": 3}, description="Keeps the damp and the static out."),
    "exo_frame": dict(display_name="Exo Frame", slot=SL_BODY, rarity=RA_UNCOMMON, level_req=10,
                      stat_bonuses={"vitality": 8}, description="Quarantine-issue load-bearing armor."),
    "phase_cloak": dict(display_name="Phase Cloak", slot=SL_BODY, rarity=RA_RARE, level_req=15,
                        stat_bonuses={"speed": 5, "dodge": 0.04}, description="Hard to hit what flickers."),
    "spring_greaves": dict(display_name="Spring Greaves", slot=SL_LEGS, rarity=RA_COMMON, level_req=1,
                           stat_bonuses={"speed": 3}, description="Bouncy. Surprisingly so."),
    "heavy_treads": dict(display_name="Heavy Treads", slot=SL_LEGS, rarity=RA_COMMON, level_req=4,
                         stat_bonuses={"vitality": 4}, description="Planted like a bulkhead."),
    "servo_legs": dict(display_name="Servo Legs", slot=SL_LEGS, rarity=RA_UNCOMMON, level_req=12,
                       stat_bonuses={"speed": 6}, description="Military actuators, lightly used."),
    "grip_wraps": dict(display_name="Grip Wraps", slot=SL_HANDS, rarity=RA_COMMON, level_req=1,
                       stat_bonuses={"strength": 2}, description="Oil-stained but dependable."),
    "shock_gauntlets": dict(display_name="Shock Gauntlets", slot=SL_HANDS, rarity=RA_UNCOMMON, level_req=8,
                            stat_bonuses={"strength": 5}, description="Every punch carries a charge."),
    "surgeon_gloves": dict(display_name="Surgeon Gloves", slot=SL_HANDS, rarity=RA_UNCOMMON, level_req=8,
                           stat_bonuses={"instinct": 5}, description="Steady hands, steadier mind."),
    "lucky_bolt": dict(display_name="Lucky Bolt", slot=SL_TRINKET, rarity=RA_COMMON, level_req=2,
                       stat_bonuses={"crit_chance": 0.04}, description="The first piece of you that was replaced."),
    "core_capacitor": dict(display_name="Core Capacitor", slot=SL_TRINKET, rarity=RA_UNCOMMON, level_req=6,
                           stat_bonuses={"focus_regen": 4}, description="Stores a little extra intent."),
    "mag_anchor": dict(display_name="Mag Anchor", slot=SL_TRINKET, rarity=RA_UNCOMMON, level_req=9,
                       stat_bonuses={"vitality": 4, "max_hp": 20}, description="Keeps your feet — and your frame — together."),
    "dampener_coil": dict(display_name="Dampener Coil", slot=SL_TRINKET, rarity=RA_UNCOMMON, level_req=10,
                          stat_bonuses={"dodge": 0.05}, description="Bends incoming fire a half-degree wide."),
    "overclock_chip": dict(display_name="Overclock Chip", slot=SL_TRINKET, rarity=RA_RARE, level_req=14,
                           stat_bonuses={"strength": 4, "instinct": 4}, description="Runs hot. Runs beautifully."),
    "aegis_node": dict(display_name="Aegis Node", slot=SL_TRINKET, rarity=RA_RARE, level_req=16,
                       stat_bonuses={"max_hp": 60}, description="A heartbeat of pure shielding."),
}

# ---------------------------------------------------------------- enemies
def loot(*ids):
    return [{"item_id": i, "weight": 1.0} for i in ids]

ENEMIES = {
    # Zone 1 — Salvage Barge "Vesper" (lv 1-4). The player is solo here, so
    # fodder runs low hp_mult and gentle offense.
    "scrap_drone": dict(display_name="Scrap Drone", body_color=Color("8c8c99"), body_shape=SH_ORB,
                        level=1, strength=2, instinct=2, speed=5, vitality=2, hp_mult=0.45,
                        ai_profile=AI_BRUTE,
                        abilities=["claw"], xp_reward=18, credit_reward=4,
                        loot_chance=0.2, loot_table=loot("grip_wraps", "scrap_visor")),
    "rust_hound": dict(display_name="Rust Hound", body_color=Color("a65932"), body_shape=SH_SPIKE,
                       level=2, strength=4, instinct=2, speed=7, vitality=3, hp_mult=0.5,
                       ai_profile=AI_BRUTE,
                       abilities=["claw", "bite"], xp_reward=26, credit_reward=6,
                       loot_chance=0.25, loot_table=loot("rusty_blade", "spring_greaves")),
    "oil_slug": dict(display_name="Oil Slug", body_color=Color("3e4a3d"), body_shape=SH_ORB,
                     level=2, strength=2, instinct=4, speed=3, vitality=6, hp_mult=0.55,
                     ai_profile=AI_CASTER,
                     abilities=["venom_spit", "claw"], xp_reward=28, credit_reward=6,
                     loot_chance=0.25, loot_table=loot("focus_rod", "plate_vest")),
    "deck_welder": dict(display_name="Deck Welder", body_color=Color("cc7a29"), body_shape=SH_BLOCK,
                        level=3, strength=4, instinct=6, speed=4, vitality=5, hp_mult=0.55,
                        ai_profile=AI_CASTER,
                        abilities=["weld_beam", "claw"], xp_reward=35, credit_reward=8,
                        loot_chance=0.3, loot_table=loot("shock_baton", "ceramic_helm")),
    "foreman_rig": dict(display_name="Foreman Rig", body_color=Color("b33636"), body_shape=SH_TALL,
                        level=5, strength=8, instinct=4, speed=6, vitality=10, hp_mult=0.9,
                        ai_profile=AI_BRUTE,
                        abilities=["slam", "jolt", "claw"], xp_reward=130, credit_reward=30,
                        loot_chance=0.5, loot_table=loot("heavy_treads")),
    # Zone 2 — Drowned Refinery (lv 5-9)
    "vapor_wraith": dict(display_name="Vapor Wraith", body_color=Color("b3c6d9"), body_shape=SH_ORB,
                         level=5, strength=4, instinct=10, speed=9, vitality=6, hp_mult=0.6, ai_profile=AI_CASTER,
                         abilities=["zap", "siphon"], xp_reward=55, credit_reward=10,
                         loot_chance=0.25, loot_table=loot("focus_rod", "insulated_suit", "lucky_bolt")),
    "refinery_drone": dict(display_name="Refinery Drone", body_color=Color("5c7a8c"), body_shape=SH_ORB,
                           level=6, strength=8, instinct=4, speed=9, vitality=6, hp_mult=0.6, ai_profile=AI_BRUTE,
                           abilities=["claw", "zap"], xp_reward=60, credit_reward=11,
                           loot_chance=0.25, loot_table=loot("targeting_visor", "spring_greaves")),
    "corroded_welder": dict(display_name="Corroded Welder", body_color=Color("997a29"), body_shape=SH_BLOCK,
                            level=6, strength=9, instinct=7, speed=5, vitality=9, hp_mult=0.65, ai_profile=AI_BRUTE,
                            abilities=["weld_beam", "slam"], xp_reward=65, credit_reward=12,
                            loot_chance=0.3, loot_table=loot("shock_gauntlets", "ceramic_helm")),
    "sump_horror": dict(display_name="Sump Horror", body_color=Color("4d6652"), body_shape=SH_WIDE,
                        level=7, strength=11, instinct=4, speed=4, vitality=12, hp_mult=0.7, ai_profile=AI_BRUTE,
                        abilities=["bite", "venom_spit", "slam"], xp_reward=80, credit_reward=14,
                        loot_chance=0.3, loot_table=loot("plate_vest", "heavy_treads", "mag_anchor")),
    "the_custodian": dict(display_name="The Custodian", body_color=Color("3f7385"), body_shape=SH_WIDE,
                          level=9, strength=10, instinct=12, speed=7, vitality=20, hp_mult=0.85, ai_profile=AI_DISRUPTOR,
                          abilities=["slam", "shield_wall", "suppress", "patch_up"],
                          xp_reward=280, credit_reward=60,
                          loot_chance=0.5, loot_table=loot("mag_anchor")),
    # Zone 3 — The Quarantine Line (lv 10-15)
    "security_exo": dict(display_name="Security Exo", body_color=Color("607d8b"), body_shape=SH_BLOCK,
                         level=10, strength=14, instinct=5, speed=8, vitality=14, hp_mult=0.65, ai_profile=AI_BRUTE,
                         abilities=["slam", "suppress", "claw"], xp_reward=110, credit_reward=18,
                         loot_chance=0.3, loot_table=loot("exo_frame", "shock_gauntlets")),
    "field_medic": dict(display_name="Field Medic", body_color=Color("80cbc4"), body_shape=SH_TALL,
                        level=11, strength=6, instinct=16, speed=10, vitality=10, hp_mult=0.6, ai_profile=AI_HEALER,
                        abilities=["patch_up", "zap", "shield_wall"], xp_reward=120, credit_reward=20,
                        loot_chance=0.3, loot_table=loot("surgeon_gloves", "core_capacitor")),
    "shock_trooper": dict(display_name="Shock Trooper", body_color=Color("78909c"), body_shape=SH_SPIKE,
                          level=12, strength=15, instinct=8, speed=12, vitality=12, hp_mult=0.65, ai_profile=AI_BRUTE,
                          abilities=["gut_punch", "bite", "jolt"], xp_reward=135, credit_reward=22,
                          loot_chance=0.3, loot_table=loot("servo_legs", "targeting_visor")),
    "plague_hound": dict(display_name="Plague Hound", body_color=Color("7a4d66"), body_shape=SH_SPIKE,
                         level=11, strength=13, instinct=6, speed=15, vitality=10, hp_mult=0.6, ai_profile=AI_BRUTE,
                         abilities=["bite", "venom_spit"], xp_reward=120, credit_reward=20,
                         loot_chance=0.25, loot_table=loot("dampener_coil", "spring_greaves")),
    "warden_khros": dict(display_name="Warden Khros", body_color=Color("8c3a3a"), body_shape=SH_TALL,
                         level=14, strength=20, instinct=10, speed=11, vitality=28, hp_mult=0.9, ai_profile=AI_BRUTE,
                         abilities=["slam", "jolt", "war_howl", "gut_punch"],
                         xp_reward=500, credit_reward=120,
                         loot_chance=0.5, loot_table=loot("overclock_chip")),
    # Zone 4 — Relay Spire (lv 16-22)
    "signal_husk": dict(display_name="Signal Husk", body_color=Color("9fa8da"), body_shape=SH_ORB,
                        level=16, strength=8, instinct=20, speed=13, vitality=14, hp_mult=0.65, ai_profile=AI_CASTER,
                        abilities=["zap", "siphon", "suppress"], xp_reward=200, credit_reward=30,
                        loot_chance=0.3, loot_table=loot("neural_crown", "overclock_chip")),
    "spire_sentinel": dict(display_name="Spire Sentinel", body_color=Color("5c6bc0"), body_shape=SH_BLOCK,
                           level=17, strength=18, instinct=12, speed=9, vitality=20, hp_mult=0.75, ai_profile=AI_DISRUPTOR,
                           abilities=["slam", "shield_wall", "suppress"], xp_reward=220, credit_reward=32,
                           loot_chance=0.3, loot_table=loot("exo_frame", "aegis_node")),
    "arc_phantom": dict(display_name="Arc Phantom", body_color=Color("b39ddb"), body_shape=SH_SPIKE,
                        level=18, strength=14, instinct=18, speed=20, vitality=12, hp_mult=0.65, ai_profile=AI_CASTER,
                        abilities=["zap", "jolt", "siphon"], xp_reward=240, credit_reward=34,
                        loot_chance=0.3, loot_table=loot("phase_cloak", "dampener_coil")),
    "vanguard_exo": dict(display_name="Vanguard Exo", body_color=Color("455a64"), body_shape=SH_BLOCK,
                         level=19, strength=22, instinct=10, speed=12, vitality=22, hp_mult=0.75, ai_profile=AI_BRUTE,
                         abilities=["slam", "gut_punch", "war_howl"], xp_reward=260, credit_reward=36,
                         loot_chance=0.3, loot_table=loot("conduit_blade", "breaker_maul")),
    "chief_medic": dict(display_name="Chief Medic", body_color=Color("4db6ac"), body_shape=SH_TALL,
                        level=18, strength=10, instinct=24, speed=13, vitality=16, hp_mult=0.65, ai_profile=AI_HEALER,
                        abilities=["patch_up", "shield_wall", "zap", "jolt"],
                        xp_reward=250, credit_reward=35,
                        loot_chance=0.3, loot_table=loot("surgeon_gloves", "neural_crown")),
    "the_conductor": dict(display_name="The Conductor", body_color=Color("7c4dff"), body_shape=SH_TALL,
                          level=22, strength=18, instinct=26, speed=14, vitality=34, hp_mult=1.0, ai_profile=AI_CASTER,
                          abilities=["jolt", "siphon", "slam", "war_howl"],
                          xp_reward=900, credit_reward=250,
                          loot_chance=0.6, loot_table=loot("aegis_node")),
}

# ---------------------------------------------------------------- stages
STAGES = {
    # Zone 1
    "v1": dict(zone_id="vesper", display_name="Cargo Hold", recommended_level=1,
               waves=[["scrap_drone", "scrap_drone"]],
               first_clear_xp_bonus=50, first_clear_item="rusty_blade"),
    "v2": dict(zone_id="vesper", display_name="Lower Decks", recommended_level=2,
               waves=[["scrap_drone", "rust_hound"]], requires_stage_id="v1",
               first_clear_xp_bonus=60, first_clear_item="scrap_visor"),
    "v3": dict(zone_id="vesper", display_name="Engine Room", recommended_level=3,
               waves=[["oil_slug", "scrap_drone"], ["rust_hound", "rust_hound"]],
               requires_stage_id="v2", pre_dialogue_id="z1_mid",
               first_clear_xp_bonus=80, first_clear_item="plate_vest"),
    "v_training": dict(zone_id="vesper", display_name="Sparring Bay", recommended_level=3,
                       waves=[["scrap_drone", "scrap_drone", "scrap_drone"]],
                       requires_stage_id="v2", is_training=True),
    "v_boss": dict(zone_id="vesper", display_name="Foreman's Perch", recommended_level=4,
                   waves=[["deck_welder", "foreman_rig"]], requires_stage_id="v3",
                   pre_dialogue_id="z1_boss_pre", post_dialogue_id="z1_boss_post",
                   first_clear_xp_bonus=150, first_clear_item="shock_baton"),
    # Zone 2
    "r1": dict(zone_id="refinery", display_name="Flooded Gate", recommended_level=5,
               waves=[["refinery_drone", "refinery_drone"]], pre_dialogue_id="z2_intro",
               first_clear_xp_bonus=100, first_clear_item="insulated_suit"),
    "r2": dict(zone_id="refinery", display_name="Condenser Row", recommended_level=6,
               waves=[["vapor_wraith", "refinery_drone"], ["corroded_welder"]],
               requires_stage_id="r1", post_dialogue_id="z2_ally", recruit_ally_id="vela",
               first_clear_xp_bonus=140, first_clear_item="focus_rod"),
    "r3": dict(zone_id="refinery", display_name="Sump Tunnels", recommended_level=7,
               waves=[["sump_horror", "vapor_wraith"]], requires_stage_id="r2",
               first_clear_xp_bonus=160, first_clear_item="targeting_visor"),
    "r_training": dict(zone_id="refinery", display_name="Maintenance Pit", recommended_level=7,
                       waves=[["refinery_drone", "vapor_wraith", "refinery_drone"]],
                       requires_stage_id="r1", is_training=True),
    "r_boss": dict(zone_id="refinery", display_name="Custodian Core", recommended_level=9,
                   waves=[["corroded_welder", "the_custodian", "vapor_wraith"]],
                   requires_stage_id="r3", pre_dialogue_id="z2_boss_pre",
                   first_clear_xp_bonus=300, first_clear_item="core_capacitor"),
    # Zone 3
    "q1": dict(zone_id="quarantine", display_name="Checkpoint Ruins", recommended_level=10,
               waves=[["security_exo", "plague_hound"]], pre_dialogue_id="z3_intro",
               first_clear_xp_bonus=200, first_clear_item="exo_frame"),
    "q2": dict(zone_id="quarantine", display_name="Field Hospital", recommended_level=11,
               waves=[["field_medic", "security_exo"], ["shock_trooper"]],
               requires_stage_id="q1",
               first_clear_xp_bonus=240, first_clear_item="surgeon_gloves"),
    "q3": dict(zone_id="quarantine", display_name="Kennel Blocks", recommended_level=12,
               waves=[["plague_hound", "plague_hound", "field_medic"]],
               requires_stage_id="q2", post_dialogue_id="z3_ally", recruit_ally_id="brick",
               first_clear_xp_bonus=280, first_clear_item="servo_legs"),
    "q_training": dict(zone_id="quarantine", display_name="Drill Yard", recommended_level=13,
                       waves=[["security_exo", "shock_trooper"]],
                       requires_stage_id="q1", is_training=True),
    "q_boss": dict(zone_id="quarantine", display_name="Warden's Gate", recommended_level=14,
                   waves=[["security_exo", "warden_khros", "field_medic"]],
                   requires_stage_id="q3", pre_dialogue_id="z3_boss_pre",
                   first_clear_xp_bonus=500, first_clear_item="arc_projector"),
    # Zone 4
    "s1": dict(zone_id="spire", display_name="Antenna Fields", recommended_level=16,
               waves=[["signal_husk", "signal_husk", "arc_phantom"]], pre_dialogue_id="z4_intro",
               first_clear_xp_bonus=350, first_clear_item="phase_cloak"),
    "s2": dict(zone_id="spire", display_name="Sentinel Walk", recommended_level=17,
               waves=[["spire_sentinel", "vanguard_exo"]], requires_stage_id="s1",
               first_clear_xp_bonus=400, first_clear_item="conduit_blade"),
    "s3": dict(zone_id="spire", display_name="Resonance Chamber", recommended_level=18,
               waves=[["chief_medic", "arc_phantom", "signal_husk"]], requires_stage_id="s2",
               first_clear_xp_bonus=450, first_clear_item="neural_crown"),
    "s_training": dict(zone_id="spire", display_name="Echo Range", recommended_level=19,
                       waves=[["arc_phantom", "spire_sentinel", "signal_husk"]],
                       requires_stage_id="s1", is_training=True),
    "s_boss": dict(zone_id="spire", display_name="The Conductor", recommended_level=21,
                   waves=[["spire_sentinel", "signal_husk"], ["the_conductor", "chief_medic"]],
                   requires_stage_id="s3", pre_dialogue_id="z4_boss_pre",
                   post_dialogue_id="finale",
                   first_clear_xp_bonus=1000, first_clear_item="aegis_node"),
}

ZONES = {
    "vesper": dict(display_name="Salvage Barge Vesper", order=0, theme_color=Color("2b3a4d"),
                   description="A rust-bitten salvage barge adrift on a chemical sea. You woke up here. Something else woke up first.",
                   stages=["v1", "v2", "v3", "v_training", "v_boss"]),
    "refinery": dict(display_name="Drowned Refinery", order=1, theme_color=Color("2d4d40"),
                     description="Half-sunk processing towers, still running on nobody's orders. The signal grows louder below the waterline.",
                     stages=["r1", "r2", "r3", "r_training", "r_boss"],
                     unlocked_by_zone_id="vesper"),
    "quarantine": dict(display_name="The Quarantine Line", order=2, theme_color=Color("4d3a2b"),
                       description="A wall built to keep the signal in — or everyone else out. Its keepers stopped asking which long ago.",
                       stages=["q1", "q2", "q3", "q_training", "q_boss"],
                       unlocked_by_zone_id="refinery"),
    "spire": dict(display_name="Relay Spire", order=3, theme_color=Color("3a2b4d"),
                  description="The source. Every antenna for a hundred miles bends toward it like grass in wind.",
                  stages=["s1", "s2", "s3", "s_training", "s_boss"],
                  unlocked_by_zone_id="quarantine"),
}

TREES = {
    "havoc": dict(display_name="Havoc", theme_color=Color("ef5350"),
                  description="Physical destruction: burst damage, bleeds, and stuns.",
                  entries=[
                      {"ability_id": "rend", "tier": 1, "level_req": 1},
                      {"ability_id": "crack", "tier": 1, "level_req": 2},
                      {"ability_id": "overload_strike", "tier": 2, "level_req": 4},
                      {"ability_id": "concuss", "tier": 2, "level_req": 6},
                      {"ability_id": "frenzy_skill", "tier": 3, "level_req": 9},
                      {"ability_id": "executioner", "tier": 4, "level_req": 13},
                  ]),
    "surge": dict(display_name="Surge", theme_color=Color("64b5f6"),
                  description="Psy offense: nukes, damage over time, and focus theft.",
                  entries=[
                      {"ability_id": "static_bolt", "tier": 1, "level_req": 1},
                      {"ability_id": "corrode", "tier": 1, "level_req": 3},
                      {"ability_id": "drain_pulse", "tier": 2, "level_req": 5},
                      {"ability_id": "chain_arc", "tier": 2, "level_req": 7},
                      {"ability_id": "mind_spike", "tier": 3, "level_req": 10},
                      {"ability_id": "cascade", "tier": 4, "level_req": 14},
                  ]),
    "bastion": dict(display_name="Bastion", theme_color=Color("66bb6a"),
                    description="Protection: heals, shields, taunts, and cleanses.",
                    entries=[
                        {"ability_id": "mend", "tier": 1, "level_req": 1},
                        {"ability_id": "barrier_skill", "tier": 1, "level_req": 2},
                        {"ability_id": "provoke", "tier": 2, "level_req": 5},
                        {"ability_id": "purge", "tier": 3, "level_req": 8},
                        {"ability_id": "rally_skill", "tier": 3, "level_req": 11},
                        {"ability_id": "second_wind", "tier": 4, "level_req": 15},
                    ]),
}

# ---------------------------------------------------------------- dialogue
DIALOGUE = {
    "intro": [
        ("???", "Power at four percent. Core integrity... acceptable. Wake up."),
        ("S-7", "...Where is this? Who—"),
        ("Echo", "I'm Echo. Ship intelligence, what's left of one. You're Unit S-7, and you were cargo until ten minutes ago."),
        ("Echo", "Something in the hold woke before you did, and it isn't friendly. The exit is aft. Make yourself useful."),
    ],
    "z1_mid": [
        ("Echo", "The engine room is crawling. Whatever signal woke you is coming from off-ship — these things are just... resonating with it."),
        ("S-7", "Resonating. Like me?"),
        ("Echo", "Let's hope not exactly like you."),
    ],
    "z1_boss_pre": [
        ("Echo", "The loading foreman was a rig twice your size before the signal got into it. It's blocking the only launch."),
        ("S-7", "Then it moves, or I do."),
    ],
    "z1_boss_post": [
        ("Echo", "Launch is clear. The signal's source bearing puts it past the old refinery."),
        ("S-7", "I keep hearing it. Under everything. Like a name I almost remember."),
        ("Echo", "That's what worries me."),
    ],
    "z2_intro": [
        ("Echo", "Drowned Refinery. It was abandoned decades ago, but the towers are still running. Someone — something — is drawing power."),
    ],
    "z2_ally": [
        ("???", "Hold fire! You're not one of the husks."),
        ("Vela", "Name's Vela. Scavenger, currently un-eaten, planning to keep it that way. You're heading toward the signal? So is everything else."),
        ("Vela", "I know these flooded halls. Take me along and I'll burn a path."),
    ],
    "z2_boss_pre": [
        ("Vela", "The Custodian runs the refinery's defenses. It used to protect workers. Now it just... protects."),
        ("Echo", "It will repair itself. Cut down its shields first or you'll be here all week."),
    ],
    "z3_intro": [
        ("Echo", "The Quarantine Line. Built when the signal first appeared. The exo units still hold it — and they don't check credentials anymore."),
    ],
    "z3_ally": [
        ("Brick", "You broke the kennels. Those hounds were going to be released on the refugees down the coast."),
        ("Brick", "I was a line medic before the Warden sealed the gates. People out there still need me — but nothing gets through while he stands. I'll shield you to him."),
    ],
    "z3_boss_pre": [
        ("Brick", "Warden Khros was the best of us. He believes he's still saving the world."),
        ("S-7", "Then I'll be quick."),
    ],
    "z4_intro": [
        ("Echo", "The Relay Spire. The signal isn't coming from it, S-7. It's coming from something inside it, using the antennas like a throat."),
        ("S-7", "It's been calling me since the barge."),
        ("Vela", "Then let's go answer rudely."),
    ],
    "z4_boss_pre": [
        ("The Conductor", "Unit S-7. The last instrument arrives, self-delivering. Your frame was built to carry my chorus."),
        ("S-7", "I'm not an instrument. And this is my frame."),
        ("The Conductor", "Then we will see which of us conducts."),
    ],
    "finale": [
        ("Echo", "Signal terminated. Every husk for a hundred miles just went quiet."),
        ("Vela", "So what now, S-7? You were built for its chorus and you ended the concert."),
        ("S-7", "Now? Whatever I choose. That's the whole point."),
        ("Echo", "Power at one hundred percent. Core integrity: yours. Welcome back."),
    ],
}


# ---------------------------------------------------------------- writers
def fmt(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        s = f"{value:.6g}"
        return s + ".0" if "." not in s and "e" not in s else s
    if isinstance(value, int):
        return str(value)
    if isinstance(value, str):
        return '"%s"' % value.replace("\\", "\\\\").replace('"', '\\"')
    if isinstance(value, Color):
        return f"Color({value.r:.6g}, {value.g:.6g}, {value.b:.6g}, 1)"
    if isinstance(value, dict):
        inner = ", ".join(f"{fmt(k)}: {fmt(v)}" for k, v in value.items())
        return "{%s}" % inner
    if isinstance(value, list):
        return "[%s]" % ", ".join(fmt(v) for v in value)
    raise TypeError(f"cannot serialize {value!r}")


class TresWriter:
    def __init__(self, script_class, script_path):
        self.script_class = script_class
        self.script_path = script_path
        self.ext = {}  # path -> (id, type)

    def ext_id(self, path, rtype="Resource"):
        if path not in self.ext:
            self.ext[path] = (str(len(self.ext) + 2), rtype)
        return self.ext[path][0]

    def render(self, value):
        if isinstance(value, Ref):
            return f'ExtResource("{self.ext_id(f"res://data/{value.kind}/{value.rid}.tres")}")'
        if isinstance(value, list):
            return "[%s]" % ", ".join(self.render(v) for v in value)
        if isinstance(value, dict):
            inner = ", ".join(f"{fmt(k)}: {self.render(v)}" for k, v in value.items())
            return "{%s}" % inner
        return fmt(value)


class RawValue:
    def __init__(self, text):
        self.text = text


def main():
    # Statuses
    for rid, data in STATUSES.items():
        w = TresWriter("StatusEffectData", "res://src/data/status_effect_data.gd")
        fields = {"id": rid}
        flags = data.pop("flags", None)
        fields.update(data)
        if flags:
            fields["flags"] = RawValue("Array[String]([%s])" % ", ".join(fmt(v) for v in flags))
        _write(w, "statuses", rid, fields)

    for rid, data in ABILITIES.items():
        w = TresWriter("AbilityData", "res://src/data/ability_data.gd")
        fields = {"id": rid}
        fields.update(data)
        _write(w, "abilities", rid, fields)

    for rid, data in ITEMS.items():
        w = TresWriter("ItemData", "res://src/data/item_data.gd")
        fields = {"id": rid}
        fields.update(data)
        _write(w, "items", rid, fields)

    for rid, data in ENEMIES.items():
        w = TresWriter("EnemyData", "res://src/data/enemy_data.gd")
        fields = {"id": rid}
        fields.update(data)
        fields["abilities"] = [Ref("abilities", a) for a in data["abilities"]]
        _write(w, "enemies", rid, fields)

    for rid, data in STAGES.items():
        w = TresWriter("StageData", "res://src/data/stage_data.gd")
        fields = {"id": rid}
        fields.update(data)
        fields["waves"] = [[Ref("enemies", e) for e in wave] for wave in data["waves"]]
        if "first_clear_item" in data:
            fields["first_clear_item"] = Ref("items", data["first_clear_item"])
        _write(w, "stages", rid, fields)

    for rid, data in ZONES.items():
        w = TresWriter("ZoneData", "res://src/data/zone_data.gd")
        fields = {"id": rid}
        fields.update(data)
        fields["stages"] = [Ref("stages", s) for s in data["stages"]]
        _write(w, "zones", rid, fields)

    for rid, data in TREES.items():
        w = TresWriter("AbilityTreeData", "res://src/data/ability_tree_data.gd")
        fields = {"id": rid}
        fields.update(data)
        _write(w, "trees", rid, fields)

    import json
    dialogue_dir = os.path.join(ROOT, "data", "dialogue")
    os.makedirs(dialogue_dir, exist_ok=True)
    for rid, lines in DIALOGUE.items():
        payload = {"id": rid, "lines": [{"speaker": s, "text": t} for s, t in lines]}
        with open(os.path.join(dialogue_dir, f"{rid}.json"), "w") as f:
            json.dump(payload, f, indent=2)
            f.write("\n")

    total = sum(len(s) for s in [STATUSES, ABILITIES, ITEMS, ENEMIES, STAGES, ZONES, TREES, DIALOGUE])
    print(f"Generated {total} content files under data/")


def _write(writer, kind, rid, fields):
    out = {}
    for k, v in fields.items():
        out[k] = v.text if isinstance(v, RawValue) else writer.render(v)
    lines = [f"{k} = {v}" for k, v in out.items()]
    ext_lines = [f'[ext_resource type="Script" path="{writer.script_path}" id="1"]']
    for path, (eid, rtype) in writer.ext.items():
        ext_lines.append(f'[ext_resource type="{rtype}" path="{path}" id="{eid}"]')
    header = (f'[gd_resource type="Resource" script_class="{writer.script_class}" '
              f'load_steps={len(ext_lines) + 1} format=3]')
    content = header + "\n\n" + "\n".join(ext_lines) + "\n\n[resource]\n"
    content += 'script = ExtResource("1")\n' + "\n".join(lines) + "\n"
    out_path = os.path.join(ROOT, "data", kind, f"{rid}.tres")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w") as f:
        f.write(content)


if __name__ == "__main__":
    main()
