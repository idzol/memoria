extends Resource
class_name NPCData

# res://data/resources/NPCData.gd
# The template for non-player characters.
# UPDATED: Aligned defaults with the 8x1 spritemap convention.

@export_group("Identity")
@export var name: String = "Stranger"
@export_enum("Villager", "Merchant", "Guard", "QuestGiver", "Archivist") var role: String = "Villager"
@export var biome: String = "town"

@export_group("Visuals")
@export var idle_sheet: Texture2D ## Default idle spritesheet
@export var talk_sheet: Texture2D ## Animation for when the dialog box is active
@export var interact_sheet: Texture2D ## Unique animation (e.g. waving or pointing)

# UPDATED: Defaults now match your 8x1 convention to prevent scaling/slicing bugs
@export var hframes: int = 8 
@export var vframes: int = 1
@export var total_frames: int = 8
@export var frame_speed: float = 0.1

@export_group("Audio")
@export var voice_pitch: float = 1.0 ## Modifier for the 'typing' sound in dialog
@export var ambient_sound: AudioStream ## Sounds the NPC makes while idling

@export_group("Dialogue & Narrative")
@export_multiline var initial_greeting: String = "Hello, traveler."
@export var dialog_tree_id: String = "" ## Reference to GameData.DIALOG_TREES
@export var flavor_text: Array[String] = [] 

@export_group("Economy / Trade")
@export var is_merchant: bool = false
## Dictionary of Card/Item IDs and their Gold prices: e.g. {"sword": 50, "potion": 15}
@export var wares: Dictionary = {}
@export var buy_multiplier: float = 1.0 

@export_group("RPG Logic & Persistence")
## Requirements for interaction (if/then): e.g. {"has_item": "town_seal", "min_level": 5}
@export var interaction_requirements: Dictionary = {}
## Rewards or world changes: e.g. {"give_item": "rusty_key", "trigger_signal": "gate_opened"}
@export var interaction_consequences: Dictionary = {}
## Key used in SaveManager to track if this NPC has been met or helped
@export var persistence_key: String = "npc_met_default"

@export_group("Stats (Optional)")
@export var hp: int = 100 
@export var gold_on_hand: int = 200