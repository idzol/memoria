extends Resource
class_name RoomData

# res://data/resources/RoomData.gd
# The template for creating hand-crafted encounters.

@export_group("Identity")
@export var room_name: String = "Unknown Area"
@export_enum("battle", "event", "shop", "rest", "boss") var type: String = "battle"

@export_group("Narrative")
@export_multiline var initial_dialog: String = "A sense of dread fills the air."
@export var dialog_tree_id: String = "" # Refers to GameData.DIALOG_TREES

@export_group("Combat")
@export var enemy_id: String = "pickpocket" # Refers to GameData.ENEMIES
@export var difficulty_override: int = -1 # -1 uses map layer difficulty

@export_group("Visuals")
@export var background_texture: Texture2D
@export var music_track: String = "battle_theme"