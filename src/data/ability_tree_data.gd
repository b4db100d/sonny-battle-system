class_name AbilityTreeData
extends Resource
## A skill tree: ordered ability entries with unlock requirements.
## Unlock rule: player level >= level_req AND points already spent in this
## tree >= points_required_for_tier(tier).

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var theme_color: Color = Color.WHITE

## Entries: [{"ability_id": String, "tier": int, "level_req": int}, ...]
@export var entries: Array = []


func points_required_for_tier(tier: int) -> int:
	# Tiers are reachable with 6 abilities per tree: 0/1/3/5 points.
	return [0, 0, 1, 3, 5][clampi(tier, 1, 4)]
