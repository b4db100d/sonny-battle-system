class_name RngService
extends RefCounted
## Seedable RNG wrapper so battles are deterministic in tests/simulations.

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func chance(probability: float) -> bool:
	return _rng.randf() < probability


func pick(arr: Array) -> Variant:
	return arr[_rng.randi_range(0, arr.size() - 1)]


## Weighted pick: entries [{..., "weight": float}]. Returns null on empty.
func pick_weighted(entries: Array) -> Variant:
	if entries.is_empty():
		return null
	var total := 0.0
	for e in entries:
		total += float(e.get("weight", 1.0))
	var roll := _rng.randf() * total
	for e in entries:
		roll -= float(e.get("weight", 1.0))
		if roll <= 0.0:
			return e
	return entries.back()
