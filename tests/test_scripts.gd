extends "res://tests/test_base.gd"
## Loads every .gd in the project so parse/compile errors fail CI even for
## scripts no other test exercises.


func test_all_scripts_compile() -> void:
	var paths := _find_scripts(["res://autoload", "res://src", "res://scenes", "res://tests"])
	assert_true(paths.size() >= 10, "expected scripts, found %d" % paths.size())
	for path in paths:
		var script: GDScript = load(path)
		if script == null:
			fail("failed to load script: " + path)
			continue
		assert_true(script.can_instantiate(), "script does not compile: " + path)


func _find_scripts(roots: Array) -> Array[String]:
	var found: Array[String] = []
	var dirs: Array = roots.duplicate()
	while not dirs.is_empty():
		var current: String = dirs.pop_back()
		var dir := DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			var full := current + "/" + fname
			if dir.current_is_dir():
				dirs.append(full)
			elif fname.ends_with(".gd"):
				found.append(full)
			fname = dir.get_next()
		dir.list_dir_end()
	return found
