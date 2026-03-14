extends Resource
class_name ItemData

# res://data/resources/item_data.gd
# Standardized resource for all non-card items (Equipment, Consumables, Materials).

@export_group("Identity")
@export var item_id: String = ""
@export var name: String = "Unknown Item"
@export var name_es: String = ""
@export var name_fr: String = ""
@export var name_de: String = ""
@export_enum("Material", "Consumable", "Weapon", "Armour", "Utility") var type: String = "Material"
@export var level: int = 1

@export_group("Combat Stats")
@export var item_power: int = 0
@export var hp: int = 0
@export var attack: int = 0
@export var armour: int = 0
@export var energy: int = 0
@export var effect: String = "None"

@export_group("Description & Flavor")
@export_multiline var description: String = ""
## The prompt used to generate the item's visual asset.
@export_multiline var ai_prompt: String = ""

@export_group("Visual Assets")
## High resolution representation for inventory inspection.
@export var item_image: Texture2D 
## Small representation for UI lists and loot notifications.
@export var item_icon: Texture2D
