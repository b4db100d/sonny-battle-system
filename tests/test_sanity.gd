extends "res://tests/test_base.gd"
## Toolchain sanity checks: the runner discovers tests and autoload scripts load.


func test_runner_works() -> void:
	assert_eq(1 + 1, 2)


func test_autoload_scripts_parse() -> void:
	for path in [
		"res://autoload/event_bus.gd",
		"res://autoload/db.gd",
		"res://autoload/game_state.gd",
		"res://autoload/save_manager.gd",
		"res://autoload/audio_manager.gd",
		"res://autoload/scene_router.gd",
	]:
		var script: GDScript = load(path)
		assert_true(script != null and script.can_instantiate(), "script should load: " + path)
