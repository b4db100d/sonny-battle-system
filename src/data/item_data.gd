class_name ItemData
extends Resource
## Equipment definition. Flat stat bonuses summed into StatBlock.

enum Slot { WEAPON, HEAD, BODY, LEGS, HANDS, TRINKET }
enum Rarity { COMMON, UNCOMMON, RARE }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var slot: Slot = Slot.WEAPON
@export var rarity: Rarity = Rarity.COMMON
@export var level_req: int = 1
@export var icon_color: Color = Color.GRAY

## Flat bonuses: keys are "strength", "instinct", "speed", "vitality",
## "max_hp", "focus_regen", "crit_chance", "dodge".
@export var stat_bonuses: Dictionary = {}


static func slot_name(s: Slot) -> String:
	return ["Weapon", "Head", "Body", "Legs", "Hands", "Trinket"][s]


func rarity_color() -> Color:
	match rarity:
		Rarity.UNCOMMON:
			return Color("4caf50")
		Rarity.RARE:
			return Color("42a5f5")
		_:
			return Color("b0bec5")
