extends Resource
class_name CardData

# res://data/resources/card_data.gd
# Standardized resource for all game cards (Combat, Loot, Spells).

@export_group("Identity")
@export var card_id: String = ""
@export var name: String = "Unknown Card"
@export_enum("attack", "armor", "heal", "trap", "utility", "charge", "treasure") var type: String = "attack"

@export_group("Stats & Effects")
@export var value: int = 0
@export_multiline var description: String = ""
@export var special_effect: String = ""

@export_group("Visual Assets")
## High resolution art used for the deck view or card inspection
@export var card_image: Texture2D 
## Smaller, optimized icon used on the matching grid
@export var card_icon: Texture2D