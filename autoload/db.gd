extends Node
## Content registry. Loads every .tres under res://data/ at startup and
## indexes resources by their `id` field so saves can store ids only.

var abilities: Dictionary = {}
var statuses: Dictionary = {}
var enemies: Dictionary = {}
var items: Dictionary = {}
var stages: Dictionary = {}
var zones: Dictionary = {}
var trees: Dictionary = {}

var _loaded := false


func _ready() -> void:
	load_all()


func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	_load_dir("res://data/abilities", abilities)
	_load_dir("res://data/statuses", statuses)
	_load_dir("res://data/enemies", enemies)
	_load_dir("res://data/items", items)
	_load_dir("res://data/stages", stages)
	_load_dir("res://data/zones", zones)
	_load_dir("res://data/trees", trees)


func _load_dir(path: String, registry: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			# Exported builds list .tres files as .tres.remap; load() resolves both.
			var res_name := fname.trim_suffix(".remap")
			if res_name.ends_with(".tres"):
				var res: Resource = load(path + "/" + res_name)
				if res == null:
					push_error("Db: failed to load %s/%s" % [path, res_name])
				else:
					var id: String = res.get("id")
					if id == null or id == "":
						push_error("Db: resource %s/%s has no id" % [path, res_name])
					elif registry.has(id):
						push_error("Db: duplicate id '%s' in %s" % [id, path])
					else:
						registry[id] = res
		fname = dir.get_next()
	dir.list_dir_end()


func ability(id: String) -> Resource:
	return abilities.get(id)


func status(id: String) -> Resource:
	return statuses.get(id)


func enemy(id: String) -> Resource:
	return enemies.get(id)


func item(id: String) -> Resource:
	return items.get(id)


func stage(id: String) -> Resource:
	return stages.get(id)


func zone(id: String) -> Resource:
	return zones.get(id)


func tree_data(id: String) -> Resource:
	return trees.get(id)
