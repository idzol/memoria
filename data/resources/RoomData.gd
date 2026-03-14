extends Resource
class_name RoomData

# res://data/resources/room_data.gd
# Enhanced template for hand-crafted encounters with direct asset references.

@export_group("Identity")
@export var room_name: String = "Unknown Area"
@export_enum("battle", "event", "shop", "rest", "boss", "lore") var type: String = "battle"
@export var biome: String = "town"

@export_group("Narrative")
@export_multiline var initial_dialog: String = "A sense of dread fills the air."
@export var dialog_tree_id: String = ""

@export_group("Encounters")
@export var enemy_id: String = ""
@export var npc_id: String = ""
@export var difficulty_override: int = -1

@export_group("Rewards")
@export var loot_list: Array[String] = []
@export var complete_condition: Dictionary = {}

@export_group("Visuals")
## Icon used on the World Map (res://assets/room/{biome}/{id}_map.png)
@export var map_icon: Texture2D 
## Background for the scene (res://assets/room/{biome}/{id}_scene.png)
@export var background_texture: Texture2D
@export var music_track: String = "battle_theme"
