class_name EnemyData
extends Resource
## Definition of an enemy type. Placeholder art = body_shape polygon tinted body_color.

enum AiProfile { BRUTE, CASTER, HEALER, DISRUPTOR }
enum BodyShape { BLOCK, SPIKE, ORB, WIDE, TALL }

@export var id: String = ""
@export var display_name: String = ""
@export var body_color: Color = Color.RED
@export var body_shape: BodyShape = BodyShape.BLOCK

@export var level: int = 1
@export var strength: int = 5
@export var instinct: int = 5
@export var speed: int = 5
@export var vitality: int = 5

## Array of AbilityData (untyped for easy .tres authoring).
@export var abilities: Array = []
@export var ai_profile: AiProfile = AiProfile.BRUTE

@export var xp_reward: int = 20
@export var credit_reward: int = 5
## Chance that this enemy drops anything at all.
@export var loot_chance: float = 0.25
## Weighted entries: [{"item_id": String, "weight": float}, ...]
@export var loot_table: Array = []
