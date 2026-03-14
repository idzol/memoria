extends Resource
class_name EnemyData

# res://data/resources/enemy_data.gd
# The enhanced template for characters, supporting animations, audio, and narrative events.

@export_group("Identity")
@export var name: String = "Unknown Foe"
@export var name_es: String = ""
@export var name_fr: String = ""
@export var name_de: String = ""
@export var biome: String = "town"

@export_group("Combat Stats")
@export var hp: int = 50
@export var armor: int = 0
@export var base_damage: int = 10
@export var difficulty_tier: int = 1 ## Determines board size (e.g. 1=3x3, 3=4x4, 6=5x5)
@export var xp_reward: int = 25
@export var probabilities: Array[float] = [0.6, 0.2, 0.1, 0.1] ## [Atk, Strong Atk, Debuff, Pass]
@export var abilities: Array[String] = ["strike"]

@export_group("Visual Assets")
@export var idle_sheet: Texture2D
@export var attack_sheet: Texture2D
@export var defend_sheet: Texture2D
@export var hframes: int = 4
@export var vframes: int = 5
@export var total_frames: int = 18
@export var frame_speed: float = 0.1

@export_group("Audio Assets")
@export var attack_sound: AudioStream
@export var defend_sound: AudioStream

@export_group("Loot")
@export var loot_power: int = 0
@export var gold_min: int = 10
@export var gold_max: int = 25
@export var item_drops: Array[String] = []

@export_group("Interaction")
@export_multiline var initial_dialog: String = "..."
## Logic for branching events: e.g. {"hp_below_50": "enrage", "on_death": "spawn_minions"}
@export var conditional_events: Dictionary = {}
