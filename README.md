# Static Protocol

A mobile-first, turn-based battle RPG for Android, built with
**Godot 4.4** — an original game inspired by the classic Flash-era
turn-based battle games (Sonny et al.).

You are **Unit S-7**, a derelict combat synthetic that wakes on the
salvage barge *Vesper* with fragmented memory and a signal in its head.
Fight through four zones, level up, spec into three skill trees, collect
equipment, recruit two allies, and silence the Conductor.

## Features

- Turn-based party combat: focus costs, cooldowns, crits, dodges,
  bleeds/DoTs, stuns, shields, taunts, dispels, multi-wave fights
- 4 zones × 5 stages (16 story battles + 4 re-fightable training stages)
- 21 enemy types with profile-driven AI (brutes, casters, healers,
  disruptors) and three difficulty settings
- Leveling to 24 with free respec; 3 skill trees × 6 abilities; 26
  equipment items across 6 slots; loot drops
- Two recruitable allies with their own kits (you control them in battle)
- Touch-first UI (tap ability → tap target), landscape, any aspect ratio
- Save slots (JSON, autosave after battles)

## Run it

Desktop (for development):

```bash
tools/setup_godot.sh           # one-time: downloads Godot 4.4.1 to .godot-bin/
.godot-bin/godot --path .      # play windowed (mouse simulates touch)
```

Or open the project folder in the Godot 4.4.1 editor.

**Android:** see [docs/ANDROID_EXPORT.md](docs/ANDROID_EXPORT.md). The
export preset is committed; you need the (one-time) export templates +
Android SDK setup, then:

```bash
.godot-bin/godot --headless --path . --export-debug "Android" build/static-protocol-debug.apk
adb install build/static-protocol-debug.apk
```

## Develop

```bash
tools/validate.sh              # import + full headless test suite
python3 tools/gen_content.py   # regenerate data/*.tres from the content spec
```

- Architecture overview: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- All balance numbers live in `tools/gen_content.py`; the campaign
  simulator (`tests/test_campaign_sim.gd`) prints a win-rate table to
  sanity-check changes.

## Project status

Gameplay is complete and headlessly tested end-to-end. Art and audio are
intentionally placeholder (colored shapes, silent stubs) — the code is
structured so sprites and sounds can be dropped in without touching game
logic.
