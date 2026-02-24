extends Resource
class_name PlayerData

# res://data/resources/PlayerData.gd
# Specialized resource for visual progression tiers.

@export_group("Progression")
@export_enum("Archivist", "Berserker", "Illusionist") var player_class: String = "Archivist"
@export_enum("base", "leather", "armour", "gold", "final") var stage: String = "base"
@export_multiline var description: String = ""

@export_group("Visuals")
@export var idle_sheet: Texture2D
@export var attack_sheet: Texture2D
@export var defend_sheet: Texture2D

@export_group("Animation Metadata")
@export var hframes: int = 8 
@export var vframes: int = 1
@export var total_frames: int = 8
@export var frame_speed: float = 0.1