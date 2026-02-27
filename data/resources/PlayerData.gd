extends Resource
class_name PlayerData

# res://data/resources/player_data.gd
# Specialized resource for visual and mechanical character templates.

@export_group("Identity")
@export_enum("Archivist", "Berserker", "Illusionist") var player_class: String = "Archivist"
@export_enum("base", "leather", "armour", "gold", "final") var stage: String = "base"
@export_multiline var description: String = ""

@export_group("Base Stats")
@export var base_hp: int = 100
@export var base_attack: int = 10
@export var base_defense: int = 5

@export_group("Visuals")
@export var idle_sheet: Texture2D
@export var attack_sheet: Texture2D
@export var defend_sheet: Texture2D

@export_group("Animation Metadata")
@export var hframes: int = 8 
@export var vframes: int = 1
@export var total_frames: int = 8
@export var frame_speed: float = 0.1