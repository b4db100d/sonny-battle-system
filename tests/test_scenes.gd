extends "res://tests/test_base.gd"
## Loads and instantiates every .tscn in the project (without adding to a tree,
## so _ready never runs). Catches hand-authored scene/script errors headlessly.


func test_all_scenes_instantiate() -> void:
	var paths := _find_scenes("res://scenes")
	assert_true(paths.size() >= 3, "expected scenes to exist, found %d" % paths.size())
	for path in paths:
		var packed: PackedScene = load(path)
		if packed == null:
			fail("failed to load scene: " + path)
			continue
		assert_true(packed.can_instantiate(), "cannot instantiate " + path)
		var node := packed.instantiate()
		assert_true(node != null, "instantiate returned null for " + path)
		if node != null:
			node.free()


func _find_scenes(root: String) -> Array[String]:
	var found: Array[String] = []
	var dirs: Array[String] = [root]
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
			elif fname.ends_with(".tscn"):
				found.append(full)
			fname = dir.get_next()
		dir.list_dir_end()
	return found
