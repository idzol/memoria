extends Resource
class_name CardAssetData

# res://data/resources/card_asset_data.gd
# Specialized resource to track Card UI templates for auditing and dynamic skinning.

@export_group("Card Backs")
@export var card_back_common: Texture2D
@export var card_back_uncommon: Texture2D
@export var card_back_rare: Texture2D
@export var card_back_epic: Texture2D
@export var card_back_unique: Texture2D

@export_group("Card Back Icons")
@export var card_back_common_icon: Texture2D
@export var card_back_uncommon_icon: Texture2D
@export var card_back_rare_icon: Texture2D
@export var card_back_epic_icon: Texture2D
@export var card_back_unique_icon: Texture2D

@export_group("Card Fronts")
@export var card_front: Texture2D
@export var card_front_default: Texture2D
@export var card_front_common: Texture2D
@export var card_front_uncommon: Texture2D
@export var card_front_rare: Texture2D
@export var card_front_epic: Texture2D
@export var card_front_unique: Texture2D
@export var card_front_enemy: Texture2D
@export_group("Card Front Icons (Type)")
@export var card_front_attack_icon: Texture2D
@export var card_front_defend_icon: Texture2D
@export var card_front_heal_icon: Texture2D
@export var card_front_spell_icon: Texture2D

@export_group("Card Front Icons (Rarity-Type)")
@export var card_front_common_attack_icon: Texture2D
@export var card_front_common_defend_icon: Texture2D
