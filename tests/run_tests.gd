extends SceneTree
## Headless test runner: godot --headless --path . -s res://tests/run_tests.gd
## Discovers tests/test_*.gd, runs every test_* method, exits 1 on any failure.

const TESTS_DIR := "res://tests"


func _initialize() -> void:
	var total_tests := 0
	var total_asserts := 0
	var all_failures: Array[String] = []

	for script_path in _discover():
		var script: GDScript = load(script_path)
		if script == null:
			all_failures.append("%s: failed to load" % script_path)
			continue
		var case: RefCounted = script.new()
		for method in case.get_method_list():
			var mname: String = method["name"]
			if not mname.begins_with("test_"):
				continue
			total_tests += 1
			case._current_test = "%s::%s" % [script_path.get_file(), mname]
			case.call(mname)
		total_asserts += case.assert_count
		for f in case.failures:
			all_failures.append(f)

	print("")
	print("==== %d tests, %d asserts, %d failures ====" % [total_tests, total_asserts, all_failures.size()])
	for f in all_failures:
		printerr("FAIL  " + f)
	if total_tests == 0:
		printerr("FAIL  no tests discovered")
	quit(1 if (all_failures.size() > 0 or total_tests == 0) else 0)


func _discover() -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		return found
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.begins_with("test_") and fname.ends_with(".gd") and fname != "test_base.gd":
			found.append(TESTS_DIR + "/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found
