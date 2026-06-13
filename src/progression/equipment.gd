class_name Equipment
extends RefCounted
## Equip/unequip operations on profile dictionaries. Slot keys are lowercase
## strings ("weapon", "head", ...) so profiles stay JSON-friendly.


static func slot_key(slot: int) -> String:
	return ItemData.slot_name(slot).to_lower()


static func can_equip(profile: Dictionary, item: ItemData) -> bool:
	return int(profile.get("level", 1)) >= item.level_req


## Moves item from inventory into its slot; previous occupant returns to
## inventory. Returns false if requirements fail or item isn't owned.
static func equip(profile: Dictionary, item: ItemData) -> bool:
	if not can_equip(profile, item):
		return false
	var inventory: Array = profile.get("inventory", [])
	if not item.id in inventory:
		return false
	var equipped: Dictionary = profile.get("equipped", {})
	var key := slot_key(item.slot)
	inventory.erase(item.id)
	if equipped.has(key):
		inventory.append(equipped[key])
	equipped[key] = item.id
	return true


static func unequip(profile: Dictionary, key: String) -> void:
	var equipped: Dictionary = profile.get("equipped", {})
	if equipped.has(key):
		profile.get("inventory", []).append(equipped[key])
		equipped.erase(key)
