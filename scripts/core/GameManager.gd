extends Node

# res://scripts/core/GameManager.gd
# Central state management for character and run progression.

# --- Character State ---
var player_name: String = ""
var player_class: String = "Archivist"
var current_hp: int = 100
var max_hp: int = 100
var gold: int = 50
var player_inventory: Array = ["sword", "shield", "heart", "trap", "scroll"]

# --- Run Progression ---
var current_level: int = 1
var completed_nodes: Array = []
var current_node: Dictionary = {}

# Tracking player by grid coordinates: x = column (0-4), y = layer (-1 to 19)
# Home is at Layer -1, Column 2 (Center)
var player_grid_pos: Vector2i = Vector2i(2, -1) 
var active_deck: Array = []

# Persistent "Fixed" locations that stay the same for this character
# Format: { Vector2i(column, layer): "type_string" }
var fixed_nodes: Dictionary = {}

func _ready():
	SignalBus.node_selected.connect(_on_node_selected)
	SignalBus.combat_won.connect(_on_combat_won)
	SignalBus.combat_lost.connect(_on_combat_lost)

func start_actual_run():
	current_hp = max_hp
	gold = 50
	current_level = 1
	completed_nodes = []
	player_grid_pos = Vector2i(2, -1) # Ensure player starts at Home
	active_deck = ["sword", "shield", "heart", "frost", "scroll", "trap"]
	
	# INITIALIZE FIXED NODES:
	# Certain squares become "fixed" over time or are guaranteed by the map design
	fixed_nodes.clear()
	# Requirement: First mapnode (center of first layer) is always a Town Square
	fixed_nodes[Vector2i(2, 0)] = "town_square"
	
	SaveManager.save_mid_run_state()
	get_tree().change_scene_to_file("res://scenes/map/WorldMap.tscn")

func load_run_from_data(data: Dictionary):
	player_name = data.get("player_name", "Unknown")
	player_class = data.get("player_class", "Archivist")
	current_hp = data.get("hp", 100)
	max_hp = data.get("max_hp", 100)
	gold = data.get("gold", 0)
	current_level = data.get("current_level", 1)
	completed_nodes = data.get("completed_nodes", [])
	
	# Restore fixed node data
	fixed_nodes = data.get("fixed_nodes", {})
	
	var saved_pos = data.get("grid_pos", [2, -1])
	player_grid_pos = Vector2i(saved_pos[0], saved_pos[1])
	
	get_tree().change_scene_to_file("res://scenes/map/WorldMap.tscn")

func _on_node_selected(node_data: Dictionary):
	current_node = node_data
	if node_data.get("type") == "home": return

	match node_data.get("type", "battle"):
		"battle", "boss":
			get_tree().change_scene_to_file("res://scenes/combat/BattleScene.tscn")
		"shop", "town_square": # Town Square functions as a safe hub/shop
			get_tree().change_scene_to_file("res://scenes/encounters/ShopScene.tscn")
		"rest":
			get_tree().change_scene_to_file("res://scenes/encounters/RestScene.tscn")
		"event":
			get_tree().change_scene_to_file("res://scenes/encounters/EventScene.tscn")
			
	SaveManager.save_mid_run_state()

func _on_combat_won():
	gold += 25
	if current_node.has("id"):
		completed_nodes.append(current_node.id)
		# Update grid position on victory
		player_grid_pos = Vector2i(current_node.column, current_node.layer)
		
	SaveManager.save_mid_run_state()
	get_tree().change_scene_to_file("res://scenes/map/WorldMap.tscn")

func _on_combat_lost():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/DeathScreen.tscn")

func take_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	SignalBus.hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		SignalBus.combat_lost.emit()

# Helper function for MapGenerator to check for specific overrides
func get_fixed_type(col: int, layer: int) -> String:
	var pos = Vector2i(col, layer)
	return fixed_nodes.get(pos, "")