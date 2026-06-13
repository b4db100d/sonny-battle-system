class_name ZoneData
extends Resource
## A chapter of the campaign: themed group of stages.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var theme_color: Color = Color("1d3a4f")
@export var order: int = 0

## Array of StageData in display order (untyped for .tres authoring).
@export var stages: Array = []
## Zone whose boss must be cleared before this zone unlocks; "" = start zone.
@export var unlocked_by_zone_id: String = ""
